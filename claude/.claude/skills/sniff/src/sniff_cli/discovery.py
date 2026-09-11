import fnmatch
import subprocess
from collections.abc import Iterable
from pathlib import Path
from typing import Any

from sniff_cli.models import SniffError

IGNORED_DIRS = {".git", ".hg", ".svn", ".sniff", ".venv", "node_modules"}


def _matches(path: str, patterns: Iterable[str]) -> bool:
    for pattern in patterns:
        if fnmatch.fnmatch(path, pattern):
            return True
        if pattern.startswith("**/") and fnmatch.fnmatch(path, pattern[3:]):
            return True
    return False


def _git_root(start: Path) -> Path | None:
    result = subprocess.run(
        ["git", "-C", str(start), "rev-parse", "--show-toplevel"],
        capture_output=True,
        text=True,
        check=False,
    )
    return Path(result.stdout.strip()).resolve() if result.returncode == 0 else None


def _git_files(directory: Path) -> list[Path] | None:
    root = _git_root(directory)
    if root is None:
        return None
    try:
        relative = directory.resolve().relative_to(root)
    except ValueError:
        return None
    pathspec = str(relative) if str(relative) != "." else "."
    result = subprocess.run(
        [
            "git",
            "-C",
            str(root),
            "ls-files",
            "-z",
            "--cached",
            "--others",
            "--exclude-standard",
            "--",
            pathspec,
        ],
        capture_output=True,
        check=False,
    )
    if result.returncode:
        raise SniffError(
            result.stderr.decode(errors="replace").strip()
            or "git file discovery failed"
        )
    return [root / item.decode() for item in result.stdout.split(b"\0") if item]


def _walk(directory: Path) -> Iterable[Path]:
    for path in directory.rglob("*"):
        if any(part in IGNORED_DIRS for part in path.parts):
            continue
        if path.is_file():
            yield path


def discover_inputs(
    raw_paths: list[str], profile: dict[str, Any], project_root: Path
) -> list[Path]:
    include = profile.get("include", ["*"])
    exclude = profile.get("exclude", [])
    discovered: list[Path] = []
    explicit_files: set[Path] = set()

    for raw in raw_paths:
        if raw == "-":
            continue
        path = Path(raw).expanduser().resolve()
        if not path.exists():
            raise SniffError(f"no such input: {raw}")
        if path.is_file():
            explicit_files.add(path)
            discovered.append(path)
            continue
        candidates = _git_files(path)
        discovered.extend(candidates if candidates is not None else _walk(path))

    kept: list[Path] = []
    seen: set[Path] = set()
    for path in discovered:
        path = path.resolve()
        if path in seen:
            continue
        seen.add(path)
        try:
            display = path.relative_to(project_root).as_posix()
        except ValueError:
            display = path.as_posix()
        if path in explicit_files:
            if _matches(display, include):
                kept.append(path)
            continue
        if _matches(display, include) and not _matches(display, exclude):
            kept.append(path)
    return sorted(kept)
