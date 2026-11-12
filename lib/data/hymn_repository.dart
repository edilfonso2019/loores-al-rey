import 'dart:convert';

import 'package:flutter/services.dart';

import '../models/hymn.dart';

/// Carga los himnarios desde `assets/data/*.json` y expone búsqueda offline.
class HymnRepository {
  HymnRepository._();
  static final HymnRepository instance = HymnRepository._();

  final Map<String, List<Hymn>> _books = {};
  bool _loaded = false;

  static const books = {
    'nuevo': 'Himnario Adventista (2010)',
    'antiguo': 'Himnario Adventista (1962)',
  };

  Future<void> load() async {
    if (_loaded) return;
    for (final book in books.keys) {
      final raw = await rootBundle.loadString('assets/data/$book.json');
      final list = (jsonDecode(raw) as List)
          .map((e) => Hymn.fromJson(e as Map<String, dynamic>))
          .toList()
        ..sort((a, b) => a.number.compareTo(b.number));
      _books[book] = list;
    }
    _loaded = true;
  }

  List<Hymn> byBook(String book) => _books[book] ?? const [];

  Hymn? find(String book, int number) {
    for (final h in byBook(book)) {
      if (h.number == number) return h;
    }
    return null;
  }

  Hymn? byId(String id) {
    final parts = id.split('-');
    if (parts.length != 2) return null;
    return find(parts[0], int.tryParse(parts[1]) ?? -1);
  }

  /// Busca por número exacto, título o fragmento de letra (sin tildes).
  List<Hymn> search(String book, String query) {
    final q = _normalize(query.trim());
    if (q.isEmpty) return byBook(book);
    final asNumber = int.tryParse(q);
    final results = <Hymn>[];
    for (final h in byBook(book)) {
      if (asNumber != null && h.number.toString().startsWith(q)) {
        results.add(h);
      } else if (_normalize(h.title).contains(q) ||
          _normalize(h.fullText).contains(q)) {
        results.add(h);
      }
    }
    return results;
  }

  static String _normalize(String s) => s
      .toLowerCase()
      .replaceAll(RegExp('[áàä]'), 'a')
      .replaceAll(RegExp('[éèë]'), 'e')
      .replaceAll(RegExp('[íìï]'), 'i')
      .replaceAll(RegExp('[óòö]'), 'o')
      .replaceAll(RegExp('[úùü]'), 'u')
      .replaceAll('ñ', 'n');
}
