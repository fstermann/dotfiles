from __future__ import annotations

from dataclasses import dataclass, field
from pathlib import Path
from typing import Any


class SniffError(RuntimeError):
    """A configuration, input, or detector failure."""


@dataclass(frozen=True)
class Sniffer:
    kind: str
    options: dict[str, Any] = field(default_factory=dict)


@dataclass(frozen=True)
class Rule:
    id: str
    name: str
    family: str
    applies_to: tuple[str, ...]
    severity: str
    message: str
    body: str
    path: Path
    sniffers: tuple[Sniffer, ...]
    fix: str = "manual"
    evidence: str = ""
    llm_exempt: bool = False

    def sniffers_of(self, kind: str) -> tuple[Sniffer, ...]:
        return tuple(item for item in self.sniffers if item.kind == kind)


@dataclass(frozen=True)
class Finding:
    path: str
    line: int
    column: int
    end_line: int
    end_column: int
    rule: str
    severity: str
    detector: str
    span: str
    message: str

    def as_dict(self) -> dict[str, Any]:
        return {
            "path": self.path,
            "line": self.line,
            "column": self.column,
            "end_line": self.end_line,
            "end_column": self.end_column,
            "rule": self.rule,
            "severity": self.severity,
            "detector": self.detector,
            "span": self.span,
            "message": self.message,
        }

    def key(self) -> tuple[str, int, int, str, str]:
        return (self.path, self.line, self.column, self.rule, self.detector)
