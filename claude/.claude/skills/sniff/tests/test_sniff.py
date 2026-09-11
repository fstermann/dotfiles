from __future__ import annotations

import io
import json
import os
import stat
import subprocess
import tempfile
import textwrap
import unittest
from contextlib import redirect_stdout
from pathlib import Path
from unittest.mock import patch

from sniff_cli.adapters import run_ruff, run_vale
from sniff_cli.cli import _parser, _print_findings, _report_format
from sniff_cli.config import _merge, load_config
from sniff_cli.discovery import discover_inputs
from sniff_cli.models import Finding, Rule, Sniffer, SniffError
from sniff_cli.report import parse_report_findings, render_report
from sniff_cli.rules import effective_severity, load_rules, selected_rules

SKILL_ROOT = Path(__file__).resolve().parents[1]


def executable(path: Path, content: str) -> Path:
    path.write_text(textwrap.dedent(content).lstrip(), encoding="utf-8")
    path.chmod(path.stat().st_mode | stat.S_IXUSR)
    return path


def sample_rule(kind: str, options: dict[str, object]) -> Rule:
    return Rule(
        id=f"test-{kind}",
        name="Test",
        family="test",
        applies_to=("core",),
        severity="warning",
        message="Test message.",
        body="Test guidance.",
        path=Path(f"test-{kind}.md"),
        sniffers=(Sniffer(kind, options), Sniffer("llm", {})),
    )


class RuleTests(unittest.TestCase):
    def test_bundled_registry_is_valid_and_every_rule_has_llm(self) -> None:
        rules = load_rules([SKILL_ROOT / "rules"])
        self.assertEqual(43, len(rules))
        self.assertEqual(
            13, sum(bool(rule.sniffers_of("vale")) for rule in rules.values())
        )
        self.assertTrue(all(rule.sniffers_of("llm") for rule in rules.values()))

    def test_profiles_and_spec_severity(self) -> None:
        context = load_config(SKILL_ROOT, SKILL_ROOT)
        rules = load_rules(context.rule_dirs)
        prompt = selected_rules(rules, context.data, "prompt")
        document = selected_rules(rules, context.data, "document")
        self.assertEqual(43, len(prompt))
        self.assertEqual(31, len(document))
        self.assertEqual(
            "error",
            effective_severity(rules["ref-missing-actor"], context.data, "spec"),
        )
        self.assertEqual(
            "warning",
            effective_severity(rules["ref-missing-actor"], context.data, "document"),
        )

    def test_unknown_configured_rule_is_rejected(self) -> None:
        context = load_config(SKILL_ROOT, SKILL_ROOT)
        rules = load_rules(context.rule_dirs)
        config = _merge(
            context.data, {"rules": {"not-a-real-rule": {"enabled": False}}}
        )
        with self.assertRaisesRegex(SniffError, "unknown rule"):
            selected_rules(rules, config, "document")

    def test_duplicate_rule_ids_are_rejected(self) -> None:
        with tempfile.TemporaryDirectory() as temp:
            custom = Path(temp)
            source = SKILL_ROOT / "rules" / "lex-open-ended.md"
            (custom / source.name).write_text(
                source.read_text(encoding="utf-8"), encoding="utf-8"
            )
            with self.assertRaisesRegex(SniffError, "duplicate rule id"):
                load_rules([SKILL_ROOT / "rules", custom])


class ConfigTests(unittest.TestCase):
    def test_layers_append_lists_and_override_scalars(self) -> None:
        merged = _merge(
            {"items": ["base"], "nested": {"enabled": True, "severity": "warning"}},
            {"items": ["project"], "nested": {"severity": "error"}},
        )
        self.assertEqual(["base", "project"], merged["items"])
        self.assertEqual({"enabled": True, "severity": "error"}, merged["nested"])

    def test_global_then_project_precedence_and_rule_directories(self) -> None:
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            xdg = root / "xdg"
            project = root / "project"
            xdg.joinpath("sniff").mkdir(parents=True)
            project.mkdir()
            xdg.joinpath("sniff/sniff.toml").write_text(
                'version = 1\nfail_on = "warning"\n', encoding="utf-8"
            )
            project.joinpath("sniff.toml").write_text(
                'version = 1\nfail_on = "suggestion"\n', encoding="utf-8"
            )
            with patch.dict(os.environ, {"XDG_CONFIG_HOME": str(xdg)}):
                context = load_config(SKILL_ROOT, project)
            self.assertEqual("suggestion", context.data["fail_on"])
            self.assertEqual(xdg / "sniff/rules", context.rule_dirs[1])
            self.assertEqual(project.resolve() / ".sniff/rules", context.rule_dirs[2])


class AdapterTests(unittest.TestCase):
    def test_vale_output_is_normalized(self) -> None:
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            target = root / "draft.md"
            target.write_text("This is etc. vague.\n", encoding="utf-8")
            fake = executable(
                root / "vale",
                f"""
                #!/usr/bin/env python3
                import json
                print(json.dumps({{{str(target)!r}: [{{
                    "Check": "Sniff.test-vale", "Line": 1, "Span": [9, 12],
                    "Match": "etc", "Description": "Test message."
                }}]}}))
                raise SystemExit(1)
                """,
            )
            config = {"adapters": {"vale": {"executable": str(fake)}}}
            findings = run_vale(
                [target],
                [sample_rule("vale", {"pattern": r"\betc\b"})],
                config,
                "document",
            )
            self.assertEqual(1, len(findings))
            self.assertEqual("test-vale", findings[0].rule)
            self.assertEqual("vale", findings[0].detector)
            self.assertEqual("etc", findings[0].span)

    def test_ruff_output_is_normalized_and_only_registered_code_is_kept(self) -> None:
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            target = root / "sample.py"
            target.write_text("exit()\n", encoding="utf-8")
            fake = executable(
                root / "ruff",
                f"""
                #!/usr/bin/env python3
                import json
                print(json.dumps([
                    {{"code": "PLR1722", "message": "Use sys.exit", "filename": {str(target)!r},
                     "location": {{"row": 1, "column": 1}}, "end_location": {{"row": 1, "column": 5}}}},
                    {{"code": "F401", "message": "Unregistered", "filename": {str(target)!r},
                     "location": {{"row": 1, "column": 1}}, "end_location": {{"row": 1, "column": 5}}}}
                ]))
                raise SystemExit(1)
                """,
            )
            config = {"adapters": {"ruff": {"executable": str(fake)}}}
            rule = sample_rule("ruff", {"rule": "PLR1722"})
            findings = run_ruff([target], [rule], config, "code")
            self.assertEqual(1, len(findings))
            self.assertEqual("test-ruff", findings[0].rule)
            self.assertEqual("ruff", findings[0].detector)
            self.assertEqual("exit", findings[0].span)

    def test_ruff_fix_uses_safe_fixes_only(self) -> None:
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            target = root / "sample.py"
            marker = root / "args.txt"
            target.write_text("exit()\n", encoding="utf-8")
            fake = executable(
                root / "ruff",
                f"""
                #!/usr/bin/env python3
                import json
                import pathlib
                import sys
                pathlib.Path({str(marker)!r}).write_text(" ".join(sys.argv[1:]))
                print(json.dumps([]))
                """,
            )
            config = {"adapters": {"ruff": {"executable": str(fake)}}}
            run_ruff(
                [target],
                [sample_rule("ruff", {"rule": "PLR1722"})],
                config,
                "code",
                fix=True,
            )
            arguments = marker.read_text(encoding="utf-8")
            self.assertIn("--fix", arguments)
            self.assertIn("--no-unsafe-fixes", arguments)

    def test_missing_selected_adapter_fails(self) -> None:
        config = {"adapters": {"vale": {"executable": "definitely-not-a-real-vale"}}}
        with tempfile.TemporaryDirectory() as temp:
            target = Path(temp) / "draft.md"
            target.write_text("text", encoding="utf-8")
            with self.assertRaisesRegex(SniffError, "unavailable"):
                run_vale(
                    [target],
                    [sample_rule("vale", {"pattern": "text"})],
                    config,
                    "document",
                )


class DiscoveryTests(unittest.TestCase):
    def test_git_discovery_includes_untracked_and_excludes_ignored(self) -> None:
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp).resolve()
            subprocess.run(["git", "init", "-q", str(root)], check=True)
            (root / ".gitignore").write_text("ignored.md\n", encoding="utf-8")
            (root / "tracked.md").write_text("tracked\n", encoding="utf-8")
            (root / "new.md").write_text("new\n", encoding="utf-8")
            (root / "ignored.md").write_text("ignored\n", encoding="utf-8")
            (root / "source.py").write_text("# source\n", encoding="utf-8")
            subprocess.run(
                ["git", "-C", str(root), "add", ".gitignore", "tracked.md"], check=True
            )
            profile = {"include": ["*.md", "**/*.md"], "exclude": []}
            found = discover_inputs([str(root)], profile, root)
            self.assertEqual([root / "new.md", root / "tracked.md"], found)

    def test_explicit_ignored_file_is_still_selected(self) -> None:
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp).resolve()
            target = root / "ignored.md"
            target.write_text("text\n", encoding="utf-8")
            found = discover_inputs(
                [str(target)], {"include": ["*.md"], "exclude": ["*"]}, root
            )
            self.assertEqual([target], found)

    def test_explicit_file_still_respects_profile_file_types(self) -> None:
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp).resolve()
            target = root / "source.py"
            target.write_text("# prose\n", encoding="utf-8")
            found = discover_inputs(
                [str(target)], {"include": ["*.md"], "exclude": []}, root
            )
            self.assertEqual([], found)


class ReportTests(unittest.TestCase):
    def test_report_format_defaults_to_auto(self) -> None:
        args = _parser().parse_args(["report"])
        self.assertEqual("auto", args.format)

    def test_auto_report_format_detects_assistant_environments(self) -> None:
        self.assertEqual("markdown", _report_format("auto", {"CLAUDECODE": "1"}))
        self.assertEqual(
            "markdown", _report_format("auto", {"CLAUDE_CODE_ENTRYPOINT": "cli"})
        )
        self.assertEqual(
            "markdown", _report_format("auto", {"CODEX_THREAD_ID": "thread"})
        )
        self.assertEqual("terminal", _report_format("auto", {}))

    def test_explicit_report_format_overrides_environment(self) -> None:
        environment = {"CLAUDECODE": "1", "CODEX_THREAD_ID": "thread"}
        self.assertEqual("terminal", _report_format("terminal", environment))
        self.assertEqual("markdown", _report_format("markdown", {}))

    def test_check_report_format_renders_candidates_without_confirmation(self) -> None:
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp).resolve()
            target = root / "prompt.md"
            target.write_text(
                "Must always apply.\nbetween\nCould potentially fail.\n",
                encoding="utf-8",
            )
            candidate = Finding(
                path="prompt.md",
                line=1,
                column=1,
                end_line=1,
                end_column=19,
                rule="log-universal-quantifier",
                severity="error",
                detector="vale",
                span="Must always apply.",
                message="The scope is unbounded.",
            )
            later_candidate = Finding(
                path="prompt.md",
                line=3,
                column=1,
                end_line=3,
                end_column=18,
                rule="lex-hedge-stack",
                severity="warning",
                detector="vale",
                span="Could potentially",
                message="Stacked hedges obscure intent.",
            )
            output = io.StringIO()
            with redirect_stdout(output):
                _print_findings([candidate, later_candidate], "report", root)
            rendered = output.getvalue()
            self.assertIn("2 candidates across 1 file", rendered)
            self.assertIn("· via Vale", rendered)
            self.assertNotIn("Vale → LLM", rendered)
            self.assertNotIn("```", rendered)
            self.assertNotIn("**", rendered)
            self.assertIn("prompt.md:1", rendered)
            self.assertIn("prompt.md:3", rendered)

    def test_adjudicated_findings_render_with_source_context(self) -> None:
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp).resolve()
            target = root / "prompt.md"
            target.write_text(
                "before\n"
                "Cut AI tells from any writing. Must always apply.\n"
                "disable-model-invocation: true\n",
                encoding="utf-8",
            )
            findings = parse_report_findings(
                [
                    '{"path":"prompt.md","line":2,"column":33,'
                    '"end_line":2,"end_column":50,'
                    '"rule":"log-universal-quantifier","severity":"error",'
                    '"source":"llm only","span":"Must always apply.",'
                    '"message":"The scope is unbounded."}',
                    '{"path":"prompt.md","line":2,"column":33,'
                    '"end_line":3,"end_column":31,'
                    '"rule":"log-contradiction","severity":"warning",'
                    '"source":"vale -> llm confirmed","span":"Must always apply.",'
                    '"message":"The directives conflict."}',
                ]
            )
            rendered = render_report(findings, root)
            self.assertIn("2 findings across 1 file", rendered)
            self.assertIn(f"](<{target}:2>)", rendered)
            self.assertIn(
                "└── **[ERROR] log-universal-quantifier** · *via LLM*", rendered
            )
            self.assertIn(
                "\u3000\u3000**[WARNING] log-contradiction** · *via Vale → LLM*",
                rendered,
            )
            self.assertLess(
                rendered.index("[ERROR] log-universal-quantifier"),
                rendered.index("[WARNING] log-contradiction"),
            )
            self.assertIn("│ › 2 │ Cut AI tells", rendered)
            self.assertIn("│   3 │ disable-model-invocation: true", rendered)
            self.assertIn("│     │ ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^", rendered)
            self.assertIn("└── *The directives conflict.*", rendered)

    def test_terminal_report_separates_excerpt_from_label_and_diagnosis(self) -> None:
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp).resolve()
            (root / "prompt.md").write_text("Must always apply.\n", encoding="utf-8")
            findings = parse_report_findings(
                [
                    '{"path":"prompt.md","line":1,"column":1,'
                    '"end_line":1,"end_column":19,'
                    '"rule":"log-universal-quantifier","severity":"warning",'
                    '"source":"llm only","span":"Must always apply.",'
                    '"message":"The scope is unbounded."}'
                ]
            )

            rendered = render_report(findings, root, markdown=False)

            self.assertIn("· via LLM\n\n    │", rendered)
            self.assertIn("^^^^^^^^^^^^^^^^^^\n\n　　└──", rendered)

    def test_multiline_diagnosis_uses_a_hanging_indent(self) -> None:
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp).resolve()
            (root / "prompt.md").write_text("Must always apply.\n", encoding="utf-8")
            message = (
                "The allowed degree of editing is not defined, so aggregators can "
                "make materially different changes while claiming to clean the "
                "reports lightly."
            )
            findings = parse_report_findings(
                [
                    '{"path":"prompt.md","line":1,"column":1,'
                    '"end_line":1,"end_column":19,'
                    '"rule":"log-universal-quantifier","severity":"warning",'
                    '"source":"llm only","span":"Must always apply.",'
                    f'"message":{json.dumps(message)}}}'
                ]
            )

            rendered = render_report(findings, root, markdown=False)

            diagnosis = rendered.split("\n\n")[-1].splitlines()
            self.assertGreater(len(diagnosis), 1)
            self.assertTrue(diagnosis[0].startswith("　　└── The"))
            self.assertTrue(diagnosis[1].startswith("　　    "))
            self.assertEqual(
                diagnosis[0].index("The"), diagnosis[1].index("materially")
            )

    def test_report_rejects_unconfirmed_provenance(self) -> None:
        payload = (
            '{"path":"prompt.md","line":1,"column":1,'
            '"rule":"test","severity":"warning","source":"vale candidate",'
            '"span":"text","message":"message"}'
        )
        with self.assertRaisesRegex(SniffError, "invalid source"):
            parse_report_findings([payload])


if __name__ == "__main__":
    unittest.main()
