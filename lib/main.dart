import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:audio_service/audio_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'data/hymn_repository.dart';
import 'screens/shell_screen.dart';
import 'services/app_state.dart';
import 'services/audio_handler.dart';
import 'services/backup_service.dart';
import 'services/media_service.dart';
import 'services/player_service.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // De borde a borde: la barra inferior de la app se extiende detrás de los
  // botones del sistema en lugar de dejar una franja gris.
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  HymnAudioHandler? audioHandler;
  try {
    audioHandler = await AudioService.init(
      builder: HymnAudioHandler.new,
      config: const AudioServiceConfig(
        androidNotificationChannelId: 'pe.looresalrey.app.audio',
        androidNotificationChannelName: 'Reproducción de himnos',
        androidNotificationOngoing: true,
        androidNotificationIcon: 'drawable/ic_notificacion',
        notificationColor: Brand.azul,
      ),
    );
  } catch (e) {
    // Sin controles en la notificación, pero la app sigue funcionando.
    debugPrint('AudioService no disponible: $e');
  }
  final state = AppState();
  final media = MediaService();
  await Future.wait([
    state.init(),
    // La ubicación de descargas (interna / SD) se guarda en preferencias.
    SharedPreferences.getInstance().then((prefs) => media.init(prefs: prefs)),
    HymnRepository.instance.load(),
  ]);
  // Marcas de sincronización partitura ↔ audio incluidas en la app.
  try {
    state.bundledSync = AppState.decodeSync(
      await rootBundle.loadString('assets/data/sincronizacion.json'),
    );
  } catch (_) {}
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: state),
        ChangeNotifierProvider.value(value: media),
        ChangeNotifierProvider(
          create: (_) => PlayerService(media, state, audioHandler),
        ),
        Provider(create: (_) => BackupService(state)),
        ChangeNotifierProvider(create: (_) => NavController()),
      ],
      child: const LooresAlReyApp(),
    ),
  );
}

class LooresAlReyApp extends StatelessWidget {
  const LooresAlReyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // El fondo "Noche" oscurece toda la app, no solo la letra.
    final themeMode = context.select<AppState, ThemeMode>(
      (s) =>
          s.background == LyricsBackground.noche ? ThemeMode.dark : s.themeMode,
    );
    return MaterialApp(
      title: 'Loores al Rey',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: themeMode,
      locale: const Locale('es'),
      supportedLocales: const [Locale('es')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      home: const ShellScreen(),
    );
  }
}
