import importlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tempfile
import time
import unittest
from unittest.mock import patch


REPO = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(REPO / "codex/.codex"))


class CodexPayloadTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.renderer = importlib.import_module("statusline.render")

    def test_maps_codex_metadata_without_inventing_claude_fields(self):
        value = self.renderer.payload({
            "model": "GPT-6.1-Sol", "effort": "medium", "cwd": "/work/example",
            "context_used": 17,
            "quotas": {
                "5h": {"remaining": 94, "reset_at": 1900000000},
                "weekly": {"remaining": 99, "reset_at": 1900300000},
            },
        })
        self.assertEqual(value["model"]["display_name"], "GPT-6.1-Sol")
        self.assertEqual(value["workspace"]["current_dir"], "/work/example")
        self.assertEqual(value["context_window"]["used_percentage"], 17)
        self.assertEqual(value["rate_limits"]["five_hour"]["used_percentage"], 6)
        self.assertEqual(value["rate_limits"]["five_hour"]["resets_at"], 1900000000)
        self.assertEqual(value["rate_limits"]["seven_day"]["used_percentage"], 1)
        for field in ("cost", "output_style", "prompt_cache"):
            self.assertNotIn(field, value)

    def test_zero_usage_is_known_and_unknown_fields_are_absent(self):
        value = self.renderer.payload({
            "context_used": 0,
            "quotas": {"5h": {"remaining": 100, "reset_at": 1900000000}},
        })
        self.assertEqual(value["context_window"]["used_percentage"], 0)
        self.assertEqual(value["rate_limits"]["five_hour"]["used_percentage"], 0)
        unknown = self.renderer.payload({"context_used": None, "quotas": {}})
        self.assertNotIn("context_window", unknown)
        self.assertFalse(unknown.get("rate_limits"))

    def test_converts_rgb_and_escapes_literal_tmux_formats(self):
        text = "\x1b[38;2;191;97;106mGPT\x1b[0m #{pane_title} #[fg=red]"
        result = self.renderer.ansi_to_tmux(text)
        self.assertIn("#[fg=#bf616a]", result)
        self.assertIn("##{pane_title}", result)
        self.assertIn("##[fg=red]", result)
        self.assertNotIn("\x1b", result)

    def test_removes_terminal_title_control_sequences(self):
        text = "first\x1b]0;unwanted title\x07second"
        result = self.renderer.ansi_to_tmux(text)
        self.assertIn("first", result)
        self.assertIn("second", result)
        self.assertNotIn("unwanted title", result)
        self.assertNotIn("\x07", result)

    @unittest.skipUnless(shutil.which("oh-my-posh"), "oh-my-posh is not installed")
    def test_shared_omp_theme_renders_zero_usage_without_cost(self):
        with tempfile.TemporaryDirectory() as temporary:
            state = {
                "model": "GPT-6.1-Sol", "cwd": temporary, "context_used": 0,
                "quotas": {
                    "5h": {"remaining": 100, "reset_at": time.time() + 7200},
                    "weekly": {"remaining": 100, "reset_at": time.time() + 345600},
                },
            }
            result = subprocess.run(
                ["oh-my-posh", "claude", "--config",
                 str(REPO / "oh-my-posh/.config/zsh/oh-my-posh/pure.claude.toml")],
                input=json.dumps(self.renderer.payload(state)), text=True, capture_output=True,
                cwd=temporary, env=dict(os.environ, COLORTERM="truecolor", COLUMNS="180"),
                timeout=10, check=True,
            )
            output = self.renderer.OSC.sub("", result.stdout)
            output = re.sub(r"\x1b\[[0-9;]*[A-Za-z]", "", output)
            rows = [line for line in output.splitlines() if line.strip()]
            self.assertEqual(len(rows), 2)
            self.assertIn("GPT-6.1-Sol", rows[1])
            self.assertGreaterEqual(rows[1].count("0%"), 3)
            self.assertIn("", rows[1])
            self.assertIn("󰨳", rows[1])
            self.assertNotIn("$", rows[1])
            self.assertNotIn("error", output.lower())
            self.assertNotIn("error", result.stderr.lower())


class CodexSessionBindingTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.data = importlib.import_module("statusline.data")
        cls.launcher = importlib.import_module("statusline.launcher")

    def test_title_parsing_and_clear_do_not_reuse_previous_context(self):
        session = "12345678-1234-1234-1234-123456789012"
        current = self.data.parse_title(f"GPT-6.1-Sol | Context 17% used | {session}")
        cleared = self.data.parse_title(f"GPT-6.1-Sol | Context unknown | {session}")
        self.assertEqual(current["context_used"], 17)
        self.assertIsNone(cleared["context_used"])
        self.assertEqual(current["session_hint"], session)
        for malformed in ("", "GPT | wrong | bad-id", f"GPT | invalid | {session}"):
            with self.subTest(title=malformed), self.assertRaises(ValueError):
                self.data.parse_title(malformed)

    def test_only_current_launch_and_unambiguous_thread_bind(self):
        first = "12345678-1234-1234-1234-123456789012"
        second = "12345678-1234-1234-1234-123456789099"
        bindings = {
            first: {"launch_id": "launch-a", "transcript_path": "/logs/first"},
            second: {"launch_id": "launch-b", "transcript_path": "/logs/second"},
        }
        self.assertEqual(self.launcher.binding_for(bindings, first, "launch-a"), bindings[first])
        self.assertIsNone(self.launcher.binding_for(bindings, first, "launch-b"))
        hint = first[:29] + "..."
        self.assertEqual(self.launcher.binding_for(bindings, hint, "launch-a"), bindings[first])
        bindings[second]["launch_id"] = "launch-a"
        self.assertIsNone(self.launcher.binding_for(bindings, hint, "launch-a"))
        self.assertIsNone(self.launcher.binding_for(bindings, "unrecognized", "launch-a"))

    def test_noninteractive_commands_and_redirected_io_bypass_wrapper(self):
        with patch.dict(os.environ, {"TERM": "xterm-256color"}), \
                patch.object(os, "isatty", return_value=True):
            self.assertTrue(self.launcher.interactive([]))
            self.assertTrue(self.launcher.interactive(["--profile", "work", "resume", "--last"]))
            for args in (["exec", "task"], ["--profile", "work", "exec", "task"],
                         ["--version"], ["--help"], ["login"]):
                with self.subTest(args=args):
                    self.assertFalse(self.launcher.interactive(args))
        with patch.dict(os.environ, {"TERM": "xterm-256color"}), \
                patch.object(os, "isatty", return_value=False):
            self.assertFalse(self.launcher.interactive([]))

    def test_log_reader_uses_window_lengths_and_waits_for_complete_records(self):
        def event(limit_id, window, used):
            return json.dumps({
                "type": "event_msg", "timestamp": "2026-11-15T10:00:00Z",
                "payload": {"type": "token_count", "info": None,
                            "rate_limits": {"limit_id": limit_id,
                                            "primary": {"window_minutes": window,
                                                        "used_percent": used,
                                                        "resets_at": 1900000000}}},
            })

        with tempfile.TemporaryDirectory() as temporary:
            path = Path(temporary) / "rollout-example.jsonl"
            path.write_text(event("codex_other", 300, 99) + "\n")
            reader = self.data.LogReader()
            initial = reader.update(str(path))
            self.assertIsNone(initial["quotas"]["5h"]["remaining"])
            weekly = event("codex", 10080, 25)
            with path.open("a") as stream:
                stream.write(weekly[:30])
            partial = reader.update(str(path))
            self.assertIsNone(partial["quotas"]["weekly"]["remaining"])
            with path.open("a") as stream:
                stream.write(weekly[30:] + "\n")
            complete = reader.update(str(path))
            self.assertEqual(complete["quotas"]["weekly"]["remaining"], 75)
            self.assertIsNone(complete["quotas"]["5h"]["remaining"])

    def test_session_start_hook_records_exact_transcript_path_silently(self):
        launch = "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa"
        session = "bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb"
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            (root / "launch.json").write_text(json.dumps({"launch_id": launch}))
            event = {
                "hook_event_name": "SessionStart", "session_id": session,
                "transcript_path": str(root / "exact-transcript.jsonl"),
                "cwd": "/work/example", "model": "gpt-6.1-sol", "source": "resume",
            }
            result = subprocess.run(
                ["python3", str(REPO / "codex/.codex/statusline/entry.py"), "hook"],
                input=json.dumps(event), text=True, capture_output=True, check=True,
                env=dict(os.environ, CODEX_STATUSLINE_STATE=temporary,
                         CODEX_STATUSLINE_LAUNCH=launch),
            )
            self.assertEqual(result.stdout, "")
            self.assertEqual(result.stderr, "")
            bindings = json.loads((root / "bindings.json").read_text())
            self.assertEqual(bindings[session]["transcript_path"], event["transcript_path"])
            self.assertEqual(bindings[session]["launch_id"], launch)
            self.assertEqual(bindings[session]["cwd"], event["cwd"])
