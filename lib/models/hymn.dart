/// Modelo de himno. Cada himno pertenece a un himnario (`book`):
/// - `nuevo`  → Himnario Adventista 2010 (613 himnos)
/// - `antiguo` → Himnario Adventista 1962 (525 himnos)
class Hymn {
  final String book;
  final int number;
  final String title;

  /// Estrofas en orden. El coro se marca con `isChorus = true`.
  final List<Verse> verses;

  /// Categoría/sección del himnario (ej. "Adoración y alabanza").
  final String? category;

  /// Ruta o URL de audio instrumental (opcional, se descarga bajo demanda).
  final String? audioUrl;

  const Hymn({
    required this.book,
    required this.number,
    required this.title,
    required this.verses,
    this.category,
    this.audioUrl,
  });

  String get id => '$book-$number';

  String get fullText => verses.map((v) => v.text).join('\n\n');

  factory Hymn.fromJson(Map<String, dynamic> json) => Hymn(
        book: json['book'] as String,
        number: json['number'] as int,
        title: json['title'] as String,
        category: json['category'] as String?,
        audioUrl: json['audioUrl'] as String?,
        verses: (json['verses'] as List)
            .map((v) => Verse.fromJson(v as Map<String, dynamic>))
            .toList(),
      );

  Map<String, dynamic> toJson() => {
        'book': book,
        'number': number,
        'title': title,
        if (category != null) 'category': category,
        if (audioUrl != null) 'audioUrl': audioUrl,
        'verses': verses.map((v) => v.toJson()).toList(),
      };
}

class Verse {
  final String text;
  final bool isChorus;

  const Verse({required this.text, this.isChorus = false});

  factory Verse.fromJson(Map<String, dynamic> json) => Verse(
        text: json['text'] as String,
        isChorus: json['chorus'] as bool? ?? false,
      );

  Map<String, dynamic> toJson() => {
        'text': text,
        if (isChorus) 'chorus': true,
      };
}
