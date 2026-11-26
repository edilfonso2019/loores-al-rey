/// Acordes sincronizados de un himno (`assets/data/acordes.json`).
///
/// Los acordes salen de la partitura (exactos) y los tiempos de la IA que
/// escuchó la pista instrumental (ver `tools/acordes/`). Antes del primer
/// acorde de la partitura (la introducción) se usa lo que oyó la IA.
library;

/// Una sílaba de la letra con los acordes que lleva encima.
class ChordSyllable {
  /// Segundo en que se canta.
  final double t;
  final String text;

  /// La siguiente sílaba es de la misma palabra (no hay espacio).
  final bool joinNext;
  final List<String> chords;
  const ChordSyllable(this.t, this.text, this.joinNext, this.chords);
}

/// Un renglón de la letra (de una estrofa o del coro).
class ChordLine {
  final bool chorus;
  final int stanza;
  final List<ChordSyllable> syllables;
  const ChordLine(this.chorus, this.stanza, this.syllables);

  double get start => syllables.isEmpty ? 0 : syllables.first.t;
  String get header => chorus ? 'Coro' : 'Estrofa $stanza';
}

/// Un acorde de la partitura con su tiempo y su lugar en la página (0..1).
class ChordEvent {
  final double? t;
  final String chord;
  final int page;
  final double x;
  final double y;
  const ChordEvent(this.t, this.chord, this.page, this.x, this.y);
}

class HymnChords {
  final int? tempo;
  final String meter;

  /// Onda de la pista: [peaksPerSecond] valores por segundo, 0..1.
  final List<double> peaks;
  final int peaksPerSecond;

  /// Un pulso por beat: (segundo, acorde que oyó la IA o null).
  final List<(double, String?)> beats;
  final List<ChordLine> lines;
  final List<ChordEvent> events;

  /// Acordes en el tiempo (partitura cuando hay; antes, la IA), sin repetir.
  late final List<(double, String)> timeline = _buildTimeline();

  HymnChords({
    required this.tempo,
    required this.meter,
    required this.peaks,
    required this.peaksPerSecond,
    required this.beats,
    required this.lines,
    required this.events,
  });

  bool get hasLyrics => lines.isNotEmpty;

  int get beatsPerBar => int.tryParse(meter.split('/').first) ?? 4;

  factory HymnChords.fromJson(Map<String, dynamic> j) {
    double d(Object? v) => (v as num).toDouble();
    return HymnChords(
      tempo: (j['tempo'] as num?)?.toInt(),
      meter: j['compas'] as String? ?? '4/4',
      peaksPerSecond: (j['pps'] as num?)?.toInt() ?? 10,
      peaks: [for (final p in j['picos'] as List) d(p) / 100],
      beats: [
        for (final b in j['pulsos'] as List)
          (d((b as List)[0]), b[1] as String?),
      ],
      lines: [
        for (final l in j['lineas'] as List? ?? const [])
          ChordLine(
            (l as Map<String, dynamic>)['coro'] == 1,
            (l['e'] as num).toInt(),
            [
              for (final s in l['s'] as List)
                ChordSyllable(
                  d((s as List)[0]),
                  s[1] as String,
                  s[2] == 1,
                  List<String>.from(s[3] as List),
                ),
            ],
          ),
      ],
      events: [
        for (final e in j['eventos'] as List? ?? const [])
          ChordEvent(
            (e as List)[0] == null ? null : d(e[0]),
            e[1] as String,
            (e[2] as num).toInt(),
            d(e[3]),
            d(e[4]),
          ),
      ],
    );
  }

  List<(double, String)> _buildTimeline() {
    final fromScore = [
      for (final e in events)
        if (e.t != null) (e.t!, e.chord),
    ]..sort((a, b) => a.$1.compareTo(b.$1));
    final first = fromScore.isEmpty ? double.infinity : fromScore.first.$1;
    final out = <(double, String)>[];
    for (final (t, c) in beats) {
      if (t >= first) break;
      if (c != null && (out.isEmpty || out.last.$2 != c)) out.add((t, c));
    }
    for (final e in fromScore) {
      if (out.isEmpty || out.last.$2 != e.$2) out.add(e);
    }
    return out;
  }

  /// Índice del último elemento de [list] con tiempo <= [t] (-1 si ninguno).
  static int indexAt<T>(List<T> list, double Function(T) time, double t) {
    var lo = 0, hi = list.length - 1, k = -1;
    while (lo <= hi) {
      final m = (lo + hi) >> 1;
      if (time(list[m]) <= t) {
        k = m;
        lo = m + 1;
      } else {
        hi = m - 1;
      }
    }
    return k;
  }

  /// Acorde que suena en [t] (índice en [timeline]).
  int chordIndexAt(double t) => indexAt(timeline, (e) => e.$1, t);

  /// Renglón que se canta en [t] (-1 en la introducción).
  int lineAt(double t) => indexAt(lines, (l) => l.start, t + 0.15);

  /// Evento de la partitura que suena en [t] (-1 antes del primero).
  int eventAt(double t) {
    var k = -1;
    for (var i = 0; i < events.length; i++) {
      final et = events[i].t;
      if (et != null && et <= t + 0.05) k = i;
    }
    return k;
  }
}

// ---------------------------------------------------------------------------
// Nombres, transporte y calidad.
// ---------------------------------------------------------------------------

/// Un acorde descompuesto: fundamental (0 = Do), calidad normalizada y bajo.
class Chord {
  final int root;

  /// '', 'm', '7', 'm7', 'maj7', 'dim', 'm7b5', 'sus4'.
  final String quality;
  final int? bass;
  const Chord(this.root, this.quality, [this.bass]);

  static const _pc = {
    'C': 0, 'C#': 1, 'Db': 1, 'D': 2, 'D#': 3, 'Eb': 3, 'E': 4, 'F': 5, //
    'F#': 6, 'Gb': 6, 'G': 7, 'G#': 8, 'Ab': 8, 'A': 9, 'A#': 10, 'Bb': 10,
    'B': 11, 'Cb': 11,
  };
  static final _re = RegExp(r'^([A-G][#b]?)([^/]*)(?:/([A-G][#b]?))?');

  /// "Ab7/C", "Em/G", "Bb7-9", "Ab4sus", "F#m". Null si no se entiende.
  static Chord? parse(String s) {
    final m = _re.firstMatch(s.trim());
    if (m == null) return null;
    final root = _pc[m[1]];
    if (root == null) return null;
    return Chord(root, normalizeQuality(m[2] ?? ''), _pc[m[3]]);
  }

  static String normalizeQuality(String q) {
    if (q.startsWith('maj7')) return 'maj7';
    if (q.startsWith('m7b5') || q.startsWith('ø')) return 'm7b5';
    if (q.startsWith('dim') || q.startsWith('º') || q.startsWith('°')) {
      return 'dim';
    }
    if (q.startsWith('m7')) return 'm7';
    if (q.startsWith('m') && !q.startsWith('maj')) return 'm';
    if (q.contains('sus')) return q.startsWith('7') ? '7' : 'sus4';
    if (RegExp(r'^(7|9|11|13)').hasMatch(q)) return '7';
    return '';
  }

  /// Solo mayor / menor / disminuido (modo "Básico").
  static const _basic = {
    '': '', 'm': 'm', '7': '', 'm7': 'm', 'maj7': '', 'dim': 'dim', //
    'm7b5': 'dim', 'sus4': '',
  };

  Chord simplified() => Chord(root, _basic[quality] ?? '');

  Chord transposed(int semitones) => Chord(
    (root + semitones) % 12,
    quality,
    bass == null ? null : (bass! + semitones) % 12,
  );

  bool get isMinor => quality.startsWith('m') && !quality.startsWith('maj');
}

/// Cómo se escriben los acordes en pantalla.
class ChordStyle {
  /// Solo mayor/menor (sin 7, sin bajo).
  final bool basic;

  /// Do Re Mi en vez de C D E.
  final bool latin;

  /// Semitonos que se transporta (tono del audio − capo).
  final int shift;

  /// Escribir con bemoles (Bb) en vez de sostenidos (A#).
  final bool flats;

  const ChordStyle({
    this.basic = true,
    this.latin = false,
    this.shift = 0,
    this.flats = false,
  });

  static const _sharp = [
    'C', 'C#', 'D', 'D#', 'E', 'F', 'F#', 'G', 'G#', 'A', 'A#', 'B', //
  ];
  static const _flat = [
    'C', 'Db', 'D', 'Eb', 'E', 'F', 'Gb', 'G', 'Ab', 'A', 'Bb', 'B', //
  ];
  static const _latin = {
    'C': 'Do', 'D': 'Re', 'E': 'Mi', 'F': 'Fa', 'G': 'Sol', 'A': 'La', //
    'B': 'Si',
  };

  String note(int pc) {
    final n = (flats ? _flat : _sharp)[pc % 12];
    return latin ? '${_latin[n[0]]}${n.substring(1)}' : n;
  }

  /// Acorde ya transportado y simplificado según el estilo.
  Chord? apply(String raw) {
    final c = Chord.parse(raw)?.transposed(shift);
    if (c == null) return null;
    return basic ? c.simplified() : c;
  }

  String label(String raw) {
    final c = apply(raw);
    if (c == null) return raw;
    final bass = !basic && c.bass != null ? '/${note(c.bass!)}' : '';
    return '${note(c.root)}${c.quality}$bass';
  }

  /// Bemoles si la tonalidad (mayor relativa) los usa: Fa, Sib, Mib, Lab, Reb, Solb.
  static bool keyUsesFlats(Chord tonic) {
    final major = tonic.isMinor ? (tonic.root + 3) % 12 : tonic.root;
    return const {5, 10, 3, 8, 1, 6}.contains(major);
  }
}

// ---------------------------------------------------------------------------
// Formas de guitarra.
// ---------------------------------------------------------------------------

/// Cómo se pone un acorde: traste por cuerda (6ª→1ª; -1 = no se toca,
/// 0 = al aire), dedo por cuerda (0 = ninguno) y cejilla (traste, 0 = sin).
class GuitarShape {
  final List<int> frets;
  final List<int> fingers;
  final int barre;
  const GuitarShape(this.frets, this.fingers, [this.barre = 0]);

  /// Primer traste que se dibuja (1 si todo cabe en los primeros 4).
  int get baseFret {
    final pressed = frets.where((f) => f > 0);
    if (pressed.isEmpty) return 1;
    final max = pressed.reduce((a, b) => a > b ? a : b);
    return max > 4 ? pressed.reduce((a, b) => a < b ? a : b) : 1;
  }

  bool get isOpen => barre == 0;

  static const _open = <String, GuitarShape>{
    '0': GuitarShape([-1, 3, 2, 0, 1, 0], [0, 3, 2, 0, 1, 0]),
    '0|7': GuitarShape([-1, 3, 2, 3, 1, 0], [0, 3, 2, 4, 1, 0]),
    '0|maj7': GuitarShape([-1, 3, 2, 0, 0, 0], [0, 3, 2, 0, 0, 0]),
    '2': GuitarShape([-1, -1, 0, 2, 3, 2], [0, 0, 0, 1, 3, 2]),
    '2|m': GuitarShape([-1, -1, 0, 2, 3, 1], [0, 0, 0, 2, 3, 1]),
    '2|7': GuitarShape([-1, -1, 0, 2, 1, 2], [0, 0, 0, 2, 1, 3]),
    '2|m7': GuitarShape([-1, -1, 0, 2, 1, 1], [0, 0, 0, 2, 1, 1]),
    '2|maj7': GuitarShape([-1, -1, 0, 2, 2, 2], [0, 0, 0, 1, 2, 3]),
    '2|sus4': GuitarShape([-1, -1, 0, 2, 3, 3], [0, 0, 0, 1, 3, 4]),
    '4': GuitarShape([0, 2, 2, 1, 0, 0], [0, 2, 3, 1, 0, 0]),
    '4|m': GuitarShape([0, 2, 2, 0, 0, 0], [0, 2, 3, 0, 0, 0]),
    '4|7': GuitarShape([0, 2, 0, 1, 0, 0], [0, 2, 0, 1, 0, 0]),
    '4|m7': GuitarShape([0, 2, 0, 0, 0, 0], [0, 2, 0, 0, 0, 0]),
    '4|sus4': GuitarShape([0, 2, 2, 2, 0, 0], [0, 2, 3, 4, 0, 0]),
    '7': GuitarShape([3, 2, 0, 0, 0, 3], [2, 1, 0, 0, 0, 3]),
    '7|7': GuitarShape([3, 2, 0, 0, 0, 1], [3, 2, 0, 0, 0, 1]),
    '7|maj7': GuitarShape([3, 2, 0, 0, 0, 2], [3, 2, 0, 0, 0, 1]),
    '9': GuitarShape([-1, 0, 2, 2, 2, 0], [0, 0, 1, 2, 3, 0]),
    '9|m': GuitarShape([-1, 0, 2, 2, 1, 0], [0, 0, 2, 3, 1, 0]),
    '9|7': GuitarShape([-1, 0, 2, 0, 2, 0], [0, 0, 2, 0, 3, 0]),
    '9|m7': GuitarShape([-1, 0, 2, 0, 1, 0], [0, 0, 2, 0, 1, 0]),
    '9|maj7': GuitarShape([-1, 0, 2, 1, 2, 0], [0, 0, 2, 1, 3, 0]),
    '9|sus4': GuitarShape([-1, 0, 2, 2, 3, 0], [0, 0, 1, 2, 3, 0]),
    '11|7': GuitarShape([-1, 2, 1, 2, 0, 2], [0, 2, 1, 3, 0, 4]),
  };

  /// Formas con cejilla: (trastes relativos, dedos). Raíz en 6ª (E) o 5ª (A).
  static const _eShape = <String, (List<int>, List<int>)>{
    '': ([0, 2, 2, 1, 0, 0], [1, 3, 4, 2, 1, 1]),
    'm': ([0, 2, 2, 0, 0, 0], [1, 3, 4, 1, 1, 1]),
    '7': ([0, 2, 0, 1, 0, 0], [1, 3, 1, 2, 1, 1]),
    'm7': ([0, 2, 0, 0, 0, 0], [1, 3, 1, 1, 1, 1]),
    'maj7': ([0, -1, 1, 1, 0, -1], [1, 0, 3, 4, 2, 0]),
    'sus4': ([0, 2, 2, 2, 0, 0], [1, 2, 3, 4, 1, 1]),
  };
  static const _aShape = <String, (List<int>, List<int>)>{
    '': ([-1, 0, 2, 2, 2, 0], [0, 1, 3, 3, 3, 1]),
    'm': ([-1, 0, 2, 2, 1, 0], [0, 1, 3, 4, 2, 1]),
    '7': ([-1, 0, 2, 0, 2, 0], [0, 1, 3, 1, 4, 1]),
    'm7': ([-1, 0, 2, 0, 1, 0], [0, 1, 3, 1, 2, 1]),
    'maj7': ([-1, 0, 2, 1, 2, 0], [0, 1, 3, 2, 4, 1]),
    'sus4': ([-1, 0, 2, 2, 3, 0], [0, 1, 2, 3, 4, 1]),
    'dim': ([-1, 0, 1, 2, 1, -1], [0, 1, 2, 4, 3, 0]),
    'm7b5': ([-1, 0, 1, 0, 1, -1], [0, 1, 3, 2, 4, 0]),
  };

  /// Forma abierta si existe; si no, la cejilla en el traste más bajo.
  static GuitarShape of(Chord c) {
    final q = c.quality;
    final open = _open[q.isEmpty ? '${c.root}' : '${c.root}|$q'];
    if (open != null) return open;
    final options = <(int, (List<int>, List<int>))>[];
    for (final (table, base) in [(_eShape, 4), (_aShape, 9)]) {
      final s = table[q];
      if (s == null) continue;
      var fret = (c.root - base) % 12;
      if (fret == 0) fret = 12;
      options.add((fret, s));
    }
    if (options.isEmpty) return of(Chord(c.root, c.isMinor ? 'm' : ''));
    options.sort((a, b) => a.$1.compareTo(b.$1));
    final (fret, (rel, fingers)) = options.first;
    return GuitarShape(
      [for (final r in rel) r < 0 ? -1 : r + fret],
      fingers,
      fret,
    );
  }

  /// Si existe una forma abierta (sin cejilla) para [c].
  static bool hasOpen(Chord c) => _open.containsKey(
    c.quality.isEmpty ? '${c.root}' : '${c.root}|${c.quality}',
  );
}

/// Capo que deja menos cejillas para tocar [chords] (0..5; ante empate, el más bajo).
int suggestedCapo(Iterable<String> chords, {bool basic = true}) {
  final parsed = [
    for (final s in chords)
      if (Chord.parse(s) case final c?) basic ? c.simplified() : c,
  ];
  var best = 0, min = 1 << 30;
  for (var capo = 0; capo <= 5; capo++) {
    var barres = 0;
    for (final c in parsed) {
      if (!GuitarShape.hasOpen(c.transposed(-capo))) barres++;
    }
    if (barres < min) {
      min = barres;
      best = capo;
    }
  }
  return best;
}
