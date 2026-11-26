import 'dart:convert';
// Capturas de pantalla para revisar el diseño (no es parte de `flutter test`).
//
//   flutter test tool/capturas/capturas_test.dart --update-goldens
//
// Dibuja cada pantalla con las fuentes reales en tamaño teléfono y tablet,
// en tema claro y oscuro, y guarda los PNG en tool/capturas/salida/.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:loores_al_rey/data/hymn_repository.dart';
import 'package:loores_al_rey/models/playlist.dart';
import 'package:loores_al_rey/screens/backup_screen.dart';
import 'package:loores_al_rey/screens/download_picker_screen.dart';
import 'package:loores_al_rey/screens/downloads_screen.dart';
import 'package:loores_al_rey/screens/favorites_screen.dart';
import 'package:loores_al_rey/screens/hymn_screen.dart';
import 'package:loores_al_rey/screens/projection_screen.dart';
import 'package:loores_al_rey/screens/shell_screen.dart';
import 'package:loores_al_rey/screens/topics_screen.dart';
import 'package:loores_al_rey/services/app_state.dart';
import 'package:loores_al_rey/services/backup_service.dart';
import 'package:loores_al_rey/services/media_service.dart';
import 'package:loores_al_rey/services/player_service.dart';
import 'package:loores_al_rey/theme/app_theme.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../test/test_utils.dart';

const phone = Size(390, 844);
const tablet = Size(800, 1280);
const tabletLand = Size(1280, 800);

Future<void> _loadFonts() async {
  Future<void> family(String name, List<String> files) async {
    final loader = FontLoader(name);
    for (final f in files) {
      loader.addFont(
        File(f).readAsBytes().then((b) => ByteData.sublistView(b)),
      );
    }
    await loader.load();
  }

  await family('NotoSans', [
    for (final w in ['Regular', 'Italic', 'Medium', 'SemiBold', 'Bold'])
      'assets/fonts/NotoSans-$w.ttf',
  ]);
  await family('GreatVibes', ['assets/fonts/GreatVibes-Regular.ttf']);
  await family('MaterialIcons', [
    'C:/src/flutter/bin/cache/artifacts/material_fonts/materialicons-regular.otf',
  ]);
}

late AppState state;
late MediaService media;
late PlayerService player;
late NavController nav;
final navKey = GlobalKey<NavigatorState>();

Future<void> _setup() async {
  SharedPreferences.setMockInitialValues({
    'favorites': ['clasico-131', 'clasico-1', 'clasico-219'],
    'history': ['clasico-249', 'clasico-131', 'clasico-8', 'clasico-791'],
    'playlists': jsonEncode([
      Playlist(id: '1', name: 'Culto sábado', items: ['clasico-25', 'clasico-131', 'clasico-32']).toJson(),
    ]),
  });
  state = AppState();
  await state.init();
  final tmp = Directory.systemTemp.createTempSync('capturas');
  media = MediaService(
    baseDir: () async => tmp,
    client: MockClient((req) async {
      final ok = !req.url.path.contains('cantado') || req.url.path.endsWith('_1.mp3');
      return ok ? http.Response.bytes(List.filled(100, 1), 200) : http.Response('', 404);
    }),
  );
  await media.init();
  player = PlayerService(media, state);
  nav = NavController();
}

Widget _app({bool dark = false, Widget? home}) => MultiProvider(
  providers: [
    ChangeNotifierProvider.value(value: state),
    ChangeNotifierProvider.value(value: media),
    ChangeNotifierProvider.value(value: player),
    Provider(create: (_) => BackupService(state)),
    ChangeNotifierProvider.value(value: nav),
  ],
  child: MaterialApp(
    navigatorKey: navKey,
    debugShowCheckedModeBanner: false,
    theme: AppTheme.light(),
    darkTheme: AppTheme.dark(),
    themeMode: dark ? ThemeMode.dark : ThemeMode.light,
    locale: const Locale('es'),
    supportedLocales: const [Locale('es')],
    localizationsDelegates: GlobalMaterialLocalizations.delegates,
    home: home ?? const ShellScreen(),
  ),
);

Future<void> _settle(WidgetTester t) async {
  for (var i = 0; i < 8; i++) {
    await t.pump(const Duration(milliseconds: 120));
  }
}

Future<void> _shot(WidgetTester t, String name) async {
  await _settle(t);
  await expectLater(
    find.byType(MaterialApp),
    matchesGoldenFile('salida/$name.png'),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await _loadFonts();
    await HymnRepository.instance.load(bundle: DiskBundle());
  });

  Future<void> size(WidgetTester t, Size s) async {
    t.view.physicalSize = s * 2;
    t.view.devicePixelRatio = 2;
    addTearDown(t.view.reset);
  }

  for (final dark in [false, true]) {
    final tag = dark ? 'oscuro' : 'claro';

    testWidgets('pestañas $tag', (t) async {
      await t.runAsync(_setup);
      await size(t, phone);
      await t.pumpWidget(_app(dark: dark));
      await _shot(t, '01_inicio_$tag');
      nav.openSearch(book: 'clasico');
      await _shot(t, '02_buscar_$tag');
      await t.enterText(find.byType(TextField).first, 'corazon');
      await _shot(t, '03_buscar_texto_$tag');
      nav.go(2);
      await _shot(t, '04_favoritos_$tag');
      nav.go(3);
      await _shot(t, '05_ajustes_$tag');
    });

    testWidgets('himno $tag', (t) async {
      await t.runAsync(_setup);
      await size(t, phone);
      final h = HymnRepository.instance.find('clasico', 3)!;
      await t.pumpWidget(_app(dark: dark, home: HymnScreen(hymn: h)));
      await _shot(t, '06_himno_$tag');
      await t.tap(find.text('Cantado'));
      await _shot(t, '07_himno_cantado_$tag');
    });
  }

  testWidgets('otras pantallas', (t) async {
    await t.runAsync(_setup);
    await size(t, phone);
    final repo = HymnRepository.instance;
    final screens = <String, Widget>{
      '08_listas': const FavoritesScreen(),
      '09_lista_detalle': const PlaylistScreen(playlistId: '1'),
      '10_descargas': const DownloadsScreen(),
      '11_elegir_himnos': const DownloadPickerScreen(
        book: 'clasico',
        kind: MediaKind.instrumental,
      ),
      '12_tematicas': const TopicsScreen(),
      '13_tematica': TopicScreen(topic: repo.topicIndex('clasico')[1].topics.first),
      '14_respaldo': const BackupScreen(),
      '15_proyeccion': ProjectionScreen(hymn: repo.find('clasico', 3)!),
      '16_himno_791_sin_datos': HymnScreen(hymn: repo.find('clasico', 791)!),
    };
    for (final e in screens.entries) {
      await t.pumpWidget(_app(home: e.value));
      if (e.key == '08_listas') {
        await t.tap(find.text('Listas'));
      }
      await _shot(t, e.key);
    }
  });

  testWidgets('tablet', (t) async {
    await t.runAsync(_setup);
    await size(t, tablet);
    await t.pumpWidget(_app());
    await _shot(t, '20_tablet_inicio');
    nav.openSearch(book: 'clasico');
    await _shot(t, '21_tablet_buscar');
    nav.go(3);
    await _shot(t, '22_tablet_ajustes');
    await t.pumpWidget(
      _app(home: HymnScreen(hymn: HymnRepository.instance.find('clasico', 131)!)),
    );
    await _shot(t, '23_tablet_himno');
    await size(t, tabletLand);
    await t.pumpWidget(_app(home: const ShellScreen()));
    nav.go(0);
    await _shot(t, '24_tablet_horizontal_inicio');
  });
}
