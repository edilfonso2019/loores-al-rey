import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../models/hymn.dart';
import '../models/score_sync.dart';
import '../services/app_state.dart';
import '../services/media_service.dart';
import '../services/player_service.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import '../widgets/score_view.dart';

/// Modo marcar: mientras suena la pista, se toca el inicio de cada renglón
/// de la partitura. Con eso la rayita sigue el audio para siempre.
class ScoreSyncScreen extends StatefulWidget {
  const ScoreSyncScreen({super.key, required this.hymn});
  final Hymn hymn;

  @override
  State<ScoreSyncScreen> createState() => _ScoreSyncScreenState();
}

class _ScoreSyncScreenState extends State<ScoreSyncScreen> {
  /// Se resta al instante del toque: la gente toca un poco tarde.
  static const _reaction = Duration(milliseconds: 150);

  MediaKind _kind = MediaKind.instrumental;
  List<SyncMark> _marks = [];
  List<ScorePage>? _pages;
  String? _error;
  bool _dirty = false;
  bool _showHelp = true;

  String get _key => ScoreSync.key(widget.hymn.id, _kind.name);

  @override
  void initState() {
    super.initState();
    WakelockPlus.enable();
    _marks = [...context.read<AppState>().syncFor(_key)];
    _showHelp = _marks.isEmpty;
    _load();
  }

  Future<void> _load() async {
    try {
      final p = await loadScorePages(context.read<MediaService>(), widget.hymn);
      if (mounted) setState(() => _pages = p);
    } catch (e) {
      if (mounted) {
        setState(
          () => _error = e is MediaNotAvailable
              ? e.message
              : 'No se pudo cargar la partitura. Revisa tu conexión.',
        );
      }
    }
  }

  PlayerService get _player => context.read<PlayerService>();

  Future<void> _playPause() async {
    final p = _player;
    if (p.isCurrent(widget.hymn, _kind)) {
      await p.toggle();
    } else {
      await p.play(widget.hymn, _kind);
    }
  }

  void _tap(int page, double x, double y) {
    final p = _player;
    if (!p.isCurrent(widget.hymn, _kind) || !p.player.playing) {
      showSnack(context, 'Primero toca ▶ y marca mientras suena la música.');
      return;
    }
    var pos = p.player.position - _reaction;
    if (pos.isNegative) pos = Duration.zero;
    setState(() {
      _marks = [
        ..._marks,
        SyncMark(ms: pos.inMilliseconds, page: page, x: x, y: y),
      ]..sort((a, b) => a.ms.compareTo(b.ms));
      _dirty = true;
      _showHelp = false;
    });
  }

  void _undo() {
    if (_marks.isEmpty) return;
    // Quita la última marcada en el tiempo.
    setState(() {
      _marks = [..._marks]..removeLast();
      _dirty = true;
    });
  }

  Future<void> _restart() async {
    if (_marks.isNotEmpty &&
        !await confirm(
          context,
          'Empezar de nuevo',
          'Se borrarán las ${_marks.length} marcas y la pista volverá al inicio.',
          ok: 'Empezar de nuevo',
        )) {
      return;
    }
    setState(() {
      _marks = [];
      _dirty = true;
    });
    final p = _player;
    if (p.isCurrent(widget.hymn, _kind)) {
      await p.seek(Duration.zero);
    }
  }

  void _save() {
    context.read<AppState>().setSync(_key, _marks);
    _dirty = false;
    showSnack(
      context,
      _marks.isEmpty
          ? 'Marcas borradas'
          : 'Guardado: la partitura seguirá el audio (${_marks.length} renglones)',
    );
    Navigator.pop(context);
  }

  void _changeKind(MediaKind k) {
    if (k == _kind) return;
    setState(() {
      _kind = k;
      _marks = [...context.read<AppState>().syncFor(_key)];
      _dirty = false;
    });
  }

  void _share() {
    final all = context.read<AppState>().syncMarks;
    if (all.isEmpty) {
      showSnack(context, 'Aún no has guardado marcas.');
      return;
    }
    SharePlus.instance.share(
      ShareParams(
        subject: 'Marcas de partituras — Loores al Rey',
        text:
            'Marcas de sincronización de partituras (Loores al Rey), '
            '${all.length} himnos:\n\n${AppState.encodeSync(all)}',
      ),
    );
  }

  @override
  void dispose() {
    WakelockPlus.enable(); // la pantalla del himno la sigue necesitando
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final player = context.watch<PlayerService>();
    final media = context.watch<MediaService>();
    // (no usar context.read dentro de build)
    final playingThis =
        player.isCurrent(widget.hymn, _kind) && player.player.playing;
    final secondary = Brand.textoSecundario(context);
    final cantadoMissing =
        media.availability(widget.hymn, MediaKind.cantado) == false;
    final pages = _pages;
    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final leave = await confirm(
          context,
          'Salir sin guardar',
          'Tienes marcas sin guardar. ¿Salir de todas formas?',
          ok: 'Salir',
        );
        if (leave && context.mounted) {
          setState(() => _dirty = false);
          Navigator.pop(context);
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text('Marcar renglones · #${widget.hymn.number}'),
          actions: [
            IconButton(
              tooltip: 'Cómo se marca',
              icon: const Icon(Icons.help_outline_rounded),
              onPressed: () => setState(() => _showHelp = !_showHelp),
            ),
            PopupMenuButton<String>(
              onSelected: (v) {
                if (v == 'compartir') _share();
              },
              itemBuilder: (_) => const [
                PopupMenuItem(
                  value: 'compartir',
                  child: ListTile(
                    leading: Icon(Icons.share_rounded),
                    title: Text('Compartir mis marcas'),
                    subtitle: Text('Para incluirlas en la app'),
                  ),
                ),
              ],
            ),
          ],
        ),
        body: Column(
          children: [
            // Pista con la que se marca.
            Padding(
              padding: const EdgeInsets.fromLTRB(
                Space.gutter,
                Space.s,
                Space.gutter,
                Space.xs,
              ),
              child: SegmentedButton<MediaKind>(
                showSelectedIcon: false,
                segments: [
                  const ButtonSegment(
                    value: MediaKind.instrumental,
                    label: Text('Instrumental'),
                  ),
                  ButtonSegment(
                    value: MediaKind.cantado,
                    label: const Text('Cantado'),
                    enabled: !cantadoMissing,
                  ),
                ],
                selected: {_kind},
                onSelectionChanged: (s) => _changeKind(s.first),
              ),
            ),
            if (_showHelp)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.symmetric(horizontal: Space.gutter),
                padding: const EdgeInsets.all(Space.s),
                decoration: BoxDecoration(
                  color: Brand.crema.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(Space.s),
                ),
                child: const Text(
                  '1. Toca ▶ para que suene la pista.\n'
                  '2. Cada vez que la música empiece un renglón, toca el '
                  'comienzo de ese renglón en la partitura.\n'
                  '3. Si la pista repite la estrofa, vuelve a tocar el primer '
                  'renglón.\n'
                  '4. Al terminar, toca Guardar.',
                  style: TextStyle(
                    fontSize: FontSizes.small,
                    height: 1.4,
                    color: Brand.azul,
                  ),
                ),
              ),
            const SizedBox(height: Space.xs),
            Expanded(
              child: _error != null
                  ? Center(child: Text(_error!, textAlign: TextAlign.center))
                  : pages == null
                  ? const Center(child: CircularProgressIndicator())
                  : ColoredBox(
                      color: Colors.white,
                      child: ScoreCanvas(
                        hymn: widget.hymn,
                        pages: pages,
                        marks: _marks,
                        onTapPage: _tap,
                        showDots: true,
                      ),
                    ),
            ),
          ],
        ),
        bottomNavigationBar: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              Space.gutter,
              Space.xs,
              Space.gutter,
              Space.s,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    IconButton.filled(
                      iconSize: 32,
                      tooltip: playingThis ? 'Pausar' : 'Reproducir',
                      onPressed: player.loading ? null : _playPause,
                      icon: Icon(
                        playingThis
                            ? Icons.pause_rounded
                            : Icons.play_arrow_rounded,
                      ),
                    ),
                    const SizedBox(width: Space.s),
                    Expanded(
                      child: StreamBuilder<Duration>(
                        stream: player.player.positionStream,
                        builder: (context, snap) {
                          final active = player.isCurrent(widget.hymn, _kind);
                          final pos = active
                              ? (snap.data ?? Duration.zero)
                              : Duration.zero;
                          final total = active
                              ? (player.player.duration ?? Duration.zero)
                              : Duration.zero;
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                player.error != null && active
                                    ? player.error!
                                    : '${formatDuration(pos)} / ${formatDuration(total)}',
                                style: const TextStyle(
                                  fontSize: FontSizes.body,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                _marks.isEmpty
                                    ? 'Sin marcas'
                                    : '${_marks.length} renglones marcados',
                                style: TextStyle(
                                  fontSize: FontSizes.caption,
                                  color: secondary,
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                    IconButton(
                      tooltip: 'Deshacer la última marca',
                      onPressed: _marks.isEmpty ? null : _undo,
                      icon: const Icon(Icons.undo_rounded),
                    ),
                    IconButton(
                      tooltip: 'Empezar de nuevo',
                      onPressed: _restart,
                      icon: const Icon(Icons.restart_alt_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: Space.xs),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(Space.touch),
                  ),
                  onPressed: _dirty ? _save : null,
                  icon: const Icon(Icons.check_rounded),
                  label: const Text('Guardar'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
