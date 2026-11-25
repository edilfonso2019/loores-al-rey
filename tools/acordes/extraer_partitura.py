"""Extrae los cifrados (acordes) escritos sobre el pentagrama en las partituras PDF.

En los PDF cada acorde viene en pedazos: la letra y números en Times (~10 pt) y las
alteraciones como glifos pequeños de la fuente musical Maestro ('α' = bemol).
Aquí se juntan por renglón y cercanía horizontal.

Uso:  .venv\\Scripts\\python.exe extraer_partitura.py 1 10 50 ...
"""
import json
import os
import re
import sys

import pymupdf

AQUI = os.path.dirname(os.path.abspath(__file__))
ACORDE = re.compile(r"^[A-G][b#]?(m|maj|dim|aug|sus|º|°|\+)?\d*(-\d+)?(sus\d*|add\d+)?(/[A-G][b#]?)?$")
MAESTRO = {"α": "b", "∀": "#"}


def piezas_de_pagina(pagina):
    piezas = []
    for bloque in pagina.get_text("rawdict")["blocks"]:
        for linea in bloque.get("lines", []):
            for span in linea["spans"]:
                es_maestro = span["font"] == "Maestro"
                if es_maestro and span["size"] > 15:
                    continue  # glifos del pentagrama, no del cifrado
                if not es_maestro and not (8 <= span["size"] <= 11.5):
                    continue  # títulos, números de compás grandes, etc.
                for c in span["chars"]:
                    ch = c["c"]
                    if es_maestro:
                        ch = MAESTRO.get(ch)
                        if not ch:
                            continue
                    if ch.strip():
                        x0, y0, x1, y1 = c["bbox"]
                        piezas.append({"c": ch, "x0": x0, "x1": x1, "y": (y0 + y1) / 2, "m": es_maestro})
    return piezas


def acordes_de_pagina(pagina):
    piezas = sorted(piezas_de_pagina(pagina), key=lambda p: (round(p["y"] / 4), p["x0"]))
    # renglones por altura (tolerancia 3.5 px)
    renglones = []
    for p in sorted(piezas, key=lambda p: p["y"]):
        if renglones and abs(renglones[-1][-1]["y"] - p["y"]) < 3.5:
            renglones[-1].append(p)
        else:
            renglones.append([p])
    encontrados = []
    for r in renglones:
        r.sort(key=lambda p: p["x0"])
        palabras, actual, fin = [], "", None
        x_ini = None
        for p in r:
            if fin is not None and p["x0"] - fin > 2.5:
                palabras.append((x_ini, actual))
                actual, x_ini = "", None
            if x_ini is None:
                x_ini = p["x0"]
            actual += p["c"]
            fin = p["x1"]
        if actual:
            palabras.append((x_ini, actual))
        for x, w in palabras:
            if ACORDE.match(w):
                encontrados.append({"x": round(x, 1), "y": round(r[0]["y"], 1), "acorde": w})
    return encontrados


def ordenar_por_sistema(acordes):
    """Los cifrados de un mismo sistema están en 1-2 alturas escalonadas: se ordenan por x dentro del sistema."""
    acordes = sorted(acordes, key=lambda a: a["y"])
    sistemas = []
    for a in acordes:
        if sistemas and a["y"] - sistemas[-1][0]["y"] < 20:
            sistemas[-1].append(a)
        else:
            sistemas.append([a])
    salida = []
    for s in sistemas:
        salida.extend(sorted(s, key=lambda a: a["x"]))
    return salida


def extraer(n):
    doc = pymupdf.open(os.path.join(AQUI, "partituras", f"{n}.pdf"))
    todos = []
    for i, pag in enumerate(doc):
        for a in ordenar_por_sistema(acordes_de_pagina(pag)):
            a["pagina"] = i + 1
            todos.append(a)
    return todos


if __name__ == "__main__":
    os.makedirs(os.path.join(AQUI, "salida"), exist_ok=True)
    for arg in sys.argv[1:]:
        n = int(arg)
        acordes = extraer(n)
        json.dump(acordes, open(os.path.join(AQUI, "salida", f"partitura_{n}.json"), "w", encoding="utf-8"),
                  ensure_ascii=False, indent=1)
        print(n, len(acordes), " ".join(a["acorde"] for a in acordes))
