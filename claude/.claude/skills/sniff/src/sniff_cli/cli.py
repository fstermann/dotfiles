from __future__ import annotations

import argparse
import json
import os
import sys
import tempfile
from collections import Counter
from collections.abc import Mapping
from dataclasses import replace
from pathlib import Path
from typing import Any

from . import __version__
from .adapters import run_adapters
from .config import ConfigContext, load_config
from .discovery import discover_inputs
from .models import Finding, Rule, SniffError
from .report import ReportFinding, parse_report_findings, render_report
from .rules import effective_severity, load_rules, selected_rules

SEVERITY_RANK = {"suggestion": 0, "warning": 1, "error": 2}
ASSISTANT_ENV_VARS = (
    "CLAUDECODE",
    "CLAUDE_CODE_ENTRYPOINT",
    "CODEX_THREAD_ID",
)


def _skill_root() -> Path:
    return Path(__file__).resolve().parents[2]


def _start_path(raw_paths: list[str] | None, target: str | None = None) -> Path:
    raw = target
    if raw is None and raw_paths:
        raw = next((item for item in raw_paths if item != "-"), None)
    return Path(raw).expanduser() if raw else Path.cwd()


def _context(
    args: argparse.Namespace, raw_paths: list[str] | None = None
) -> ConfigContext:
    explicit = Path(args.config) if args.config else None
    return load_config(
        _skill_root(), _start_path(raw_paths, getattr(args, "target", None)), explicit
    )


def _profile(
    config: dict[str, Any], requested: str | None
) -> tuple[str, dict[str, Any]]:
    name = requested or str(config.get("default_profile", "document"))
    profile = config.get("profiles", {}).get(name)
    if not isinstance(profile, dict):
        choices = ", ".join(sorted(config.get("profiles", {})))
        raise SniffError(f"unknown profile {name!r}; choose one of: {choices}")
    return name, profile


def _display_finding(
    finding: Finding, project_root: Path, stdin_path: Path | None
) -> Finding:
    path = Path(finding.path)
    if stdin_path is not None and path.resolve() == stdin_path.resolve():
        display = "<stdin>"
    else:
        try:
            display = path.resolve().relative_to(project_root.resolve()).as_posix()
        except ValueError:
            display = str(path)
    return replace(finding, path=display)


def _print_findings(
    findings: list[Finding],
    output_format: str,
    project_root: Path | None = None,
    stdin_source: str | None = None,
) -> None:
    if output_format in {"json", "jsonl"}:
        for finding in findings:
            print(json.dumps(finding.as_dict(), ensure_ascii=False, sort_keys=True))
        return
    if output_format == "report":
        root = (project_root or Path.cwd()).resolve()
        candidates = [
            ReportFinding(
                path=finding.path,
                line=finding.line,
                column=finding.column,
                end_line=finding.end_line,
                end_column=finding.end_column,
                rule=finding.rule,
                code=finding.code,
                severity=finding.severity,
                source=f"{finding.detector} candidate",
                span=finding.span,
                message=finding.message,
                source_text=stdin_source if finding.path == "<stdin>" else None,
            )
            for finding in findings
        ]
        print(
            render_report(
                candidates,
                root,
                subject="candidate",
                markdown=False,
                ansi=sys.stdout.isatty(),
            )
        )
        return
    for finding in findings:
        print(
            f"{finding.path}:{finding.line}:{finding.column}  "
            f"[{finding.severity} {finding.code}]  {finding.rule}  "
            f"({finding.detector} candidate)"
        )
        print(f'  span:   "{finding.span}"')
        print(f"  why:    {finding.message}")


def _check(args: argparse.Namespace) -> int:
    if args.paths.count("-") > 1 or ("-" in args.paths and len(args.paths) > 1):
        raise SniffError("stdin ('-') cannot be combined with other inputs")
    if args.fix and "-" in args.paths:
        raise SniffError("--fix cannot modify stdin")

    context = _context(args, args.paths)
    profile_name, profile = _profile(context.data, args.profile)
    rules = selected_rules(load_rules(context.rule_dirs), context.data, profile_name)
    if not rules:
        print("sniff: 0 rules selected", file=sys.stderr)
        return 0
    paths = discover_inputs(args.paths, profile, context.project_root)
    stdin_path: Path | None = None

    with tempfile.TemporaryDirectory(prefix="sniff-stdin-") as temp:
        if "-" in args.paths:
            suffix = ".py" if profile_name == "code" else ".md"
            stdin_path = Path(temp) / f"stdin{suffix}"
            stdin_path.write_text(sys.stdin.read(), encoding="utf-8")
            paths = [stdin_path]

        if not paths:
            print("sniff: 0 files selected", file=sys.stderr)
            return 0

        before = run_adapters(paths, rules, context.data, profile_name)
        findings = before
        if args.fix:
            run_adapters(paths, rules, context.data, profile_name, fix=True)
            findings = run_adapters(paths, rules, context.data, profile_name)
            identity = lambda item: (item.path, item.rule, item.detector, item.span)
            removed = Counter(map(identity, before)) - Counter(map(identity, findings))
            applied = sum(removed.values())
            print(f"sniff: applied {applied} safe fix(es); rechecked", file=sys.stderr)

        displayed = [
            _display_finding(item, context.project_root, stdin_path)
            for item in findings
        ]
        stdin_source = (
            stdin_path.read_text(encoding="utf-8") if stdin_path is not None else None
        )
        _print_findings(displayed, args.format, context.project_root, stdin_source)

    threshold = args.fail_on or str(context.data.get("fail_on", "error"))
    if threshold not in SEVERITY_RANK:
        raise SniffError(f"invalid failure level {threshold!r}")
    return int(
        any(
            SEVERITY_RANK[item.severity] >= SEVERITY_RANK[threshold]
            for item in findings
        )
    )


def _rule_payload(rule: Rule, config: dict[str, Any], profile: str) -> dict[str, Any]:
    return {
        "id": rule.id,
        "code": rule.code,
        "severity": effective_severity(rule, config, profile),
        "message": rule.message,
        "guidance": rule.body,
    }


def _rules(args: argparse.Namespace) -> int:
    context = _context(args)
    profile_name, _ = _profile(context.data, args.profile)
    rules = [
        rule
        for rule in selected_rules(
            load_rules(context.rule_dirs), context.data, profile_name
        )
        if rule.sniffers_of("llm")
    ]
    if args.format in {"json", "jsonl"}:
        for rule in rules:
            print(
                json.dumps(
                    _rule_payload(rule, context.data, profile_name), ensure_ascii=False
                )
            )
        return 0
    for rule in rules:
        severity = effective_severity(rule, context.data, profile_name)
        print(f"### {rule.code} {rule.id} [{severity}]")
        print(rule.message)
        print()
        print(rule.body)
        print()
    return 0


def _report_format(
    requested: str, environ: Mapping[str, str] | None = None
) -> str:
    if requested != "auto":
        return requested
    environment = os.environ if environ is None else environ
    if any(environment.get(name) for name in ASSISTANT_ENV_VARS):
        return "markdown"
    return "terminal"


def _report(args: argparse.Namespace) -> int:
    project_root = Path(args.project_root).expanduser().resolve()
    findings = parse_report_findings(sys.stdin)
    output_format = _report_format(args.format)
    print(
        render_report(
            findings,
            project_root,
            markdown=output_format == "markdown",
            ansi=output_format == "terminal" and sys.stdout.isatty(),
        )
    )
    return 0


def _parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(prog="sniff")
    parser.add_argument("--version", action="version", version=f"sniff {__version__}")
    subparsers = parser.add_subparsers(dest="command", required=True)

    check = subparsers.add_parser(
        "check", help="run registered deterministic detectors"
    )
    check.add_argument("paths", nargs="+", help="files, directories, or '-' for stdin")
    check.add_argument("--profile", help="built-in or project-defined profile")
    check.add_argument("--config", help="explicit project configuration")
    check.add_argument(
        "--format", choices=("human", "report", "json", "jsonl"), default="human"
    )
    check.add_argument("--fail-on", choices=("suggestion", "warning", "error"))
    check.add_argument(
        "--fix", action="store_true", help="apply safe deterministic fixes and recheck"
    )
    check.set_defaults(handler=_check)

    rules = subparsers.add_parser("rules", help="emit applicable LLM rule guidance")
    rules.add_argument("--profile", help="built-in or project-defined profile")
    rules.add_argument("--target", help="target used for project config discovery")
    rules.add_argument("--config", help="explicit project configuration")
    rules.add_argument("--format", choices=("llm", "json", "jsonl"), default="llm")
    rules.set_defaults(handler=_rules)

    report = subparsers.add_parser(
        "report", help="render adjudicated JSONL findings"
    )
    report.add_argument(
        "--project-root",
        default=".",
        help="base directory for relative paths and clickable locations",
    )
    report.add_argument(
        "--format",
        choices=("auto", "terminal", "markdown"),
        default="auto",
        help="infer the host, or render explicitly for a terminal or Markdown host",
    )
    report.set_defaults(handler=_report)
    return parser


def main(argv: list[str] | None = None) -> int:
    try:
        args = _parser().parse_args(argv)
        return int(args.handler(args))
    except SniffError as exc:
        print(f"sniff: error: {exc}", file=sys.stderr)
        return 2
