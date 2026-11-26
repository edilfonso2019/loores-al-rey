import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/hymn_repository.dart';
import '../models/hymn.dart';
import '../services/media_service.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import 'download_picker_screen.dart';

/// Administrador de descargas: dónde guardar (interna / SD) y, por tipo
/// (instrumental, cantado, partituras), descargar todo o elegir himnos.
class DownloadsScreen extends StatefulWidget {
  const DownloadsScreen({super.key});

  @override
  State<DownloadsScreen> createState() => _DownloadsScreenState();
}

class _DownloadsScreenState extends State<DownloadsScreen> {
  MediaKind _kind = MediaKind.instrumental;

  /// Himnario cuyas descargas se administran (el primero activo).
  String get _book =>
      HymnRepository.instance.activeHymnals.firstOrNull?.id ?? 'clasico';

  List<Hymn> get _hymns => HymnRepository.instance.byBook(_book);

  Future<void> _downloadAll(MediaService media) async {
    final pending = _hymns.length - media.downloadedCount(_kind, book: _book);
    if (pending == 0) {
      showSnack(context, 'Ya están todos descargados.');
      return;
    }
    final ok = await confirm(
      context,
      'Descargar todos',
      'Se descargarán $pending ${_kindPlural(_kind)} en '
          '${media.location.label.toLowerCase()}. Puede ocupar varios cientos '
          'de MB; conviene usar Wi-Fi.'
          '${_kind == MediaKind.cantado ? '\n\nLas pistas cantadas que aún no existen se omiten.' : ''}',
      ok: 'Descargar',
    );
    if (!ok || !mounted) return;
    final n = await media.downloadAll(_hymns, _kind);
    if (mounted) showSnack(context, '$n ${_kindPlural(_kind)} descargadas');
  }

  Future<void> _pick(MediaService media) async {
    final selected = await Navigator.push<List<Hymn>>(
      context,
      MaterialPageRoute(
        builder: (_) => DownloadPickerScreen(book: _book, kind: _kind),
      ),
    );
    if (selected == null || selected.isEmpty || !mounted) return;
    final n = await media.downloadAll(selected, _kind);
    if (mounted) showSnack(context, '$n ${_kindPlural(_kind)} descargadas');
  }

  @override
  Widget build(BuildContext context) {
    final media = context.watch<MediaService>();
    final secondary = Brand.textoSecundario(context);
    final total = _hymns.length;
    final done = media.downloadedCount(_kind, book: _book);
    final runningHere = media.bulkRunning && media.bulkKind == _kind;
    return Scaffold(
      appBar: AppBar(title: const Text('Descargas')),
      body: ReadableWidth(
        child: FutureBuilder<List<DownloadedItem>>(
          // Se recalcula cuando cambia algo de las descargas.
          key: ValueKey(
            '${media.progress.length}-${media.bulkDone}-${media.bulkRunning}-$done-$_kind',
          ),
          future: media.listDownloads(),
          builder: (context, snap) {
            final all = snap.data ?? const <DownloadedItem>[];
            final items = all.where((d) => d.kind == _kind).toList();
            final bytes = items.fold<int>(0, (a, d) => a + d.bytes);
            final totalBytes = all.fold<int>(0, (a, d) => a + d.bytes);
            return ListView(
              padding: const EdgeInsets.only(bottom: Space.l),
              children: [
                // ---------- Ubicación ----------
                _Header('GUARDAR EN', color: secondary),
                RadioGroup<StorageLocation>(
                  groupValue: media.location,
                  onChanged: (l) {
                    if (l != null) media.setLocation(l);
                  },
                  child: Column(
                    children: [
                      RadioListTile<StorageLocation>(
                        value: StorageLocation.interna,
                        title: const Text('Memoria interna'),
                        subtitle: Text(
                          'Siempre disponible',
                          style: TextStyle(color: secondary),
                        ),
                        secondary: const Icon(Icons.phone_android_rounded),
                      ),
                      RadioListTile<StorageLocation>(
                        value: StorageLocation.externa,
                        enabled: media.hasExternal,
                        title: const Text('Tarjeta SD'),
                        subtitle: Text(
                          media.hasExternal
                              ? 'Ahorra espacio del teléfono'
                              : 'No se detectó una tarjeta SD',
                          style: TextStyle(color: secondary),
                        ),
                        secondary: const Icon(Icons.sd_card_rounded),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
                  child: Text(
                    'Lo ya descargado se conserva donde está. Las descargas se '
                    'borran si desinstalas la app.'
                    '${totalBytes > 0 ? ' En total: ${formatBytes(totalBytes)}.' : ''}',
                    style: TextStyle(
                      fontSize: FontSizes.caption,
                      color: secondary,
                    ),
                  ),
                ),

                // ---------- Tipo ----------
                _Header('QUÉ DESCARGAR', color: secondary),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
                  child: SegmentedButton<MediaKind>(
                    showSelectedIcon: false,
                    segments: const [
                      ButtonSegment(
                        value: MediaKind.instrumental,
                        label: Text('Instrumental'),
                      ),
                      ButtonSegment(
                        value: MediaKind.cantado,
                        label: Text('Cantado'),
                      ),
                      ButtonSegment(
                        value: MediaKind.partitura,
                        label: Text('Partituras'),
                      ),
                    ],
                    selected: {_kind},
                    onSelectionChanged: (s) => setState(() => _kind = s.first),
                  ),
                ),
                const SizedBox(height: Space.m),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        '$done de $total descargados'
                        '${bytes > 0 ? ' · ${formatBytes(bytes)}' : ''}',
                        style: const TextStyle(
                          fontSize: FontSizes.body,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: Space.xs),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(Space.xxs),
                        child: LinearProgressIndicator(
                          minHeight: 6,
                          value: total == 0
                              ? 0
                              : runningHere && media.bulkTotal > 0
                              ? media.bulkDone / media.bulkTotal
                              : done / total,
                        ),
                      ),
                      const SizedBox(height: Space.m),
                      if (runningHere)
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Descargando ${media.bulkDone} de ${media.bulkTotal}…',
                                style: TextStyle(color: secondary),
                              ),
                            ),
                            TextButton(
                              onPressed: media.cancelBulk,
                              child: const Text('Cancelar'),
                            ),
                          ],
                        )
                      else ...[
                        if (media.bulkError != null && media.bulkKind == _kind)
                          Padding(
                            padding: const EdgeInsets.only(bottom: Space.s),
                            child: Text(
                              'Descarga detenida: ${media.bulkError}',
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.error,
                              ),
                            ),
                          ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Builder(
                              builder: (_) => FilledButton.icon(
                                style: FilledButton.styleFrom(
                                  minimumSize: const Size(0, Space.touch),
                                ),
                                onPressed:
                                    media.bulkRunning || !media.canDownload
                                    ? null
                                    : () => _downloadAll(media),
                                icon: const Icon(Icons.download_rounded),
                                label: const Text('Descargar todos'),
                              ),
                            ),
                            const SizedBox(height: Space.s),
                            Builder(
                              builder: (_) => OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  minimumSize: const Size(0, Space.touch),
                                ),
                                onPressed:
                                    media.bulkRunning || !media.canDownload
                                    ? null
                                    : () => _pick(media),
                                icon: const Icon(Icons.checklist_rounded),
                                label: const Text('Elegir himnos'),
                              ),
                            ),
                          ],
                        ),
                        if (media.bulkRunning)
                          Padding(
                            padding: const EdgeInsets.only(top: Space.xs),
                            child: Text(
                              'Espera a que termine la descarga de '
                              '${_kindPlural(media.bulkKind ?? _kind)}.',
                              style: TextStyle(
                                fontSize: FontSizes.caption,
                                color: secondary,
                              ),
                            ),
                          ),
                      ],
                    ],
                  ),
                ),

                // ---------- Descargados de este tipo ----------
                if (items.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      Space.gutter,
                      Space.l,
                      Space.xs,
                      0,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            'DESCARGADOS',
                            style: TextStyle(
                              fontSize: FontSizes.caption,
                              fontWeight: FontWeight.w700,
                              letterSpacing: .6,
                              color: secondary,
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: () async {
                            if (await confirm(
                              context,
                              'Borrar ${_kindPlural(_kind)}',
                              '¿Borrar las ${items.length} descargas de este tipo del teléfono?',
                              ok: 'Borrar',
                            )) {
                              await media.deleteAll(kind: _kind);
                            }
                          },
                          child: const Text('Borrar todos'),
                        ),
                      ],
                    ),
                  ),
                  for (final d in items)
                    ListTile(
                      contentPadding: const EdgeInsets.only(
                        left: Space.gutter,
                        right: Space.xxs,
                      ),
                      title: Text('${d.hymn.number} - ${d.hymn.title}'),
                      subtitle: Text(
                        '${formatBytes(d.bytes)} · ${_whereLabel(media, d)}',
                        style: TextStyle(
                          fontSize: FontSizes.caption,
                          color: secondary,
                        ),
                      ),
                      trailing: IconButton(
                        tooltip: 'Borrar',
                        icon: const Icon(Icons.delete_outline_rounded),
                        onPressed: () => media.delete(d.hymn, d.kind),
                      ),
                    ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }

  String _whereLabel(MediaService media, DownloadedItem d) {
    final sd = media.locationPath(StorageLocation.externa);
    return sd != null && d.file.path.startsWith(sd)
        ? StorageLocation.externa.label
        : StorageLocation.interna.label;
  }
}

String _kindPlural(MediaKind k) => switch (k) {
  MediaKind.instrumental => 'pistas instrumentales',
  MediaKind.cantado => 'pistas cantadas',
  MediaKind.partitura => 'partituras',
};

class _Header extends StatelessWidget {
  const _Header(this.text, {required this.color});
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(
      Space.gutter,
      Space.l,
      Space.gutter,
      Space.xs,
    ),
    child: Text(
      text,
      style: TextStyle(
        fontSize: FontSizes.caption,
        fontWeight: FontWeight.w700,
        letterSpacing: .6,
        color: color,
      ),
    ),
  );
}
