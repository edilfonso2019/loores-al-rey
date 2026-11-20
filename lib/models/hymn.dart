import '../config.dart';

/// Un himnario completo (`assets/data/<id>.json`).
class Hymnal {
  final String id;
  final String nombre;

  /// Si es `false` la app lo muestra como "Próximamente".
  final bool activo;
  final List<String> categorias;
  final List<Hymn> himnos;
  final ServerConfig? servidor;

  /// Agrupación de temáticas para el índice (opcional en el JSON).
  final List<Section> secciones;

  const Hymnal({
    required this.id,
    required this.nombre,
    required this.activo,
    required this.categorias,
    required this.himnos,
    this.servidor,
    this.secciones = const [],
  });

  /// Letra corta para listas: "(C)" para Clásico, "(CG)" para CG.
  String get sigla => id == 'clasico' ? 'C' : id.toUpperCase();

  /// Nombre corto: "Clásico", "CG".
  String get nombreCorto => nombre.replaceFirst('Himnario ', '');

  factory Hymnal.fromJson(Map<String, dynamic> json) {
    final id = json['id'] as String;
    final servidorJson = json['servidor'] as Map<String, dynamic>?;
    return Hymnal(
      id: id,
      nombre: json['nombre'] as String,
      activo: json['activo'] as bool? ?? false,
      categorias: List<String>.from(json['categorias'] as List? ?? const []),
      himnos:
          (json['himnos'] as List? ?? const [])
              .map((e) => Hymn.fromJson(id, e as Map<String, dynamic>))
              .toList()
            ..sort((a, b) => a.number.compareTo(b.number)),
      servidor: servidorJson != null
          ? ServerConfig.fromJson(servidorJson)
          : kServidores[id],
      secciones: (json['secciones'] as List? ?? const [])
          .map((e) => Section.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

/// Sección del índice: agrupa las temáticas [desde]..[hasta] (índices de
/// `categorias`, inclusive). Ej. "Jesucristo" agrupa "Su primer advenimiento"…
class Section {
  final String nombre;
  final int desde;
  final int hasta;
  const Section({
    required this.nombre,
    required this.desde,
    required this.hasta,
  });

  factory Section.fromJson(Map<String, dynamic> json) => Section(
    nombre: json['nombre'] as String,
    desde: json['desde'] as int,
    hasta: json['hasta'] as int,
  );
}

/// Una temática con sus himnos (para el índice).
class Topic {
  final int index;
  final String name;
  final List<Hymn> hymns;
  const Topic({required this.index, required this.name, required this.hymns});

  int get first => hymns.first.number;
  int get last => hymns.last.number;

  /// "1–24" o "512" si es uno solo.
  String get range => first == last ? '$first' : '$first–$last';
}

/// Grupo del índice: una sección y sus temáticas.
class TopicGroup {
  final String? name; // null = sin secciones definidas
  final List<Topic> topics;
  const TopicGroup({required this.name, required this.topics});

  int get hymnCount => topics.fold(0, (a, t) => a + t.hymns.length);
}

/// Un himno. `estrofas` en orden; `coro` (si existe) se canta después de
/// cada estrofa.
class Hymn {
  final String book;
  final int number;
  final String title;
  final int? categoryIndex;
  final List<String> estrofas;
  final String? coro;
  final String? cita;
  final String? versiculo;

  /// Datos de la partitura (opcionales; aún faltan algunos himnos).
  /// [autor] es "Desconocido" si la partitura no lo indica.
  final String? autor;

  /// Tonalidad, ej. "Si bemol mayor".
  final String? tono;

  /// Compás, ej. "4/4".
  final String? compas;

  /// Tonalidades a las que modula (raro), ej. ["Sol mayor"].
  final List<String> modula;

  /// Arreglo, traducción, etc. Ej. "Traducción por W. R. Adell".
  final List<String> creditos;

  const Hymn({
    required this.book,
    required this.number,
    required this.title,
    required this.estrofas,
    this.categoryIndex,
    this.coro,
    this.cita,
    this.versiculo,
    this.autor,
    this.tono,
    this.compas,
    this.modula = const [],
    this.creditos = const [],
  });

  String get id => '$book-$number';

  bool get hasChorus => coro != null && coro!.trim().isNotEmpty;

  /// Estrofas y coros en el orden en que se cantan.
  List<Verse> get verses {
    final out = <Verse>[];
    for (var i = 0; i < estrofas.length; i++) {
      out.add(Verse(text: estrofas[i], number: i + 1));
      if (hasChorus) out.add(Verse(text: coro!, isChorus: true));
    }
    return out;
  }

  /// Primera línea de la letra (para resultados de búsqueda).
  String get firstLine =>
      estrofas.isEmpty ? '' : estrofas.first.split('\n').first.trim();

  String get fullText => [...estrofas, if (hasChorus) coro!].join('\n\n');

  bool get hasScoreData => autor != null || tono != null || compas != null;

  /// "Juan Hatton", "Autor desconocido" o null si no hay datos.
  String? get autorMostrado => autor == null
      ? null
      : (autor == 'Desconocido' ? 'Autor desconocido' : autor);

  /// Versión corta, como en la partitura: "Si♭ M · 4/4".
  String? get tonoCorto => _tonoCompas(abreviar(tono));

  /// Versión completa: "Si bemol mayor · 4/4".
  String? get tonoLargo => _tonoCompas(tono);

  String? _tonoCompas(String? t) {
    final parts = [?t, ?compas];
    return parts.isEmpty ? null : parts.join(' · ');
  }

  /// "Si bemol mayor" → "Si♭ M"; "Do sostenido menor" → "Do♯ m".
  static String? abreviar(String? tono) {
    if (tono == null) return null;
    return tono
        .replaceAll(' bemol', '♭')
        .replaceAll(' sostenido', '♯')
        .replaceAll(RegExp(r' mayor$'), ' M')
        .replaceAll(RegExp(r' menor$'), ' m');
  }

  factory Hymn.fromJson(String book, Map<String, dynamic> json) => Hymn(
    book: book,
    number: json['n'] as int,
    title: (json['t'] as String).trim(),
    categoryIndex: json['cat'] as int?,
    estrofas: List<String>.from(json['estrofas'] as List),
    coro: json['coro'] as String?,
    cita: json['cita'] as String?,
    versiculo: json['versiculo'] as String?,
    autor: json['autor'] as String?,
    tono: json['tono'] as String?,
    compas: json['compas'] as String?,
    modula: List<String>.from(json['modula'] as List? ?? const []),
    creditos: List<String>.from(json['creditos'] as List? ?? const []),
  );
}

class Verse {
  final String text;
  final bool isChorus;

  /// Número de estrofa (null para el coro).
  final int? number;

  const Verse({required this.text, this.isChorus = false, this.number});
}
