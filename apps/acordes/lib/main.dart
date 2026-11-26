import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:loores_al_rey/config.dart';
import 'package:loores_al_rey/data/chords_repository.dart';
import 'package:loores_al_rey/data/hymn_repository.dart';
import 'package:loores_al_rey/services/app_state.dart';
import 'package:loores_al_rey/services/audio_handler.dart';
import 'package:loores_al_rey/services/media_service.dart';
import 'package:loores_al_rey/services/player_service.dart';
import 'package:loores_al_rey/theme/app_theme.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'home_screen.dart';

/// Oyentes que viven toda la app (se guardan para que no se descarten).
final List<AppLifecycleListener> _oyentes = [];

/// Acordes IASDMR: la app para músicos de la familia Loores al Rey. Usa el
/// mismo código (himnos, descargas, reproductor, acordes) y comparte las
/// descargas con Loores al Rey si está instalada.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  kOtraApp = 'Loores al Rey';
  kAssetPrefix = 'packages/loores_al_rey/';
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  HymnAudioHandler? audioHandler;
  try {
    audioHandler = await AudioService.init(
      builder: HymnAudioHandler.new,
      config: const AudioServiceConfig(
        androidNotificationChannelId: 'pe.looresalrey.acordes.audio',
        androidNotificationChannelName: 'Reproducción de pistas',
        androidNotificationOngoing: true,
        androidNotificationIcon: 'drawable/ic_notificacion',
        notificationColor: Brand.azul,
      ),
    );
  } catch (e) {
    debugPrint('AudioService no disponible: $e');
  }
  final state = AppState();
  final media = MediaService();
  await Future.wait([
    state.init(),
    SharedPreferences.getInstance().then((prefs) => media.init(prefs: prefs)),
    HymnRepository.instance.load(),
    ChordsRepository.instance.load(),
  ]);
  _oyentes.add(AppLifecycleListener(onResume: media.refreshShared));
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: state),
        ChangeNotifierProvider.value(value: media),
        ChangeNotifierProvider(create: (_) => PlayerService(media, state, audioHandler)),
      ],
      child: const AcordesApp(),
    ),
  );
}

class AcordesApp extends StatelessWidget {
  const AcordesApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Acordes IASDMR',
      debugShowCheckedModeBanner: false,
      // Siempre oscura: se lee mejor en el atril y con poca luz.
      theme: AppTheme.dark(),
      locale: const Locale('es'),
      supportedLocales: const [Locale('es')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      home: const AcordesHome(),
    );
  }
}
