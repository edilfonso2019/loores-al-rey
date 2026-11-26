import 'dart:convert';

import 'package:flutter/services.dart';

import '../config.dart';
import '../models/chords.dart';

/// Acordes sincronizados por himno (`assets/data/acordes.json`). Se carga la
/// primera vez que se necesita (no retrasa el arranque de la app).
class ChordsRepository {
  ChordsRepository._();
  static final ChordsRepository instance = ChordsRepository._();

  Map<String, dynamic>? _raw;
  final Map<String, HymnChords> _parsed = {};
  Future<void>? _loading;

  Future<void> load({AssetBundle? bundle}) =>
      _loading ??= (bundle ?? rootBundle)
          .loadString('${kAssetPrefix}assets/data/acordes.json')
          .then((s) {
            _raw =
                (jsonDecode(s) as Map<String, dynamic>)['himnos']
                    as Map<String, dynamic>;
          })
          .catchError((Object _) {
            _raw = const {};
          });

  bool get isLoaded => _raw != null;

  /// ¿Este himno ("clasico-200") tiene acordes? (false si aún no cargó).
  bool has(String hymnId) => _raw?.containsKey(hymnId) ?? false;

  HymnChords? get(String hymnId) {
    final cached = _parsed[hymnId];
    if (cached != null) return cached;
    final j = _raw?[hymnId];
    if (j == null) return null;
    return _parsed[hymnId] = HymnChords.fromJson(j as Map<String, dynamic>);
  }
}
