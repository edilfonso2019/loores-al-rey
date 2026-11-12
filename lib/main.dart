import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'data/hymn_repository.dart';
import 'screens/home_screen.dart';
import 'services/app_state.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final state = AppState();
  await Future.wait([state.init(), HymnRepository.instance.load()]);
  runApp(
    ChangeNotifierProvider.value(value: state, child: const LooresAlReyApp()),
  );
}

class LooresAlReyApp extends StatelessWidget {
  const LooresAlReyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeMode = context.select<AppState, ThemeMode>((s) => s.themeMode);
    return MaterialApp(
      title: 'Loores al Rey',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: themeMode,
      home: const HomeScreen(),
    );
  }
}
