"""Letra con acordes sincronizada, a partir de la partitura PDF y la pista.

1. De la partitura: por cada sistema (renglón de música) se leen los acordes (con su x) y las
   filas de letra (una por estrofa, más el coro). Cada acorde se pone sobre la sílaba más cercana.
2. Se arma la secuencia que se canta: estrofa 1 (+ coro), estrofa 2 (+ coro), ...
3. Se alinea esa secuencia con lo que oyó la IA pulso a pulso, por segmentos: cada acorde debe
   durar más o menos lo que indica la partitura (su posición en el compás, leída de la x y de los
   números de compás de cada sistema). Entre estrofas se permite una pausa (calderón/interludio);
   la introducción y el final de la pista se saltan. Las sílabas toman su tiempo de su posición
   en el compás, interpolando entre los acordes ya ubicados.

Uso:  .venv\\Scripts\\python.exe sincronizar.py 1 10 50 ...   ->  salida/sinc_{n}.json
"""
import base64
import json
import os
import re
import sys

import numpy as np
import pymupdf

from comparar import basico
from extraer_partitura import acordes_de_pagina

AQUI = os.path.dirname(os.path.abspath(__file__))
SINALEFA = re.compile(r"(?<=[a-záéíóúüñ,;:.!?])I(?=[a-záéíóúüñ¡¿])")
DPI = 100
LETRA = re.compile(r"[\dA-Za-zÁÉÍÓÚÜÑáéíóúüñ¡¿!?,.;:'\"()\-_]*[A-Za-zÁÉÍÓÚÜÑáéíóúüñ][\dA-Za-zÁÉÍÓÚÜÑáéíóúüñ¡¿!?,.;:'\"()\-_]*")


# ---------------------------------------------------------------- partitura
def filas_de_letra(pagina, y_acordes):
    filas = []
    for x0, y0, x1, y1, w, *_ in pagina.get_text("words"):
        # Las palabras con sinalefa (glifo 'I') tienen la caja más alta: se corrige el centro.
        y = y0 + 10.3 if (y1 - y0) > 14 and "I" in w else (y0 + y1) / 2
        if w in ("I", "©", "_") or re.fullmatch(r"\d+", w) or set(w) <= {"_"}:
            continue
        if w != "-" and not LETRA.fullmatch(w):
            continue  # glifos musicales (notas, alteraciones) que no son letra
        if any(abs(y - ya) < 9 for ya in y_acordes):
            continue
        for f in filas:
            if abs(f["y"] - y) < 3:
                f["t"].append((x0, x1, w))
                break
        else:
            filas.append({"y": y, "t": [(x0, x1, w)]})
    for f in filas:
        f["t"].sort()
        f["x0"] = f["t"][0][0]
    return sorted(filas, key=lambda f: f["y"])


def silabas(fila):
    """Tokens -> sílabas {x, texto, une} (une=True si la siguiente sílaba es de la misma palabra)."""
    out = []
    for x0, x1, w in fila["t"]:
        if w == "-":
            if out:
                out[-1]["une"] = True
            continue
        w = w.strip("_")
        m = re.match(r"^(\d+)\.(.*)$", w)
        if m:  # "1.Pa" -> número de estrofa fuera
            w = m.group(2)
            x0 += 9
        if not w:
            continue
        if w.startswith("-") and out:
            out[-1]["une"] = True
            w = w[1:]
        une = w.endswith("-")
        out.append({"x": x0, "texto": SINALEFA.sub(" ", w.rstrip("-")), "une": une})
    return out


def leer_partitura(n, n_estrofas, tiene_coro):
    doc = pymupdf.open(os.path.join(AQUI, "partituras", f"{n}.pdf"))
    sistemas, paginas = [], []
    for ip, pag in enumerate(doc):
        pix = pag.get_pixmap(dpi=DPI)
        paginas.append({"w": pix.width, "h": pix.height,
                        "img": "data:image/jpeg;base64," + base64.b64encode(pix.tobytes("jpeg", jpg_quality=70)).decode()})
        acordes = acordes_de_pagina(pag)
        if not acordes:
            continue
        ys = sorted({a["y"] for a in acordes})
        # grupos de acordes = sistemas
        grupos = []
        for y in ys:
            if grupos and y - grupos[-1][-1] < 20:
                grupos[-1].append(y)
            else:
                grupos.append([y])
        filas = filas_de_letra(pag, ys)
        filas = [f for f in filas if f["y"] > grupos[0][0]]  # sin título/autor
        # Números de compás al margen izquierdo de cada sistema ("5", "9", "13"...).
        numeros = [(int(w[4]), (w[1] + w[3]) / 2) for w in pag.get_text("words")
                   if w[0] < 85 and re.fullmatch(r"\d{1,3}", w[4]) and int(w[4]) != n]
        for k, g in enumerate(grupos):
            y_ini = g[0]
            y_fin = grupos[k + 1][0] if k + 1 < len(grupos) else 1e9
            sis_acordes = sorted([a for a in acordes if g[0] - 1 <= a["y"] <= g[-1] + 1], key=lambda a: a["x"])
            sis_filas = [f for f in filas if y_ini < f["y"] < y_fin]
            num = next((v for v, y in numeros if g[0] - 12 <= y <= g[0] + 40), None)
            xs = [a["x"] for a in sis_acordes] + [f["x0"] for f in sis_filas]
            sistemas.append({"pagina": ip, "acordes": sis_acordes, "filas": sis_filas, "y": y_ini,
                             "num": num, "x0": min(xs) - 4, "x1": pag.rect.width * 0.93})
    if not sistemas:
        return None, paginas
    # Compás donde empieza cada sistema (0 = primero) y cuántos compases tiene.
    for k, s in enumerate(sistemas):
        ok = k > 0 and s["num"] and s["num"] - 1 > (sistemas[k - 1]["m0"] or 0)
        s["m0"] = 0 if k == 0 else (s["num"] - 1 if ok else None)
        if s["m0"] is None:  # sin número legible: tantos compases como el sistema anterior
            ancho = (sistemas[k - 1]["m0"] - sistemas[k - 2]["m0"]) if k >= 2 else 4
            s["m0"] = sistemas[k - 1]["m0"] + ancho
    for k, s in enumerate(sistemas):
        s["m"] = (sistemas[k + 1]["m0"] - s["m0"]) if k + 1 < len(sistemas) else (
            s["m0"] - sistemas[k - 1]["m0"] if k else 4)
    # número de estrofas = filas que arrancan con "1.", "2.", ... en el primer sistema
    izquierda = min(f["x0"] for s in sistemas for f in s["filas"]) if any(s["filas"] for s in sistemas) else 0
    for s in sistemas:
        if tiene_coro:
            verso = [f for f in s["filas"] if f["x0"] < izquierda + 60]
            resto = [f for f in s["filas"] if f["x0"] >= izquierda + 60]
        else:  # sin coro: todas las filas son estrofas (algunas empiezan corridas por una ligadura)
            verso, resto = s["filas"], []
        if len(verso) >= n_estrofas:
            s["estrofas"] = [silabas(f) for f in verso[:n_estrofas]]
            s["coro"] = silabas(resto[0]) if resto and tiene_coro else None
            s["coro_x"] = resto[0]["x0"] - 15 if resto and tiene_coro else 1e9
        else:  # sistema de coro (todas las estrofas cantan lo mismo)
            s["estrofas"] = None
            s["coro"] = silabas(verso[0]) if verso else (silabas(resto[0]) if resto else [])
            s["coro_x"] = -1
    total = sistemas[-1]["m0"] + sistemas[-1]["m"]
    return {"sistemas": sistemas, "n_estrofas": n_estrofas, "compases": total}, paginas


def posicion(s, x):
    """Posición (en compases, desde el inicio de la estrofa) de algo en la x de un sistema."""
    f = (x - s["x0"]) / max(s["x1"] - s["x0"], 1)
    return s["m0"] + min(max(f, 0.0), 0.999) * s["m"]


def silaba_mas_cercana(sils, x):
    if not sils:
        return None
    candidatos = [i for i, s in enumerate(sils) if s["x"] <= x + 12] or [0]
    return min(candidatos, key=lambda i: abs(sils[i]["x"] - x))


def armar_lineas(part):
    """Líneas en orden de canto, cada una con sílabas y sus acordes; y la lista de eventos (acordes)."""
    lineas, eventos = [], []
    sistemas = part["sistemas"]
    hay_coro = any(s["coro"] for s in sistemas)
    for e in range(part["n_estrofas"]):
        for fase in ("verso", "coro"):
            if fase == "coro" and not hay_coro:
                continue
            for s in sistemas:
                if fase == "verso":
                    if not s["estrofas"]:
                        continue
                    sils = s["estrofas"][e]
                    acs = [a for a in s["acordes"] if a["x"] < s["coro_x"]]
                else:
                    if not s["coro"]:
                        continue
                    sils = s["coro"]
                    acs = [a for a in s["acordes"] if a["x"] >= s["coro_x"]]
                if not sils:
                    continue
                linea = {"tipo": fase, "estrofa": e + 1,
                         "silabas": [dict(t=None, texto=x["texto"], une=x["une"], acordes=[],
                                          pos=posicion(s, x["x"])) for x in sils]}
                for a in acs:
                    i = silaba_mas_cercana(sils, a["x"])
                    ev = {"acorde": a["acorde"], "linea": len(lineas), "silaba": i, "estrofa": e,
                          "pos": posicion(s, a["x"]), "pagina": s["pagina"], "x": a["x"], "y": a["y"]}
                    linea["silabas"][i]["acordes"].append(len(eventos))
                    eventos.append(ev)
                lineas.append(linea)
    return lineas, eventos


# ---------------------------------------------------------------- alineamiento
def costo(ev, pulso):
    if pulso is None:
        return 0.7
    a, b = basico(ev), basico(pulso)
    if a == b:
        return 0.0
    return 0.5 if a[0] == b[0] else 1.0


def alinear(eventos, pulsos):
    """Devuelve el pulso donde empieza cada evento (o None si se saltó)."""
    E, B = len(eventos), len(pulsos)
    C = np.array([[costo(ev["acorde"], p[1]) for p in pulsos] for ev in eventos])
    INF = 1e9
    D = np.full((E, B), INF)
    P = np.zeros((E, B), dtype=np.int8)  # 0=continúa, 1=empieza (desde i-1), 2=empieza saltando i-1, 3=inicio
    SALTO, FINAL = 1.5, 0.03
    for j in range(B):
        for i in range(E):
            mejor, de = INF, 0
            if j > 0 and D[i, j - 1] < mejor:
                mejor, de = D[i, j - 1], 0
            if i == 0 and 0 < mejor:
                mejor, de = 0.0, 3  # la introducción no cuesta
            if i > 0 and j > 0 and D[i - 1, j - 1] < mejor:
                mejor, de = D[i - 1, j - 1], 1
            if i > 1 and j > 0 and D[i - 2, j - 1] + SALTO < mejor:
                mejor, de = D[i - 2, j - 1] + SALTO, 2
            D[i, j] = mejor + C[i, j]
            P[i, j] = de
    fin = np.argmin(D[E - 1] + FINAL * (B - 1 - np.arange(B)))
    inicio = [None] * E
    i, j = E - 1, int(fin)
    while i >= 0 and j >= 0:
        de = P[i, j]
        if de == 0:
            j -= 1
            continue
        inicio[i] = j
        if de == 3:
            break
        if de == 1:
            i, j = i - 1, j - 1
        else:  # se saltó i-1
            i, j = i - 2, j - 1
    aciertos = sum(1 for k, s in enumerate(inicio) if s is not None and C[k, s] == 0)
    return inicio, aciertos / E


def pulsos_por_compas(pulsos, compases, numerador):
    """Cuántos pulsos de la IA hay en un compás: el valor con el que la música se repite cada
    estrofa (autosimilitud de los acordes con un desfase de compases × pulsos)."""
    B = [basico(c) if c else None for _, c in pulsos]
    sims = {}
    for b in sorted({1, 2, 3, 4, 6, 8, numerador, numerador * 2, max(1, numerador // 2)}):
        base = compases * b
        mejor = -1.0
        for lag in range(int(base * 0.85), int(base * 1.2) + 1):
            if lag < 8 or lag >= len(B):
                continue
            pares = [(x, y) for x, y in zip(B, B[lag:]) if x and y]
            if len(pares) < lag // 2:
                continue
            mejor = max(mejor, sum(x == y for x, y in pares) / len(pares))
        sims[b] = mejor
    tope = max(sims.values())
    # La música también se repite cada 2 estrofas: ante un empate, el compás más corto.
    return min(b for b, s in sims.items() if s >= tope - 0.05)


def alinear_segmentos(eventos, pulsos, compases, bpb):
    """Programación dinámica por segmentos: cada acorde ocupa d pulsos seguidos, con d cerca de
    la duración que indica la partitura. Devuelve el pulso donde empieza cada evento."""
    E, B = len(eventos), len(pulsos)
    INF = 1e9
    C = np.array([[costo(ev["acorde"], p[1]) for p in pulsos] for ev in eventos])
    acum = np.concatenate([np.zeros((E, 1)), np.cumsum(C, axis=1)], axis=1)  # acum[i, j] = C[i, :j].sum()
    esperada = []
    for i, ev in enumerate(eventos):
        sig = eventos[i + 1] if i + 1 < E and eventos[i + 1]["estrofa"] == ev["estrofa"] else None
        fin = sig["pos"] if sig else compases
        esperada.append(max(0.0, (fin - ev["pos"]) * bpb))
    LAMBDA, PAUSA, FINAL = 0.6, 0.15, 0.02
    PAUSA_MAX = int(3 * bpb) + 2
    F = np.full((E + 1, B + 1), INF)  # F[i, j]: eventos 0..i-1 ubicados y el siguiente empieza en j
    F[0, :] = 0.0  # la introducción no cuesta
    dur = np.zeros((E + 1, B + 1), dtype=np.int16)  # duración elegida del evento i-1 que termina en j
    pausa = np.zeros((E + 1, B + 1), dtype=np.int16)  # pausa antes del evento i que empieza en j
    for i in range(E):
        G = F[i].copy()
        if i > 0 and eventos[i]["estrofa"] != eventos[i - 1]["estrofa"]:
            for g in range(1, PAUSA_MAX + 1):
                cand = np.full(B + 1, INF)
                cand[g:] = F[i, :B + 1 - g] + PAUSA * g
                m = cand < G
                G[m] = cand[m]
                pausa[i, m] = g
        e = esperada[i]
        dmin = 0 if e < 0.75 else max(1, int(round(e * 0.5)))
        dmax = max(dmin, int(round(e * 1.6)) + 2)
        for d in range(dmin, min(dmax, B) + 1):
            seg = acum[i, d:] - acum[i, :B + 1 - d]  # costo de los pulsos [j, j+d)
            cand = G[:B + 1 - d] + seg + LAMBDA * abs(d - e) + (0.3 if d == 0 else 0.0)
            dest = F[i + 1, d:]
            m = cand < dest
            dest[m] = cand[m]
            dur[i + 1, d:][m] = d
    j = int(np.argmin(F[E] + FINAL * (B - np.arange(B + 1))))
    inicio = [0] * E
    for i in range(E, 0, -1):
        j -= int(dur[i, j])
        inicio[i - 1] = j
        if i - 1 > 0:
            j -= int(pausa[i - 1, j])
    aciertos = sum(1 for k, s in enumerate(inicio) if s < B and C[k, s] == 0)
    return inicio, aciertos / E


def main(numeros):
    datos = json.load(open(os.path.join(AQUI, "..", "..", "assets", "data", "clasico.json"), encoding="utf-8"))
    himnos = {h["n"]: h for h in datos["himnos"]}
    for n in numeros:
        ia = json.load(open(os.path.join(AQUI, "salida", f"{n}.json"), encoding="utf-8"))
        h = himnos[n]
        part, paginas = leer_partitura(n, len(h["estrofas"]), bool(h.get("coro")))
        if not part:
            print(n, "sin cifrado en la partitura")
            continue
        lineas, eventos = armar_lineas(part)
        pulsos = ia["pulsos"]
        numerador = int((h.get("compas") or "4/4").split("/")[0])
        bpb = pulsos_por_compas(pulsos, part["compases"], numerador)
        inicio, calidad = alinear_segmentos(eventos, pulsos, part["compases"], bpb)
        tiempos = [p[0] for p in pulsos] + [pulsos[-1][0] + 0.5]
        for ev, b in zip(eventos, inicio):
            ev["t"] = round(tiempos[min(b, len(tiempos) - 1)], 2)
        # Sílabas: su posición en el compás, interpolada entre los acordes de su estrofa.
        for li in lineas:
            evs = [ev for ev in eventos if ev["estrofa"] == li["estrofa"] - 1]
            ps, ts = [ev["pos"] for ev in evs], [ev["t"] for ev in evs]
            for s in li["silabas"]:
                s["t"] = round(float(np.interp(s.pop("pos"), ps, ts)), 2)
            for a, b in zip(li["silabas"], li["silabas"][1:]):  # nunca hacia atrás
                b["t"] = max(b["t"], a["t"])
        inicios = []
        for li in lineas:
            if not inicios or inicios[-1][0] != li["estrofa"]:
                inicios.append((li["estrofa"], li["silabas"][0]["t"]))
        salida = {"n": n, "estrofas": part["n_estrofas"], "calidad": round(calidad * 100, 1),
                  "lineas": lineas, "eventos": eventos, "paginas": paginas}
        json.dump(salida, open(os.path.join(AQUI, "salida", f"sinc_{n}.json"), "w", encoding="utf-8"), ensure_ascii=False)
        primera = " ".join((("[" + "|".join(eventos[k]["acorde"] for k in s["acordes"]) + "]") if s["acordes"] else "")
                           + s["texto"] + ("" if s["une"] else " ") for s in lineas[0]["silabas"])
        print(f"{n:>4} compases={part['compases']} pulsos/compás={bpb} coinciden={salida['calidad']}%  "
              f"estrofas en {[round(t) for _, t in inicios]}  renglones {[round(l['silabas'][0]['t']) for l in lineas[:5]]}")


if __name__ == "__main__":
    main([int(a) for a in sys.argv[1:]])
