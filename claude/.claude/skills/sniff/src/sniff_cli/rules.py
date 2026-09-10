from __future__ import annotations

import re
from collections.abc import Iterable
from pathlib import Path
from typing import Any

import yaml

from .models import Rule, Sniffer, SniffError

SEVERITIES = {"suggestion", "warning", "error"}
SNIFFER_KINDS = {"llm", "vale", "ruff"}
RULE_ID = re.compile(r"^[a-z][a-z0-9]*(?:-[a-z0-9]+)+$")


def _read_rule(path: Path) -> Rule:
    text = path.read_text(encoding="utf-8")
    if not text.startswith("---\n"):
        raise SniffError(f"{path}: rule must start with YAML frontmatter")
    try:
        raw_frontmatter, body = text[4:].split("\n---\n", 1)
    except ValueError as exc:
        raise SniffError(f"{path}: unterminated YAML frontmatter") from exc
    try:
        data = yaml.safe_load(raw_frontmatter)
    except yaml.YAMLError as exc:
        raise SniffError(f"{path}: invalid YAML: {exc}") from exc
    if not isinstance(data, dict):
        raise SniffError(f"{path}: frontmatter must be a mapping")

    rule_id = data.get("id")
    if not isinstance(rule_id, str) or not RULE_ID.fullmatch(rule_id):
        raise SniffError(f"{path}: invalid rule id {rule_id!r}")
    if rule_id != path.stem:
        raise SniffError(f"{path}: id must equal filename stem")

    applies_to = data.get("applies_to")
    if (
        not isinstance(applies_to, list)
        or not applies_to
        or not all(isinstance(item, str) and item for item in applies_to)
    ):
        raise SniffError(f"{path}: applies_to must be a non-empty string list")

    severity = data.get("severity")
    if severity not in SEVERITIES:
        raise SniffError(f"{path}: severity must be suggestion, warning, or error")

    raw_sniffers = data.get("sniffers")
    if not isinstance(raw_sniffers, list) or not raw_sniffers:
        raise SniffError(f"{path}: sniffers must be a non-empty list")
    sniffers: list[Sniffer] = []
    for raw in raw_sniffers:
        if not isinstance(raw, dict) or raw.get("kind") not in SNIFFER_KINDS:
            raise SniffError(f"{path}: unsupported sniffer {raw!r}")
        kind = raw["kind"]
        options = {key: value for key, value in raw.items() if key != "kind"}
        if kind == "vale" and not isinstance(options.get("pattern"), str):
            raise SniffError(f"{path}: vale sniffer requires pattern")
        if kind == "ruff" and not isinstance(options.get("rule"), str):
            raise SniffError(f"{path}: ruff sniffer requires rule")
        sniffers.append(Sniffer(kind=kind, options=options))

    llm_exempt = bool(data.get("llm_exempt", False))
    if not llm_exempt and not any(item.kind == "llm" for item in sniffers):
        raise SniffError(f"{path}: add an llm sniffer or set llm_exempt: true")

    required_strings = ("name", "family", "message")
    for key in required_strings:
        if not isinstance(data.get(key), str) or not data[key].strip():
            raise SniffError(f"{path}: {key} must be a non-empty string")

    return Rule(
        id=rule_id,
        name=data["name"],
        family=data["family"],
        applies_to=tuple(applies_to),
        severity=severity,
        message=data["message"],
        body=body.strip(),
        path=path,
        sniffers=tuple(sniffers),
        fix=str(data.get("fix", "manual")),
        evidence=str(data.get("evidence", "")),
        llm_exempt=llm_exempt,
    )


def load_rules(directories: Iterable[Path]) -> dict[str, Rule]:
    loaded: dict[str, Rule] = {}
    for directory in directories:
        if not directory.is_dir():
            continue
        for path in sorted(directory.glob("*.md")):
            rule = _read_rule(path)
            if rule.id in loaded:
                raise SniffError(
                    f"duplicate rule id {rule.id!r}: {loaded[rule.id].path} and {path}"
                )
            loaded[rule.id] = rule
    return loaded


def selected_rules(
    rules: dict[str, Rule], config: dict[str, Any], profile_name: str
) -> list[Rule]:
    profiles = config.get("profiles", {})
    profile = profiles.get(profile_name)
    if not isinstance(profile, dict):
        choices = ", ".join(sorted(profiles))
        raise SniffError(f"unknown profile {profile_name!r}; choose one of: {choices}")
    tags = set(profile.get("tags", []))
    include_ids = set(profile.get("include_rules", []))
    exclude_ids = set(profile.get("exclude_rules", []))
    overrides = config.get("rules", {})
    referenced = include_ids | exclude_ids | set(overrides)
    unknown = referenced - set(rules)
    if unknown:
        raise SniffError(
            f"configuration references unknown rule(s): {', '.join(sorted(unknown))}"
        )

    chosen: list[Rule] = []
    for rule in rules.values():
        override = overrides.get(rule.id, {}) if isinstance(overrides, dict) else {}
        if isinstance(override, dict) and override.get("enabled") is False:
            continue
        applies = "*" in tags or bool(tags.intersection(rule.applies_to))
        if rule.id in include_ids:
            applies = True
        if rule.id in exclude_ids:
            applies = False
        if applies:
            chosen.append(rule)
    return sorted(chosen, key=lambda item: item.id)


def effective_severity(rule: Rule, config: dict[str, Any], profile_name: str) -> str:
    severity = rule.severity
    profile = config.get("profiles", {}).get(profile_name, {})
    profile_severity = profile.get("severity", {}) if isinstance(profile, dict) else {}
    if isinstance(profile_severity, dict):
        severity = profile_severity.get(rule.id, severity)
    override = config.get("rules", {}).get(rule.id, {})
    if isinstance(override, dict):
        severity = override.get("severity", severity)
    if severity not in SEVERITIES:
        raise SniffError(f"{rule.id}: invalid effective severity {severity!r}")
    return severity
