"""One isolated tmux server per interactive launch. No PTY input interception."""

import json
import os
import re
import shutil
import signal
import subprocess
import sys
import tempfile
import threading
import time
import uuid
from pathlib import Path

from .hook import atomic_json

ENTRY = Path(__file__).resolve().parent / "entry.py"
TITLE = 'tui.terminal_title=["model","context-used","thread-id","thread-name"]'
NONINTERACTIVE = {
    "agents",
    "plugin",
    "remote-control",
    "queue",
    "delete",
    "unarchive",
    "migrate-nfs-db",
    "exec-server",
    "exec",
    "e",
    "review",
    "login",
    "logout",
    "mcp",
    "mcp-server",
    "app",
    "app-server",
    "completion",
    "sandbox",
    "debug",
    "apply",
    "a",
    "cloud",
    "cloud-tasks",
    "features",
    "archive",
    "help",
    "update",
    "migrate-rollouts",
}
VALUE_FLAGS = {
    "-c",
    "--config",
    "-m",
    "--model",
    "-p",
    "--profile",
    "-s",
    "--sandbox",
    "-a",
    "--ask-for-approval",
    "-C",
    "--cd",
    "-i",
    "--image",
    "--add-dir",
    "--enable",
    "--disable",
    "--remote-auth-token-env",
}


def official():
    override = os.environ.get("CODEX_STATUSLINE_CODEX")
    path = override or shutil.which("codex")
    if not path or not Path(path).is_file() or not os.access(path, os.X_OK):
        raise RuntimeError("Official codex executable not found on PATH.")
    if Path(path).resolve() == ENTRY.resolve():
        raise RuntimeError("Official executable resolves to this wrapper; refusing recursion.")
    return os.path.abspath(path)  # Keep upgrade-managed symlinks, resolve again every launch.


def interactive(args):
    if not all(os.isatty(fd) for fd in (0, 1, 2)) or os.environ.get("TERM") in (
        "dumb",
        "",
    ):
        return False
    skip = False
    for arg in args:
        if skip:
            skip = False
            continue
        if arg in ("-h", "--help", "-V", "--version", "--remote") or arg.startswith("--remote="):
            return False
        if arg in VALUE_FLAGS:
            skip = True
            continue
        if arg == "--":
            break
        if arg.startswith("-"):
            continue
        return arg not in NONINTERACTIVE
    return True


def version(path):
    p = subprocess.run([path, "--version"], capture_output=True, text=True, timeout=5)
    match = re.search(r"codex-cli (\d+)\.(\d+)\.(\d+)", p.stdout)
    return tuple(map(int, match.groups())) if match else (0, 0, 0)


def raw(args):
    os.execv(official(), [official(), *args])


def child(directory):
    root = Path(directory)
    config = json.loads((root / "launch.json").read_text())
    atomic_json(root / "started.json", {"started": True})
    env = dict(
        os.environ,
        CODEX_STATUSLINE_STATE=str(root),
        CODEX_STATUSLINE_LAUNCH=config["launch_id"],
    )
    orphaned = False
    try:
        proc = subprocess.Popen(config["argv"], env=env)
        # Codex owns terminal input. A late Ctrl-C after it restores canonical
        # mode must not kill this supervisor before it records the exit code.
        signal.signal(signal.SIGINT, signal.SIG_IGN)
        while True:
            try:
                os.kill(config["launcher_pid"], 0)
            except ProcessLookupError:
                orphaned = True
                proc.terminate()
                try:
                    code = proc.wait(timeout=3)
                except subprocess.TimeoutExpired:
                    proc.kill()
                    code = proc.wait()
                break
            code = proc.poll()
            if code is not None:
                break
            time.sleep(2)
        if code < 0:
            code = 128 - code
    except OSError as error:
        print(f"codex-statusline: cannot start official Codex: {error}", file=sys.stderr)
        code = 127
    atomic_json(root / "exit.json", {"code": code})
    if orphaned:
        # Survive tmux's hangup long enough to remove this launch's state.
        signal.signal(signal.SIGHUP, signal.SIG_IGN)
        try:
            subprocess.run(
                ["tmux", "-S", str(root / "tmux.sock"), "kill-server"],
                capture_output=True, timeout=2,
            )
        finally:
            shutil.rmtree(root, ignore_errors=True)
    return code


def binding_for(bindings, hint, launch_id):
    # A title is an invalidation guard, not a filesystem lookup. Bindings were
    # supplied by trusted hooks for this launch, each with the full session UUID.
    if not isinstance(hint, str) or not re.fullmatch(r"[0-9a-f-]{29}\.\.\.|[0-9a-f-]{36}", hint):
        return None
    prefix = hint.removesuffix("...")
    candidates = [
        b
        for sid, b in bindings.items()
        if sid.startswith(prefix) and b.get("launch_id") == launch_id
    ]
    return candidates[0] if len(candidates) == 1 else None


def launch(args):
    binary = official()
    if not interactive(args):
        os.execv(binary, [binary, *args])
    tmux = shutil.which("tmux")
    try:
        if not tmux:
            raise RuntimeError(
                "tmux is missing; install it yourself (brew install tmux / your package manager)."
            )
        if not shutil.which("oh-my-posh"):
            raise RuntimeError("oh-my-posh is missing.")
        if version(binary) < (0, 159, 0):
            raise RuntimeError("requires Codex >= 0.159.0 for the tested title protocol.")
    except (OSError, RuntimeError, subprocess.TimeoutExpired) as error:
        print(
            f"codex-statusline: {error} Falling back to official Codex.",
            file=sys.stderr,
        )
        os.execv(binary, [binary, *args])
    root = Path(tempfile.mkdtemp(prefix="csl-", dir="/tmp"))
    token = str(uuid.uuid4())
    # A private in-process server ensures SessionStart inherits this launch's
    # environment, rather than a long-lived daemon's earlier environment.
    argv = [binary, "--no-daemon", "-c", TITLE, "-c", "tui.status_line=[]", *args]
    cwd = os.getcwd()
    for i, arg in enumerate(args):
        if arg in ("-C", "--cd") and i + 1 < len(args):
            cwd = os.path.abspath(os.path.expanduser(args[i + 1]))
        elif arg.startswith("--cd="):
            cwd = os.path.abspath(os.path.expanduser(arg.split("=", 1)[1]))
    config = {"launch_id": token, "argv": argv, "cwd": cwd, "launcher_pid": os.getpid()}
    atomic_json(root / "launch.json", config)
    conf = root / "tmux.conf"
    conf.write_text(
        "set -g status on\n"
        "set -g status-position bottom\n"
        "set -g status-interval 0\n"
        "set -g status-left-length 10000\n"
        'set -g status-right ""\n'
        'set -g status-format "#{status-left}"\n'
        'set -g status-left ""\n'
        "set -g allow-rename off\n"
        "set -g set-titles on\n"
        "set -g @terminal_title Codex\n"
        'set -g set-titles-string "#{@terminal_title}"\n'
        "set -g mouse on\n"
        # Every key belongs to Codex: no prefix (Ctrl-B), no wait after Esc.
        "set -g prefix None\n"
        "unbind C-b\n"
        "set -s escape-time 10\n"
        "set -g history-limit 10000\n"
        "set -g remain-on-exit on\n"
        "set -g exit-empty on\n"
    )
    with conf.open("a") as stream:
        stream.write('set -g status-style "bg=default,fg=default"\n')
        stream.write('set -g status 2\nset -g status-format[1] "#{@line2}"\n')
    # -u: draw UTF-8 even when LANG/LC_* say otherwise (e.g. over ssh), or tmux drops the bars.
    base = [tmux, "-u", "-S", str(root / "tmux.sock"), "-f", str(conf)]
    env = dict(os.environ)
    env.pop("TMUX", None)
    env.pop("TMUX_PANE", None)
    stop = threading.Event()
    started = False

    def call(*command, timeout=2):
        return subprocess.run(
            [*base, *command], env=env, text=True, capture_output=True, timeout=timeout
        )

    def monitor():
        from .data import LogReader, merge_quotas, newest_quotas, parse_title, sessions_dir
        from .render import payload, render_rows

        reader = LogReader()
        sessions, readers, others, scan_at = sessions_dir(), {}, {}, 0.0
        last_line = last_second = None
        last_render = last_state = None
        last_title = "Codex"
        rendered_at = 0.0
        width = 80
        while not stop.is_set():
            try:
                if (root / "exit.json").exists():
                    call("kill-server")
                    return
                p = call(
                    "display-message",
                    "-p",
                    "-t",
                    "codex:0.0",
                    "#{pane_title}\n#{client_width}",
                )
                if p.returncode:
                    return
                title, _, width = p.stdout.rstrip("\n").partition("\n")
                state = parse_title(title)
                terminal_title = "Codex"
                if state["thread_name"]:
                    terminal_title += ": " + state["thread_name"]
                if terminal_title != last_title:
                    call("set-option", "-g", "@terminal_title", terminal_title)
                    last_title = terminal_title
                state["cwd"] = config["cwd"]
                state["quotas"] = {}
                if time.monotonic() - scan_at > 10:
                    others, scan_at = newest_quotas(sessions, readers), time.monotonic()
                try:
                    bindings = json.loads((root / "bindings.json").read_text())
                    bound = binding_for(bindings, state.get("session_hint"), token)
                except (OSError, ValueError, TypeError, AttributeError):
                    bound = None
                if bound:
                    state["cwd"] = bound.get("cwd") or config["cwd"]
                    snapshot = reader.update(bound["transcript_path"])
                    state["quotas"] = snapshot.get("quotas", {})
                    for key in ("tokens", "usage", "effort"):
                        state[key] = snapshot.get(key)
                state["quotas"] = merge_quotas(state["quotas"], others)
                render_key = (payload(state), int(width or 80), int(time.time() // 60))
                if render_key != last_render or time.monotonic() - rendered_at >= 10:
                    line, second = render_rows(state, int(width or 80))
                    if line != last_line:
                        call("set-option", "-t", "codex", "status-left", line)
                        last_line = line
                    if second != last_second:
                        call("set-option", "-t", "codex", "@line2", second)
                        last_second = second
                    last_render, rendered_at = render_key, time.monotonic()
                # Save metadata-only current view for doctor/tests; never pane text.
                if state != last_state:
                    atomic_json(root / "view.json", state)
                    last_state = state
            except Exception as error:
                atomic_json(root / "error.json", {"error": repr(error)[:500]})
                last_render = None
                last_line = None
                # Invalidate both rows so a previous thread's context cannot linger.
                try:
                    fallback = render_rows({"cwd": config["cwd"], "quotas": others}, int(width or 80))
                except Exception:
                    fallback = ("Codex", "")
                try:
                    call("set-option", "-g", "@terminal_title", "Codex")
                    last_title = "Codex"
                    call("set-option", "-t", "codex", "status-left", fallback[0])
                    call("set-option", "-t", "codex", "@line2", fallback[1])
                    last_line = last_second = None
                except Exception:
                    pass
            stop.wait(2)

    def interrupted(signum, frame):
        raise SystemExit(128 + signum)

    old_handlers = {sig: signal.signal(sig, interrupted) for sig in (signal.SIGTERM, signal.SIGHUP)}
    try:
        p = call(
            "new-session",
            "-d",
            "-s",
            "codex",
            sys.executable,
            "-c",
            "import time; time.sleep(86400)",
        )
        if p.returncode:
            raise RuntimeError(p.stderr.strip() or "tmux initialization failed")
        # Beyond this boundary a child may exist even if tmux times out.
        started = True
        p = call(
            "respawn-pane",
            "-k",
            "-t",
            "codex:0.0",
            sys.executable,
            str(ENTRY),
            "_child",
            str(root),
        )
        if p.returncode:
            raise RuntimeError(p.stderr.strip() or "tmux child launch failed")
        worker = threading.Thread(target=monitor, daemon=True)
        worker.start()
        attach = subprocess.Popen([*base, "attach-session", "-t", "codex"], env=env)
        attach.wait()
        if (root / "exit.json").exists():
            return json.loads((root / "exit.json").read_text())["code"]
        return attach.returncode
    except (OSError, RuntimeError, subprocess.TimeoutExpired) as error:
        # Once creation succeeds or the child marker exists, NEVER start a second Codex.
        print(f"codex-statusline: {error}", file=sys.stderr)
        if not started and not (root / "started.json").exists():
            try:
                call("kill-server")
            except Exception:
                pass
            shutil.rmtree(root, ignore_errors=True)
            os.execv(binary, [binary, *args])
        return 1
    finally:
        stop.set()
        for sig, handler in old_handlers.items():
            signal.signal(sig, handler)
        try:
            call("kill-server")
        except Exception:
            pass
        if "attach" in locals() and attach.poll() is None:
            try:
                attach.wait(timeout=3)
            except subprocess.TimeoutExpired:
                attach.terminate()
                attach.wait(timeout=3)
        if "worker" in locals():
            worker.join(timeout=3)
        shutil.rmtree(root, ignore_errors=True)
