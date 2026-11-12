import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/app_state.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    return Scaffold(
      appBar: AppBar(title: const Text('Ajustes')),
      body: ListView(
        children: [
          const ListTile(title: Text('Tema')),
          RadioListTile<ThemeMode>(
            title: const Text('Según el sistema'),
            value: ThemeMode.system,
            groupValue: state.themeMode,
            onChanged: (v) => state.setThemeMode(v!),
          ),
          RadioListTile<ThemeMode>(
            title: const Text('Claro'),
            value: ThemeMode.light,
            groupValue: state.themeMode,
            onChanged: (v) => state.setThemeMode(v!),
          ),
          RadioListTile<ThemeMode>(
            title: const Text('Oscuro'),
            value: ThemeMode.dark,
            groupValue: state.themeMode,
            onChanged: (v) => state.setThemeMode(v!),
          ),
          const Divider(),
          ListTile(
            title: const Text('Tamaño de letra'),
            subtitle: Slider(
              min: 0.8,
              max: 2.5,
              divisions: 17,
              value: state.fontScale,
              label: '${(state.fontScale * 100).round()} %',
              onChanged: state.setFontScale,
            ),
          ),
          const Divider(),
          const AboutListTile(
            applicationName: 'Loores al Rey',
            applicationVersion: '0.1.0',
            applicationLegalese:
                'Himnario Adventista del Séptimo Día. Letras © sus autores / Asociación Publicadora.',
            child: Text('Acerca de'),
          ),
        ],
      ),
    );
  }
}
