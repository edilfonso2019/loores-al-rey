"""Prueba piloto: acordes de las pistas instrumentales con el modelo BTC (ISMIR 2019).

Uso:  .venv\\Scripts\\python.exe analizar.py 1 10 50 ...
Lee pistas/{n}.mp3 y deja salida/{n}.json y salida/resumen.json.
"""
import json
import os
import sys
import warnings

import librosa
import mir_eval
import numpy as np
import torch

warnings.filterwarnings("ignore")
# El código de BTC (2019) usa alias que numpy ya quitó.
np.float, np.int, np.complex = float, int, complex
AQUI = os.path.dirname(os.path.abspath(__file__))
BTC = os.path.join(AQUI, "BTC-ISMIR19")
sys.path.insert(0, BTC)
from btc_model import BTC_model, HParams  # noqa: E402
from utils.mir_eval_modules import audio_file_to_features, idx2voca_chord  # noqa: E402

NOTAS = ["C", "C#", "D", "Eb", "E", "F", "F#", "G", "Ab", "A", "Bb", "B"]
TONOS = {"do": 0, "do sostenido": 1, "re bemol": 1, "re": 2, "mi bemol": 3, "mi": 4, "fa": 5,
         "fa sostenido": 6, "sol bemol": 6, "sol": 7, "la bemol": 8, "la": 9, "si bemol": 10, "si": 11}


def cargar_modelo():
    import yaml
    with open(os.path.join(BTC, "run_config.yaml")) as f:
        config = HParams(**yaml.safe_load(f))
    config.feature["large_voca"] = True
    config.model["num_chords"] = 170
    modelo = BTC_model(config=config.model)
    # Repositorio oficial del paper (MIT); el checkpoint trae arrays de numpy.
    ck = torch.load(os.path.join(BTC, "test", "btc_model_large_voca.pt"), map_location="cpu", weights_only=False)
    modelo.load_state_dict(ck["model"])
    modelo.eval()
    return modelo, config, ck["mean"], ck["std"]


def reconocer(ruta, modelo, config, mean, std):
    """Devuelve una etiqueta de acorde por cuadro (~0.093 s) y la duración de cada cuadro."""
    feat, fps, _ = audio_file_to_features(ruta, config)
    feat = (feat.T - mean) / std
    n = config.model["timestep"]
    pad = n - (feat.shape[0] % n)
    total = feat.shape[0]
    feat = np.pad(feat, ((0, pad), (0, 0)))
    x = torch.tensor(feat, dtype=torch.float32).unsqueeze(0)
    idx = []
    with torch.no_grad():
        for t in range(feat.shape[0] // n):
            sa, _ = modelo.self_attn_layers(x[:, n * t:n * (t + 1), :])
            pred, _ = modelo.output_layer(sa)
            idx.extend(pred.squeeze().tolist())
    voca = idx2voca_chord()
    return [voca[i] for i in idx[:total]], fps


def simplificar(lab):
    """'G:7' -> 'G7', 'A:min' -> 'Am', 'N' -> None."""
    if lab in ("N", "X"):
        return None
    raiz, _, cal = lab.partition(":")
    raiz = NOTAS[librosa.note_to_midi(raiz + "0") % 12] if raiz else raiz
    cal = cal or "maj"
    mapa = {"maj": "", "min": "m", "7": "7", "min7": "m7", "maj7": "maj7", "dim": "dim", "dim7": "dim7",
            "hdim7": "m7b5", "aug": "aug", "sus2": "sus2", "sus4": "sus4", "maj6": "6", "min6": "m6",
            "minmaj7": "m(maj7)"}
    base = cal.split("/")[0]
    return raiz + mapa.get(base, "")


def por_pulsos(ruta, cuadros, fps):
    """Un acorde por pulso (el que más dura dentro del pulso); luego une repetidos."""
    y, sr = librosa.load(ruta, sr=22050, mono=True)
    tempo, beats = librosa.beat.beat_track(y=y, sr=sr, units="time")
    dur = len(y) / sr
    bordes = np.concatenate([[0.0], beats, [dur]])
    seg, pulsos = [], []
    for a, b in zip(bordes[:-1], bordes[1:]):
        i0, i1 = int(a / fps), max(int(a / fps) + 1, int(b / fps))
        trozo = [simplificar(c) for c in cuadros[i0:i1]]
        trozo = [c for c in trozo if c]
        acorde = max(set(trozo), key=trozo.count) if trozo else None
        pulsos.append([round(float(a), 2), acorde])
        if seg and seg[-1]["acorde"] == acorde:
            seg[-1]["fin"] = round(float(b), 2)
        else:
            seg.append({"inicio": round(float(a), 2), "fin": round(float(b), 2), "acorde": acorde})
    return [s for s in seg if s["acorde"]], float(np.atleast_1d(tempo)[0]), pulsos


def tonalidad(tono):
    t = tono.lower().replace(" mayor", "|M").replace(" menor", "|m")
    nombre, modo = t.split("|")
    return TONOS[nombre.strip()], modo


def raiz_y_tipo(acorde):
    raiz = acorde[:2] if len(acorde) > 1 and acorde[1] in "#b" else acorde[:1]
    return NOTAS.index(raiz)


def diatonico(acorde, tonica, modo):
    """¿La fundamental del acorde pertenece a la escala de la tonalidad (o es V/V, V/vi)?"""
    root = raiz_y_tipo(acorde)
    escala = [0, 2, 4, 5, 7, 9, 11] if modo == "M" else [0, 2, 3, 5, 7, 8, 10, 11]
    return (root - tonica) % 12 in escala


def main(numeros):
    datos = json.load(open(os.path.join(AQUI, "..", "..", "assets", "data", "clasico.json"), encoding="utf-8"))
    himnos = {h["n"]: h for h in datos["himnos"]}
    modelo, config, mean, std = cargar_modelo()
    os.makedirs(os.path.join(AQUI, "salida"), exist_ok=True)
    resumen = []
    for n in numeros:
        h = himnos[n]
        ruta = os.path.join(AQUI, "pistas", f"{n}.mp3")
        cuadros, fps = reconocer(ruta, modelo, config, mean, std)
        segs, tempo, pulsos = por_pulsos(ruta, cuadros, fps)
        tonica, modo = tonalidad(h["tono"])
        tiempo = {}
        for s in segs:
            tiempo[s["acorde"]] = tiempo.get(s["acorde"], 0) + s["fin"] - s["inicio"]
        total = sum(tiempo.values())
        en_tono = sum(v for k, v in tiempo.items() if diatonico(k, tonica, modo)) / total
        principal = max(tiempo, key=tiempo.get)
        ultimo = segs[-1]["acorde"]
        res = {
            "n": n, "titulo": h["t"], "tono_partitura": h["tono"], "compas": h.get("compas"),
            "tonica_esperada": NOTAS[tonica] + ("" if modo == "M" else "m"),
            "acorde_mas_usado": principal, "acorde_final": ultimo,
            "pct_en_tonalidad": round(en_tono * 100, 1), "tempo_bpm": round(tempo),
            "cambios": len(segs),
            "top": sorted(((k, round(v / total * 100, 1)) for k, v in tiempo.items()), key=lambda x: -x[1])[:6],
        }
        resumen.append(res)
        json.dump({"n": n, "titulo": h["t"], "tono": h["tono"], "compas": h.get("compas"),
                   "tempo": round(tempo), "acordes": segs, "pulsos": pulsos},
                  open(os.path.join(AQUI, "salida", f"{n}.json"), "w", encoding="utf-8"), ensure_ascii=False, indent=1)
        print(f"{n:>4} {h['t'][:30]:30} tono={res['tonica_esperada']:4} mas_usado={principal:5} final={ultimo:5} "
              f"en_tono={res['pct_en_tonalidad']:5}% cambios={len(segs)}")
    json.dump(resumen, open(os.path.join(AQUI, "salida", "resumen.json"), "w", encoding="utf-8"),
              ensure_ascii=False, indent=1)


if __name__ == "__main__":
    main([int(a) for a in sys.argv[1:]])
