import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../data/hymn_repository.dart';
import '../models/hymn.dart';
import '../services/app_state.dart';
import '../services/media_service.dart';
import '../services/player_service.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import '../widgets/score_view.dart';
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
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _state.pushHistory(_hymn.id),
    );
    // Mientras se canta, que la pantalla no se apague.
    WakelockPlus.enable();
  }

  @override
  void dispose() {
    // Sin "modo minimizado" la música no sigue fuera del himno.
    if (!_state.minimizedMode && _player.current != null && !_player.hasQueue) {
      _player.stop();
    }
    WakelockPlus.disable();
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
    for (var i = 0; i < h.estrofas.length; i++) {
      buf.writeln('${i + 1}. ${h.estrofas[i]}\n');
      // El coro se escribe una sola vez, después de la primera estrofa.
      if (i == 0 && h.hasChorus) buf.writeln('Coro:\n${h.coro}\n');
    }
    if (h.cita != null) buf.writeln('${h.versiculo ?? ''} ${h.cita}'.trim());
    buf.write('\n— App Loores al Rey');
    SharePlus.instance.share(
      ShareParams(text: buf.toString(), subject: h.title),
    );
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
                  // La proyección apaga el wakelock al salir: se vuelve a activar.
                  Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => ProjectionScreen(hymn: h),
                    ),
                  ).then((_) => WakelockPlus.enable());
                case 'anterior':
                  _goTo(HymnRepository.instance.neighbor(h, -1));
                case 'siguiente':
                  _goTo(HymnRepository.instance.neighbor(h, 1));
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: 'lista',
                child: ListTile(
                  leading: Icon(Icons.playlist_add),
                  title: Text('Agregar a lista de culto'),
                ),
              ),
              PopupMenuItem(
                value: 'compartir',
                child: ListTile(
                  leading: Icon(Icons.share),
                  title: Text('Compartir letra'),
                ),
              ),
              PopupMenuItem(
                value: 'proyectar',
                child: ListTile(
                  leading: Icon(Icons.cast),
                  title: Text('Modo proyección'),
                ),
              ),
              PopupMenuItem(
                value: 'anterior',
                child: ListTile(
                  leading: Icon(Icons.skip_previous),
                  title: Text('Himno anterior'),
                ),
              ),
              PopupMenuItem(
                value: 'siguiente',
                child: ListTile(
                  leading: Icon(Icons.skip_next),
                  title: Text('Himno siguiente'),
                ),
              ),
            ],
          ),
        ],
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: showScore
                ? ScoreView(key: ValueKey('pdf-${h.id}'), hymn: h)
                : _PinchToZoom(
                    // Pellizcar con dos dedos: cambia el tamaño de la letra.
                    onStart: () => state.fontSize,
                    onScale: (base, scale) => state.setFontSize(base * scale),
                    child: GestureDetector(
                      // Deslizar a los lados: himno anterior / siguiente.
                      onHorizontalDragEnd: (d) {
                        final v = d.primaryVelocity ?? 0;
                        if (v.abs() < 400) return;
                        _goTo(
                          HymnRepository.instance.neighbor(h, v < 0 ? 1 : -1),
                        );
                      },
                      child: _Lyrics(
                        key: ValueKey('ly-${h.id}'),
                        hymn: h,
                        fontSize: state.fontSize,
                        color: bg.foreground,
                        onNavigate: _goTo,
                      ),
                    ),
                  ),
          ),
          Positioned(
            left: Space.m,
            bottom: Space.m,
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
                  _KindTabs(
                    kind: _kind,
                    onChanged: (k) => setState(() => _kind = k),
                  ),
                ],
              ),
            ),
    );
  }
}

class _Lyrics extends StatelessWidget {
  const _Lyrics({
    super.key,
    required this.hymn,
    required this.fontSize,
    this.color,
    required this.onNavigate,
  });
  final Hymn hymn;
  final double fontSize;
  final Color? color;
  final ValueChanged<Hymn?> onNavigate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fg = color ?? theme.colorScheme.onSurface;
    final body = TextStyle(fontSize: fontSize, height: 1.45, color: fg);
    return SelectionArea(
      child: ListView(
        // Abajo deja espacio para el botón de favorito (48 + márgenes).
        padding: const EdgeInsets.fromLTRB(
          Space.reading,
          Space.m,
          Space.reading,
          88,
        ),
        children: [
          Text(
            hymn.title,
            style: TextStyle(
              fontSize: fontSize + 2,
              fontWeight: FontWeight.w700,
              color: fg,
            ),
          ),
          const SizedBox(height: Space.m),
          for (final (i, v) in hymn.verses.indexed) ...[
            // El coro completo solo la primera vez; después, una marca breve
            // para no alargar la pantalla (en proyección sí se repite).
            if (v.isChorus && i > 1)
              Padding(
                padding: const EdgeInsets.only(left: Space.m),
                child: Row(
                  children: [
                    Icon(
                      Icons.replay_rounded,
                      size: fontSize * 0.8,
                      color: Brand.azulClaro,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Coro',
                      style: body.copyWith(
                        fontStyle: FontStyle.italic,
                        color: fg.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
              )
            else if (v.isChorus)
              Padding(
                padding: const EdgeInsets.only(left: Space.m),
                child: Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: 'Coro\n',
                        style: TextStyle(
                          fontSize: fontSize * 0.75,
                          fontWeight: FontWeight.w700,
                          color: Brand.azulClaro,
                        ),
                      ),
                      TextSpan(
                        text: v.text,
                        style: body.copyWith(fontStyle: FontStyle.italic),
                      ),
                    ],
                  ),
                ),
              )
            else
              Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: '${v.number}  ',
                      style: body.copyWith(
                        fontWeight: FontWeight.w700,
                        color: Brand.azulClaro,
                      ),
                    ),
                    TextSpan(text: v.text, style: body),
                  ],
                ),
              ),
            SizedBox(height: fontSize),
          ],
          if (hymn.versiculo != null || hymn.cita != null) ...[
            const Divider(),
            const SizedBox(height: 8),
            Text(
              [
                if (hymn.versiculo != null) '"${hymn.versiculo}"',
                if (hymn.cita != null) hymn.cita,
              ].join('\n'),
              style: TextStyle(
                fontSize: fontSize * 0.8,
                fontStyle: FontStyle.italic,
                color: fg.withValues(alpha: 0.75),
              ),
            ),
          ],
          const SizedBox(height: 16),
          _NeighborButtons(hymn: hymn, onNavigate: onNavigate),
        ],
      ),
    );
  }
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
        icon: Icon(
          fav ? Icons.favorite : Icons.favorite_border,
          color: fav ? Brand.coral : Theme.of(context).colorScheme.primary,
        ),
        onPressed: () {
          context.read<AppState>().toggleFavorite(id);
          showSnack(
            context,
            fav ? 'Quitado de favoritos' : 'Agregado a favoritos',
          );
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
    // En la pestaña Partituras se reproduce la pista (instrumental, o la
    // que ya esté sonando de este himno) para seguirla con la rayita.
    final audioKind = kind.isAudio
        ? kind
        : (player.current?.id == hymn.id && player.kind.isAudio
              ? player.kind
              : MediaKind.instrumental);
    final active = player.isCurrent(hymn, audioKind);
    // Si faltan ambos datos se dice una sola vez (menos ruido visual).
    final String subtitle;
    final String? tono;
    if (!hymn.hasScoreData) {
      subtitle = 'Autor y tono no disponibles';
      tono = null;
    } else {
      subtitle = hymn.autorMostrado ?? 'Autor no disponible';
      // Corto, como en la partitura y el Figma: "Fa M · 4/4".
      tono = hymn.tonoCorto ?? 'Tono no disponible';
    }
    // Si el servidor no tiene el recurso, se avisa sin esperar a que toquen play.
    media.prefetchAvailability(hymn, audioKind);
    if (!kind.isAudio) media.prefetchAvailability(hymn, kind);
    final missing = media.availability(hymn, audioKind) == false;
    final fileMissing = media.availability(hymn, kind) == false;
    final error = missing
        ? MediaService.notAvailableMessage(hymn, audioKind)
        : (active ? player.error : null);
    final secondary = Brand.textoSecundario(context);
    return Container(
      margin: const EdgeInsets.fromLTRB(Space.s, Space.xs, Space.s, Space.xs),
      padding: const EdgeInsets.all(Space.xxs),
      decoration: BoxDecoration(
        color: dark ? const Color(0xFF1F2A44) : const Color(0xFFDADADA),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        children: [
          _RoundButton(
            tooltip: active && player.playing ? 'Pausar' : 'Reproducir',
            icon: active && player.playing
                ? Icons.pause_rounded
                : Icons.play_arrow_rounded,
            busy: active && player.loading,
            onPressed: missing ? null : () => player.play(hymn, audioKind),
          ),
          const SizedBox(width: Space.xs),
          Expanded(
            child: active && error == null
                ? _Progress(player: player, subtitle: subtitle, tono: tono)
                : Padding(
                    padding: const EdgeInsets.symmetric(horizontal: Space.xxs),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            error ?? subtitle,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: FontSizes.caption,
                              color: missing
                                  ? secondary
                                  : (error != null
                                        ? Theme.of(context).colorScheme.error
                                        : secondary),
                              fontStyle: missing ? FontStyle.italic : null,
                            ),
                          ),
                        ),
                        if (tono != null) ...[
                          const SizedBox(width: Space.xs),
                          Text(
                            tono,
                            style: TextStyle(
                              fontSize: FontSizes.caption,
                              color: secondary,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
          ),
          const SizedBox(width: Space.xs),
          _DownloadButton(
            hymn: hymn,
            kind: kind,
            media: media,
            enabled: !fileMissing,
          ),
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
    final secondary = Brand.textoSecundario(context);
    const caption = TextStyle(fontSize: FontSizes.caption);
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
                  value: max <= 0
                      ? 0
                      : pos.inMilliseconds.clamp(0, max).toDouble(),
                  max: max <= 0 ? 1 : max,
                  activeColor: Brand.azul,
                  onChanged: max <= 0
                      ? null
                      : (v) => player.seek(Duration(milliseconds: v.round())),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: Space.xs),
              child: Row(
                children: [
                  Text(formatDuration(pos), style: caption),
                  const SizedBox(width: Space.xs),
                  Expanded(
                    child: Text(
                      subtitle,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: caption.copyWith(color: secondary),
                    ),
                  ),
                  if (tono != null)
                    Padding(
                      padding: const EdgeInsets.only(right: Space.xs),
                      child: Text(
                        tono!,
                        style: caption.copyWith(color: secondary),
                      ),
                    ),
                  Text(formatDuration(total), style: caption),
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
  const _DownloadButton({
    required this.hymn,
    required this.kind,
    required this.media,
    this.enabled = true,
  });
  final Hymn hymn;
  final MediaKind kind;
  final MediaService media;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final downloaded = media.isDownloaded(hymn, kind);
    final progress = media.progress[MediaService.key(hymn, kind)];
    if (progress != null) {
      return SizedBox(
        width: 48,
        height: 48,
        child: Padding(
          padding: const EdgeInsets.all(Space.s),
          child: CircularProgressIndicator(
            value: progress == 0 ? null : progress,
            strokeWidth: 3,
          ),
        ),
      );
    }
    return _RoundButton(
      tooltip: downloaded
          ? 'Descargado (quitar)'
          : 'Descargar ${kind.label.toLowerCase()}',
      icon: downloaded ? Icons.download_done_rounded : Icons.download_rounded,
      filled: !downloaded,
      onPressed: !enabled
          ? null
          : () async {
              if (downloaded) {
                final ok = await confirm(
                  context,
                  'Quitar descarga',
                  '¿Borrar ${kind.label.toLowerCase()} del himno ${hymn.number} del teléfono?',
                  ok: 'Borrar',
                );
                if (ok) await media.delete(hymn, kind);
                return;
              }
              try {
                await media.download(hymn, kind);
                if (context.mounted) {
                  showSnack(context, '${kind.label} disponible sin conexión');
                }
              } on MediaNotAvailable catch (e) {
                if (context.mounted) showSnack(context, e.message);
              } catch (_) {
                if (context.mounted) {
                  showSnack(
                    context,
                    'No se pudo descargar. Revisa tu conexión.',
                  );
                }
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
  final VoidCallback? onPressed;
  final String tooltip;
  final bool busy;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 48,
      height: 48,
      child: Material(
        color: !filled
            ? Colors.transparent
            : (onPressed == null
                  ? Brand.gris.withValues(alpha: 0.5)
                  : Brand.azul),
        shape: const CircleBorder(),
        child: busy
            ? const Padding(
                padding: EdgeInsets.all(Space.s),
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: Colors.white,
                ),
              )
            : IconButton(
                tooltip: tooltip,
                icon: Icon(
                  icon,
                  color: filled ? Colors.white : Brand.azulClaro,
                ),
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
                      height: Space.touch,
                      padding: const EdgeInsets.symmetric(horizontal: Space.m),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: k == kind
                            ? (dark ? Brand.azulClaro : Brand.azul)
                            : (dark
                                  ? const Color(0xFF2A3550)
                                  : const Color(0xFFDADADA)),
                        border: const Border(
                          right: BorderSide(color: Colors.white, width: 1),
                        ),
                      ),
                      child: Text(
                        _labels[k]!,
                        style: TextStyle(
                          color: k == kind
                              ? Colors.white
                              : (dark ? Colors.white : Brand.azul),
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

/// Botones "anterior / siguiente" al final de la letra (también se puede
/// deslizar a los lados, pero esto se descubre mejor).
class _NeighborButtons extends StatelessWidget {
  const _NeighborButtons({required this.hymn, required this.onNavigate});
  final Hymn hymn;
  final ValueChanged<Hymn?> onNavigate;

  @override
  Widget build(BuildContext context) {
    final repo = HymnRepository.instance;
    final prev = repo.neighbor(hymn, -1);
    final next = repo.neighbor(hymn, 1);
    return Row(
      children: [
        if (prev != null)
          TextButton.icon(
            onPressed: () => onNavigate(prev),
            icon: const Icon(Icons.chevron_left_rounded),
            label: Text('#${prev.number}'),
          ),
        const Spacer(),
        if (next != null)
          TextButton.icon(
            onPressed: () => onNavigate(next),
            iconAlignment: IconAlignment.end,
            icon: const Icon(Icons.chevron_right_rounded),
            label: Text('#${next.number}'),
          ),
      ],
    );
  }
}

/// Detecta el pellizco con dos dedos sin competir con el desplazamiento de
/// la lista (usa eventos crudos, fuera del "gesture arena").
class _PinchToZoom extends StatefulWidget {
  const _PinchToZoom({
    required this.child,
    required this.onStart,
    required this.onScale,
  });
  final Widget child;
  final double Function() onStart;
  final void Function(double base, double scale) onScale;

  @override
  State<_PinchToZoom> createState() => _PinchToZoomState();
}

class _PinchToZoomState extends State<_PinchToZoom> {
  final Map<int, Offset> _pointers = {};
  double? _startDistance;
  double _base = 18;

  double get _distance {
    final p = _pointers.values.take(2).toList();
    return (p[0] - p[1]).distance;
  }

  void _reset() {
    _startDistance = _pointers.length >= 2 ? _distance : null;
    if (_startDistance != null) _base = widget.onStart();
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (e) {
        _pointers[e.pointer] = e.localPosition;
        _reset();
      },
      onPointerMove: (e) {
        _pointers[e.pointer] = e.localPosition;
        final start = _startDistance;
        if (start != null && start > 0 && _pointers.length >= 2) {
          widget.onScale(_base, _distance / start);
        }
      },
      onPointerUp: (e) {
        _pointers.remove(e.pointer);
        _reset();
      },
      onPointerCancel: (e) {
        _pointers.remove(e.pointer);
        _reset();
      },
      child: widget.child,
    );
  }
}
