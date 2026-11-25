import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/app_state.dart';
import '../services/backup_service.dart';
import '../widgets/common.dart';

/// Sincronizar y respaldar: archivo y Google Drive.
class BackupScreen extends StatefulWidget {
  const BackupScreen({super.key});

  @override
  State<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends State<BackupScreen> {
  bool _busy = false;

  Future<void> _run(String ok, Future<String?> Function() action) async {
    setState(() => _busy = true);
    try {
      final msg = await action();
      if (mounted && msg != null) showSnack(context, msg == '' ? ok : msg);
    } catch (e) {
      if (mounted) showSnack(context, BackupService.describeError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final backup = context.read<BackupService>();
    final state = context.watch<AppState>();
    final last = state.lastDriveBackup;
    return Scaffold(
      appBar: AppBar(title: const Text('Respaldo y sincronización')),
      body: ReadableWidth(
        child: Stack(
          children: [
            ListView(
              children: [
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'Se respaldan favoritos, listas de culto, historial y ajustes. '
                    'Las descargas de audio no se incluyen.',
                  ),
                ),
                const ListTile(
                  title: Text('ARCHIVO', style: TextStyle(fontSize: 12)),
                ),
                ListTile(
                  leading: const Icon(Icons.save_alt),
                  title: const Text('Exportar a un archivo'),
                  onTap: _busy
                      ? null
                      : () => _run(
                          'Respaldo guardado',
                          () async => await backup.exportToFile() ? '' : null,
                        ),
                ),
                ListTile(
                  leading: const Icon(Icons.file_open),
                  title: const Text('Importar desde un archivo'),
                  subtitle: const Text('Reemplaza tus datos actuales'),
                  onTap: _busy
                      ? null
                      : () async {
                          if (!await confirm(
                            context,
                            'Importar respaldo',
                            'Esto reemplazará tus favoritos, listas y ajustes. ¿Continuar?',
                          )) {
                            return;
                          }
                          await _run(
                            'Respaldo restaurado',
                            () async =>
                                await backup.importFromFile() ? '' : null,
                          );
                        },
                ),
                const ListTile(
                  title: Text('GOOGLE DRIVE', style: TextStyle(fontSize: 12)),
                ),
                if (last != null)
                  ListTile(
                    leading: const Icon(Icons.check_circle_outline),
                    title: Text(
                      'Último respaldo: ${last.toLocal().toString().substring(0, 16)}',
                    ),
                  ),
                ListTile(
                  leading: const Icon(Icons.cloud_upload),
                  title: const Text('Respaldar en Google Drive'),
                  onTap: _busy
                      ? null
                      : () => _run('Respaldo subido a Google Drive', () async {
                          await backup.backupToDrive();
                          return '';
                        }),
                ),
                ListTile(
                  leading: const Icon(Icons.cloud_download),
                  title: const Text('Restaurar desde Google Drive'),
                  subtitle: const Text('Reemplaza tus datos actuales'),
                  onTap: _busy
                      ? null
                      : () async {
                          if (!await confirm(
                            context,
                            'Restaurar',
                            'Esto reemplazará tus favoritos, listas y ajustes. ¿Continuar?',
                          )) {
                            return;
                          }
                          await _run('Respaldo restaurado', () async {
                            final d = await backup.restoreFromDrive();
                            return d == null
                                ? 'No hay respaldo en tu Google Drive.'
                                : '';
                          });
                        },
                ),
              ],
            ),
            if (_busy)
              const Positioned.fill(
                child: ColoredBox(
                  color: Color(0x44000000),
                  child: Center(child: CircularProgressIndicator()),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
