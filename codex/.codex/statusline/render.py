"""Translate Codex metadata into the shared OMP theme and tmux styles."""

import json
import os
from pathlib import Path
import re
import subprocess
import time


OSC = re.compile(r"\x1b\].*?(?:\x07|\x1b\\)", re.DOTALL)
CSI = re.compile(r"\x1b\[([0-9;]*)([A-Za-z])")
ANSI_COLORS = ("black", "red", "green", "yellow", "blue", "magenta", "cyan", "white")


def payload(state):
    result = {
        "model": {"display_name": state.get("model") or "Codex"},
        "workspace": {"current_dir": state.get("cwd") or os.getcwd()},
    }
    context = state.get("context_used")
    if context is not None:
        result["context_window"] = {"used_percentage": round(context)}
    if state.get("effort"):
        result["effort"] = {"level": state["effort"]}
    limits = {}
    for key, name in (("5h", "five_hour"), ("weekly", "seven_day")):
        quota = state.get("quotas", {}).get(key, {})
        remaining, reset = quota.get("remaining"), quota.get("reset_at")
        if remaining is None or reset is None or reset <= time.time():
            continue
        limits[name] = {"used_percentage": 100 - remaining, "resets_at": int(reset)}
    if limits:
        result["rate_limits"] = limits
    return result


def ansi_to_tmux(text):
    text = OSC.sub("", text).replace("#", "##")

    def style(match):
        if match[2] != "m":
            return ""
        codes = [int(value or 0) for value in match[1].split(";")]
        styles = []
        index = 0
        while index < len(codes):
            code = codes[index]
            if code == 0:
                styles.append("default")
            elif code in (1, 2, 3, 4, 7, 22, 23, 24, 27):
                styles.append({1: "bold", 2: "dim", 3: "italics", 4: "underscore",
                               7: "reverse", 22: "nobold,nodim", 23: "noitalics",
                               24: "nounderscore", 27: "noreverse"}[code])
            elif code in (39, 49):
                styles.append(("fg" if code == 39 else "bg") + "=default")
            elif 30 <= code <= 37 or 40 <= code <= 47:
                styles.append(("fg" if code < 40 else "bg") + "=" + ANSI_COLORS[code % 10])
            elif 90 <= code <= 97 or 100 <= code <= 107:
                styles.append(("fg" if code < 100 else "bg") + "=bright" + ANSI_COLORS[code % 10])
            elif code in (38, 48) and index + 2 < len(codes):
                channel = "fg" if code == 38 else "bg"
                mode = codes[index + 1]
                if mode == 2 and index + 4 < len(codes):
                    rgb = codes[index + 2:index + 5]
                    styles.append(channel + "=#" + "".join(f"{value:02x}" for value in rgb))
                    index += 4
                elif mode == 5:
                    styles.append(f"{channel}=colour{codes[index + 2]}")
                    index += 2
            index += 1
        return "".join("#[" + value + "]" for value in styles)

    text = CSI.sub(style, text)
    return re.sub(r"[\x00-\x1f\x7f]", "", text)


def render_rows(state, width=80):
    theme = Path.home() / ".config/zsh/oh-my-posh/pure.claude.toml"
    env = dict(os.environ, COLUMNS=str(width), COLORTERM="truecolor")
    directory = state.get("cwd") or os.getcwd()
    result = subprocess.run(
        ["oh-my-posh", "claude", "--config", str(theme)],
        input=json.dumps(payload(state)), capture_output=True, text=True,
        cwd=directory, env=env, timeout=3, check=True,
    )
    text = OSC.sub("", result.stdout)
    rows = [ansi_to_tmux(row) for row in text.splitlines() if row.strip()]
    return (rows + ["", ""])[:2]
