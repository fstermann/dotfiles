from __future__ import annotations

import os
import subprocess
from dataclasses import dataclass
from pathlib import Path
from typing import Any

import tomllib

from .models import SniffError

SEVERITIES = {"suggestion", "warning", "error"}


@dataclass(frozen=True)
class ConfigContext:
    data: dict[str, Any]
    project_root: Path
    rule_dirs: tuple[Path, ...]
    sources: tuple[Path, ...]


def _load(path: Path) -> dict[str, Any]:
    try:
        with path.open("rb") as handle:
            data = tomllib.load(handle)
    except (OSError, tomllib.TOMLDecodeError) as exc:
        raise SniffError(f"cannot load config {path}: {exc}") from exc
    if data.get("version", 1) != 1:
        raise SniffError(f"{path}: unsupported config version {data.get('version')!r}")
    return data


def _merge(base: dict[str, Any], overlay: dict[str, Any]) -> dict[str, Any]:
    result = dict(base)
    for key, value in overlay.items():
        previous = result.get(key)
        if isinstance(previous, dict) and isinstance(value, dict):
            result[key] = _merge(previous, value)
        elif isinstance(previous, list) and isinstance(value, list):
            result[key] = list(dict.fromkeys([*previous, *value]))
        else:
            result[key] = value
    return result


def _git_root(start: Path) -> Path | None:
    result = subprocess.run(
        ["git", "-C", str(start), "rev-parse", "--show-toplevel"],
        capture_output=True,
        text=True,
        check=False,
    )
    if result.returncode:
        return None
    return Path(result.stdout.strip()).resolve()


def _project_config(start: Path) -> tuple[Path | None, Path]:
    start = start.resolve()
    if start.is_file():
        start = start.parent
    git_root = _git_root(start)
    stop = git_root or Path(start.anchor)
    current = start
    while True:
        candidate = current / "sniff.toml"
        if candidate.is_file():
            return candidate, current
        if current == stop or current.parent == current:
            break
        current = current.parent
    return None, git_root or start


def _string_list(value: Any, location: str) -> None:
    if not isinstance(value, list) or not all(isinstance(item, str) for item in value):
        raise SniffError(f"{location} must be a list of strings")


def _validate(data: dict[str, Any]) -> None:
    profiles = data.get("profiles")
    if not isinstance(profiles, dict) or not profiles:
        raise SniffError("config must define at least one profile")
    default = data.get("default_profile")
    if not isinstance(default, str) or default not in profiles:
        raise SniffError(f"default_profile references unknown profile {default!r}")
    if data.get("fail_on", "error") not in SEVERITIES:
        raise SniffError("fail_on must be suggestion, warning, or error")

    for name, profile in profiles.items():
        if not isinstance(profile, dict):
            raise SniffError(f"profiles.{name} must be a table")
        for key in ("tags", "include", "exclude", "include_rules", "exclude_rules"):
            if key in profile:
                _string_list(profile[key], f"profiles.{name}.{key}")
        severity = profile.get("severity", {})
        if not isinstance(severity, dict) or any(
            value not in SEVERITIES for value in severity.values()
        ):
            raise SniffError(f"profiles.{name}.severity contains an invalid level")

    rules = data.get("rules", {})
    if not isinstance(rules, dict):
        raise SniffError("rules must be a table")
    for rule_id, override in rules.items():
        if not isinstance(override, dict):
            raise SniffError(f"rules.{rule_id} must be a table")
        if "enabled" in override and not isinstance(override["enabled"], bool):
            raise SniffError(f"rules.{rule_id}.enabled must be true or false")
        if override.get("severity", "warning") not in SEVERITIES:
            raise SniffError(f"rules.{rule_id}.severity contains an invalid level")

    adapters = data.get("adapters", {})
    if not isinstance(adapters, dict):
        raise SniffError("adapters must be a table")
    for name, adapter in adapters.items():
        if not isinstance(adapter, dict):
            raise SniffError(f"adapters.{name} must be a table")
        if "enabled" in adapter and not isinstance(adapter["enabled"], bool):
            raise SniffError(f"adapters.{name}.enabled must be true or false")
        if "executable" in adapter and not isinstance(adapter["executable"], str):
            raise SniffError(f"adapters.{name}.executable must be a string")


def load_config(
    skill_root: Path,
    start: Path,
    explicit: Path | None = None,
) -> ConfigContext:
    defaults = skill_root / "config" / "defaults.toml"
    data = _load(defaults)
    sources = [defaults]

    xdg = Path(os.environ.get("XDG_CONFIG_HOME", Path.home() / ".config"))
    global_root = xdg / "sniff"
    global_config = global_root / "sniff.toml"
    if global_config.is_file():
        data = _merge(data, _load(global_config))
        sources.append(global_config)

    if explicit is not None:
        project_config = explicit.expanduser().resolve()
        if not project_config.is_file():
            raise SniffError(f"no such config: {project_config}")
        project_root = project_config.parent
    else:
        project_config, project_root = _project_config(start)
    if project_config is not None:
        data = _merge(data, _load(project_config))
        sources.append(project_config)

    _validate(data)

    rule_dirs = (
        skill_root / "rules",
        global_root / "rules",
        project_root / ".sniff" / "rules",
    )
    return ConfigContext(data, project_root, rule_dirs, tuple(sources))
