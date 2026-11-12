import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/playlist.dart';
import '../theme/app_theme.dart';

/// Estado global persistido: favoritos, historial, playlists y ajustes.
/// Todo lo que va en el respaldo sale de [toBackup] / [restoreBackup].
class AppState extends ChangeNotifier {
  static const _kFavorites = 'favorites';
  static const _kHistory = 'history';
  static const _kPlaylists = 'playlists';
  static const _kFontSize = 'fontSize';
  static const _kThemeMode = 'themeMode';
  static const _kBackground = 'lyricsBackground';
  static const _kBasic = 'basicMode';
  static const _kContinuous = 'continuousPlay';
  static const _kMinimized = 'minimizedMode';
  static const _kLastBackup = 'lastDriveBackup';

  static const minFont = 14.0;
  static const maxFont = 40.0;

  SharedPreferences? _prefs;

  final List<String> favorites = [];
  final List<String> history = [];
  final List<Playlist> playlists = [];
  double fontSize = 18;
  ThemeMode themeMode = ThemeMode.light;
  LyricsBackground background = LyricsBackground.defecto;

  /// Solo letra: oculta reproductor y pestañas.
  bool basicMode = false;

  /// Al terminar un himno, pasa al siguiente (o al siguiente de la lista).
  bool continuousPlay = false;

  /// Mantiene el mini reproductor visible en toda la app.
  bool minimizedMode = true;

  DateTime? lastDriveBackup;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    final p = _prefs!;
    favorites
      ..clear()
      ..addAll(p.getStringList(_kFavorites) ?? []);
    history
      ..clear()
      ..addAll(p.getStringList(_kHistory) ?? []);
    playlists
      ..clear()
      ..addAll(_decodePlaylists(p.getString(_kPlaylists)));
    fontSize = (p.getDouble(_kFontSize) ?? 18).clamp(minFont, maxFont);
    themeMode = ThemeMode.values[(p.getInt(_kThemeMode) ?? 1).clamp(0, 2)];
    background = LyricsBackground.values.firstWhere(
      (b) => b.name == p.getString(_kBackground),
      orElse: () => LyricsBackground.defecto,
    );
    basicMode = p.getBool(_kBasic) ?? false;
    continuousPlay = p.getBool(_kContinuous) ?? false;
    minimizedMode = p.getBool(_kMinimized) ?? true;
    final last = p.getString(_kLastBackup);
    lastDriveBackup = last == null ? null : DateTime.tryParse(last);
    notifyListeners();
  }

  // ---------------- Favoritos e historial ----------------

  bool isFavorite(String id) => favorites.contains(id);

  void toggleFavorite(String id) {
    if (!favorites.remove(id)) favorites.insert(0, id);
    _prefs?.setStringList(_kFavorites, favorites);
    notifyListeners();
  }

  void reorderFavorites(int oldIndex, int newIndex) {
    if (newIndex > oldIndex) newIndex--;
    favorites.insert(newIndex, favorites.removeAt(oldIndex));
    _prefs?.setStringList(_kFavorites, favorites);
    notifyListeners();
  }

  void pushHistory(String id) {
    history.remove(id);
    history.insert(0, id);
    if (history.length > 50) history.removeLast();
    _prefs?.setStringList(_kHistory, history);
    notifyListeners();
  }

  void clearHistory() {
    history.clear();
    _prefs?.setStringList(_kHistory, history);
    notifyListeners();
  }

  // ---------------- Playlists ----------------

  Playlist createPlaylist(String name) {
    final pl = Playlist(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      name: name.trim().isEmpty ? 'Lista de culto' : name.trim(),
    );
    playlists.add(pl);
    _savePlaylists();
    return pl;
  }

  Playlist? playlist(String id) {
    for (final p in playlists) {
      if (p.id == id) return p;
    }
    return null;
  }

  void renamePlaylist(Playlist pl, String name) {
    if (name.trim().isEmpty) return;
    pl.name = name.trim();
    _savePlaylists();
  }

  void deletePlaylist(Playlist pl) {
    playlists.remove(pl);
    _savePlaylists();
  }

  /// Devuelve false si el himno ya estaba en la lista.
  bool addToPlaylist(Playlist pl, String hymnId) {
    if (pl.items.contains(hymnId)) return false;
    pl.items.add(hymnId);
    _savePlaylists();
    return true;
  }

  void removeFromPlaylist(Playlist pl, int index) {
    pl.items.removeAt(index);
    _savePlaylists();
  }

  void reorderPlaylist(Playlist pl, int oldIndex, int newIndex) {
    if (newIndex > oldIndex) newIndex--;
    pl.items.insert(newIndex, pl.items.removeAt(oldIndex));
    _savePlaylists();
  }

  void _savePlaylists() {
    _prefs?.setString(
      _kPlaylists,
      jsonEncode(playlists.map((p) => p.toJson()).toList()),
    );
    notifyListeners();
  }

  static List<Playlist> _decodePlaylists(String? raw) {
    if (raw == null || raw.isEmpty) return [];
    try {
      return (jsonDecode(raw) as List)
          .map((e) => Playlist.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  // ---------------- Ajustes ----------------

  void setFontSize(double value) {
    fontSize = value.clamp(minFont, maxFont).roundToDouble();
    _prefs?.setDouble(_kFontSize, fontSize);
    notifyListeners();
  }

  void setThemeMode(ThemeMode mode) {
    themeMode = mode;
    _prefs?.setInt(_kThemeMode, mode.index);
    notifyListeners();
  }

  void setBackground(LyricsBackground value) {
    background = value;
    _prefs?.setString(_kBackground, value.name);
    notifyListeners();
  }

  void setBasicMode(bool value) {
    basicMode = value;
    _prefs?.setBool(_kBasic, value);
    notifyListeners();
  }

  void setContinuousPlay(bool value) {
    continuousPlay = value;
    _prefs?.setBool(_kContinuous, value);
    notifyListeners();
  }

  void setMinimizedMode(bool value) {
    minimizedMode = value;
    _prefs?.setBool(_kMinimized, value);
    notifyListeners();
  }

  void markDriveBackup(DateTime when) {
    lastDriveBackup = when;
    _prefs?.setString(_kLastBackup, when.toIso8601String());
    notifyListeners();
  }

  // ---------------- Respaldo ----------------

  static const backupVersion = 1;

  /// Favoritos + playlists + historial + ajustes en un mapa JSON.
  Map<String, dynamic> toBackup() => {
        'app': 'loores_al_rey',
        'version': backupVersion,
        'fecha': DateTime.now().toIso8601String(),
        'favoritos': favorites,
        'historial': history,
        'playlists': playlists.map((p) => p.toJson()).toList(),
        'ajustes': {
          'fontSize': fontSize,
          'themeMode': themeMode.index,
          'fondo': background.name,
          'modoBasico': basicMode,
          'tocarContinuamente': continuousPlay,
          'modoMinimizado': minimizedMode,
        },
      };

  /// Reemplaza el estado actual por el del respaldo. Lanza [FormatException]
  /// si el archivo no es un respaldo de la app.
  Future<void> restoreBackup(Map<String, dynamic> data) async {
    if (data['app'] != 'loores_al_rey') {
      throw const FormatException('El archivo no es un respaldo de Loores al Rey.');
    }
    favorites
      ..clear()
      ..addAll(List<String>.from(data['favoritos'] as List? ?? const []));
    history
      ..clear()
      ..addAll(List<String>.from(data['historial'] as List? ?? const []));
    playlists
      ..clear()
      ..addAll((data['playlists'] as List? ?? const [])
          .map((e) => Playlist.fromJson(e as Map<String, dynamic>)));
    final a = (data['ajustes'] as Map?)?.cast<String, dynamic>() ?? const {};
    fontSize = ((a['fontSize'] as num?)?.toDouble() ?? fontSize).clamp(minFont, maxFont);
    themeMode = ThemeMode.values[((a['themeMode'] as int?) ?? themeMode.index).clamp(0, 2)];
    background = LyricsBackground.values.firstWhere(
      (b) => b.name == a['fondo'],
      orElse: () => background,
    );
    basicMode = a['modoBasico'] as bool? ?? basicMode;
    continuousPlay = a['tocarContinuamente'] as bool? ?? continuousPlay;
    minimizedMode = a['modoMinimizado'] as bool? ?? minimizedMode;

    final p = _prefs;
    if (p != null) {
      await p.setStringList(_kFavorites, favorites);
      await p.setStringList(_kHistory, history);
      await p.setString(_kPlaylists, jsonEncode(playlists.map((e) => e.toJson()).toList()));
      await p.setDouble(_kFontSize, fontSize);
      await p.setInt(_kThemeMode, themeMode.index);
      await p.setString(_kBackground, background.name);
      await p.setBool(_kBasic, basicMode);
      await p.setBool(_kContinuous, continuousPlay);
      await p.setBool(_kMinimized, minimizedMode);
    }
    notifyListeners();
  }
}
