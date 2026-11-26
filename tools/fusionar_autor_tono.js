#!/usr/bin/env node
// Fusiona autor, tonalidad, compás y créditos en assets/data/clasico.json.
//
// Fuente: tools/fuentes/himnos_autor_tono.json (armado a partir de las
// partituras). Se puede volver a ejecutar cuando la fuente se complete o se
// corrija; solo reemplaza los campos que maneja este script.
//
//   node tools/fusionar_autor_tono.js            (escribe clasico.json)
//   node tools/fusionar_autor_tono.js --revisar  (solo muestra el informe)

const fs = require('fs');
const path = require('path');

const raiz = path.join(__dirname, '..');
const rutaFuente = path.join(__dirname, 'fuentes', 'himnos_autor_tono.json');
const rutaClasico = path.join(raiz, 'assets', 'data', 'clasico.json');
const soloRevisar = process.argv.includes('--revisar');

// Errores de tipeo seguros en los nombres de autor. Las iniciales dudosas
// (p. ej. "C. H. Gabriel" / "C. A. Gabriel") NO se tocan: hay que verlas
// en la partitura.
const CORRECCIONES_AUTOR = {
  'Jorque C. Stebbins': 'Jorge C. Stebbins',
  'Luwding van Beethoven': 'Ludwig van Beethoven',
  'L. Van Beethoven': 'L. van Beethoven',
  'Feliz Mendelssohn-Bartholdy': 'Félix Mendelssohn-Bartholdy',
  'L. Masón': 'L. Mason',
  'Melodía arreglada por L. Masón': 'Melodía arreglada por L. Mason',
  'Juan Marron': 'Juan Marrón',
  'Melodía inglesia': 'Melodía inglesa',
  'Melodía arregalda por Samuel Dyer': 'Melodía arreglada por Samuel Dyer',
  'Franz Cruber': 'Franz Gruber',
};

// Correcciones de título en clasico.json (el dato original estaba mal).
const CORRECCIONES_TITULO = {
  541: 'Oh Señor, procuro en vano', // decía "Canten con alegría" (es el 542)
};

const limpiar = (s) => String(s ?? '').replace(/\s+/g, ' ').trim();

const fuente = JSON.parse(fs.readFileSync(rutaFuente, 'utf8'));
const textoClasico = fs.readFileSync(rutaClasico, 'utf8');
const clasico = JSON.parse(textoClasico);
const porNumero = new Map(clasico.himnos.map((h) => [h.n, h]));

const informe = {
  fusionados: 0,
  autorDesconocido: 0,
  autoresCorregidos: 0,
  titulosLimpiados: 0,
  titulosCorregidos: 0,
  sinDatos: [],
  noExisten: [],
};

// 1) Títulos: saltos de línea / espacios dobles y correcciones puntuales.
for (const h of clasico.himnos) {
  const corregido = CORRECCIONES_TITULO[h.n];
  if (corregido && h.t !== corregido) {
    h.t = corregido;
    informe.titulosCorregidos++;
  }
  const limpio = limpiar(h.t);
  if (limpio !== h.t) {
    h.t = limpio;
    informe.titulosLimpiados++;
  }
}

// 2) Autor, tonalidad, compás y créditos.
for (const r of fuente) {
  const h = porNumero.get(r.numero);
  if (!h) {
    informe.noExisten.push(r.numero);
    continue;
  }
  let autor = limpiar(r.autor);
  const desconocido =
    r.estado_autor !== 'indicado en la partitura' ||
    /^(desconocido|no indicado)$/i.test(autor);
  if (desconocido) {
    autor = 'Desconocido';
    informe.autorDesconocido++;
  } else if (CORRECCIONES_AUTOR[autor]) {
    autor = CORRECCIONES_AUTOR[autor];
    informe.autoresCorregidos++;
  }
  h.autor = autor;
  if (r.tonalidad) h.tono = limpiar(r.tonalidad);
  if (r.compas) h.compas = limpiar(r.compas);
  const creditos = (r.creditos_adicionales ?? []).map(limpiar).filter(Boolean);
  if (creditos.length) h.creditos = creditos;
  else delete h.creditos;
  const modula = (r.modulaciones ?? []).map((m) => limpiar(m.tonalidad)).filter(Boolean);
  if (modula.length) h.modula = modula;
  else delete h.modula;
  informe.fusionados++;
}
const conDatos = new Set(fuente.map((r) => r.numero));
informe.sinDatos = clasico.himnos.filter((h) => !conDatos.has(h.n)).map((h) => h.n);

// Orden de campos estable en cada himno (más fácil de revisar en git).
const ORDEN = ['n', 't', 'cat', 'autor', 'tono', 'compas', 'modula', 'creditos', 'estrofas', 'coro', 'cita', 'versiculo'];
clasico.himnos = clasico.himnos.map((h) => {
  const o = {};
  for (const k of ORDEN) if (h[k] !== undefined) o[k] = h[k];
  for (const k of Object.keys(h)) if (!(k in o)) o[k] = h[k];
  return o;
});

const rango = (ns) => {
  if (!ns.length) return 'ninguno';
  return `${ns.length} (${ns[0]}–${ns[ns.length - 1]})`;
};
console.log('Himnos con autor/tono/compás:', informe.fusionados);
console.log('  con autor "Desconocido":   ', informe.autorDesconocido);
console.log('  nombres de autor corregidos:', informe.autoresCorregidos);
console.log('Títulos corregidos:           ', informe.titulosCorregidos);
console.log('Títulos con saltos limpiados: ', informe.titulosLimpiados);
console.log('Himnos aún sin datos:         ', rango(informe.sinDatos));
if (informe.noExisten.length) console.log('¡Números que no existen!', informe.noExisten);

if (soloRevisar) {
  console.log('\n(--revisar: no se escribió nada)');
} else {
  // Se conserva el formato del archivo original (minificado o no).
  const minificado = !textoClasico.includes('\n ');
  fs.writeFileSync(rutaClasico, minificado ? JSON.stringify(clasico) : JSON.stringify(clasico, null, 1));
  console.log('\nEscrito:', path.relative(raiz, rutaClasico));
}
