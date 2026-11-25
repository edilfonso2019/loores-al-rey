"""Genera salida/visor.html al estilo Chord ai: cuadrícula de compases que avanza con la pista,
diagramas de guitarra del acorde actual y el siguiente, capo (con sugerencia) y nombres Do-Re-Mi / C-D-E.
Solo para revisar la prueba piloto."""
import json
import os
import sys

AQUI = os.path.dirname(os.path.abspath(__file__))


def main(numeros):
    ruta_comp = os.path.join(AQUI, "salida", "comparacion.json")
    comp = {c["n"]: c for c in json.load(open(ruta_comp, encoding="utf-8"))} if os.path.exists(ruta_comp) else {}
    datos = []
    for n in numeros:
        ia = json.load(open(os.path.join(AQUI, "salida", f"{n}.json"), encoding="utf-8"))
        datos.append({"n": n, "titulo": ia["titulo"], "tono": ia["tono"], "compas": ia.get("compas") or "4/4",
                      "pulsos": ia["pulsos"], "comp": comp.get(n, {})})
    html = PLANTILLA.replace("__DATOS__", json.dumps(datos, ensure_ascii=False))
    ruta = os.path.join(AQUI, "salida", "visor.html")
    open(ruta, "w", encoding="utf-8").write(html)
    print(ruta)


PLANTILLA = r"""<!doctype html>
<html lang="es"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>Acordes piloto</title>
<link href="https://fonts.googleapis.com/css2?family=Noto+Sans:wght@400;600;800&display=swap" rel="stylesheet">
<style>
:root{--azul:#0A245E;--azul2:#0F3999;--claro:#3E80F2;--dorado:#F1BE48;--fondo:#F2F1EF;--gris:#7E7E82;--linea:#dfe3ec}
*{box-sizing:border-box}html,body{margin:0}body{font-family:'Noto Sans',sans-serif;background:var(--fondo);color:#1b1b1f;padding-bottom:96px}
header{background:var(--azul);color:#fff;padding:12px 16px;position:sticky;top:0;z-index:5}
header select{width:100%;font:inherit;font-weight:600;padding:8px;border-radius:8px;border:0;background:#ffffff1f;color:#fff}
header select option{color:#000}
.info{display:flex;gap:8px;flex-wrap:wrap;margin-top:8px;font-size:12px}.info span{background:#ffffff26;padding:3px 8px;border-radius:99px}
main{max-width:960px;margin:0 auto;padding:12px 16px}
.diagramas{display:flex;gap:12px;align-items:flex-end;justify-content:center;background:#fff;border-radius:14px;padding:12px;box-shadow:0 1px 3px #0001;position:sticky;top:104px;z-index:4}
.diag{text-align:center}.diag .nom{font-weight:800;color:var(--azul);font-size:30px;line-height:1.1}
.diag.sig{opacity:.55}.diag.sig .nom{font-size:20px}.diag small{display:block;color:var(--gris);font-size:11px;text-transform:uppercase;letter-spacing:.06em}
.ctrl{display:flex;gap:8px;flex-wrap:wrap;align-items:center;margin:12px 0}
.btn{border:1px solid var(--linea);background:#fff;border-radius:99px;padding:6px 12px;font:inherit;font-size:14px;cursor:pointer;min-height:36px}
.btn.on{background:var(--azul);color:#fff;border-color:var(--azul)}.btn.dor{background:var(--dorado);border-color:var(--dorado);font-weight:600}
.capo{display:flex;align-items:center;gap:4px;background:#fff;border:1px solid var(--linea);border-radius:99px;padding:2px}
.capo b{min-width:64px;text-align:center;font-size:14px}.capo .btn{border:0;min-width:36px;padding:6px}
.grid{display:grid;grid-template-columns:repeat(4,1fr);gap:6px}
@media(max-width:640px){.grid{grid-template-columns:repeat(2,1fr)}.diagramas{top:96px}}
.compas{background:#fff;border-radius:8px;display:flex;border:1px solid var(--linea);min-height:52px;overflow:hidden}
.pulso{flex:1;position:relative;border-left:1px dashed #e6e9f0;cursor:pointer;display:flex;align-items:center;padding-left:4px;font-weight:800;color:var(--azul);font-size:17px;white-space:nowrap}
.pulso:first-child{border-left:0}.pulso.ya{color:#9aa3b8}.pulso.ahora{background:#dfe9ff}.pulso.ahora::after{content:'';position:absolute;left:0;top:0;bottom:0;width:3px;background:var(--claro)}
.nota{font-size:12px;color:var(--gris);margin:12px 0}
.player{position:fixed;left:0;right:0;bottom:0;background:var(--azul);color:#fff;display:flex;align-items:center;gap:12px;padding:12px 16px;z-index:6}
.play{width:52px;height:52px;border-radius:50%;border:0;background:var(--dorado);color:var(--azul);font-size:22px;cursor:pointer;flex:none}
.player input{flex:1;accent-color:var(--dorado)}.player .t{font-variant-numeric:tabular-nums;font-size:13px;min-width:92px;text-align:right}
</style></head><body>
<header><select id="sel" aria-label="Himno"></select><div class="info" id="info"></div></header>
<main>
<div class="diagramas"><div class="diag"><small>Ahora</small><div class="nom" id="nAct">–</div><div id="dAct"></div></div>
<div class="diag sig"><small>Sigue</small><div class="nom" id="nSig">–</div><div id="dSig"></div></div></div>
<div class="ctrl">
 <div class="capo"><button class="btn" id="capoMenos" aria-label="Bajar capo">−</button><b id="capoTxt">Sin capo</b><button class="btn" id="capoMas" aria-label="Subir capo">+</button></div>
 <button class="btn dor" id="sugerido"></button>
 <button class="btn" id="nota">Do Re Mi</button>
</div>
<div class="grid" id="grid"></div>
<p class="nota">Prueba piloto: los acordes los detecta la IA escuchando la pista instrumental. Las divisiones de compás son aproximadas.</p>
</main>
<div class="player"><button class="play" id="play" aria-label="Reproducir">▶</button><input type="range" id="barra" min="0" max="1000" value="0" aria-label="Progreso"><span class="t" id="tiempo">0:00 / 0:00</span></div>
<audio id="au" preload="auto"></audio>
<script>
const D=__DATOS__;
const SOST=['C','C#','D','D#','E','F','F#','G','G#','A','A#','B'],BEM=['C','Db','D','Eb','E','F','Gb','G','Ab','A','Bb','B'];
const PC={C:0,'C#':1,Db:1,D:2,'D#':3,Eb:3,E:4,F:5,'F#':6,Gb:6,G:7,'G#':8,Ab:8,A:9,'A#':10,Bb:10,B:11};
const LAT={C:'Do',D:'Re',E:'Mi',F:'Fa',G:'Sol',A:'La',B:'Si'};
const TONO={'do':0,'do sostenido':1,'re bemol':1,'re':2,'mi bemol':3,'mi':4,'fa':5,'fa sostenido':6,'sol bemol':6,'sol':7,'la bemol':8,'la':9,'si bemol':10,'si':11};
// Formas abiertas (cuerdas 6→1; -1 = no se toca)
const ABIERTO={'0':[-1,3,2,0,1,0],'0|7':[-1,3,2,3,1,0],'0|maj7':[-1,3,2,0,0,0],
'2':[-1,-1,0,2,3,2],'2|m':[-1,-1,0,2,3,1],'2|7':[-1,-1,0,2,1,2],'2|m7':[-1,-1,0,2,1,1],'2|maj7':[-1,-1,0,2,2,2],'2|sus4':[-1,-1,0,2,3,3],
'4':[0,2,2,1,0,0],'4|m':[0,2,2,0,0,0],'4|7':[0,2,0,1,0,0],'4|m7':[0,2,0,0,0,0],'4|sus4':[0,2,2,2,0,0],
'7':[3,2,0,0,0,3],'7|7':[3,2,0,0,0,1],'7|maj7':[3,2,0,0,0,2],
'9':[-1,0,2,2,2,0],'9|m':[-1,0,2,2,1,0],'9|7':[-1,0,2,0,2,0],'9|m7':[-1,0,2,0,1,0],'9|maj7':[-1,0,2,1,2,0],'9|sus4':[-1,0,2,2,3,0],
'11|7':[-1,2,1,2,0,2]};
const FORMA_E={'':[0,2,2,1,0,0],m:[0,2,2,0,0,0],'7':[0,2,0,1,0,0],m7:[0,2,0,0,0,0],maj7:[0,-1,1,1,0,-1],sus4:[0,2,2,2,0,0]};
const FORMA_A={'':[-1,0,2,2,2,0],m:[-1,0,2,2,1,0],'7':[-1,0,2,0,2,0],m7:[-1,0,2,0,1,0],maj7:[-1,0,2,1,2,0],sus4:[-1,0,2,2,3,0],dim:[-1,0,1,2,1,-1],m7b5:[-1,0,1,0,1,-1]};
const CAL={'':'',m:'m','7':'7',m7:'m7',maj7:'maj7',dim:'dim',dim7:'dim',m7b5:'m7b5',aug:'',sus2:'',sus4:'sus4','6':'',m6:'m','m(maj7)':'m'};

let cur=null,capo=0,latino=false,celdas=[],pulsoAct=-1,usaBemol=false;
const $=id=>document.getElementById(id),au=$('au');

function parse(a){const m=a.match(/^([A-G][#b]?)(.*)$/);return{r:PC[m[1]],q:m[2]}}
function nombre(pc,q){let n=(usaBemol?BEM:SOST)[(pc+120)%12];if(latino)n=LAT[n[0]]+n.slice(1);return n+q}
function forma(pc,q){const qq=CAL[q]??'';const abierto=ABIERTO[pc+(qq?'|'+qq:'')];if(abierto)return{f:abierto,barra:0};
 const op=[];for(const [F,base] of [[FORMA_E,4],[FORMA_A,9]]){if(F[qq]){let tr=(pc-base+12)%12;if(tr===0)tr=12;op.push({p:F[qq],tr})}}
 if(!op.length)return forma(pc,'');op.sort((a,b)=>a.tr-b.tr);const o=op[0];
 return{f:o.p.map(v=>v<0?-1:v+o.tr),barra:o.tr}}
function svg(fr,barra,esc){const w=esc*92,h=esc*112,x0=esc*18,y0=esc*22,dx=esc*13,dy=esc*17;
 const pos=fr.filter(v=>v>0),max=Math.max(...pos,0),base=max>4?Math.min(...pos):1;
 let s=`<svg width="${w}" height="${h}" viewBox="0 0 ${w} ${h}" role="img">`;
 for(let i=0;i<6;i++)s+=`<line x1="${x0+i*dx}" y1="${y0}" x2="${x0+i*dx}" y2="${y0+4*dy}" stroke="#7E7E82" stroke-width="${esc}"/>`;
 for(let j=0;j<5;j++)s+=`<line x1="${x0}" y1="${y0+j*dy}" x2="${x0+5*dx}" y2="${y0+j*dy}" stroke="#7E7E82" stroke-width="${j===0&&base===1?4*esc:esc}"/>`;
 if(base>1)s+=`<text x="${x0-4*esc}" y="${y0+dy*.65}" font-size="${10*esc}" text-anchor="end" fill="#0A245E">${base}</text>`;
 if(barra&&barra>=base){const cuerdas=fr.map((v,i)=>v===barra?i:-1).filter(i=>i>=0);if(cuerdas.length>1){const a=cuerdas[0],b=cuerdas[cuerdas.length-1];
  s+=`<rect x="${x0+a*dx-5*esc}" y="${y0+(barra-base+.5)*dy-5*esc}" width="${(b-a)*dx+10*esc}" height="${10*esc}" rx="${5*esc}" fill="#0A245E"/>`}}
 fr.forEach((v,i)=>{const x=x0+i*dx;if(v<0)s+=`<text x="${x}" y="${y0-6*esc}" font-size="${10*esc}" text-anchor="middle" fill="#7E7E82">×</text>`;
  else if(v===0)s+=`<circle cx="${x}" cy="${y0-9*esc}" r="${3.5*esc}" fill="none" stroke="#0A245E" stroke-width="${esc}"/>`;
  else if(!(barra&&v===barra))s+=`<circle cx="${x}" cy="${y0+(v-base+.5)*dy}" r="${5*esc}" fill="#0A245E"/>`});
 return s+'</svg>'}
function etiqueta(a){if(!a)return'';const[ac,baj]=a.split('/');const p=parse(ac);let t=nombre(p.r-capo,p.q);if(baj){t+='/'+nombre(PC[baj]-capo,'')}return t}
function dibujo(a,esc){if(!a)return'';const p=parse(a.split('/')[0]);const f=forma((p.r-capo+12)%12,p.q);return svg(f.f,f.barra,esc)}
function tonica(t){return TONO[t.toLowerCase().replace(/ (mayor|menor)$/,'')]}
function bemoles(){const t=cur.tono.toLowerCase(),men=t.includes('menor');const pc=((tonica(cur.tono)-capo)%12+12)%12;
 const mayRel=men?(pc+3)%12:pc;return[5,10,3,8,1,6].includes(mayRel)}
function sugerirCapo(){let mejor=0,min=1e9;for(let c=0;c<=7;c++){let barras=0;for(const[,a]of cur.pulsos){if(!a)continue;const p=parse(a);
 const qq=CAL[p.q]??'';if(!ABIERTO[((p.r-c)%12+12)%12+(qq?'|'+qq:'')])barras++}if(barras<min){min=barras;mejor=c}}return mejor}
function porCompas(){const n=parseInt(cur.compas)||4;return n===6?6:n}

function construir(){usaBemol=bemoles();const g=$('grid');g.innerHTML='';celdas=[];const n=porCompas();let prev=null,div=null;
 cur.pulsos.forEach(([t,a],i)=>{if(i%n===0){div=document.createElement('div');div.className='compas';g.appendChild(div)}
  const c=document.createElement('div');c.className='pulso';c.textContent=a&&a!==prev?etiqueta(a):'';if(a)prev=a;
  c.onclick=()=>{au.currentTime=t;au.play()};div.appendChild(c);celdas.push(c)});
 $('capoTxt').textContent=capo?`Capo ${capo}`:'Sin capo';const s=sugerirCapo();$('sugerido').textContent=s?`Sugerido: capo ${s}`:'Sugerido: sin capo';
 $('nota').textContent=latino?'C D E':'Do Re Mi';pulsoAct=-1;pintar()}
function cargar(i){cur=D[i];au.src=`../pistas/${cur.n}.mp3`;capo=0;const c=cur.comp;
 $('info').innerHTML=`<span>${cur.tono}</span><span>${cur.compas}</span>`+(c.secuencia_pct!=null?`<span>Coincide con la partitura: ${c.secuencia_pct}%</span>`:'');construir()}
function pintar(){if(!cur)return;const t=au.currentTime;let k=-1;for(let i=0;i<cur.pulsos.length;i++){if(cur.pulsos[i][0]<=t)k=i;else break}
 if(k!==pulsoAct){celdas.forEach((c,j)=>{c.classList.toggle('ahora',j===k);c.classList.toggle('ya',j<k)});
  if(k>=0&&(pulsoAct<0||celdas[k].parentElement!==celdas[pulsoAct]?.parentElement)){const r=celdas[k].getBoundingClientRect();if(r.top<230||r.bottom>innerHeight-110)celdas[k].scrollIntoView({block:'center',behavior:'smooth'})}
  pulsoAct=k;let act=null,sig=null;for(let i=Math.max(k,0);i>=0;i--)if(cur.pulsos[i][1]){act=cur.pulsos[i][1];break}
  for(let i=k+1;i<cur.pulsos.length;i++)if(cur.pulsos[i][1]&&cur.pulsos[i][1]!==act){sig=cur.pulsos[i][1];break}
  if(k<0){act=null;sig=cur.pulsos.find(p=>p[1])?.[1]}
  $('nAct').textContent=act?etiqueta(act):'–';$('dAct').innerHTML=dibujo(act,1.3);$('nSig').textContent=sig?etiqueta(sig):'–';$('dSig').innerHTML=dibujo(sig,.9)}
 const d=au.duration||0;$('barra').value=d?t/d*1000:0;$('tiempo').textContent=`${mmss(t)} / ${mmss(d)}`}
const mmss=s=>`${Math.floor(s/60)}:${String(Math.floor(s%60)).padStart(2,'0')}`;
D.forEach((h,i)=>{const o=document.createElement('option');o.value=i;o.textContent=`${h.n} · ${h.titulo}`;$('sel').appendChild(o)});
$('sel').onchange=e=>cargar(e.target.value);
$('capoMas').onclick=()=>{if(capo<9){capo++;construir()}};$('capoMenos').onclick=()=>{if(capo>0){capo--;construir()}};
$('sugerido').onclick=()=>{capo=sugerirCapo();construir()};$('nota').onclick=()=>{latino=!latino;construir()};
$('play').onclick=()=>au.paused?au.play():au.pause();au.onplay=()=>$('play').textContent='❚❚';au.onpause=()=>$('play').textContent='▶';
$('barra').oninput=e=>{if(au.duration)au.currentTime=e.target.value/1000*au.duration};
au.ontimeupdate=pintar;au.onloadedmetadata=pintar;
addEventListener('keydown',e=>{if(e.code==='Space'&&e.target.tagName!=='SELECT'){e.preventDefault();$('play').click()}});
cargar(0);
</script></body></html>"""

if __name__ == "__main__":
    main([int(a) for a in sys.argv[1:]])
