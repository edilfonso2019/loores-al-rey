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

  const Hymnal({
    required this.id,
    required this.nombre,
    required this.activo,
    required this.categorias,
    required this.himnos,
    this.servidor,
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
    );
  }
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

  /// Opcionales (aún no vienen en el JSON): autor y tonalidad "Fa M 4/4".
  final String? autor;
  final String? tono;

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
  );
}

class Verse {
  final String text;
  final bool isChorus;

  /// Número de estrofa (null para el coro).
  final int? number;

  const Verse({required this.text, this.isChorus = false, this.number});
}
