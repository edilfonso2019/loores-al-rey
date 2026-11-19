import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loores_al_rey/services/app_state.dart';
import 'package:loores_al_rey/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<AppState> fresh() async {
    SharedPreferences.setMockInitialValues({});
    final s = AppState();
    await s.init();
    return s;
  }

  test('favoritos: alternar y reordenar', () async {
    final s = await fresh();
    s.toggleFavorite('clasico-1');
    s.toggleFavorite('clasico-2');
    expect(s.favorites, ['clasico-2', 'clasico-1']);
    s.reorderFavorites(0, 1);
    expect(s.favorites, ['clasico-1', 'clasico-2']);
    s.toggleFavorite('clasico-1');
    expect(s.favorites, ['clasico-2']);
  });

  test('listas de culto: agregar sin duplicar y reordenar', () async {
    final s = await fresh();
    final pl = s.createPlaylist('  Culto sábado ');
    expect(pl.name, 'Culto sábado');
    expect(s.addToPlaylist(pl, 'clasico-5'), isTrue);
    expect(s.addToPlaylist(pl, 'clasico-5'), isFalse);
    s.addToPlaylist(pl, 'clasico-9');
    s.reorderPlaylist(pl, 1, 0);
    expect(pl.items, ['clasico-9', 'clasico-5']);
  });

  test('el respaldo restaura favoritos, listas y ajustes', () async {
    final a = await fresh();
    a.toggleFavorite('clasico-131');
    a.addToPlaylist(a.createPlaylist('Vespertino'), 'clasico-20');
    a.setFontSize(24);
    a.setBackground(LyricsBackground.sepia);
    a.setThemeMode(ThemeMode.dark);
    final backup = a.toBackup();

    final b = await fresh();
    await b.restoreBackup(backup);
    expect(b.favorites, ['clasico-131']);
    expect(b.playlists.single.name, 'Vespertino');
    expect(b.playlists.single.items, ['clasico-20']);
    expect(b.fontSize, 24);
    expect(b.background, LyricsBackground.sepia);
    expect(b.themeMode, ThemeMode.dark);

    // Y queda persistido.
    final c = AppState();
    await c.init();
    expect(c.favorites, ['clasico-131']);
  });

  test('rechaza archivos que no son respaldos de la app', () async {
    final s = await fresh();
    expect(() => s.restoreBackup({'hola': 1}), throwsFormatException);
  });
}
