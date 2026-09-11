import json
import re
from io import StringIO
from dataclasses import dataclass
from pathlib import Path
from typing import Iterable

from rich.console import Console
from rich.text import Text

from sniff.models import SniffError

SOURCE_WIDTH = 76
INDENT = "\u3000\u3000"
PROVENANCE_LABELS = {
    "vale -> llm confirmed": "Vale → LLM",
    "ruff -> llm confirmed": "Ruff → LLM",
    "llm only": "LLM",
    "vale candidate": "Vale",
    "ruff candidate": "Ruff",
}
CONFIRMED_SOURCES = {
    "vale -> llm confirmed",
    "ruff -> llm confirmed",
    "llm only",
}
RULE_CODE = re.compile(r"^[A-Z]{3}[0-9]{3}$")


@dataclass(frozen=True)
class ReportFinding:
    path: str
    line: int
    column: int
    end_line: int
    end_column: int
    rule: str
    code: str
    severity: str
    source: str
    span: str
    message: str
    source_text: str | None = None


@dataclass(frozen=True)
class SourceRow:
    line: int | None
    text: str
    start_column: int = 0
    finding: bool = False
    blank: bool = False


def _integer(payload: dict[str, object], name: str, default: int | None = None) -> int:
    value = payload.get(name, default)
    if isinstance(value, bool) or not isinstance(value, int) or value < 1:
        raise SniffError(f"report finding has invalid {name!r}")
    return value


def _string(payload: dict[str, object], name: str) -> str:
    value = payload.get(name)
    if not isinstance(value, str) or not value:
        raise SniffError(f"report finding has invalid {name!r}")
    return value


def parse_report_findings(lines: Iterable[str]) -> list[ReportFinding]:
    findings: list[ReportFinding] = []
    for number, raw in enumerate(lines, 1):
        if not raw.strip():
            continue
        try:
            payload = json.loads(raw)
        except json.JSONDecodeError as exc:
            raise SniffError(f"invalid report JSON on input line {number}: {exc}") from exc
        if not isinstance(payload, dict):
            raise SniffError(f"report input line {number} must be a JSON object")
        line = _integer(payload, "line")
        column = _integer(payload, "column")
        span = _string(payload, "span")
        end_line = _integer(payload, "end_line", line)
        end_column = _integer(payload, "end_column", column + len(span))
        severity = _string(payload, "severity").lower()
        if severity not in {"suggestion", "warning", "error"}:
            raise SniffError(f"report finding has invalid severity {severity!r}")
        source = _string(payload, "source").lower()
        if source not in CONFIRMED_SOURCES:
            choices = ", ".join(sorted(CONFIRMED_SOURCES))
            raise SniffError(f"report finding has invalid source {source!r}; use: {choices}")
        source_text = payload.get("source_text")
        if source_text is not None and not isinstance(source_text, str):
            raise SniffError("report finding has invalid 'source_text'")
        code = _string(payload, "code")
        if not RULE_CODE.fullmatch(code):
            raise SniffError(f"report finding has invalid rule code {code!r}")
        findings.append(
            ReportFinding(
                path=_string(payload, "path"),
                line=line,
                column=column,
                end_line=end_line,
                end_column=end_column,
                rule=_string(payload, "rule"),
                code=code,
                severity=severity,
                source=source,
                span=span,
                message=_string(payload, "message"),
                source_text=source_text,
            )
        )
    return findings


def _source_lines(finding: ReportFinding, project_root: Path) -> list[str]:
    if finding.source_text is not None:
        return finding.source_text.splitlines()
    path = Path(finding.path).expanduser()
    if not path.is_absolute():
        path = project_root / path
    try:
        return path.read_text(encoding="utf-8", errors="replace").splitlines()
    except OSError:
        return [finding.span]


def _wrapped(text: str, width: int = SOURCE_WIDTH) -> list[tuple[int, str]]:
    if not text:
        return [(0, "")]
    rows: list[tuple[int, str]] = []
    start = 0
    while start < len(text):
        limit = min(start + width, len(text))
        end = limit
        if limit < len(text):
            split = text.rfind(" ", start + width // 2, limit + 1)
            if split > start:
                end = split
        rows.append((start, text[start:end].rstrip()))
        start = end
        while start < len(text) and text[start] == " ":
            start += 1
    return rows


def _clip_context(text: str, *, leading: bool) -> str:
    if len(text) <= SOURCE_WIDTH:
        return text
    if leading:
        return "… " + text[-(SOURCE_WIDTH - 2) :].lstrip()
    return text[: SOURCE_WIDTH - 2].rstrip() + " …"


def _target_rows(finding: ReportFinding, text: str) -> list[SourceRow]:
    wrapped = _wrapped(text)
    span_start = max(finding.column - 1, 0)
    span_end = max(span_start + len(finding.span), finding.end_column - 1)
    hits = [
        index
        for index, (offset, value) in enumerate(wrapped)
        if offset < span_end and offset + max(len(value), 1) > span_start
    ]
    if not hits:
        hits = [min(len(wrapped) - 1, span_start // SOURCE_WIDTH)]
    first, last = min(hits), max(hits)
    if last - first + 1 > 3:
        last = first + 2
    elif last == first and len(wrapped) > 1:
        if first + 1 < len(wrapped):
            last += 1
        elif first:
            first -= 1
    result: list[SourceRow] = []
    selected = wrapped[first : last + 1]
    for index, (offset, value) in enumerate(selected):
        rendered = value
        adjusted_offset = offset
        if index == 0 and first > 0:
            rendered = "… " + rendered
            adjusted_offset -= 2
        if index == len(selected) - 1 and last < len(wrapped) - 1:
            rendered = rendered.rstrip() + " …"
        result.append(
            SourceRow(
                line=finding.line if index == 0 else None,
                text=rendered,
                start_column=adjusted_offset,
                finding=True,
            )
        )
    return result


def _excerpt_rows(finding: ReportFinding, project_root: Path) -> list[SourceRow]:
    lines = _source_lines(finding, project_root)
    target_index = finding.line - 1
    target = lines[target_index] if 0 <= target_index < len(lines) else finding.span
    target_rows = _target_rows(finding, target)
    budget = max(0, 3 - len(target_rows))
    before: list[SourceRow] = []
    after: list[SourceRow] = []

    def context_row(index: int, *, leading: bool) -> SourceRow:
        value = lines[index]
        return SourceRow(
            line=index + 1,
            text=_clip_context(value, leading=leading),
            finding=finding.line <= index + 1 <= finding.end_line,
            blank=not bool(value),
        )

    if budget >= 2 and target_index > 0:
        before.append(context_row(target_index - 1, leading=True))
        if before[-1].blank and target_index > 1:
            before.insert(0, context_row(target_index - 2, leading=True))
        if any(not item.blank for item in before):
            budget -= 1
    index = target_index + 1
    while index < len(lines) and budget > 0:
        item = context_row(index, leading=False)
        after.append(item)
        if not item.blank:
            budget -= 1
        index += 1
    if budget > 0 and not before:
        index = target_index - 1
        while index >= 0 and budget > 0:
            item = context_row(index, leading=True)
            before.insert(0, item)
            if not item.blank:
                budget -= 1
            index -= 1
    return [*before, *target_rows, *after]


def _caret_row(finding: ReportFinding, row: SourceRow) -> str | None:
    if not row.finding:
        return None
    if row.line is not None and finding.end_line > finding.line:
        span_start = finding.column - 1 if row.line == finding.line else 0
        span_end = finding.end_column - 1 if row.line == finding.end_line else len(row.text)
    else:
        span_start = max(finding.column - 1, 0)
        span_end = max(span_start + len(finding.span), finding.end_column - 1)
    row_start = max(row.start_column, 0)
    visible_prefix = 2 if row.text.startswith("… ") else 0
    suffix = 2 if row.text.endswith(" …") else 0
    row_end = row_start + len(row.text) - visible_prefix - suffix
    overlap_start = max(span_start, row_start)
    overlap_end = min(span_end, row_end)
    if overlap_start >= overlap_end:
        return None
    padding = visible_prefix + overlap_start - row_start
    return " " * padding + "^" * max(1, overlap_end - overlap_start)


def _render_excerpt(finding: ReportFinding, project_root: Path) -> list[str]:
    rows = _excerpt_rows(finding, project_root)
    digits = len(str(max((row.line or 0 for row in rows), default=finding.line)))
    rendered: list[str] = []
    for row in rows:
        if row.line is None:
            marker, number = " ", " " * digits
        else:
            marker = "›" if row.line == finding.line else " "
            number = str(row.line).rjust(digits)
        rendered.append(f"    │ {marker} {number} │ {row.text}")
        caret = _caret_row(finding, row)
        if caret:
            rendered.append(f"    │   {' ' * digits} │ {caret}")
    return rendered


def _markdown_escape(value: str) -> str:
    return value.replace("\\", "\\\\").replace("[", "\\[").replace("]", "\\]")


def _location(
    path_value: str, line: int, project_root: Path, *, markdown: bool
) -> str:
    if path_value == "<stdin>":
        return f"<stdin>:{line}"
    path = Path(path_value).expanduser()
    absolute = path if path.is_absolute() else project_root / path
    absolute = absolute.resolve()
    try:
        label_path = absolute.relative_to(project_root.resolve()).as_posix()
    except ValueError:
        label_path = path_value
    label = _markdown_escape(f"{label_path}:{line}")
    if not markdown or not absolute.exists():
        return label
    return f"[{label}](<{absolute}:{line}>)"


def _italic(value: str) -> str:
    return value.replace("*", "\\*").replace("_", "\\_")


def _render_message(message: str, *, markdown: bool) -> list[str]:
    lines = [
        value
        for paragraph in message.split("\n")
        for _, value in _wrapped(paragraph)
    ]
    rendered: list[str] = []
    for index, line in enumerate(lines):
        prefix = f"{INDENT}└── " if index == 0 else f"{INDENT}    "
        styled = f"*{_italic(line)}*" if markdown else line
        rendered.append(prefix + styled)
    return rendered


def _terminal_report(
    findings: list[ReportFinding],
    project_root: Path,
    *,
    subject: str,
    color: bool,
) -> str:
    stream = StringIO()
    console = Console(
        file=stream,
        force_terminal=color,
        no_color=not color,
        color_system="standard" if color else None,
        width=120,
    )
    output = Text()
    output.append(" ___ _  _ ___ ___ ___\n", style="bold cyan")
    output.append("/ __| \\| |_ _| __| __|\n", style="bold cyan")
    output.append("\\__ \\ .` || || _|| _|\n", style="bold cyan")
    output.append("|___/_|\\_|___|_| |_|\n\n", style="bold cyan")
    subject_word = subject if len(findings) == 1 else f"{subject}s"
    file_count = len({finding.path for finding in findings})
    file_word = "file" if file_count == 1 else "files"
    output.append(
        f"{len(findings)} {subject_word} across {file_count} {file_word}\n",
        style="bold",
    )

    grouped: dict[tuple[str, int], list[ReportFinding]] = {}
    for finding in findings:
        grouped.setdefault((finding.path, finding.line), []).append(finding)
    for (path, line), items in grouped.items():
        items.sort(key=lambda item: (item.line, item.column))
        output.append("\n")
        output.append(
            _location(path, line, project_root, markdown=False),
            style="bold cyan underline",
        )
        output.append("\n")
        for index, finding in enumerate(items):
            if index:
                output.append("\n")
            marker = "└── " if finding.severity == "error" else INDENT
            provenance = PROVENANCE_LABELS[finding.source]
            severity_style = {
                "error": "bold red",
                "warning": "bold yellow",
                "suggestion": "bold cyan",
            }[finding.severity]
            output.append(marker)
            output.append(
                f"[{finding.severity.upper()} {finding.code}] {finding.rule}",
                style=severity_style,
            )
            output.append(" · ")
            output.append(f"via {provenance}\n\n", style="dim italic")
            for excerpt_line in _render_excerpt(finding, project_root):
                style = severity_style if "^" in excerpt_line else "dim"
                output.append(excerpt_line + "\n", style=style)
            output.append("\n")
            for message_line in _render_message(finding.message, markdown=False):
                output.append(message_line + "\n", style="italic")

    console.print(output, end="", soft_wrap=True)
    return stream.getvalue().rstrip("\n")


def render_report(
    findings: list[ReportFinding],
    project_root: Path,
    *,
    subject: str = "finding",
    markdown: bool = True,
    ansi: bool = False,
) -> str:
    if not findings:
        qualifier = "confirmed " if subject == "finding" else ""
        return f"sniff: no {qualifier}{subject}s"
    if not markdown:
        return _terminal_report(
            findings, project_root, subject=subject, color=ansi
        )
    grouped: dict[tuple[str, int], list[ReportFinding]] = {}
    for finding in findings:
        grouped.setdefault((finding.path, finding.line), []).append(finding)
    subject_word = subject if len(findings) == 1 else f"{subject}s"
    file_count = len({finding.path for finding in findings})
    file_word = "file" if file_count == 1 else "files"
    banner = [
        " ___ _  _ ___ ___ ___",
        "/ __| \\| |_ _| __| __|",
        "\\__ \\ .` || || _|| _|",
        "|___/_|\\_|___|_| |_|",
        "",
        f"{len(findings)} {subject_word} across {file_count} {file_word}",
    ]
    output = ["```text", *banner, "```"] if markdown else banner
    for (path, line), items in grouped.items():
        items.sort(key=lambda item: (item.line, item.column))
        location = _location(path, line, project_root, markdown=markdown)
        output.extend(["", location + ("  " if markdown else "")])
        for index, finding in enumerate(items):
            if index:
                output.append("")
            marker = "└── " if finding.severity == "error" else INDENT
            provenance = PROVENANCE_LABELS[finding.source]
            label = f"[{finding.severity.upper()} {finding.code}] {finding.rule}"
            if markdown:
                output.extend(
                    [
                        f"{marker}**{label}** · *via {provenance}*",
                        "",
                        "```text",
                        *_render_excerpt(finding, project_root),
                        "```",
                        "",
                        *_render_message(finding.message, markdown=True),
                    ]
                )
    return "\n".join(output)
