"""Compara los acordes que oyó la IA (salida/{n}.json) con los de la partitura (salida/partitura_{n}.json).

Se compara a nivel "fundamental + mayor/menor" (sin 7, sin inversiones, sin sus), que es lo
que un guitarrista necesita como mínimo.
- vocabulario: % del tiempo de la pista en que la IA da un acorde que sí existe en la partitura.
- secuencia: % de los acordes de la partitura (una vuelta) que aparecen en el mismo orden en lo
  que oyó la IA (alineamiento local tipo Smith-Waterman contra la mejor estrofa).
"""
import json
import os
import sys

AQUI = os.path.dirname(os.path.abspath(__file__))
NOTAS = {"C": 0, "C#": 1, "Db": 1, "D": 2, "D#": 3, "Eb": 3, "E": 4, "F": 5, "F#": 6, "Gb": 6,
         "G": 7, "G#": 8, "Ab": 8, "A": 9, "A#": 10, "Bb": 10, "B": 11, "Cb": 11}


def basico(acorde):
    """'Ab7/C' -> (8, 'M'); 'Em/G' -> (4, 'm'); 'Ddim' -> (2, 'd')."""
    a = acorde.split("/")[0]
    raiz = a[:2] if len(a) > 1 and a[1] in "#b" else a[:1]
    resto = a[len(raiz):]
    if resto.startswith("dim") or resto.startswith("m7b5"):
        cal = "d"
    elif resto.startswith("m") and not resto.startswith("maj"):
        cal = "m"
    else:
        cal = "M"
    return NOTAS[raiz], cal


def sin_repetir(seq):
    out = []
    for s in seq:
        if not out or out[-1] != s:
            out.append(s)
    return out


def alinear(ref, hyp):
    """Smith-Waterman: cuántos acordes de ref aparecen en orden dentro de hyp."""
    m, n = len(ref), len(hyp)
    h = [[0] * (n + 1) for _ in range(m + 1)]
    c = [[0] * (n + 1) for _ in range(m + 1)]  # coincidencias en el camino
    mejor = (0, 0)
    for i in range(1, m + 1):
        for j in range(1, n + 1):
            opciones = [
                (h[i - 1][j - 1] + (2 if ref[i - 1] == hyp[j - 1] else -1),
                 c[i - 1][j - 1] + (ref[i - 1] == hyp[j - 1])),
                (h[i - 1][j] - 1, c[i - 1][j]),
                (h[i][j - 1] - 1, c[i][j - 1]),
                (0, 0),
            ]
            h[i][j], c[i][j] = max(opciones)
            if h[i][j] > mejor[0]:
                mejor = (h[i][j], c[i][j])
    return mejor[1]


def main(numeros):
    filas = []
    for n in numeros:
        ia = json.load(open(os.path.join(AQUI, "salida", f"{n}.json"), encoding="utf-8"))
        pa = json.load(open(os.path.join(AQUI, "salida", f"partitura_{n}.json"), encoding="utf-8"))
        if not pa:
            filas.append({"n": n, "sin_cifrado": True})
            continue
        ref = sin_repetir([basico(a["acorde"]) for a in pa])
        vocab = set(ref)
        total = sum(s["fin"] - s["inicio"] for s in ia["acordes"])
        dentro = sum(s["fin"] - s["inicio"] for s in ia["acordes"] if basico(s["acorde"]) in vocab)
        hyp = sin_repetir([basico(s["acorde"]) for s in ia["acordes"]])
        coinciden = alinear(ref, hyp)
        fila = {"n": n, "titulo": ia["titulo"], "acordes_partitura": len(ref),
                "vocabulario_pct": round(dentro / total * 100, 1),
                "secuencia_pct": round(coinciden / len(ref) * 100, 1)}
        filas.append(fila)
        print(f"{n:>4} {ia['titulo'][:30]:30} vocabulario={fila['vocabulario_pct']:5}%  "
              f"secuencia={fila['secuencia_pct']:5}%  ({coinciden}/{len(ref)})")
    validas = [f for f in filas if "secuencia_pct" in f]
    if validas:
        print(f"PROMEDIO vocabulario={sum(f['vocabulario_pct'] for f in validas) / len(validas):.1f}%  "
              f"secuencia={sum(f['secuencia_pct'] for f in validas) / len(validas):.1f}%")
    json.dump(filas, open(os.path.join(AQUI, "salida", "comparacion.json"), "w", encoding="utf-8"),
              ensure_ascii=False, indent=1)


if __name__ == "__main__":
    main([int(a) for a in sys.argv[1:]])
