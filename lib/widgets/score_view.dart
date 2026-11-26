import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:pdfx/pdfx.dart';
import 'package:provider/provider.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../models/hymn.dart';
import '../models/score_sync.dart';
import '../screens/score_sync_screen.dart';
import '../services/app_state.dart';
import '../services/media_service.dart';
import '../services/player_service.dart';
import '../theme/app_theme.dart';

// ---------------------------------------------------------------------------
// Carga de la partitura (archivo descargado o servidor) a imágenes por página.
// ---------------------------------------------------------------------------

/// Una página de la partitura ya dibujada.
class ScorePage {
  final Uint8List png;

  /// ancho / alto
  final double aspect;
  const ScorePage(this.png, this.aspect);
}

/// Páginas dibujadas en esta sesión (las últimas 4 partituras), para no
/// volver a descargarlas ni dibujarlas al cambiar de vista.
final Map<String, List<ScorePage>> _cache = {};

Future<List<ScorePage>> loadScorePages(MediaService media, Hymn hymn) async {
  final local = media.localFile(hymn, MediaKind.partitura);
  final shared = media.isShared(hymn, MediaKind.partitura);
  final url = media.remoteUrl(hymn, MediaKind.partitura);
  final key = local?.path ?? (shared ? 'compartida-${hymn.id}' : url);
  if (key == null) {
    throw const MediaNotAvailable('Partitura aún no disponible.');
  }
  final cached = _cache.remove(key);
  if (cached != null) return _cache[key] = cached;

  // La partitura que descargó la otra app (Loores al Rey / Acordes IASDMR).
  final sharedBytes = local == null && shared
      ? await media.readShared(hymn, MediaKind.partitura)
      : null;
  final PdfDocument doc;
  if (local != null) {
    doc = await PdfDocument.openFile(local.path);
  } else if (sharedBytes != null) {
    doc = await PdfDocument.openData(sharedBytes);
  } else {
    final res = await http
        .get(Uri.parse(url!))
        .timeout(const Duration(seconds: 25));
    if (res.statusCode == 404) {
      throw const MediaNotAvailable('Partitura aún no disponible.');
    }
    if (res.statusCode != 200) throw Exception('HTTP ${res.statusCode}');
    doc = await PdfDocument.openData(Uint8List.fromList(res.bodyBytes));
  }
  final pages = <ScorePage>[];
  try {
    for (var i = 1; i <= doc.pagesCount; i++) {
      final page = await doc.getPage(i);
      try {
        // 1600 px de ancho: nítido con zoom sin gastar demasiada memoria.
        const w = 1600.0;
        final h = w * page.height / page.width;
        final img = await page.render(
          width: w,
          height: h,
          format: PdfPageImageFormat.png,
          backgroundColor: '#FFFFFF',
        );
        if (img != null) {
          pages.add(ScorePage(img.bytes, page.width / page.height));
        }
      } finally {
        await page.close();
      }
    }
  } finally {
    await doc.close();
  }
  _cache[key] = pages;
  while (_cache.length > 4) {
    _cache.remove(_cache.keys.first);
  }
  return pages;
}

// ---------------------------------------------------------------------------
// Visor con zoom, rayita que sigue el audio y (opcional) marcas.
// ---------------------------------------------------------------------------

/// Partitura con zoom. Si el himno está sonando y tiene marcas, una rayita
/// sigue el audio renglón por renglón y la vista se desplaza sola.
///
/// [marks] fuerza unas marcas (modo marcar); si es null se usan las
/// guardadas para lo que esté sonando. [onTapPage] recibe los toques (modo
/// marcar) y [showDots] dibuja las marcas numeradas.
class ScoreCanvas extends StatefulWidget {
  const ScoreCanvas({
    super.key,
    required this.hymn,
    required this.pages,
    this.marks,
    this.onTapPage,
    this.showDots = false,
  });

  final Hymn hymn;
  final List<ScorePage> pages;
  final List<SyncMark>? marks;
  final void Function(int page, double x, double y)? onTapPage;
  final bool showDots;

  @override
  State<ScoreCanvas> createState() => _ScoreCanvasState();
}

class _ScoreCanvasState extends State<ScoreCanvas>
    with SingleTickerProviderStateMixin {
  final _transform = TransformationController();
  late final AnimationController _anim = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 450),
  );
  Animation<Matrix4>? _tween;
  DateTime _lastTouch = DateTime(2000);
  int _lastMark = -1;
  Size _viewport = Size.zero;

  @override
  void initState() {
    super.initState();
    _anim.addListener(() {
      final t = _tween;
      if (t != null) _transform.value = t.value;
    });
  }

  @override
  void dispose() {
    _anim.dispose();
    _transform.dispose();
    super.dispose();
  }

  /// Alto de cada página dibujada con el ancho de la vista.
  List<double> _pageHeights(double width) => [
    for (final p in widget.pages) width / p.aspect,
  ];

  /// Lleva el renglón que suena a la parte superior de la vista, salvo que
  /// la persona haya tocado la partitura hace poco (no se le quita el control).
  void _follow(CursorPos c) {
    if (c.mark == _lastMark) return;
    _lastMark = c.mark;
    if (DateTime.now().difference(_lastTouch).inSeconds < 5) return;
    if (_viewport == Size.zero) return;
    final heights = _pageHeights(_viewport.width);
    if (c.page >= heights.length) return;
    final pageTop = heights.take(c.page).fold<double>(0, (a, b) => a + b);
    final scale = _transform.value.getMaxScaleOnAxis();
    final total = heights.fold<double>(0, (a, b) => a + b) * scale;
    final y = (pageTop + c.top * heights[c.page]) * scale;
    final current = _transform.value.clone();
    final tx = current.getTranslation().x;
    var ty = -(y - _viewport.height * 0.15);
    final minTy = -(total - _viewport.height).clamp(0.0, double.infinity);
    ty = ty.clamp(minTy, 0.0);
    final target = Matrix4.identity()
      ..translateByDouble(tx, ty, 0, 1)
      ..scaleByDouble(scale, scale, 1, 1);
    _tween = Matrix4Tween(
      begin: current,
      end: target,
    ).animate(CurvedAnimation(parent: _anim, curve: Curves.easeInOut));
    _anim.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        _viewport = box.biggest;
        final heights = _pageHeights(box.maxWidth);
        return InteractiveViewer(
          transformationController: _transform,
          constrained: false,
          minScale: 1,
          maxScale: 6,
          onInteractionStart: (_) {
            _lastTouch = DateTime.now();
            _anim.stop();
          },
          child: SizedBox(
            width: box.maxWidth,
            child: Column(
              children: [
                for (var i = 0; i < widget.pages.length; i++)
                  SizedBox(
                    height: heights[i],
                    width: box.maxWidth,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Image.memory(
                          widget.pages[i].png,
                          fit: BoxFit.fill,
                          gaplessPlayback: true,
                          filterQuality: FilterQuality.medium,
                        ),
                        _CursorLayer(
                          hymn: widget.hymn,
                          page: i,
                          marks: widget.marks,
                          showDots: widget.showDots,
                          onCursor: _follow,
                        ),
                        if (widget.onTapPage != null)
                          GestureDetector(
                            behavior: HitTestBehavior.translucent,
                            onTapUp: (d) => widget.onTapPage!(
                              i,
                              d.localPosition.dx / box.maxWidth,
                              d.localPosition.dy / heights[i],
                            ),
                          ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Dibuja la rayita (y las marcas) sobre una página, siguiendo el audio.
class _CursorLayer extends StatelessWidget {
  const _CursorLayer({
    required this.hymn,
    required this.page,
    required this.marks,
    required this.showDots,
    required this.onCursor,
  });

  final Hymn hymn;
  final int page;
  final List<SyncMark>? marks;
  final bool showDots;
  final void Function(CursorPos) onCursor;

  @override
  Widget build(BuildContext context) {
    final player = context.watch<PlayerService>();
    final state = context.watch<AppState>();
    final playingThis = player.current?.id == hymn.id && player.kind.isAudio;
    final kind = playingThis ? player.kind : MediaKind.instrumental;
    final list = marks ?? state.syncFor(ScoreSync.key(hymn.id, kind.name));
    if (list.isEmpty) return const SizedBox.shrink();
    // Marcas de esta página con su número global (1, 2, 3… en orden de toque).
    final dots = showDots
        ? [
            for (final (i, m) in list.indexed)
              if (m.page == page) (i + 1, m),
          ]
        : null;
    if (!playingThis) {
      return dots == null
          ? const SizedBox.shrink()
          : CustomPaint(painter: _ScorePainter(null, dots));
    }
    return StreamBuilder<Duration>(
      stream: player.player.positionStream,
      builder: (context, snap) {
        final c = ScoreSync.at(
          list,
          snap.data ?? Duration.zero,
          total: player.player.duration,
        );
        if (c != null && c.page == page) {
          WidgetsBinding.instance.addPostFrameCallback((_) => onCursor(c));
        }
        return CustomPaint(
          painter: _ScorePainter(c?.page == page ? c : null, dots),
        );
      },
    );
  }
}

class _ScorePainter extends CustomPainter {
  _ScorePainter(this.cursor, this.dots);
  final CursorPos? cursor;
  final List<(int, SyncMark)>? dots;

  @override
  void paint(Canvas canvas, Size size) {
    final c = cursor;
    if (c != null) {
      final x = c.x * size.width;
      final top = c.top * size.height;
      final bottom = c.bottom * size.height;
      // Franja suave + línea firme: se ve sin tapar las notas.
      canvas.drawRect(
        Rect.fromLTRB(x - 10, top, x + 10, bottom),
        Paint()..color = Brand.azulClaro.withValues(alpha: 0.18),
      );
      canvas.drawLine(
        Offset(x, top),
        Offset(x, bottom),
        Paint()
          ..color = Brand.coral
          ..strokeWidth = 3
          ..strokeCap = StrokeCap.round,
      );
    }
    final d = dots;
    if (d == null) return;
    for (final (n, m) in d) {
      final p = Offset(m.x * size.width, m.y * size.height);
      canvas.drawCircle(p, 14, Paint()..color = Brand.azul);
      final tp = TextPainter(
        text: TextSpan(
          text: '$n',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, p - Offset(tp.width / 2, tp.height / 2));
    }
  }

  @override
  bool shouldRepaint(_ScorePainter old) =>
      old.cursor?.x != cursor?.x ||
      old.cursor?.page != cursor?.page ||
      old.dots?.length != dots?.length;
}

// ---------------------------------------------------------------------------
// Pestaña "Partituras" del himno.
// ---------------------------------------------------------------------------

/// Visor de la pestaña Partituras: carga, errores, "Ver completa" y acceso
/// al modo marcar.
class ScoreView extends StatefulWidget {
  const ScoreView({super.key, required this.hymn, this.allowFullScreen = true});
  final Hymn hymn;
  final bool allowFullScreen;

  @override
  State<ScoreView> createState() => _ScoreViewState();
}

class _ScoreViewState extends State<ScoreView> {
  List<ScorePage>? _pages;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final pages = await loadScorePages(
        context.read<MediaService>(),
        widget.hymn,
      );
      if (mounted) setState(() => _pages = pages);
    } on MediaNotAvailable catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'No se pudo cargar la partitura.\nRevisa tu conexión o descárgala para verla sin internet.',
        );
      }
    }
  }

  void _openFullScreen() => Navigator.of(context).push(
    MaterialPageRoute<void>(
      fullscreenDialog: true,
      builder: (_) => ScoreFullScreen(hymn: widget.hymn),
    ),
  );

  void _openMarking() => Navigator.of(context).push(
    MaterialPageRoute<void>(builder: (_) => ScoreSyncScreen(hymn: widget.hymn)),
  );

  @override
  Widget build(BuildContext context) {
    final pages = _pages;
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(Space.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.music_off, size: 48, color: Brand.gris),
              const SizedBox(height: Space.s),
              Text(_error!, textAlign: TextAlign.center),
            ],
          ),
        ),
      );
    }
    if (pages == null) return const Center(child: CircularProgressIndicator());
    final state = context.watch<AppState>();
    final synced = state
        .syncFor(ScoreSync.key(widget.hymn.id, MediaKind.instrumental.name))
        .isNotEmpty;
    return ColoredBox(
      color: Colors.white,
      child: Stack(
        children: [
          Positioned.fill(
            child: ScoreCanvas(hymn: widget.hymn, pages: pages),
          ),
          if (widget.allowFullScreen)
            Positioned(
              top: Space.s,
              left: Space.s,
              right: Space.s,
              child: Row(
                children: [
                  _Pill(
                    icon: synced
                        ? Icons.timeline_rounded
                        : Icons.touch_app_rounded,
                    label: synced ? 'Sigue el audio' : 'Marcar renglones',
                    tooltip: synced
                        ? 'Volver a marcar los renglones'
                        : 'Marcar los renglones para que la partitura siga el audio',
                    filled: false,
                    onTap: _openMarking,
                  ),
                  const Spacer(),
                  _Pill(
                    icon: Icons.fullscreen_rounded,
                    label: 'Ver completa',
                    tooltip: 'Ver la partitura en pantalla completa',
                    onTap: _openFullScreen,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({
    required this.icon,
    required this.label,
    required this.tooltip,
    required this.onTap,
    this.filled = true,
  });
  final IconData icon;
  final String label;
  final String tooltip;
  final VoidCallback onTap;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final fg = filled ? Colors.white : Brand.azul;
    return Tooltip(
      message: tooltip,
      child: Material(
        color: filled ? Brand.azul : Colors.white,
        shape: StadiumBorder(
          side: filled ? BorderSide.none : const BorderSide(color: Brand.azul),
        ),
        elevation: 3,
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 44),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: Space.m),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, color: fg, size: 20),
                  const SizedBox(width: Space.xs),
                  Text(
                    label,
                    style: TextStyle(color: fg, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Pantalla completa.
// ---------------------------------------------------------------------------

/// Partitura a pantalla completa: sin barras del sistema, se puede girar el
/// teléfono, la pantalla no se apaga y hay play/pausa (la rayita sigue).
class ScoreFullScreen extends StatefulWidget {
  const ScoreFullScreen({super.key, required this.hymn});
  final Hymn hymn;

  @override
  State<ScoreFullScreen> createState() => _ScoreFullScreenState();
}

class _ScoreFullScreenState extends State<ScoreFullScreen> {
  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    WakelockPlus.enable();
  }

  @override
  void dispose() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setPreferredOrientations(const []);
    // La pantalla del himno sigue necesitando la pantalla encendida.
    WakelockPlus.enable();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final player = context.watch<PlayerService>();
    final h = widget.hymn;
    final playingThis = player.current?.id == h.id && player.playing;
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          Positioned.fill(child: ScoreView(hymn: h, allowFullScreen: false)),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(Space.s),
              child: Row(
                children: [
                  _RoundIcon(
                    icon: Icons.fullscreen_exit_rounded,
                    tooltip: 'Cerrar vista completa',
                    onTap: () => Navigator.pop(context),
                  ),
                  const SizedBox(width: Space.s),
                  _RoundIcon(
                    icon: playingThis
                        ? Icons.pause_rounded
                        : Icons.play_arrow_rounded,
                    tooltip: playingThis ? 'Pausar' : 'Reproducir',
                    onTap: () => playingThis
                        ? player.toggle()
                        : player.play(
                            h,
                            player.current?.id == h.id
                                ? player.kind
                                : MediaKind.instrumental,
                          ),
                  ),
                  const SizedBox(width: Space.s),
                  Flexible(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: Space.s,
                        vertical: Space.xs,
                      ),
                      decoration: BoxDecoration(
                        color: Brand.azul.withValues(alpha: 0.85),
                        borderRadius: BorderRadius.circular(Space.m),
                      ),
                      child: Text(
                        '${h.number}. ${h.title}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RoundIcon extends StatelessWidget {
  const _RoundIcon({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: Brand.azul,
    shape: const CircleBorder(),
    elevation: 3,
    child: IconButton(
      tooltip: tooltip,
      color: Colors.white,
      icon: Icon(icon),
      onPressed: onTap,
    ),
  );
}
