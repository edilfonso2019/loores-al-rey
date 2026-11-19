import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/hymn_repository.dart';
import '../services/media_service.dart';
import '../widgets/common.dart';

/// Administrador de descargas: ver, borrar y descargar en lote.
class DownloadsScreen extends StatelessWidget {
  const DownloadsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final media = context.watch<MediaService>();
    return Scaffold(
      appBar: AppBar(title: const Text('Administrador de descargas')),
      body: FutureBuilder<List<DownloadedItem>>(
        key: ValueKey(
          '${media.progress.length}-${media.bulkDone}-${media.bulkRunning}',
        ),
        future: media.listDownloads(),
        builder: (context, snap) {
          final items = snap.data ?? const [];
          final total = items.fold<int>(0, (a, b) => a + b.bytes);
          final clasico = HymnRepository.instance.byBook('clasico');
          return ListView(
            children: [
              ListTile(
                title: Text('${items.length} archivos · ${formatBytes(total)}'),
                trailing: items.isEmpty
                    ? null
                    : TextButton(
                        onPressed: () async {
                          if (await confirm(
                            context,
                            'Borrar todo',
                            '¿Borrar todas las descargas?',
                            ok: 'Borrar',
                          )) {
                            await media.deleteAll();
                          }
                        },
                        child: const Text('Borrar todo'),
                      ),
              ),
              if (media.bulkRunning)
                ListTile(
                  title: Text(
                    'Descargando ${media.bulkDone}/${media.bulkTotal}…',
                  ),
                  subtitle: LinearProgressIndicator(
                    value: media.bulkTotal == 0
                        ? null
                        : media.bulkDone / media.bulkTotal,
                  ),
                  trailing: TextButton(
                    onPressed: media.cancelBulk,
                    child: const Text('Cancelar'),
                  ),
                )
              else ...[
                if (media.bulkError != null)
                  ListTile(
                    leading: const Icon(
                      Icons.error_outline,
                      color: Colors.redAccent,
                    ),
                    title: Text('Descarga detenida: ${media.bulkError}'),
                  ),
                ListTile(
                  leading: const Icon(Icons.library_music),
                  title: const Text('Descargar todos los instrumentales'),
                  subtitle: const Text(
                    'Himnario Clásico · requiere mucho espacio y datos',
                  ),
                  onTap: () async {
                    if (!await confirm(
                      context,
                      'Descarga masiva',
                      'Se descargarán ${clasico.length} pistas (varios cientos de MB). Usa Wi-Fi. ¿Continuar?',
                      ok: 'Descargar',
                    )) {
                      return;
                    }
                    final n = await media.downloadAll(
                      clasico,
                      MediaKind.instrumental,
                    );
                    if (context.mounted) {
                      showSnack(context, '$n pistas descargadas');
                    }
                  },
                ),
              ],
              const Divider(),
              for (final d in items)
                ListTile(
                  leading: Icon(
                    d.kind == MediaKind.partitura
                        ? Icons.picture_as_pdf
                        : Icons.music_note,
                  ),
                  title: Text('${d.hymn.number} - ${d.hymn.title}'),
                  subtitle: Text('${d.kind.label} · ${formatBytes(d.bytes)}'),
                  trailing: IconButton(
                    tooltip: 'Borrar',
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () => media.delete(d.hymn, d.kind),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
