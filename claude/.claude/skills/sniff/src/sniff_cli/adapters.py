import json
import shutil
import subprocess
import tempfile
from collections.abc import Iterable, Iterator
from pathlib import Path
from typing import Any

import yaml

from .models import Finding, Rule, SniffError
from .rules import effective_severity

BATCH_SIZE = 200


def _batches(paths: Iterable[Path]) -> Iterator[list[Path]]:
    batch: list[Path] = []
    for path in paths:
        batch.append(path)
        if len(batch) == BATCH_SIZE:
            yield batch
            batch = []
    if batch:
        yield batch


def _executable(config: dict[str, Any], kind: str) -> str:
    adapter = config.get("adapters", {}).get(kind, {})
    if not isinstance(adapter, dict) or adapter.get("enabled", True) is False:
        raise SniffError(f"required adapter {kind!r} is disabled")
    executable = str(adapter.get("executable", kind))
    resolved = shutil.which(executable)
    if resolved is None:
        raise SniffError(
            f"required adapter {kind!r} is unavailable: install {executable}"
        )
    return resolved


def _source_line(path: str, line: int) -> str:
    try:
        return Path(path).read_text(encoding="utf-8").splitlines()[line - 1]
    except (OSError, UnicodeError, IndexError):
        return ""


def _vale_config(
    root: Path, rules: list[Rule], config: dict[str, Any], profile: str
) -> Path:
    style = root / "styles" / "Sniff"
    style.mkdir(parents=True)
    for rule in rules:
        sniffers = rule.sniffers_of("vale")
        sniffer = sniffers[0]
        payload: dict[str, Any] = {
            "extends": "existence",
            "message": rule.message,
            "level": effective_severity(rule, config, profile),
            "ignorecase": bool(sniffer.options.get("ignorecase", True)),
            "scope": sniffer.options.get("scope", "text"),
            "raw": [item.options["pattern"] for item in sniffers],
        }
        (style / f"{rule.id}.yml").write_text(
            yaml.safe_dump(payload, sort_keys=False, allow_unicode=True),
            encoding="utf-8",
        )
    vale_config = root / ".vale.ini"
    vale_config.write_text(
        "StylesPath = styles\nMinAlertLevel = suggestion\n\n[*]\nBasedOnStyles = Sniff\n",
        encoding="utf-8",
    )
    return vale_config


def run_vale(
    paths: list[Path],
    rules: list[Rule],
    config: dict[str, Any],
    profile: str,
    fix: bool = False,
) -> list[Finding]:
    applicable = [rule for rule in rules if rule.sniffers_of("vale")]
    if not applicable or not paths:
        return []
    executable = _executable(config, "vale")
    by_native = {f"Sniff.{rule.id}": rule for rule in applicable}
    payloads: list[dict[str, Any]] = []
    with tempfile.TemporaryDirectory(prefix="sniff-vale-") as temp:
        temp_root = Path(temp)
        vale_config = _vale_config(temp_root, applicable, config, profile)
        command = [
            executable,
            "--no-global",
            "--config",
            str(vale_config),
            "--output=JSON",
        ]
        for batch in _batches(paths):
            result = subprocess.run(
                [*command, *(str(path) for path in batch)],
                capture_output=True,
                text=True,
                check=False,
            )
            if result.returncode not in (0, 1):
                raise SniffError(
                    f"vale failed ({result.returncode}): {result.stderr.strip()}"
                )
            try:
                payload = json.loads(result.stdout or "{}")
            except json.JSONDecodeError as exc:
                raise SniffError(
                    f"vale returned invalid JSON: {exc}: {result.stderr.strip()}"
                ) from exc
            if not isinstance(payload, dict):
                raise SniffError("vale returned an unexpected JSON shape")
            payloads.append(payload)

    findings: list[Finding] = []
    for payload in payloads:
        for filename, alerts in payload.items():
            for alert in alerts or []:
                native = alert.get("Check", "")
                rule = by_native.get(native)
                if rule is None:
                    continue
                span = alert.get("Span") or [1, 1]
                line = int(alert.get("Line", 1))
                match = str(alert.get("Match", ""))
                if not match:
                    source = _source_line(filename, line)
                    start = max(int(span[0]) - 1, 0)
                    end = max(int(span[-1]), start)
                    match = source[start:end]
                findings.append(
                    Finding(
                        path=str(Path(filename).resolve()),
                        line=line,
                        column=int(span[0]),
                        end_line=line,
                        end_column=int(span[-1]),
                        rule=rule.id,
                        code=rule.code,
                        severity=effective_severity(rule, config, profile),
                        detector="vale",
                        span=match,
                        message=rule.message,
                    )
                )
    return findings


def run_ruff(
    paths: list[Path],
    rules: list[Rule],
    config: dict[str, Any],
    profile: str,
    fix: bool = False,
) -> list[Finding]:
    applicable = [rule for rule in rules if rule.sniffers_of("ruff")]
    python_paths = [path for path in paths if path.suffix in {".py", ".pyi"}]
    if not applicable or not python_paths:
        return []
    executable = _executable(config, "ruff")
    by_native: dict[str, Rule] = {}
    for rule in applicable:
        for sniffer in rule.sniffers_of("ruff"):
            native = str(sniffer.options["rule"])
            if native in by_native:
                raise SniffError(f"ruff rule {native} is registered more than once")
            by_native[native] = rule
    command = [
        executable,
        "check",
        "--output-format=json",
        "--select",
        ",".join(sorted(by_native)),
    ]
    if fix:
        command.extend(["--fix", "--no-unsafe-fixes"])
    payload: list[dict[str, Any]] = []
    for batch in _batches(python_paths):
        result = subprocess.run(
            [*command, *(str(path) for path in batch)],
            capture_output=True,
            text=True,
            check=False,
        )
        if result.returncode not in (0, 1):
            raise SniffError(
                f"ruff failed ({result.returncode}): {result.stderr.strip()}"
            )
        try:
            batch_payload = json.loads(result.stdout or "[]")
        except json.JSONDecodeError as exc:
            raise SniffError(
                f"ruff returned invalid JSON: {exc}: {result.stderr.strip()}"
            ) from exc
        if not isinstance(batch_payload, list):
            raise SniffError("ruff returned an unexpected JSON shape")
        payload.extend(batch_payload)

    findings: list[Finding] = []
    for alert in payload:
        rule = by_native.get(str(alert.get("code", "")))
        if rule is None:
            continue
        location = alert.get("location", {})
        end = alert.get("end_location", location)
        filename = str(alert["filename"])
        line = int(location.get("row", 1))
        start_column = int(location.get("column", 1))
        end_line = int(end.get("row", line))
        end_column = int(end.get("column", start_column))
        source = _source_line(filename, line)
        span = (
            source[max(start_column - 1, 0) : max(end_column - 1, start_column)]
            if line == end_line and source
            else str(alert.get("message", ""))
        )
        findings.append(
            Finding(
                path=str(Path(filename).resolve()),
                line=line,
                column=start_column,
                end_line=end_line,
                end_column=end_column,
                rule=rule.id,
                code=rule.code,
                severity=effective_severity(rule, config, profile),
                detector="ruff",
                span=span,
                message=rule.message,
            )
        )
    return findings


def run_adapters(
    paths: list[Path],
    rules: list[Rule],
    config: dict[str, Any],
    profile: str,
    fix: bool = False,
) -> list[Finding]:
    findings = [
        *run_vale(paths, rules, config, profile, fix=fix),
        *run_ruff(paths, rules, config, profile, fix=fix),
    ]
    return sorted(findings, key=lambda item: item.key())
