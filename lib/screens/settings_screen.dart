import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/app_state.dart';
import '../services/notification_permission.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import 'backup_screen.dart';
import 'downloads_screen.dart';
import 'shell_screen.dart';

/// Configuración (Figma 2472:771).
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    // Encabezado de sección: más aire arriba que abajo (ley de proximidad:
    // el título se agrupa con su sección, no con la anterior).
    Widget header(String t) => Padding(
      padding: const EdgeInsets.fromLTRB(
        Space.gutter,
        Space.l,
        Space.gutter,
        Space.xs,
      ),
      child: Text(
        t,
        style: TextStyle(
          fontSize: FontSizes.caption,
          fontWeight: FontWeight.w700,
          letterSpacing: .5,
          color: Brand.textoSecundario(context),
        ),
      ),
    );
    return Scaffold(
      appBar: AppBar(
        title: const Text('Configuración'),
        actions: [
          IconButton(
            tooltip: 'Buscar',
            icon: const Icon(Icons.search_rounded, size: 28),
            onPressed: () => context.read<NavController>().openSearch(),
          ),
        ],
      ),
      body: ReadableWidth(
        child: ListView(
          children: [
            header('CONFIGURACIÓN GLOBAL:'),
            ListTile(
              leading: const Icon(Icons.palette),
              title: const Text('Color de fondo'),
              trailing: Text(
                s.background.label,
                style: const TextStyle(color: Brand.azulClaro),
              ),
              onTap: () => _pickBackground(context, s),
            ),
            ListTile(
              leading: const Icon(Icons.text_fields),
              title: const Text('Tamaño del texto'),
              trailing: Text(
                '${s.fontSize.round()}',
                style: const TextStyle(color: Brand.azulClaro),
              ),
              onTap: () => _pickFont(context),
            ),
            ListTile(
              leading: const Icon(Icons.dark_mode_outlined),
              title: const Text('Tema de la app'),
              trailing: Text(switch (s.themeMode) {
                ThemeMode.light => 'Claro',
                ThemeMode.dark => 'Oscuro',
                _ => 'Sistema',
              }, style: const TextStyle(color: Brand.azulClaro)),
              onTap: () => _pickTheme(context, s),
            ),
            SwitchListTile(
              secondary: const Icon(Icons.menu_book),
              title: const Text('Modo básico'),
              subtitle: const Text('Solo letra, sin reproductor'),
              value: s.basicMode,
              onChanged: s.setBasicMode,
            ),
            ListTile(
              leading: const Icon(Icons.download),
              title: const Text('Administrador de descargas'),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => const DownloadsScreen(),
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.cloud_upload),
              // "Listas" como en el resto de la app (no "playlists").
              title: const Text('Respaldar favoritos y listas'),
              subtitle: const Text('En un archivo o en Google Drive'),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute<void>(builder: (_) => const BackupScreen()),
              ),
            ),
            // Donación: oculto en v1.
            header('REPRODUCTOR'),
            const _NotificationPermissionTile(),
            SwitchListTile(
              secondary: const Icon(Icons.play_arrow),
              title: const Text('Tocar continuamente'),
              subtitle: const Text('Al terminar, pasa al siguiente himno'),
              value: s.continuousPlay,
              onChanged: s.setContinuousPlay,
            ),
            SwitchListTile(
              secondary: const Icon(Icons.headphones_rounded),
              title: const Text('Modo minimizado'),
              subtitle: const Text('La música sigue al salir del himno'),
              value: s.minimizedMode,
              onChanged: s.setMinimizedMode,
            ),
            // "Calificar esta App": oculto hasta publicar en Play Store (una
            // opción que no hace nada confunde más de lo que ayuda).
            header('LA APP'),
            ListTile(
              leading: const Icon(Icons.info),
              title: const Text('Acerca de esta App'),
              onTap: () => showAboutDialog(
                context: context,
                applicationName: 'Loores al Rey',
                applicationVersion: '0.1.0',
                applicationLegalese:
                    'Himnario de la Iglesia Adventista del Séptimo Día Movimiento de Reforma.\nSin anuncios.',
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _pickBackground(BuildContext context, AppState s) {
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: RadioGroup<LyricsBackground>(
          groupValue: s.background,
          onChanged: (v) {
            if (v != null) s.setBackground(v);
            Navigator.pop(ctx);
          },
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final b in LyricsBackground.values)
                RadioListTile<LyricsBackground>(
                  value: b,
                  title: Text(b.label),
                  secondary: CircleAvatar(
                    backgroundColor: b.background ?? Brand.fondo,
                    radius: 12,
                    child: const SizedBox.shrink(),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _pickTheme(BuildContext context, AppState s) {
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: RadioGroup<ThemeMode>(
          groupValue: s.themeMode,
          onChanged: (v) {
            if (v != null) s.setThemeMode(v);
            Navigator.pop(ctx);
          },
          child: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              RadioListTile(value: ThemeMode.light, title: Text('Claro')),
              RadioListTile(value: ThemeMode.dark, title: Text('Oscuro')),
              RadioListTile(
                value: ThemeMode.system,
                title: Text('Según el sistema'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _pickFont(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => Consumer<AppState>(
        builder: (ctx, s, _) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Tamaño del texto: ${s.fontSize.round()}',
                  style: Theme.of(ctx).textTheme.titleMedium,
                ),
                Slider(
                  value: s.fontSize,
                  min: AppState.minFont,
                  max: AppState.maxFont,
                  divisions: (AppState.maxFont - AppState.minFont).round(),
                  onChanged: s.setFontSize,
                ),
                Text(
                  'Así se verá la letra del himno.',
                  style: TextStyle(fontSize: s.fontSize),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Aviso visible solo si el permiso de notificaciones está desactivado.
class _NotificationPermissionTile extends StatefulWidget {
  const _NotificationPermissionTile();

  @override
  State<_NotificationPermissionTile> createState() =>
      _NotificationPermissionTileState();
}

class _NotificationPermissionTileState
    extends State<_NotificationPermissionTile>
    with WidgetsBindingObserver {
  bool _granted = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _check();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // Al volver de los ajustes del sistema, se vuelve a comprobar.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _check();
  }

  Future<void> _check() async {
    final g = await NotificationPermission.granted();
    if (mounted && g != _granted) setState(() => _granted = g);
  }

  @override
  Widget build(BuildContext context) {
    if (_granted) return const SizedBox.shrink();
    return const ListTile(
      leading: Icon(Icons.notifications_off_outlined, color: Brand.coral),
      title: Text('Activar controles en la notificación'),
      subtitle: Text(
        'Para pausar o cambiar de himno desde la pantalla de bloqueo',
      ),
      trailing: Icon(Icons.open_in_new_rounded, size: 18),
      onTap: NotificationPermission.openSettings,
    );
  }
}
