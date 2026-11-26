import 'dart:convert';

import 'package:flutter/services.dart';

import '../config.dart';
import '../models/hymn.dart';

/// Carga los himnarios desde `assets/data/*.json` y expone búsqueda offline.
class HymnRepository {
  HymnRepository._();
  static final HymnRepository instance = HymnRepository._();

  /// Ids de himnario en el orden en que se muestran.
  static const ids = ['clasico', 'cg'];

  final Map<String, Hymnal> _hymnals = {};
  final Map<String, String> _searchIndex = {};
  bool _loaded = false;

  Future<void> load({AssetBundle? bundle}) async {
    if (_loaded) return;
    final b = bundle ?? rootBundle;
    for (final id in ids) {
      final raw = await b.loadString('${kAssetPrefix}assets/data/$id.json');
      final hymnal = Hymnal.fromJson(jsonDecode(raw) as Map<String, dynamic>);
      _hymnals[id] = hymnal;
      for (final h in hymnal.himnos) {
        _searchIndex[h.id] = normalize('${h.title}\n${h.fullText}');
      }
    }
    _loaded = true;
  }

  /// Todos los himnarios (activos o no).
  List<Hymnal> get hymnals => [for (final id in ids) ?_hymnals[id]];

  /// Solo los himnarios activos.
  List<Hymnal> get activeHymnals => hymnals.where((h) => h.activo).toList();

  Hymnal? hymnal(String id) => _hymnals[id];

  List<Hymn> byBook(String book) => _hymnals[book]?.himnos ?? const [];

  Hymn? find(String book, int number) {
    final list = byBook(book);
    // Los himnos vienen ordenados y casi siempre n == índice + 1.
    if (number >= 1 &&
        number <= list.length &&
        list[number - 1].number == number) {
      return list[number - 1];
    }
    for (final h in list) {
      if (h.number == number) return h;
    }
    return null;
  }

  /// Resuelve ids "libro-numero" (ej. "clasico-131").
  Hymn? byId(String id) {
    final i = id.lastIndexOf('-');
    if (i <= 0) return null;
    return find(id.substring(0, i), int.tryParse(id.substring(i + 1)) ?? -1);
  }

  /// Himno siguiente/anterior dentro del mismo himnario.
  Hymn? neighbor(Hymn h, int delta) {
    final list = byBook(h.book);
    final i = list.indexOf(h);
    if (i < 0) return null;
    final j = i + delta;
    return j >= 0 && j < list.length ? list[j] : null;
  }

  String categoryName(Hymn h) {
    final cats = _hymnals[h.book]?.categorias ?? const [];
    final i = h.categoryIndex;
    return i != null && i >= 0 && i < cats.length ? cats[i] : '';
  }

  /// Busca por número, título o letra (sin tildes ni mayúsculas).
  ///
  /// [book] `null` = todos los himnarios activos. [category] filtra por
  /// nombre de temática.
  List<Hymn> search(String query, {String? book, String? category}) {
    final q = normalize(query.trim());
    final books = book == null
        ? activeHymnals.map((h) => h.id)
        : [if (_hymnals[book]?.activo ?? false) book];
    final asNumber = int.tryParse(q);
    final byNumber = <Hymn>[];
    final byTitle = <Hymn>[];
    final byText = <Hymn>[];
    for (final b in books) {
      for (final h in byBook(b)) {
        if (category != null && categoryName(h) != category) continue;
        if (q.isEmpty) {
          byNumber.add(h);
        } else if (asNumber != null) {
          if (h.number == asNumber) {
            byNumber.insert(0, h);
          } else if (h.number.toString().startsWith(q)) {
            byNumber.add(h);
          }
        } else if (normalize(h.title).contains(q)) {
          byTitle.add(h);
        } else if (_searchIndex[h.id]!.contains(q)) {
          byText.add(h);
        }
      }
    }
    return [...byNumber, ...byTitle, ...byText];
  }

  /// Índice por temática de [book]: secciones con sus temáticas y himnos.
  /// Omite temáticas sin himnos. Si el JSON no trae `secciones`, devuelve
  /// un solo grupo sin nombre.
  List<TopicGroup> topicIndex(String book) {
    final hymnal = _hymnals[book];
    if (hymnal == null) return const [];
    final byCat = <int, List<Hymn>>{};
    for (final h in hymnal.himnos) {
      final c = h.categoryIndex;
      if (c != null) (byCat[c] ??= []).add(h);
    }
    Topic? topic(int i) {
      final hymns = byCat[i];
      if (hymns == null || hymns.isEmpty) return null;
      return Topic(index: i, name: hymnal.categorias[i], hymns: hymns);
    }

    if (hymnal.secciones.isEmpty) {
      return [
        TopicGroup(
          name: null,
          topics: [
            for (var i = 0; i < hymnal.categorias.length; i++) ?topic(i),
          ],
        ),
      ];
    }
    return [
      for (final s in hymnal.secciones)
        TopicGroup(
          name: s.nombre,
          topics: [for (var i = s.desde; i <= s.hasta; i++) ?topic(i)],
        ),
    ].where((g) => g.topics.isNotEmpty).toList();
  }

  /// Temáticas disponibles para [book] (o la unión de los activos si es null).
  List<String> categories({String? book}) {
    final src = book == null ? activeHymnals : [?_hymnals[book]];
    final seen = <String>{};
    return [
      for (final h in src)
        for (final c in h.categorias)
          if (seen.add(c)) c,
    ];
  }

  static const _accents = {
    'á': 'a',
    'à': 'a',
    'ä': 'a',
    'â': 'a',
    'é': 'e',
    'è': 'e',
    'ë': 'e',
    'ê': 'e',
    'í': 'i',
    'ì': 'i',
    'ï': 'i',
    'î': 'i',
    'ó': 'o',
    'ò': 'o',
    'ö': 'o',
    'ô': 'o',
    'ú': 'u',
    'ù': 'u',
    'ü': 'u',
    'û': 'u',
    'ñ': 'n',
  };

  /// Minúsculas y sin tildes. Conserva la longitud del texto (una letra por
  /// letra) para poder resaltar coincidencias sobre el texto original.
  static String normalize(String s) {
    final buf = StringBuffer();
    for (final ch in s.toLowerCase().split('')) {
      buf.write(_accents[ch] ?? ch);
    }
    return buf.toString();
  }
}
