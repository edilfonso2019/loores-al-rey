import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../data/hymn_repository.dart';
import '../models/hymn.dart';
import '../services/app_state.dart';
import '../services/media_service.dart';
import '../services/player_service.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import 'projection_screen.dart';
import 'shell_screen.dart';

/// Himno (Figma 2404:255 / 2415:821 / 2415:878): letra, reproductor y
/// pestañas Instrumental | Cantado | Partituras.
class HymnScreen extends StatefulWidget {
  const HymnScreen({super.key, required this.hymn, this.initialKind});
  final Hymn hymn;
  final MediaKind? initialKind;

  @override
  State<HymnScreen> createState() => _HymnScreenState();
}

class _HymnScreenState extends State<HymnScreen> {
  late Hymn _hymn = widget.hymn;
  late MediaKind _kind = widget.initialKind ?? MediaKind.instrumental;
  late final PlayerService _player;
  late final AppState _state;

  @override
  void initState() {
    super.initState();
    _player = context.read<PlayerService>();
    _state = context.read<AppState>();
    WidgetsBinding.instance.addPostFrameCallback((_) => _state.pushHistory(_hymn.id));
  }

  @override
  void dispose() {
    // Sin "modo minimizado" la música no sigue fuera del himno.
    if (!_state.minimizedMode && _player.current != null) {
      _player.stop();
    }
    super.dispose();
  }

  void _goTo(Hymn? h) {
    if (h == null) return;
    setState(() => _hymn = h);
    _state.pushHistory(h.id);
  }

  void _share() {
    final h = _hymn;
    final buf = StringBuffer('${h.number}. ${h.title}\n${hymnalName(h)}\n\n');
    for (final v in h.verses) {
      buf.writeln(v.isChorus ? 'Coro:\n${v.text}\n' : '${v.number}. ${v.text}\n');
    }
    if (h.cita != null) buf.writeln('${h.versiculo ?? ''} ${h.cita}'.trim());
    buf.write('\n— App Loores al Rey');
    SharePlus.instance.share(ShareParams(text: buf.toString(), subject: h.title));
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final h = _hymn;
    final hymnal = HymnRepository.instance.hymnal(h.book);
    final basic = state.basicMode;
    final showScore = !basic && _kind == MediaKind.partitura;
    final bg = state.background;
    return Scaffold(
      backgroundColor: showScore ? null : bg.background,
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Atrás',
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Himno # ${h.number} - ${hymnal?.nombreCorto ?? ''}'),
        actions: [
          IconButton(
            tooltip: 'Buscar',
            icon: const Icon(Icons.search_rounded, size: 28),
            onPressed: () {
              context.read<NavController>().go(1);
              Navigator.of(context).popUntil((r) => r.isFirst);
            },
          ),
          PopupMenuButton<String>(
            onSelected: (v) {
              switch (v) {
                case 'lista':
                  showAddToPlaylist(context, h);
                case 'compartir':
                  _share();
                case 'proyectar':
                  Navigator.push(context, MaterialPageRoute<void>(builder: (_) => ProjectionScreen(hymn: h)));
                case 'anterior':
                  _goTo(HymnRepository.instance.neighbor(h, -1));
                case 'siguiente':
                  _goTo(HymnRepository.instance.neighbor(h, 1));
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'lista', child: ListTile(leading: Icon(Icons.playlist_add), title: Text('Agregar a lista de culto'))),
              PopupMenuItem(value: 'compartir', child: ListTile(leading: Icon(Icons.share), title: Text('Compartir letra'))),
              PopupMenuItem(value: 'proyectar', child: ListTile(leading: Icon(Icons.cast), title: Text('Modo proyección'))),
              PopupMenuItem(value: 'anterior', child: ListTile(leading: Icon(Icons.skip_previous), title: Text('Himno anterior'))),
              PopupMenuItem(value: 'siguiente', child: ListTile(leading: Icon(Icons.skip_next), title: Text('Himno siguiente'))),
            ],
          ),
        ],
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: showScore
                ? _ScoreView(key: ValueKey('pdf-${h.id}'), hymn: h)
                : GestureDetector(
                    // Deslizar a los lados: himno anterior / siguiente.
                    onHorizontalDragEnd: (d) {
                      final v = d.primaryVelocity ?? 0;
                      if (v.abs() < 400) return;
                      _goTo(HymnRepository.instance.neighbor(h, v < 0 ? 1 : -1));
                    },
                    child: _Lyrics(key: ValueKey('ly-${h.id}'), hymn: h, fontSize: state.fontSize, color: bg.foreground),
                  ),
          ),
          Positioned(
            left: 16,
            bottom: 12,
            child: _FavoriteButton(id: h.id),
          ),
        ],
      ),
      bottomNavigationBar: basic
          ? null
          : SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _PlayerBar(hymn: h, kind: _kind),
                  _KindTabs(kind: _kind, onChanged: (k) => setState(() => _kind = k)),
                ],
              ),
            ),
    );
  }
}

class _Lyrics extends StatelessWidget {
  const _Lyrics({super.key, required this.hymn, required this.fontSize, this.color});
  final Hymn hymn;
  final double fontSize;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fg = color ?? theme.colorScheme.onSurface;
    final body = TextStyle(fontSize: fontSize, height: 1.45, color: fg);
    final cat = HymnRepository.instance.categoryName(hymn);
    return SelectionArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(22, 16, 22, 96),
        children: [
          Text(
            hymn.title,
            style: TextStyle(fontSize: fontSize + 2, fontWeight: FontWeight.w700, color: fg),
          ),
          if (cat.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(cat, style: TextStyle(fontSize: 13, color: fg.withValues(alpha: 0.6))),
            ),
          const SizedBox(height: 14),
          for (final v in hymn.verses) ...[
            if (v.isChorus)
              Padding(
                padding: const EdgeInsets.only(left: 18),
                child: Text.rich(
                  TextSpan(children: [
                    TextSpan(
                      text: 'Coro\n',
                      style: TextStyle(fontSize: fontSize * 0.75, fontWeight: FontWeight.w700, color: Brand.azulClaro),
                    ),
                    TextSpan(text: v.text, style: body.copyWith(fontStyle: FontStyle.italic)),
                  ]),
                ),
              )
            else
              Text.rich(
                TextSpan(children: [
                  TextSpan(
                    text: '${v.number}  ',
                    style: body.copyWith(fontWeight: FontWeight.w700, color: Brand.azulClaro),
                  ),
                  TextSpan(text: v.text, style: body),
                ]),
              ),
            SizedBox(height: fontSize),
          ],
          if (hymn.versiculo != null || hymn.cita != null) ...[
            const Divider(),
            const SizedBox(height: 8),
            Text(
              [if (hymn.versiculo != null) '"${hymn.versiculo}"', if (hymn.cita != null) hymn.cita].join('\n'),
              style: TextStyle(fontSize: fontSize * 0.8, fontStyle: FontStyle.italic, color: fg.withValues(alpha: 0.75)),
            ),
          ],
        ],
      ),
    );
  }
}

class _ScoreView extends StatelessWidget {
  const _ScoreView({super.key, required this.hymn});
  final Hymn hymn;

  @override
  Widget build(BuildContext context) {
    final media = context.watch<MediaService>();
    final local = media.localFile(hymn, MediaKind.partitura);
    final url = media.remoteUrl(hymn, MediaKind.partitura);
    if (local == null && url == null) {
      return const _Message(icon: Icons.music_off, text: 'Partitura aún no disponible.');
    }
    final params = PdfViewerParams(
      backgroundColor: Theme.of(context).colorScheme.surface,
      maxScale: 8,
      errorBannerBuilder: (context, error, stackTrace, documentRef) => const _Message(
        icon: Icons.cloud_off,
        text: 'No se pudo cargar la partitura.\nRevisa tu conexión o descárgala para verla sin internet.',
      ),
    );
    return local != null
        ? PdfViewer.file(local.path, params: params)
        : PdfViewer.uri(Uri.parse(url!), params: params);
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 48, color: Brand.gris),
              const SizedBox(height: 12),
              Text(text, textAlign: TextAlign.center),
            ],
          ),
        ),
      );
}

class _FavoriteButton extends StatelessWidget {
  const _FavoriteButton({required this.id});
  final String id;

  @override
  Widget build(BuildContext context) {
    final fav = context.select<AppState, bool>((s) => s.isFavorite(id));
    return Material(
      color: Theme.of(context).colorScheme.surface,
      shape: const CircleBorder(),
      elevation: 3,
      child: IconButton(
        tooltip: fav ? 'Quitar de favoritos' : 'Agregar a favoritos',
        iconSize: 28,
        icon: Icon(fav ? Icons.favorite : Icons.favorite_border, color: fav ? Brand.coral : Brand.azul),
        onPressed: () {
          context.read<AppState>().toggleFavorite(id);
          showSnack(context, fav ? 'Quitado de favoritos' : 'Agregado a favoritos');
        },
      ),
    );
  }
}

/// Reproductor fijo: play/pausa, progreso, autor/tono y descargar.
class _PlayerBar extends StatelessWidget {
  const _PlayerBar({required this.hymn, required this.kind});
  final Hymn hymn;
  final MediaKind kind;

  @override
  Widget build(BuildContext context) {
    final player = context.watch<PlayerService>();
    final media = context.watch<MediaService>();
    final dark = Theme.of(context).brightness == Brightness.dark;
    final isAudio = kind.isAudio;
    final active = isAudio && player.isCurrent(hymn, kind);
    final subtitle = hymn.autor ?? (isAudio ? kind.label : 'Partitura');
    final error = active ? player.error : null;
    return Container(
      margin: const EdgeInsets.fromLTRB(8, 6, 8, 6),
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: dark ? const Color(0xFF1F2A44) : const Color(0xFFDADADA),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        children: [
          if (isAudio)
            _RoundButton(
              tooltip: active && player.playing ? 'Pausar' : 'Reproducir',
              icon: active && player.playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
              busy: active && player.loading,
              onPressed: () => player.play(hymn, kind),
            )
          else
            const SizedBox(width: 48, height: 48, child: Icon(Icons.picture_as_pdf_rounded, color: Brand.azul)),
          const SizedBox(width: 8),
          Expanded(
            child: active && error == null
                ? _Progress(player: player, subtitle: subtitle, tono: hymn.tono)
                : Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            error ?? subtitle,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              color: error != null ? Theme.of(context).colorScheme.error : Brand.gris,
                            ),
                          ),
                        ),
                        if (hymn.tono != null)
                          Text(hymn.tono!, style: const TextStyle(fontSize: 12)),
                      ],
                    ),
                  ),
          ),
          const SizedBox(width: 8),
          _DownloadButton(hymn: hymn, kind: kind, media: media),
        ],
      ),
    );
  }
}

class _Progress extends StatelessWidget {
  const _Progress({required this.player, required this.subtitle, this.tono});
  final PlayerService player;
  final String subtitle;
  final String? tono;

  @override
  Widget build(BuildContext context) {
    final p = player.player;
    return StreamBuilder<Duration>(
      stream: p.positionStream,
      builder: (context, snap) {
        final pos = snap.data ?? Duration.zero;
        final total = p.duration ?? Duration.zero;
        final max = total.inMilliseconds.toDouble();
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 3,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
              ),
              child: SizedBox(
                height: 22,
                child: Slider(
                  value: max <= 0 ? 0 : pos.inMilliseconds.clamp(0, max).toDouble(),
                  max: max <= 0 ? 1 : max,
                  activeColor: Brand.azul,
                  onChanged: max <= 0 ? null : (v) => player.seek(Duration(milliseconds: v.round())),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                children: [
                  Text(formatDuration(pos), style: const TextStyle(fontSize: 11)),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      subtitle,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 11, color: Brand.gris),
                    ),
                  ),
                  if (tono != null) Text('$tono  ', style: const TextStyle(fontSize: 11)),
                  Text(formatDuration(total), style: const TextStyle(fontSize: 11)),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _DownloadButton extends StatelessWidget {
  const _DownloadButton({required this.hymn, required this.kind, required this.media});
  final Hymn hymn;
  final MediaKind kind;
  final MediaService media;

  @override
  Widget build(BuildContext context) {
    final downloaded = media.isDownloaded(hymn, kind);
    final progress = media.progress[MediaService.key(hymn, kind)];
    if (progress != null) {
      return SizedBox(
        width: 48,
        height: 48,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: CircularProgressIndicator(value: progress == 0 ? null : progress, strokeWidth: 3),
        ),
      );
    }
    return _RoundButton(
      tooltip: downloaded ? 'Descargado (quitar)' : 'Descargar ${kind.label.toLowerCase()}',
      icon: downloaded ? Icons.download_done_rounded : Icons.download_rounded,
      filled: !downloaded,
      onPressed: () async {
        if (downloaded) {
          final ok = await confirm(context, 'Quitar descarga',
              '¿Borrar ${kind.label.toLowerCase()} del himno ${hymn.number} del teléfono?', ok: 'Borrar');
          if (ok) await media.delete(hymn, kind);
          return;
        }
        try {
          await media.download(hymn, kind);
          if (context.mounted) showSnack(context, '${kind.label} disponible sin conexión');
        } on MediaNotAvailable catch (e) {
          if (context.mounted) showSnack(context, e.message);
        } catch (_) {
          if (context.mounted) showSnack(context, 'No se pudo descargar. Revisa tu conexión.');
        }
      },
    );
  }
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({
    required this.icon,
    required this.onPressed,
    required this.tooltip,
    this.busy = false,
    this.filled = true,
  });
  final IconData icon;
  final VoidCallback onPressed;
  final String tooltip;
  final bool busy;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 48,
      height: 48,
      child: Material(
        color: filled ? Brand.azul : Colors.transparent,
        shape: const CircleBorder(),
        child: busy
            ? const Padding(
                padding: EdgeInsets.all(13),
                child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
              )
            : IconButton(
                tooltip: tooltip,
                icon: Icon(icon, color: filled ? Colors.white : Brand.azulClaro),
                onPressed: onPressed,
              ),
      ),
    );
  }
}

/// Pestañas inferiores Instrumental | Cantado | Partituras.
class _KindTabs extends StatelessWidget {
  const _KindTabs({required this.kind, required this.onChanged});
  final MediaKind kind;
  final ValueChanged<MediaKind> onChanged;

  static const _labels = {
    MediaKind.instrumental: 'Instrumental',
    MediaKind.cantado: 'Cantado',
    MediaKind.partitura: 'Partituras',
  };

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Center(
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final k in MediaKind.values)
                Semantics(
                  selected: k == kind,
                  button: true,
                  child: InkWell(
                    onTap: () => onChanged(k),
                    child: Container(
                      height: 40,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: k == kind ? Brand.azul : (dark ? const Color(0xFF2A3550) : const Color(0xFFDADADA)),
                        border: const Border(right: BorderSide(color: Colors.white, width: 1)),
                      ),
                      child: Text(
                        _labels[k]!,
                        style: TextStyle(
                          color: k == kind ? Colors.white : (dark ? Colors.white : Brand.azul),
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
