"""Genera salida/visor.html: prototipo de la pantalla "Acordes" del himnario.

Funciones (inspiradas en apps tipo Chord ai, con la identidad de la IASDMR):
- línea de tiempo con la onda de la pista y los acordes que van pasando (se puede arrastrar);
- tonalidad y BPM; diagramas con número de dedo y cejilla; Básico / Todos; notación C D E / Do Re;
- vistas: Acordes (diagramas), Letra (acordes sobre cada sílaba, sincronizada), Partitura (marcador
  que avanza sobre el PDF) y Cuadrícula (compases);
- modo atril: pantalla completa con la línea actual en grande;
- reproductor con Altura (capo), Tempo (sin cambiar el tono) y Loop A-B.
Fuente de los acordes: la partitura (exacta) cuando existe salida/sinc_{n}.json; si no, lo que oyó la IA.
Solo para revisar la prueba piloto."""
import json
import os
import sys

import librosa
import numpy as np

AQUI = os.path.dirname(os.path.abspath(__file__))
PICOS_POR_SEG = 20


def picos(ruta):
    y, sr = librosa.load(ruta, sr=11025, mono=True)
    hop = sr // PICOS_POR_SEG
    rms = librosa.feature.rms(y=y, frame_length=hop * 2, hop_length=hop)[0]
    rms = rms / (np.percentile(rms, 99) or 1)
    return [round(float(min(v, 1.0)), 2) for v in rms]


def sinc(n):
    ruta = os.path.join(AQUI, "salida", f"sinc_{n}.json")
    if not os.path.exists(ruta):
        return None
    s = json.load(open(ruta, encoding="utf-8"))
    ev = s["eventos"]
    return {
        "calidad": s["calidad"],
        "lineas": [{"tipo": li["tipo"], "e": li["estrofa"],
                    "s": [[x["t"], x["texto"], 1 if x["une"] else 0, [ev[k]["acorde"] for k in x["acordes"]]]
                          for x in li["silabas"]]} for li in s["lineas"]],
        "eventos": [[e["t"], e["acorde"], e["pagina"], e["x"], e["y"]] for e in ev],
        "paginas": s["paginas"],
    }


def main(numeros):
    ruta_comp = os.path.join(AQUI, "salida", "comparacion.json")
    comp = {c["n"]: c for c in json.load(open(ruta_comp, encoding="utf-8"))} if os.path.exists(ruta_comp) else {}
    datos = []
    for n in numeros:
        ia = json.load(open(os.path.join(AQUI, "salida", f"{n}.json"), encoding="utf-8"))
        datos.append({"n": n, "titulo": ia["titulo"], "tono": ia["tono"], "compas": ia.get("compas") or "4/4",
                      "tempo": ia.get("tempo"), "pulsos": ia["pulsos"], "comp": comp.get(n, {}),
                      "picos": picos(os.path.join(AQUI, "pistas", f"{n}.mp3")), "sinc": sinc(n)})
    html = PLANTILLA.replace("__DATOS__", json.dumps(datos, ensure_ascii=False, separators=(",", ":"))) \
                    .replace("__PPS__", str(PICOS_POR_SEG))
    ruta = os.path.join(AQUI, "salida", "visor.html")
    open(ruta, "w", encoding="utf-8").write(html)
    print(ruta, f"{os.path.getsize(ruta) // 1024} KB")


PLANTILLA = r"""<!doctype html>
<html lang="es"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>Acordes del himnario</title>
<link href="https://fonts.googleapis.com/css2?family=Noto+Sans:wght@400;600;800&display=swap" rel="stylesheet">
<style>
:root{--azul:#0A245E;--azul2:#0F3999;--claro:#3E80F2;--crema:#EFD19F;--dorado:#F1BE48;--gris:#7E7E82;--fondo:#071a45;--panel:#12306f;--texto:#F2F1EF}
*{box-sizing:border-box}html,body{margin:0;height:100%}body{font-family:'Noto Sans',sans-serif;background:var(--fondo);color:var(--texto);display:flex;flex-direction:column;max-width:600px;margin:0 auto}
button{font:inherit;color:inherit;cursor:pointer}
.top{display:flex;align-items:center;gap:8px;padding:10px 12px}
.top select{flex:1;min-width:0;font:inherit;font-weight:600;padding:8px 10px;border-radius:99px;border:1px solid #ffffff40;background:transparent;color:var(--texto)}
.top select option{color:#000}
.icono{border:1px solid #ffffff55;background:none;border-radius:99px;padding:7px 12px;font-size:14px;white-space:nowrap}
.linea{position:relative;height:170px;background:#000;border-top:1px solid #ffffff30;border-bottom:1px solid #ffffff30;touch-action:none;flex:none}
.linea canvas{width:100%;height:100%;display:block}
.badge{position:absolute;bottom:8px;background:var(--texto);color:var(--azul);border-radius:6px;padding:2px 8px;font-size:16px;font-weight:600}
.badge.izq{left:8px}.badge.der{right:8px}
.opciones{display:grid;grid-template-columns:repeat(3,1fr);gap:6px;padding:8px 8px 0}
.op{background:var(--panel);border-radius:10px;padding:6px;text-align:center;font-size:13px;border:0}
.op .sw{display:inline-flex;margin-top:4px;border:1px solid var(--texto);border-radius:99px;overflow:hidden;font-size:12px}
.op .sw span{padding:2px 8px}.op .sw span.on{background:var(--texto);color:var(--azul)}
.vistas{display:flex;gap:4px;padding:8px;overflow-x:auto}
.vistas button{flex:1;border:0;border-bottom:2px solid transparent;background:none;padding:6px 4px;font-size:14px;opacity:.7;white-space:nowrap}
.vistas button.on{opacity:1;border-color:var(--dorado);color:var(--dorado);font-weight:600}
.cuerpo{flex:1;overflow:auto;padding:4px 12px 12px;scroll-behavior:smooth}
.verTodo{display:block;margin:0 0 6px auto;background:none;border:0;font-size:13px;opacity:.85}
.diags{display:grid;grid-template-columns:1fr 1fr;gap:8px}
.dg{text-align:center;padding:10px 4px;border-radius:10px}.dg.act{background:var(--panel)}
.dg .nom{font-size:32px;color:var(--dorado);line-height:1.2}.dg.sig .nom{opacity:.75}
.todos{display:grid;grid-template-columns:repeat(auto-fill,minmax(96px,1fr));gap:8px;margin-top:8px}
.todos .dg{background:var(--panel)}.todos .nom{font-size:20px}
.grid{display:grid;grid-template-columns:repeat(2,1fr);gap:6px}
.compas{display:flex;background:var(--panel);border-radius:8px;min-height:46px;overflow:hidden}
.pulso{flex:1;border-left:1px dashed #ffffff22;display:flex;align-items:center;padding-left:4px;font-weight:700;font-size:15px;color:var(--crema);cursor:pointer;white-space:nowrap}
.pulso:first-child{border-left:0}.pulso.ya{opacity:.4}.pulso.ahora{background:#3E80F255;box-shadow:inset 3px 0 var(--dorado)}
/* letra con acordes */
.letra .cab{font-size:12px;text-transform:uppercase;letter-spacing:.08em;color:var(--dorado);margin:14px 0 2px;opacity:.85}
.verso{padding:4px 8px;border-radius:8px;line-height:1.1;cursor:pointer;transition:background .2s}
.verso.ahora{background:var(--panel)}.verso.ya{opacity:.45}
.sil{display:inline-flex;flex-direction:column;vertical-align:bottom}.sil.esp{margin-right:.32em}
.sil .ac{font-weight:800;color:var(--crema);font-size:.82em;min-height:1.25em;white-space:nowrap;padding-right:.2em}
.sil .tx{font-size:1em;white-space:pre}
.verso .sil.ya .tx{color:var(--dorado)}.sil.ahora .ac{color:#fff;background:var(--claro);border-radius:4px;padding:0 3px}
.letra{font-size:19px}.pal{display:inline-block;white-space:nowrap}
#atril .sil.ya .tx{color:var(--dorado)}
/* partitura */
.pag{position:relative;margin-bottom:10px;border-radius:8px;overflow:hidden;background:#fff}
.pag img{width:100%;display:block}
.marca{position:absolute;border-radius:3px;background:#3E80F2;opacity:.85;transition:left .25s,top .25s}
.caja{position:absolute;border:2px solid #F1BE48;border-radius:4px;background:#F1BE4840;transition:left .25s,top .25s}
.vacio{opacity:.75;font-size:14px;padding:20px 4px;text-align:center}
/* pie */
.pie{display:grid;grid-template-columns:1fr 1.25fr;flex:none}
.info{background:var(--crema);color:var(--azul);padding:10px;display:flex;flex-direction:column;justify-content:center;gap:2px;min-width:0}
.info b{font-size:15px;line-height:1.2}.info span{font-size:12px}
.ctrl{background:var(--azul);padding:8px}
.tabs{display:grid;grid-template-columns:repeat(3,1fr);gap:4px}
.tab{background:var(--panel);border:0;border-radius:8px;padding:6px 2px;font-size:14px}.tab.on{background:var(--dorado);color:var(--azul);font-weight:600}
.ajuste{display:flex;align-items:center;justify-content:center;gap:10px;margin-top:6px;font-size:14px;min-height:34px}
.ajuste button{width:34px;height:34px;border-radius:50%;border:1px solid #ffffff55;background:none;font-size:18px}
.barra{width:100%;accent-color:var(--dorado);margin:6px 0 0}
.fila{display:flex;align-items:center;justify-content:space-between;font-size:13px;font-variant-numeric:tabular-nums}
.play{width:48px;height:48px;border-radius:50%;border:0;background:var(--dorado);color:var(--azul);font-size:20px}
/* modo atril */
#atril{position:fixed;inset:0;background:#000;color:#fff;z-index:20;display:flex;flex-direction:column;padding:14px 20px}
#atril .arriba{display:flex;align-items:center;gap:14px}
#atril .aAc{font-size:clamp(40px,9vw,88px);font-weight:800;color:var(--dorado);line-height:1}
#atril .aSigAc{font-size:clamp(18px,3.5vw,32px);opacity:.55}
#atril .esp{flex:1}
#atril .bt{border:1px solid #ffffff66;background:none;border-radius:99px;min-width:48px;height:48px;padding:0 14px;font-size:18px}
#atril .centro{flex:1;display:flex;flex-direction:column;justify-content:center;gap:4vh;overflow:hidden}
#atril .aLin{font-size:var(--atril,44px)}#atril .aLin .sil .ac{color:var(--dorado)}
#atril .aProx{font-size:calc(var(--atril,44px)*.6);opacity:.4}
#atril .cab{font-size:14px;color:var(--dorado);text-transform:uppercase;letter-spacing:.1em}
#atril .abajo{height:4px;background:#ffffff22;border-radius:2px}#atril .abajo div{height:100%;background:var(--dorado);width:0}
.oculto{display:none!important}
</style></head><body>
<div class="top"><select id="sel" aria-label="Himno"></select><button class="icono" id="btnAtril">⛶ Atril</button></div>
<div class="linea" id="linea"><canvas id="cv"></canvas><span class="badge izq" id="tono"></span><span class="badge der" id="bpm"></span></div>
<div class="opciones">
 <button class="op" id="opBasico">Acordes<br><span class="sw"><span id="swB" class="on">Básico</span><span id="swT">Todos</span></span></button>
 <button class="op" id="opNotacion">Notación<br><span class="sw"><span id="swC" class="on">C D E</span><span id="swD">Do Re</span></span></button>
 <button class="op" id="opFuente">Fuente<br><span class="sw"><span id="swP" class="on">Partitura</span><span id="swI">IA</span></span></button>
</div>
<div class="vistas" role="tablist"><button data-v="diag" class="on">Acordes</button><button data-v="letra">Letra</button><button data-v="part">Partitura</button><button data-v="grid">Cuadrícula</button></div>
<div class="cuerpo" id="cuerpo">
 <div id="vDiag"><div class="diags"><div class="dg act"><div class="nom" id="nAct">–</div><div id="dAct"></div></div><div class="dg sig"><div class="nom" id="nSig">–</div><div id="dSig"></div></div></div>
  <button class="verTodo" id="verTodo">▦ Ver todos los acordes</button><div id="vTodos" class="todos oculto"></div></div>
 <div id="vLetra" class="letra oculto"></div>
 <div id="vPart" class="oculto"></div>
 <div id="vGrid" class="grid oculto"></div>
</div>
<div class="pie">
 <div class="info"><b id="titulo"></b><span id="detalle"></span></div>
 <div class="ctrl">
  <div class="tabs"><button class="tab" data-p="altura">Altura</button><button class="tab" data-p="tempo">Tempo</button><button class="tab" data-p="loop">Loop</button></div>
  <div class="ajuste oculto" id="pAltura"><button id="altMenos" aria-label="Bajar">−</button><span id="altTxt"></span><button id="altMas" aria-label="Subir">+</button></div>
  <div class="ajuste oculto" id="pTempo"><button id="temMenos" aria-label="Más lento">−</button><span id="temTxt">100%</span><button id="temMas" aria-label="Más rápido">+</button></div>
  <div class="ajuste oculto" id="pLoop"><button id="loopBtn" style="width:auto;padding:0 12px;border-radius:99px">Marcar A</button></div>
  <input class="barra" type="range" id="barra" min="0" max="1000" value="0" aria-label="Progreso">
  <div class="fila"><span id="tiempo">0:00 / 0:00</span><button class="play" id="play" aria-label="Reproducir">▶</button></div>
 </div>
</div>
<div id="atril" class="oculto" role="dialog" aria-label="Modo atril">
 <div class="arriba"><div><div class="aAc" id="aAc">–</div><div class="aSigAc" id="aSigAc"></div></div><div id="aDiag"></div><div class="esp"></div>
  <button class="bt" id="aMenos" aria-label="Letra más chica">A−</button><button class="bt" id="aMas" aria-label="Letra más grande">A+</button>
  <button class="bt" id="aPlay" aria-label="Reproducir">▶</button><button class="bt" id="aSalir" aria-label="Salir">✕</button></div>
 <div class="centro"><div class="cab" id="aCab"></div><div class="aLin" id="aLin"></div><div class="aProx" id="aProx"></div></div>
 <div class="abajo"><div id="aBarra"></div></div>
</div>
<audio id="au" preload="auto"></audio>
<script>
const D=__DATOS__,PPS=__PPS__,PX=95,DPI=100;
const SOST=['C','C#','D','D#','E','F','F#','G','G#','A','A#','B'],BEM=['C','Db','D','Eb','E','F','Gb','G','Ab','A','Bb','B'];
const PC={C:0,'C#':1,Db:1,D:2,'D#':3,Eb:3,E:4,F:5,'F#':6,Gb:6,G:7,'G#':8,Ab:8,A:9,'A#':10,Bb:10,B:11,Cb:11};
const LAT={C:'Do',D:'Re',E:'Mi',F:'Fa',G:'Sol',A:'La',B:'Si'};
// [trastes cuerda 6→1 (-1 = no se toca), dedos]
const ABIERTO={'0':[[-1,3,2,0,1,0],[0,3,2,0,1,0]],'0|7':[[-1,3,2,3,1,0],[0,3,2,4,1,0]],'0|maj7':[[-1,3,2,0,0,0],[0,3,2,0,0,0]],
'2':[[-1,-1,0,2,3,2],[0,0,0,1,3,2]],'2|m':[[-1,-1,0,2,3,1],[0,0,0,2,3,1]],'2|7':[[-1,-1,0,2,1,2],[0,0,0,2,1,3]],'2|m7':[[-1,-1,0,2,1,1],[0,0,0,2,1,1]],'2|maj7':[[-1,-1,0,2,2,2],[0,0,0,1,2,3]],'2|sus4':[[-1,-1,0,2,3,3],[0,0,0,1,3,4]],
'4':[[0,2,2,1,0,0],[0,2,3,1,0,0]],'4|m':[[0,2,2,0,0,0],[0,2,3,0,0,0]],'4|7':[[0,2,0,1,0,0],[0,2,0,1,0,0]],'4|m7':[[0,2,0,0,0,0],[0,2,0,0,0,0]],'4|sus4':[[0,2,2,2,0,0],[0,2,3,4,0,0]],
'7':[[3,2,0,0,0,3],[2,1,0,0,0,3]],'7|7':[[3,2,0,0,0,1],[3,2,0,0,0,1]],'7|maj7':[[3,2,0,0,0,2],[3,2,0,0,0,1]],
'9':[[-1,0,2,2,2,0],[0,0,1,2,3,0]],'9|m':[[-1,0,2,2,1,0],[0,0,2,3,1,0]],'9|7':[[-1,0,2,0,2,0],[0,0,2,0,3,0]],'9|m7':[[-1,0,2,0,1,0],[0,0,2,0,1,0]],'9|maj7':[[-1,0,2,1,2,0],[0,0,2,1,3,0]],'9|sus4':[[-1,0,2,2,3,0],[0,0,1,2,3,0]],
'11|7':[[-1,2,1,2,0,2],[0,2,1,3,0,4]]};
const FORMA_E={'':[[0,2,2,1,0,0],[1,3,4,2,1,1]],m:[[0,2,2,0,0,0],[1,3,4,1,1,1]],'7':[[0,2,0,1,0,0],[1,3,1,2,1,1]],m7:[[0,2,0,0,0,0],[1,3,1,1,1,1]],maj7:[[0,-1,1,1,0,-1],[1,0,3,4,2,0]],sus4:[[0,2,2,2,0,0],[1,2,3,4,1,1]]};
const FORMA_A={'':[[-1,0,2,2,2,0],[0,1,3,3,3,1]],m:[[-1,0,2,2,1,0],[0,1,3,4,2,1]],'7':[[-1,0,2,0,2,0],[0,1,3,1,4,1]],m7:[[-1,0,2,0,1,0],[0,1,3,1,2,1]],maj7:[[-1,0,2,1,2,0],[0,1,3,2,4,1]],sus4:[[-1,0,2,2,3,0],[0,1,2,3,4,1]],dim:[[-1,0,1,2,1,-1],[0,1,2,4,3,0]],m7b5:[[-1,0,1,0,1,-1],[0,1,3,2,4,0]]};
const BAS={'':'',m:'m','7':'',m7:'m',maj7:'',dim:'dim',m7b5:'dim',sus4:''};

let cur=null,altura=0,latino=false,basico=true,usarPartitura=true,vista='diag',verTodos=false,usaBemol=false;
let celdas=[],sils=[],versos=[],pulsoAct=-2,lineaAct=-2,silAct=-2,evAct=-2,loopA=null,loopB=null,panel=null,acordesT=[],tamAtril=44,wake=null;
const $=id=>document.getElementById(id),au=$('au'),cv=$('cv'),ctx=cv.getContext('2d');

// ---- acordes: nombre, calidad, transporte ----
function normQ(q){q=q.split('/')[0];if(/^maj7/.test(q))return'maj7';if(/^(m7b5|ø)/.test(q))return'm7b5';if(/^(dim|º|°)/.test(q))return'dim';
 if(/^m7/.test(q))return'm7';if(/^m(?!aj)/.test(q))return'm';if(/sus/.test(q))return/^7/.test(q)?'7':'sus4';if(/^(7|9|11|13)/.test(q))return'7';return''}
function parse(a){const m=a.match(/^([A-G][#b]?)([^/]*)(?:\/([A-G][#b]?))?/);let q=normQ(m[2]||'');if(basico)q=BAS[q];
 return{r:PC[m[1]],q,b:m[3]!=null?PC[m[3]]:null}}
function nota(pc){let n=(usaBemol?BEM:SOST)[((pc%12)+12)%12];if(latino)n=LAT[n[0]]+n.slice(1);return n}
function etiqueta(a){if(!a)return'';const p=parse(a);return nota(p.r-altura)+p.q+(!basico&&p.b!=null?'/'+nota(p.b-altura):'')}
function forma(pc,q){const ab=ABIERTO[pc+(q?'|'+q:'')];if(ab)return{f:ab[0],d:ab[1],barra:0};
 const op=[];for(const[F,base]of[[FORMA_E,4],[FORMA_A,9]]){if(F[q]){let tr=(pc-base+12)%12;if(tr===0)tr=12;op.push({F:F[q],tr})}}
 if(!op.length)return forma(pc,'');op.sort((a,b)=>a.tr-b.tr);const o=op[0];return{f:o.F[0].map(v=>v<0?-1:v+o.tr),d:o.F[1],barra:o.tr}}
function svg(a,esc,color='#F2F1EF'){if(!a)return'';const p=parse(a);const{f,d,barra}=forma(((p.r-altura)%12+12)%12,p.q);
 const W=120*esc,H=132*esc,x0=18*esc,y0=26*esc,dx=17*esc,dy=21*esc,R=8*esc;
 const pos=f.filter(v=>v>0),max=Math.max(...pos,0),base=max>4?Math.min(...pos):1;
 let s=`<svg width="${W}" height="${H}" viewBox="0 0 ${W} ${H}" role="img" aria-label="${etiqueta(a)}">`;
 for(let i=0;i<6;i++)s+=`<line x1="${x0+i*dx}" y1="${y0}" x2="${x0+i*dx}" y2="${y0+5*dy}" stroke="${color}" stroke-width="${(i===0?2.5:1.3)*esc}"/>`;
 for(let j=0;j<6;j++)s+=`<line x1="${x0}" y1="${y0+j*dy}" x2="${x0+5*dx}" y2="${y0+j*dy}" stroke="${color}" stroke-width="${(j===0&&base===1?3:1.3)*esc}"/>`;
 if(base>1)s+=`<text x="${x0+5*dx+5*esc}" y="${y0+dy*.7}" font-size="${11*esc}" fill="${color}">${base}fr</text>`;
 const yF=v=>y0+(v-base+.5)*dy;
 if(barra){const c=f.map((v,i)=>v===barra&&d[i]===1?i:-1).filter(i=>i>=0);if(c.length>1){const A=c[0],B=c[c.length-1];
  s+=`<rect x="${x0+A*dx-R}" y="${yF(barra)-R}" width="${(B-A)*dx+2*R}" height="${2*R}" rx="${R}" fill="#EFD19F"/>`;
  s+=`<text x="${x0+A*dx}" y="${yF(barra)+4*esc}" font-size="${11*esc}" text-anchor="middle" fill="#0A245E">1</text>`}}
 f.forEach((v,i)=>{const x=x0+i*dx;
  if(v<0)s+=`<text x="${x}" y="${y0-8*esc}" font-size="${13*esc}" text-anchor="middle" fill="${color}">×</text>`;
  else if(v===0)s+=`<circle cx="${x}" cy="${y0-12*esc}" r="${5*esc}" fill="none" stroke="${color}" stroke-width="${1.3*esc}"/>`;
  else if(!(barra&&v===barra&&d[i]===1)){s+=`<circle cx="${x}" cy="${yF(v)}" r="${R}" fill="#EFD19F"/>`;
   if(d[i])s+=`<text x="${x}" y="${yF(v)+4*esc}" font-size="${11*esc}" text-anchor="middle" fill="#0A245E">${d[i]}</text>`}});
 return s+'</svg>'}
function finalP(){const a=acordesT.length?acordesT[acordesT.length-1][1]:'C';return parse(a.replace(/\/.*/,''))}
function calcBemol(){const f=finalP(),pc=((f.r-altura)%12+12)%12;return[5,10,3,8,1,6].includes(/^m/.test(f.q)?(pc+3)%12:pc)}

// ---- fuente de acordes: partitura (exacta) o IA ----
function construirFuente(){const P=cur.pulsos;const ia=[];P.forEach(([t,a])=>{if(a&&(!ia.length||ia[ia.length-1][1]!==a))ia.push([t,a])});
 if(!usarPartitura||!cur.sinc){acordesT=ia;return}
 const ev=cur.sinc.eventos.filter(e=>e[0]!=null).map(e=>[e[0],e[1]]).sort((a,b)=>a[0]-b[0]);
 acordesT=ia.filter(x=>x[0]<ev[0][0]).concat(ev)}
function idxEn(arr,t){let lo=0,hi=arr.length-1,k=-1;while(lo<=hi){const m=(lo+hi)>>1;if(arr[m][0]<=t){k=m;lo=m+1}else hi=m-1}return k}
function acordeEn(t){const k=idxEn(acordesT,t);return k>=0?acordesT[k][1]:null}

// ---- línea de tiempo ----
function dibujarLinea(){const r=cv.getBoundingClientRect(),dpr=devicePixelRatio||1;
 if(cv.width!==Math.round(r.width*dpr)||cv.height!==Math.round(r.height*dpr)){cv.width=Math.round(r.width*dpr);cv.height=Math.round(r.height*dpr)}
 const W=r.width,H=r.height;ctx.setTransform(dpr,0,0,dpr,0,0);ctx.clearRect(0,0,W,H);
 const t=au.currentTime,cx=W*.42,t0=t-cx/PX,t1=t+(W-cx)/PX,yR=22,yE=40,yM=H/2+20,hM=H*.28;
 if(loopA!=null){const xa=cx+(loopA-t)*PX,xb=loopB!=null?cx+(loopB-t)*PX:cx;ctx.fillStyle='#3E80F233';ctx.fillRect(xa,yE,xb-xa,H-yE)}
 ctx.strokeStyle='#F2F1EF99';ctx.fillStyle='#F2F1EF';ctx.font='12px Noto Sans';ctx.textAlign='center';ctx.lineWidth=1;
 ctx.beginPath();ctx.moveTo(0,yR+6);ctx.lineTo(W,yR+6);ctx.stroke();
 for(let s=Math.ceil(t0*2)/2;s<t1;s+=.5){const x=cx+(s-t)*PX;ctx.beginPath();ctx.moveTo(x,yR+6);ctx.lineTo(x,yR+(s%1===0?-2:2));ctx.stroke();
  if(s%1===0&&s>=0)ctx.fillText(mmss(s),x,yR-6)}
 const P=cur.picos,paso=PX/PPS;ctx.fillStyle='#d9d9d9';
 for(let i=Math.max(0,Math.floor(t0*PPS));i<Math.min(P.length,t1*PPS);i++){const x=cx+(i/PPS-t)*PX,h=Math.max(2,P[i]*hM);ctx.fillRect(x,yM-h,Math.max(1.5,paso*.55),2*h)}
 ctx.font='600 18px Noto Sans';ctx.textAlign='left';let prev=null,finUlt=-1e9;
 for(const[s,a]of acordesT){const e=etiqueta(a);if(e===prev)continue;prev=e;if(s<t0-3||s>t1)continue;
  let x=cx+(s-t)*PX;const w=ctx.measureText(e).width+14;const fila=x<finUlt+4?1:0;// si se encima, baja una fila
  ctx.fillStyle='#EFD19F';ctx.beginPath();ctx.roundRect(x,yE+fila*32,w,28,6);ctx.fill();ctx.fillStyle='#0A245E';ctx.fillText(e,x+7,yE+fila*32+20);if(!fila)finUlt=x+w}
 ctx.strokeStyle='#3E80F2';ctx.lineWidth=2;ctx.beginPath();ctx.moveTo(cx,yR+6);ctx.lineTo(cx,H);ctx.stroke()}
let arrastre=null;
cv.addEventListener('pointerdown',e=>{arrastre={x:e.clientX,t:au.currentTime,mov:false};cv.setPointerCapture(e.pointerId)});
cv.addEventListener('pointermove',e=>{if(!arrastre)return;const dx=e.clientX-arrastre.x;if(Math.abs(dx)>3)arrastre.mov=true;
 if(arrastre.mov){au.currentTime=Math.max(0,arrastre.t-dx/PX);refrescar()}});
cv.addEventListener('pointerup',()=>{arrastre=null});

// ---- letra ----
// Las sílabas de una misma palabra van juntas (no se cortan entre renglones); acordes repetidos en una sílaba se muestran una vez.
function htmlLinea(li,conRef){let h='',abierta=false;li.s.forEach(([t,tx,une,acs],k)=>{
  const et=acs.map(etiqueta).filter((e,i,a)=>i===0||e!==a[i-1]).join(' ');
  if(!abierta){h+='<span class="pal">';abierta=true}
  h+=`<span class="sil${une?'':' esp'}"${conRef?` data-k="${k}"`:''}><span class="ac">${et}</span><span class="tx">${tx}</span></span>`;
  if(!une){h+='</span>';abierta=false}});return h+(abierta?'</span>':'')}
function cabecera(li){return li.tipo==='coro'?'Coro':`Estrofa ${li.e}`}
function construirLetra(){const v=$('vLetra');sils=[];versos=[];
 if(!cur.sinc){v.innerHTML='<div class="vacio">Este himno aún no tiene la letra sincronizada (la partitura no trae acordes).</div>';return}
 let h='',prev='';cur.sinc.lineas.forEach((li,i)=>{const c=cabecera(li)+li.e;if(c!==prev){h+=`<div class="cab">${cabecera(li)}</div>`;prev=c}
  h+=`<div class="verso" data-i="${i}">${htmlLinea(li,true)}</div>`});v.innerHTML=h;
 let ev0=0;v.querySelectorAll('.verso').forEach(el=>{const li=cur.sinc.lineas[+el.dataset.i];versos.push({el,t:li.s[0][0]});
  el.querySelectorAll('.sil').forEach(s=>{const sl=li.s[+s.dataset.k];sils.push({el:s,t:sl[0],linea:versos.length-1,ev0,nev:sl[3].length});ev0+=sl[3].length});
  el.onclick=()=>{au.currentTime=li.s[0][0];au.play()}})}

// ---- partitura ----
function construirPartitura(){const v=$('vPart');
 if(!cur.sinc){v.innerHTML='<div class="vacio">Sin partitura con cifrado para este himno.</div>';return}
 v.innerHTML=cur.sinc.paginas.map((p,i)=>`<div class="pag" data-p="${i}"><img src="${p.img}" alt="Partitura página ${i+1}"><div class="marca oculto"></div><div class="caja oculto"></div></div>`).join('')}
function moverMarca(k){document.querySelectorAll('.pag .marca,.pag .caja').forEach(m=>m.classList.add('oculto'));if(k<0||!cur.sinc)return;
 const e=cur.sinc.eventos[k],pag=document.querySelector(`.pag[data-p="${e[2]}"]`);if(!pag)return;const P=cur.sinc.paginas[e[2]],sx=DPI/72;
 const pct=(v,tot)=>v*sx/tot*100+'%';const m=pag.querySelector('.marca'),c=pag.querySelector('.caja');
 m.style.left=pct(e[3]-3,P.w);m.style.top=pct(e[4]+8,P.h);m.style.width='3px';m.style.height=pct(125,P.h);
 c.style.left=pct(e[3]-4,P.w);c.style.top=pct(e[4]-9,P.h);c.style.width=pct(34,P.w);c.style.height=pct(18,P.h);m.classList.remove('oculto');c.classList.remove('oculto');
 if(vista==='part'){const r=c.getBoundingClientRect(),b=$('cuerpo').getBoundingClientRect();if(r.top<b.top+20||r.bottom>b.bottom-60)$('cuerpo').scrollTop+=r.top-b.top-b.height*.3}}

// ---- construir todo ----
function construir(){construirFuente();usaBemol=calcBemol();
 const g=$('vGrid');g.innerHTML='';celdas=[];const n=parseInt(cur.compas)||4;let prev=null,div=null;
 cur.pulsos.forEach(([t],i)=>{if(i%n===0){div=document.createElement('div');div.className='compas';g.appendChild(div)}
  const a=acordeEn(t+.05),e=etiqueta(a),c=document.createElement('div');c.className='pulso';c.textContent=a&&e!==prev?e:'';if(a)prev=e;
  c.onclick=()=>{au.currentTime=t;au.play()};div.appendChild(c);celdas.push(c)});
 const usados=[],vistos=new Set();acordesT.forEach(([,a])=>{const e=etiqueta(a);if(!vistos.has(e)){vistos.add(e);usados.push(a)}});
 $('vTodos').innerHTML=usados.map(a=>`<div class="dg"><div class="nom">${etiqueta(a)}</div>${svg(a,.8)}</div>`).join('');
 construirLetra();construirPartitura();
 const f=finalP();$('tono').textContent='𝄞 '+nota(f.r-altura)+(/^m/.test(f.q)?'m':'');$('bpm').textContent='BPM '+(cur.tempo||'–');
 $('altTxt').textContent=altura?`Capo ${altura}`:'Sin capo';
 [['swB',basico],['swT',!basico],['swC',!latino],['swD',latino],['swP',usarPartitura&&!!cur.sinc],['swI',!(usarPartitura&&cur.sinc)]].forEach(([id,on])=>$(id).classList.toggle('on',on));
 $('vDiag').classList.toggle('oculto',vista!=='diag');$('vLetra').classList.toggle('oculto',vista!=='letra');$('vPart').classList.toggle('oculto',vista!=='part');$('vGrid').classList.toggle('oculto',vista!=='grid');
 $('vTodos').classList.toggle('oculto',!verTodos);$('verTodo').textContent=verTodos?'Ocultar todos los acordes':'▦ Ver todos los acordes';
 document.querySelectorAll('.vistas button').forEach(b=>b.classList.toggle('on',b.dataset.v===vista));
 pulsoAct=lineaAct=silAct=evAct=-2;refrescar()}
function cargar(i){cur=D[i];$('sel').value=i;au.src=`../pistas/${cur.n}.mp3`;altura=0;loopA=loopB=null;$('loopBtn').textContent='Marcar A';
 $('titulo').textContent=`${cur.n} · ${cur.titulo}`;const c=cur.comp;
 $('detalle').textContent=`${cur.tono} · ${cur.compas}`+(cur.sinc?' · letra sincronizada':'')+(c.secuencia_pct!=null?` · IA ${c.secuencia_pct}% igual a la partitura`:'');construir()}

// ---- refresco por tiempo ----
function refrescar(){if(!cur)return;const t=au.currentTime;if(loopB!=null&&t>=loopB){au.currentTime=loopA;return}
 const k=idxEn(cur.pulsos,t);
 if(k!==pulsoAct){celdas.forEach((c,j)=>{c.classList.toggle('ahora',j===k);c.classList.toggle('ya',j<k)});
  if(vista==='grid'&&k>=0)visible(celdas[k]);pulsoAct=k}
 const ka=idxEn(acordesT,t),act=ka>=0?acordesT[ka][1]:null;let sig=null;
 for(let i=ka+1;i<acordesT.length;i++){if(!act||etiqueta(acordesT[i][1])!==etiqueta(act)){sig=acordesT[i][1];break}}
 const clave=etiqueta(act)+'|'+etiqueta(sig);if(clave!==refrescar.clave){refrescar.clave=clave;
  $('nAct').textContent=act?etiqueta(act):'–';$('dAct').innerHTML=svg(act,1.15);$('nSig').textContent=sig?etiqueta(sig):'–';$('dSig').innerHTML=svg(sig,1.15);
  $('aAc').textContent=act?etiqueta(act):'–';$('aSigAc').textContent=sig?'Sigue: '+etiqueta(sig):'';$('aDiag').innerHTML=svg(act,.9)}
 if(cur.sinc){let li=-1;for(let i=0;i<versos.length;i++){if(versos[i].t<=t+.15)li=i;else break}
  if(li!==lineaAct){versos.forEach((v,j)=>{v.el.classList.toggle('ahora',j===li);v.el.classList.toggle('ya',j<li)});if(vista==='letra'&&li>=0)visible(versos[li].el);lineaAct=li;pintarAtril(li)}
  let si=-1;for(let i=0;i<sils.length;i++){if(sils[i].t<=t+.05)si=i;else break}
  if(si!==silAct){sils.forEach((s,j)=>{s.el.classList.toggle('ya',j<=si&&s.linea===li)});
   const ev=cur.sinc.eventos;let ke=-1;for(let i=0;i<ev.length;i++){if(ev[i][0]!=null&&ev[i][0]<=t+.05)ke=i}
   if(ke!==evAct){document.querySelectorAll('.sil.ahora').forEach(s=>s.classList.remove('ahora'));evAct=ke;moverMarca(ke);marcarSilAcorde(ke)}
   silAct=si;pintarAtrilSil(t)}}
 const d=au.duration||0;$('barra').value=d?t/d*1000:0;$('tiempo').textContent=`${mmss(t)} / ${mmss(d)}`;$('aBarra').style.width=(d?t/d*100:0)+'%';dibujarLinea()}
// Los eventos están en el mismo orden que las sílabas con acorde: la sílaba s lleva los eventos [ev0, ev0+nev).
function marcarSilAcorde(ke){if(ke<0)return;const s=sils.find(s=>ke>=s.ev0&&ke<s.ev0+s.nev);if(s)s.el.classList.add('ahora')}
function visible(el){const r=el.getBoundingClientRect(),b=$('cuerpo').getBoundingClientRect();if(r.top<b.top+10||r.bottom>b.bottom-10)$('cuerpo').scrollTop+=r.top-b.top-b.height*.35}
const mmss=s=>`${Math.floor(s/60)}:${String(Math.floor(s%60)).padStart(2,'0')}`;
(function bucle(){if(cur&&!au.paused)refrescar();requestAnimationFrame(bucle)})();

// ---- modo atril ----
function pintarAtril(li){if($('atril').classList.contains('oculto'))return;const L=cur.sinc?cur.sinc.lineas:[];
 if(!L.length){$('aLin').innerHTML='';$('aProx').innerHTML='';$('aCab').textContent='';return}
 const i=Math.max(li,0);$('aCab').textContent=li<0?'Introducción':cabecera(L[i]);$('aLin').innerHTML=htmlLinea(L[i],true);$('aProx').innerHTML=L[i+1]?htmlLinea(L[i+1],false):''}
function pintarAtrilSil(t){if($('atril').classList.contains('oculto')||lineaAct<0)return;const li=cur.sinc.lineas[lineaAct];
 $('aLin').querySelectorAll('.sil').forEach(s=>s.classList.toggle('ya',li.s[+s.dataset.k][0]<=t+.05))}
async function abrirAtril(){$('atril').classList.remove('oculto');lineaAct=-2;refrescar.clave='';refrescar();
 try{await document.documentElement.requestFullscreen()}catch(e){}try{wake=await navigator.wakeLock.request('screen')}catch(e){}}
function cerrarAtril(){$('atril').classList.add('oculto');try{if(document.fullscreenElement)document.exitFullscreen()}catch(e){}try{wake&&wake.release()}catch(e){}}
$('btnAtril').onclick=abrirAtril;$('aSalir').onclick=cerrarAtril;
$('aMas').onclick=()=>{tamAtril=Math.min(90,tamAtril+6);$('atril').style.setProperty('--atril',tamAtril+'px')};
$('aMenos').onclick=()=>{tamAtril=Math.max(24,tamAtril-6);$('atril').style.setProperty('--atril',tamAtril+'px')};
$('aPlay').onclick=()=>$('play').click();

// ---- controles ----
D.forEach((h,i)=>{const o=document.createElement('option');o.value=i;o.textContent=`${h.n} · ${h.titulo}`;$('sel').appendChild(o)});
$('sel').onchange=e=>cargar(e.target.value);
$('opBasico').onclick=()=>{basico=!basico;refrescar.clave='';construir()};$('opNotacion').onclick=()=>{latino=!latino;refrescar.clave='';construir()};
$('opFuente').onclick=()=>{usarPartitura=!usarPartitura;refrescar.clave='';construir()};
$('verTodo').onclick=()=>{verTodos=!verTodos;construir()};
document.querySelectorAll('.vistas button').forEach(b=>b.onclick=()=>{vista=b.dataset.v;construir()});
document.querySelectorAll('.tab').forEach(b=>b.onclick=()=>{panel=panel===b.dataset.p?null:b.dataset.p;
 document.querySelectorAll('.tab').forEach(x=>x.classList.toggle('on',x.dataset.p===panel));
 for(const p of['altura','tempo','loop'])$('p'+p[0].toUpperCase()+p.slice(1)).classList.toggle('oculto',panel!==p)});
$('altMas').onclick=()=>{if(altura<9){altura++;refrescar.clave='';construir()}};$('altMenos').onclick=()=>{if(altura>0){altura--;refrescar.clave='';construir()}};
au.preservesPitch=true;
const vel=()=>{$('temTxt').textContent=Math.round(au.playbackRate*100)+'%'};
$('temMas').onclick=()=>{au.playbackRate=Math.min(1.5,+(au.playbackRate+.05).toFixed(2));vel()};$('temMenos').onclick=()=>{au.playbackRate=Math.max(.5,+(au.playbackRate-.05).toFixed(2));vel()};
au.onratechange=vel;
$('loopBtn').onclick=()=>{const b=$('loopBtn');if(loopA==null){loopA=au.currentTime;b.textContent='Marcar B'}
 else if(loopB==null){loopB=Math.max(au.currentTime,loopA+.5);b.textContent='Quitar loop';au.currentTime=loopA}else{loopA=loopB=null;b.textContent='Marcar A'}refrescar()};
$('play').onclick=()=>au.paused?au.play():au.pause();
au.onplay=()=>{$('play').textContent='❚❚';$('aPlay').textContent='❚❚'};au.onpause=()=>{$('play').textContent='▶';$('aPlay').textContent='▶'};
$('barra').oninput=e=>{if(au.duration){au.currentTime=e.target.value/1000*au.duration;refrescar()}};
au.ontimeupdate=refrescar;au.onloadedmetadata=refrescar;addEventListener('resize',refrescar);
addEventListener('keydown',e=>{if(e.code==='Space'&&e.target.tagName!=='SELECT'){e.preventDefault();$('play').click()}if(e.key==='Escape')cerrarAtril()});
cargar(0);
</script></body></html>"""

if __name__ == "__main__":
    main([int(a) for a in sys.argv[1:]])
