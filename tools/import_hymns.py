#!/usr/bin/env python3
"""Convierte un archivo de texto plano de himnos al JSON que usa la app.

Formato de entrada (un archivo por himnario, UTF-8):

    # 26 Santo, santo, santo
    @ Adoración y alabanza
    ¡Santo! ¡Santo! ¡Santo! Señor omnipotente,
    siempre el labio mío loores te dará.

    CORO:
    (texto del coro)

    (segunda estrofa)

Reglas:
  - "# <número> <título>" inicia un himno.
  - "@ <categoría>" (opcional) define la sección.
  - Las estrofas se separan con una línea en blanco.
  - Una estrofa que empieza con "CORO:" se marca como coro.

Uso:
    python3 tools/import_hymns.py nuevo  himnos_nuevo.txt  assets/data/nuevo.json
    python3 tools/import_hymns.py antiguo himnos_antiguo.txt assets/data/antiguo.json
"""
import json
import re
import sys


def parse(book: str, text: str) -> list[dict]:
    hymns: list[dict] = []
    current: dict | None = None
    buffer: list[str] = []

    def flush_verse() -> None:
        nonlocal buffer
        if current is not None and buffer:
            raw = "\n".join(buffer).strip()
            chorus = raw.upper().startswith("CORO:")
            if chorus:
                raw = raw[5:].strip()
            verse = {"text": raw}
            if chorus:
                verse["chorus"] = True
            current["verses"].append(verse)
        buffer = []

    for line in text.splitlines():
        header = re.match(r"^#\s*(\d+)\s+(.+)$", line)
        if header:
            flush_verse()
            if current:
                hymns.append(current)
            current = {
                "book": book,
                "number": int(header.group(1)),
                "title": header.group(2).strip(),
                "verses": [],
            }
        elif line.startswith("@") and current is not None:
            current["category"] = line[1:].strip()
        elif not line.strip():
            flush_verse()
        else:
            buffer.append(line.rstrip())

    flush_verse()
    if current:
        hymns.append(current)
    hymns.sort(key=lambda h: h["number"])
    return hymns


def main() -> None:
    if len(sys.argv) != 4:
        sys.exit(__doc__)
    book, src, dst = sys.argv[1:]
    with open(src, encoding="utf-8") as f:
        hymns = parse(book, f.read())
    with open(dst, "w", encoding="utf-8") as f:
        json.dump(hymns, f, ensure_ascii=False, indent=1)
    print(f"{len(hymns)} himnos escritos en {dst}")


if __name__ == "__main__":
    main()
