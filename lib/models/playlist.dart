/// Lista de culto: nombre + himnos en orden ("clasico-131", ...).
class Playlist {
  final String id;
  String name;
  final List<String> items;

  Playlist({required this.id, required this.name, List<String>? items})
      : items = items ?? [];

  factory Playlist.fromJson(Map<String, dynamic> json) => Playlist(
        id: json['id'] as String,
        name: json['name'] as String,
        items: List<String>.from(json['items'] as List? ?? const []),
      );

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'items': items};
}
