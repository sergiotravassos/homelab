#!/usr/bin/env python3
"""Verifica que as ligacoes relativas entre ficheiros Markdown nao estao partidas.

Um repositorio de documentacao com ligacoes mortas perde a confianca de quem o
le. Corre no CI para que isso nao aconteca em silencio.
"""
from __future__ import annotations

import re
import sys
from pathlib import Path
from urllib.parse import unquote, urlparse

ROOT = Path(__file__).resolve().parent.parent
LINK = re.compile(r"\[[^\]]*\]\(([^)]+)\)")
IMG = re.compile(r'<img[^>]+src="([^"]+)"')

SKIP_SCHEMES = {"http", "https", "mailto", "tel"}

# Directorios que nao sao nossos: providers descarregados, coleccoes do Galaxy,
# pasta de trabalho do instalador. A documentacao que trazem nao e para validar.
SKIP_DIRS = {
    ".git",
    ".terraform",
    "collections",
    "node_modules",
    "work",
    ".direnv",
    ".venv",
}


def targets(text: str):
    yield from LINK.findall(text)
    yield from IMG.findall(text)


def main() -> int:
    broken: list[str] = []
    checked = 0

    for md in sorted(ROOT.rglob("*.md")):
        if SKIP_DIRS & set(md.parts):
            continue
        text = md.read_text(encoding="utf-8")

        for raw in targets(text):
            parsed = urlparse(raw)
            if parsed.scheme in SKIP_SCHEMES:
                continue
            path = unquote(parsed.path)
            if not path or path.startswith("#"):
                continue

            checked += 1
            resolved = (md.parent / path).resolve()
            if not resolved.exists():
                rel = md.relative_to(ROOT)
                broken.append(f"{rel}: {raw}")

    for b in broken:
        print(f"LIGACAO PARTIDA  {b}")

    print(f"\n{checked} ligacoes verificadas, {len(broken)} partidas")
    return 1 if broken else 0


if __name__ == "__main__":
    sys.exit(main())
