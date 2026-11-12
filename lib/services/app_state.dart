import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Estado global persistido: himnario activo, favoritos, historial,
/// tamaño de letra y tema.
class AppState extends ChangeNotifier {
  static const _kBook = 'book';
  static const _kFavorites = 'favorites';
  static const _kHistory = 'history';
  static const _kFontScale = 'fontScale';
  static const _kThemeMode = 'themeMode';

  SharedPreferences? _prefs;

  String book = 'nuevo';
  final List<String> favorites = [];
  final List<String> history = [];
  double fontScale = 1.0;
  ThemeMode themeMode = ThemeMode.system;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    book = _prefs!.getString(_kBook) ?? 'nuevo';
    favorites
      ..clear()
      ..addAll(_prefs!.getStringList(_kFavorites) ?? []);
    history
      ..clear()
      ..addAll(_prefs!.getStringList(_kHistory) ?? []);
    fontScale = _prefs!.getDouble(_kFontScale) ?? 1.0;
    themeMode = ThemeMode.values[_prefs!.getInt(_kThemeMode) ?? 0];
    notifyListeners();
  }

  void setBook(String value) {
    book = value;
    _prefs?.setString(_kBook, value);
    notifyListeners();
  }

  bool isFavorite(String id) => favorites.contains(id);

  void toggleFavorite(String id) {
    if (!favorites.remove(id)) favorites.insert(0, id);
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

  void setFontScale(double value) {
    fontScale = value.clamp(0.8, 2.5);
    _prefs?.setDouble(_kFontScale, fontScale);
    notifyListeners();
  }

  void setThemeMode(ThemeMode mode) {
    themeMode = mode;
    _prefs?.setInt(_kThemeMode, mode.index);
    notifyListeners();
  }
}
