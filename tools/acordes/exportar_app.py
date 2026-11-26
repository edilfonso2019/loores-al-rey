"""Exporta los acordes sincronizados a assets/data/acordes.json para la app.

Por himno ("clasico-200"):
  tempo, compas,
  pps + picos: onda de la pista (pps valores por segundo, 0..100),
  pulsos: [[t, acorde_IA|null], ...]  (un pulso por beat; lo que oyó la IA),
  lineas: [{"coro": 0|1, "e": estrofa, "s": [[t, texto, une, [acordes]], ...]}, ...]
  eventos: [[t|null, acorde, pagina, x, y], ...]  (acordes de la partitura; x, y en fracción 0..1 de la página)

Uso:  .venv\\Scripts\\python.exe exportar_app.py 1 10 50 ...
"""
import json
import os
import sys

from visor import picos

AQUI = os.path.dirname(os.path.abspath(__file__))
DPI = 100  # el mismo con que sincronizar.py dibuja las páginas
PPS = 10


def main(numeros):
    salida = {"version": 1, "himnos": {}}
    for n in numeros:
        ia = json.load(open(os.path.join(AQUI, "salida", f"{n}.json"), encoding="utf-8"))
        ruta_s = os.path.join(AQUI, "salida", f"sinc_{n}.json")
        s = json.load(open(ruta_s, encoding="utf-8")) if os.path.exists(ruta_s) else None
        p20 = picos(os.path.join(AQUI, "pistas", f"{n}.mp3"))  # 20 por segundo
        p10 = [round(max(p20[i:i + 2]) * 100) for i in range(0, len(p20), 2)]
        h = {"tempo": ia.get("tempo"), "compas": ia.get("compas") or "4/4", "pps": PPS, "picos": p10,
             "pulsos": [[p[0], p[1]] for p in ia["pulsos"]], "lineas": [], "eventos": []}
        if s:
            ev = s["eventos"]
            pags = s["paginas"]
            h["lineas"] = [{"coro": 1 if li["tipo"] == "coro" else 0, "e": li["estrofa"],
                            "s": [[x["t"], x["texto"], 1 if x["une"] else 0, [ev[k]["acorde"] for k in x["acordes"]]]
                                  for x in li["silabas"]]} for li in s["lineas"]]
            h["eventos"] = [[e["t"], e["acorde"], e["pagina"],
                             round(e["x"] * DPI / 72 / pags[e["pagina"]]["w"], 4),
                             round(e["y"] * DPI / 72 / pags[e["pagina"]]["h"], 4)] for e in ev]
        salida["himnos"][f"clasico-{n}"] = h
    ruta = os.path.join(AQUI, "..", "..", "assets", "data", "acordes.json")
    with open(ruta, "w", encoding="utf-8") as f:
        json.dump(salida, f, ensure_ascii=False, separators=(",", ":"))
    print(os.path.abspath(ruta), f"{os.path.getsize(ruta) // 1024} KB", len(salida["himnos"]), "himnos")


if __name__ == "__main__":
    main([int(a) for a in sys.argv[1:]])
