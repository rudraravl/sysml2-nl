from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path


@dataclass
class TextDocument:
    text: str
    lines: list[str]
    path: str | None = None

    def span(self, start: int, end: int) -> str:
        return "\n".join(self.lines[start - 1 : end])


def from_text(text: str, path: str | None = None) -> TextDocument:
    text = text.replace("\r\n", "\n").replace("\r", "\n")
    return TextDocument(text=text, lines=text.splitlines(), path=path)


def from_file(path: str | Path) -> TextDocument:
    p = Path(path)
    return from_text(p.read_text(encoding="utf-8"), str(p))
