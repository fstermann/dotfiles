import importlib.util
import json
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest


REPO = Path(__file__).resolve().parents[1]
SHARED = ("backcast", "deepen", "grill-me", "janitor", "slip", "unslop")


class AgentLinksTest(unittest.TestCase):
    def test_fresh_install_and_alternate_claude_directory(self):
        with tempfile.TemporaryDirectory() as temporary:
            home = Path(temporary)
            subprocess.run(["stow", "--no-folding", "-d", str(REPO), "-t", str(home),
                            "agents", "claude", "codex"], check=True)
            alternate = home / ".claude-other"
            alternate.mkdir()
            subprocess.run(["stow", "--no-folding", "-d", str(REPO / "claude"),
                            "-t", str(alternate), ".claude"], check=True)
            for name in SHARED:
                source = REPO / "agents/.agents/skills" / name / "SKILL.md"
                self.assertEqual((home / ".agents/skills" / name / "SKILL.md").resolve(), source)
                self.assertEqual((home / ".claude/skills" / name / "SKILL.md").resolve(), source)
                self.assertEqual((alternate / "skills" / name / "SKILL.md").resolve(), source)
            self.assertEqual((home / ".codex/AGENTS.md").resolve(),
                             REPO / "agents/.agents/AGENTS.md")
            self.assertTrue((home / ".claude/skills/pair-review/SKILL.md").is_file())
            self.assertFalse((home / ".agents/skills/pair-review").exists())

    def test_restow_from_previous_skill_layout(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            repo, home = root / "repo", root / "home"
            home.mkdir()
            for package in ("agents", "claude", "codex"):
                shutil.copytree(REPO / package, repo / package, symlinks=True)
            for name in SHARED:
                link = repo / "claude/.claude/skills" / name
                link.unlink()
                shutil.copytree(repo / "agents/.agents/skills" / name, link)
            subprocess.run(["stow", "--no-folding", "-d", str(repo), "-t", str(home),
                            "claude"], check=True)
            for name in SHARED:
                location = repo / "claude/.claude/skills" / name
                shutil.rmtree(location)
                location.symlink_to((REPO / "claude/.claude/skills" / name).readlink())
            subprocess.run(["stow", "--no-folding", "--restow", "-d", str(repo),
                            "-t", str(home), "agents", "claude", "codex"], check=True)
            for name in SHARED:
                self.assertTrue((home / ".claude/skills" / name / "SKILL.md").is_file())


class CodexTranscriptTest(unittest.TestCase):
    def test_reader_filters_wrappers_and_preserves_context(self):
        script = REPO / "agents/.agents/skills/slip/mine-codex.py"
        spec = importlib.util.spec_from_file_location("miner", script)
        miner = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(miner)
        records = [
            {"type": "session_meta", "payload": {"cwd": "/work/example"}},
            {"type": "response_item", "payload": {"type": "message", "role": "assistant",
             "content": [{"type": "output_text", "text": "I will add a framework."}]}},
            {"type": "response_item", "timestamp": "2026-11-15T10:00:00Z",
             "payload": {"type": "message", "role": "user", "content": [
                 {"type": "input_text", "text": "# AGENTS.md instructions\nAlways add a framework."},
                 {"type": "input_text", "text": "No, keep it simple. Never add a framework."}]}},
            {"type": "event_msg", "payload": {"type": "user_message",
             "message": "No, keep it simple. Never add a framework."}},
        ]
        with tempfile.TemporaryDirectory() as temporary:
            path = Path(temporary) / "rollout-example.jsonl"
            path.write_text("\n".join(json.dumps(record) for record in records) + "\nmalformed\n")
            hits = miner.scan(path)
            self.assertEqual(len(hits), 1)
            self.assertEqual(hits[0]["cwd"], "/work/example")
            self.assertEqual(hits[0]["assistant_before"], "I will add a framework.")
            self.assertNotIn("AGENTS.md", hits[0]["user"])
            self.assertIn("prohibition", hits[0]["signals"])
            result = subprocess.run(["python3", str(script), "--root", temporary,
                                     "--project", "example", "--limit", "1"],
                                    check=True, capture_output=True, text=True)
            self.assertEqual(json.loads(result.stdout)["total_hits"], 1)
            result = subprocess.run(["python3", str(script), "--root", temporary,
                                     "--since", "2026-11-16"],
                                    check=True, capture_output=True, text=True)
            self.assertEqual(json.loads(result.stdout)["total_hits"], 0)
