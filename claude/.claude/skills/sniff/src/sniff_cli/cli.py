from __future__ import annotations

import json
import os
import sys
import tempfile
from collections import Counter
from collections.abc import Mapping
from dataclasses import replace
from enum import Enum
from pathlib import Path
from typing import Annotated, Any

import typer
from rich.console import Console
from rich.text import Text

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


class CheckFormat(str, Enum):
    human = "human"
    report = "report"
    json = "json"
    jsonl = "jsonl"


class RulesFormat(str, Enum):
    llm = "llm"
    json = "json"
    jsonl = "jsonl"


class ReportFormat(str, Enum):
    auto = "auto"
    terminal = "terminal"
    markdown = "markdown"


class ColorMode(str, Enum):
    auto = "auto"
    always = "always"
    never = "never"


app = typer.Typer(
    help="Find ambiguous, contradictory, and unverifiable writing.",
    no_args_is_help=True,
    pretty_exceptions_enable=False,
    rich_markup_mode="rich",
)


def _skill_root() -> Path:
    return Path(__file__).resolve().parents[2]


def _start_path(raw_paths: list[str] | None, target: str | None = None) -> Path:
    raw = target
    if raw is None and raw_paths:
        raw = next((item for item in raw_paths if item != "-"), None)
    return Path(raw).expanduser() if raw else Path.cwd()


def _context(
    config: str | None,
    raw_paths: list[str] | None = None,
    target: str | None = None,
) -> ConfigContext:
    explicit = Path(config) if config else None
    return load_config(
        _skill_root(), _start_path(raw_paths, target), explicit
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
    color: bool = False,
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
                ansi=color,
            )
        )
        return
    console = Console(
        file=sys.stdout,
        force_terminal=color,
        no_color=not color,
        color_system="standard" if color else None,
    )
    for finding in findings:
        severity_style = {
            "error": "bold red",
            "warning": "bold yellow",
            "suggestion": "bold cyan",
        }[finding.severity]
        console.print(
            Text.assemble(
                (f"{finding.path}:{finding.line}:{finding.column}", "bold cyan"),
                "  ",
                (f"[{finding.severity} {finding.code}]", severity_style),
                f"  {finding.rule}  ",
                (f"({finding.detector} candidate)", "dim italic"),
            )
        )
        console.print(Text.assemble(("  span:   ", "dim"), f'"{finding.span}"'))
        console.print(Text.assemble(("  why:    ", "dim"), finding.message))


def _check(
    paths_arg: list[str],
    profile_arg: str | None,
    config_arg: str | None,
    output_format: str,
    fail_on: str | None,
    fix: bool,
    color: bool,
) -> int:
    if paths_arg.count("-") > 1 or ("-" in paths_arg and len(paths_arg) > 1):
        raise SniffError("stdin ('-') cannot be combined with other inputs")
    if fix and "-" in paths_arg:
        raise SniffError("--fix cannot modify stdin")

    context = _context(config_arg, paths_arg)
    profile_name, profile = _profile(context.data, profile_arg)
    rules = selected_rules(load_rules(context.rule_dirs), context.data, profile_name)
    if not rules:
        print("sniff: 0 rules selected", file=sys.stderr)
        return 0
    paths = discover_inputs(paths_arg, profile, context.project_root)
    stdin_path: Path | None = None

    with tempfile.TemporaryDirectory(prefix="sniff-stdin-") as temp:
        if "-" in paths_arg:
            suffix = ".py" if profile_name == "code" else ".md"
            stdin_path = Path(temp) / f"stdin{suffix}"
            stdin_path.write_text(sys.stdin.read(), encoding="utf-8")
            paths = [stdin_path]

        if not paths:
            print("sniff: 0 files selected", file=sys.stderr)
            return 0

        before = run_adapters(paths, rules, context.data, profile_name)
        findings = before
        if fix:
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
        _print_findings(
            displayed,
            output_format,
            context.project_root,
            stdin_source,
            color,
        )

    threshold = fail_on or str(context.data.get("fail_on", "error"))
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


def _rules(
    profile_arg: str | None,
    target: str | None,
    config_arg: str | None,
    output_format: str,
) -> int:
    context = _context(config_arg, target=target)
    profile_name, _ = _profile(context.data, profile_arg)
    rules = [
        rule
        for rule in selected_rules(
            load_rules(context.rule_dirs), context.data, profile_name
        )
        if rule.sniffers_of("llm")
    ]
    if output_format in {"json", "jsonl"}:
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


def _report(project_root_arg: str, requested_format: str, color: bool) -> int:
    project_root = Path(project_root_arg).expanduser().resolve()
    findings = parse_report_findings(sys.stdin)
    output_format = _report_format(requested_format)
    print(
        render_report(
            findings,
            project_root,
            markdown=output_format == "markdown",
            ansi=output_format == "terminal" and color,
        )
    )
    return 0


def _version_callback(value: bool) -> None:
    if value:
        typer.echo(f"sniff {__version__}")
        raise typer.Exit()


def _color_enabled(mode: ColorMode) -> bool:
    if mode is ColorMode.always:
        return True
    if mode is ColorMode.never:
        return False
    if "NO_COLOR" in os.environ or os.environ.get("TERM") in {"dumb", "unknown"}:
        return False
    return sys.stdout.isatty()


@app.callback()
def root(
    version: Annotated[
        bool | None,
        typer.Option("--version", callback=_version_callback, is_eager=True),
    ] = None,
) -> None:
    """Find ambiguous, contradictory, and unverifiable writing."""


@app.command()
def check(
    paths: Annotated[list[str], typer.Argument(help="Files, directories, or '-' for stdin.")],
    profile: Annotated[
        str | None, typer.Option(help="Built-in or project-defined profile.")
    ] = None,
    config: Annotated[
        str | None, typer.Option(help="Explicit project configuration.")
    ] = None,
    output_format: Annotated[
        CheckFormat, typer.Option("--format", help="Output format.")
    ] = CheckFormat.human,
    fail_on: Annotated[
        str | None,
        typer.Option(help="Fail at suggestion, warning, or error severity."),
    ] = None,
    fix: Annotated[
        bool, typer.Option(help="Apply safe deterministic fixes and recheck.")
    ] = False,
    color: Annotated[
        ColorMode, typer.Option(help="Colorize terminal output.")
    ] = ColorMode.auto,
) -> None:
    """Run registered deterministic detectors."""
    if fail_on is not None and fail_on not in SEVERITY_RANK:
        raise typer.BadParameter(
            "choose suggestion, warning, or error", param_hint="--fail-on"
        )
    raise typer.Exit(
        _check(
            paths,
            profile,
            config,
            output_format.value,
            fail_on,
            fix,
            _color_enabled(color),
        )
    )


@app.command()
def rules(
    profile: Annotated[
        str | None, typer.Option(help="Built-in or project-defined profile.")
    ] = None,
    target: Annotated[
        str | None, typer.Option(help="Target used for project config discovery.")
    ] = None,
    config: Annotated[
        str | None, typer.Option(help="Explicit project configuration.")
    ] = None,
    output_format: Annotated[
        RulesFormat, typer.Option("--format", help="Output format.")
    ] = RulesFormat.llm,
) -> None:
    """Emit applicable LLM rule guidance."""
    raise typer.Exit(_rules(profile, target, config, output_format.value))


@app.command()
def report(
    project_root: Annotated[
        str,
        typer.Option(
            help="Base directory for relative paths and clickable locations."
        ),
    ] = ".",
    output_format: Annotated[
        ReportFormat,
        typer.Option(
            "--format",
            help="Infer the host, or render for a terminal or Markdown host.",
        ),
    ] = ReportFormat.auto,
    color: Annotated[
        ColorMode, typer.Option(help="Colorize terminal output.")
    ] = ColorMode.auto,
) -> None:
    """Render adjudicated JSONL findings."""
    raise typer.Exit(
        _report(project_root, output_format.value, _color_enabled(color))
    )


def main(argv: list[str] | None = None) -> int:
    try:
        app(args=argv, prog_name="sniff")
    except SniffError as exc:
        Console(stderr=True).print(f"[bold red]sniff: error:[/bold red] {exc}")
        return 2
    except SystemExit as exc:
        return int(exc.code or 0)
    return 0
