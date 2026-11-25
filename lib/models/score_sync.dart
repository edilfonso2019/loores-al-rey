/// Sincronización partitura ↔ audio, marcada a mano ("modo marcar").
///
/// Mientras suena la pista, quien marca toca el inicio de cada renglón de
/// la partitura. Cada toque guarda el instante y la posición en la página
/// (en fracciones 0..1, así no depende del tamaño de la pantalla). Si la
/// pista toca varias estrofas, se vuelve a tocar el primer renglón.
class SyncMark {
  /// Milisegundos desde el inicio de la pista.
  final int ms;

  /// Página (0 = primera).
  final int page;

  /// Posición del toque en la página, 0..1.
  final double x;
  final double y;

  const SyncMark({
    required this.ms,
    required this.page,
    required this.x,
    required this.y,
  });

  factory SyncMark.fromJson(Map<String, dynamic> j) => SyncMark(
    ms: (j['t'] as num).toInt(),
    page: (j['p'] as num?)?.toInt() ?? 0,
    x: (j['x'] as num).toDouble(),
    y: (j['y'] as num).toDouble(),
  );

  /// Compacto: se comparte y se guarda en el respaldo.
  Map<String, dynamic> toJson() => {
    't': ms,
    'p': page,
    'x': double.parse(x.toStringAsFixed(4)),
    'y': double.parse(y.toStringAsFixed(4)),
  };
}

/// Dónde dibujar la rayita: página, posición horizontal y alto (0..1).
class CursorPos {
  final int page;
  final double x;
  final double top;
  final double bottom;

  /// Índice de la marca (renglón) actual; cambia al pasar de renglón.
  final int mark;

  const CursorPos({
    required this.page,
    required this.x,
    required this.top,
    required this.bottom,
    required this.mark,
  });
}

class ScoreSync {
  /// Dos toques a menos de esta distancia vertical son el mismo renglón.
  static const sameLine = 0.04;

  /// Margen derecho de la partitura (fin de cada renglón).
  static const rightEdge = 0.96;

  /// Alto supuesto de un renglón si la página tiene uno solo marcado.
  static const defaultLine = 0.16;

  /// Posición de la rayita en el instante [pos]. null antes de la primera
  /// marca (introducción) o si no hay marcas.
  static CursorPos? at(List<SyncMark> marks, Duration pos, {Duration? total}) {
    if (marks.isEmpty) return null;
    final ms = pos.inMilliseconds;
    if (ms < marks.first.ms) return null;
    var i = 0;
    while (i + 1 < marks.length && marks[i + 1].ms <= ms) {
      i++;
    }
    final m = marks[i];
    final next = i + 1 < marks.length ? marks[i + 1] : null;

    // Hasta cuándo dura este renglón y hasta dónde llega la rayita.
    final endMs =
        next?.ms ??
        (total != null && total.inMilliseconds > m.ms
            ? total.inMilliseconds
            : m.ms + 8000);
    final sameRow =
        next != null &&
        next.page == m.page &&
        (next.y - m.y).abs() < sameLine &&
        next.x > m.x;
    final endX = sameRow ? next.x : rightEdge;

    final span = (endMs - m.ms).clamp(1, 1 << 30);
    final t = ((ms - m.ms) / span).clamp(0.0, 1.0);
    final x = m.x + (endX - m.x) * t;

    final half = lineHeight(marks, m) / 2;
    return CursorPos(
      page: m.page,
      x: x,
      top: (m.y - half).clamp(0.0, 1.0),
      bottom: (m.y + half).clamp(0.0, 1.0),
      mark: i,
    );
  }

  /// Alto del renglón de [m], según la distancia a los renglones vecinos
  /// marcados en la misma página.
  static double lineHeight(List<SyncMark> marks, SyncMark m) {
    final rows = <double>[];
    for (final o in marks) {
      if (o.page != m.page) continue;
      if (rows.every((r) => (r - o.y).abs() >= sameLine)) rows.add(o.y);
    }
    rows.sort();
    var gap = double.infinity;
    for (final r in rows) {
      final d = (r - m.y).abs();
      if (d >= sameLine && d < gap) gap = d;
    }
    return gap.isFinite ? gap * 0.9 : defaultLine;
  }

  /// Clave de almacenamiento: "clasico-131-instrumental".
  static String key(String hymnId, String kind) => '$hymnId-$kind';
}
