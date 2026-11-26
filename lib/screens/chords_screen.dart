import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../config.dart';
import '../data/chords_repository.dart';
import '../models/chords.dart';
import '../models/hymn.dart';
import '../services/app_state.dart';
import '../services/chords_playback.dart';
import '../services/media_service.dart';
import '../services/player_service.dart';
import '../theme/app_theme.dart';
import '../widgets/chord_diagram.dart';
import '../widgets/common.dart' show showSnack;
import '../widgets/score_view.dart' show ScorePage, loadScorePages;
import 'chords_stand_screen.dart';

/// Colores de la pantalla de acordes: siempre oscura (se lee mejor en el
/// atril y en templos con poca luz), con la paleta de la IASDMR.
class ChordColors {
  static const fondo = Color(0xFF071A45);
  static const panel = Color(0xFF12306F);
  static const texto = Color(0xFFF2F1EF);
  static const tenue = Color(0xFFB8C0D6);
}

/// Acordes del himno (estilo "Chord ai"): línea de tiempo con la onda y los
/// acordes, diagramas con dedos, letra con acordes sincronizada, partitura
/// que sigue la música, cuadrícula de compases, tono, capo, velocidad y loop.
class ChordsScreen extends StatefulWidget {
  const ChordsScreen({super.key, required this.hymn});
  final Hymn hymn;

  @override
  State<ChordsScreen> createState() => _ChordsScreenState();
}

enum _Tab { acordes, letra, partitura, cuadricula }

class _ChordsScreenState extends State<ChordsScreen> {
  ChordsPlayback? _pb;
  _Tab _tab = _Tab.letra;

  @override
  void initState() {
    super.initState();
    WakelockPlus.enable();
    ChordsRepository.instance.load().then((_) {
      final data = ChordsRepository.instance.get(widget.hymn.id);
      if (!mounted || data == null) return;
      setState(() {
        _pb = ChordsPlayback(widget.hymn, data, context.read<PlayerService>());
        if (!data.hasLyrics) _tab = _Tab.acordes;
      });
    });
  }

  @override
  void dispose() {
    _pb?.dispose();
    super.dispose();
  }

  void _openStand() {
    final pb = _pb;
    if (pb == null) return;
    Navigator.of(context)
        .push(
          MaterialPageRoute<void>(
            fullscreenDialog: true,
            builder: (_) => ChordsStandScreen(playback: pb),
          ),
        )
        .then((_) => WakelockPlus.enable());
  }

  @override
  Widget build(BuildContext context) {
    final pb = _pb;
    final h = widget.hymn;
    final landscape =
        MediaQuery.orientationOf(context) == Orientation.landscape;
    return Theme(
      data: AppTheme.dark().copyWith(
        scaffoldBackgroundColor: ChordColors.fondo,
      ),
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: ChordColors.fondo,
          toolbarHeight: landscape ? 44 : null,
          title: Text(
            '${h.number} · ${h.title}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          actions: [
            _OfflineButton(hymn: h),
            IconButton(
              tooltip: 'Modo atril (pantalla completa)',
              icon: const Icon(Icons.fit_screen_rounded),
              onPressed: pb == null ? null : _openStand,
            ),
          ],
        ),
        body: pb == null
            ? const Center(child: CircularProgressIndicator())
            : ListenableBuilder(
                listenable: pb,
                builder: (context, _) => SafeArea(
                  top: false,
                  child: landscape ? _landscape(pb) : _portrait(pb),
                ),
              ),
      ),
    );
  }

  // ---- vertical: todo apilado ----
  Widget _portrait(ChordsPlayback pb) {
    final tabs = [
      _Tab.acordes,
      if (pb.data.hasLyrics) ...[_Tab.letra, _Tab.partitura],
      _Tab.cuadricula,
    ];
    return Column(
      children: [
        SizedBox(height: 150, child: ChordTimeline(playback: pb)),
        _Options(playback: pb),
        _TabBar(
          tabs: tabs,
          selected: _tab,
          onChanged: (t) => setState(() => _tab = t),
        ),
        Expanded(
          child: _tabBody(
            pb,
            tabs.contains(_tab) ? _tab : tabs.first,
            landscape: false,
          ),
        ),
        _Controls(playback: pb, compact: false),
      ],
    );
  }

  // ---- horizontal: diagramas a la izquierda, letra/partitura a la derecha ----
  Widget _landscape(ChordsPlayback pb) {
    final tabs = [
      if (pb.data.hasLyrics) ...[_Tab.letra, _Tab.partitura],
      _Tab.cuadricula,
    ];
    final tab = tabs.contains(_tab) ? _tab : tabs.first;
    return Column(
      children: [
        Expanded(
          child: Row(
            children: [
              SizedBox(
                width: MediaQuery.sizeOf(context).width * 0.38,
                child: Column(
                  children: [
                    SizedBox(height: 104, child: ChordTimeline(playback: pb)),
                    Expanded(child: CurrentChords(playback: pb, compact: true)),
                    _Options(playback: pb),
                  ],
                ),
              ),
              const VerticalDivider(width: 1, color: Colors.white24),
              Expanded(
                child: Column(
                  children: [
                    _TabBar(
                      tabs: tabs,
                      selected: tab,
                      onChanged: (t) => setState(() => _tab = t),
                    ),
                    Expanded(child: _tabBody(pb, tab, landscape: true)),
                  ],
                ),
              ),
            ],
          ),
        ),
        _Controls(playback: pb, compact: true),
      ],
    );
  }

  Widget _tabBody(ChordsPlayback pb, _Tab tab, {required bool landscape}) =>
      switch (tab) {
        _Tab.acordes => CurrentChords(playback: pb, compact: false),
        _Tab.letra => ChordLyrics(playback: pb),
        _Tab.partitura => _ScoreTab(playback: pb),
        _Tab.cuadricula => _BarsGrid(playback: pb, columns: landscape ? 3 : 2),
      };
}

// ---------------------------------------------------------------------------
// Línea de tiempo: onda + acordes que pasan; se arrastra para adelantar.
// ---------------------------------------------------------------------------

class ChordTimeline extends StatefulWidget {
  const ChordTimeline({super.key, required this.playback});
  final ChordsPlayback playback;

  @override
  State<ChordTimeline> createState() => _ChordTimelineState();
}

class _ChordTimelineState extends State<ChordTimeline> {
  static const pxPerSecond = 90.0;
  final _drag = ValueNotifier<double?>(null);
  double _dragStart = 0;

  @override
  void dispose() {
    _drag.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pb = widget.playback;
    return Semantics(
      label:
          'Línea de tiempo con acordes. Desliza para adelantar o retroceder.',
      child: GestureDetector(
        onHorizontalDragStart: (_) {
          _dragStart = pb.t.value;
          _drag.value = _dragStart;
        },
        onHorizontalDragUpdate: (d) {
          final v = (_drag.value ?? _dragStart) - d.delta.dx / pxPerSecond;
          _drag.value = v.clamp(0, pb.duration > 0 ? pb.duration : 1e6);
        },
        onHorizontalDragEnd: (_) {
          final v = _drag.value;
          _drag.value = null;
          if (v != null) pb.seek(v);
        },
        child: Stack(
          fit: StackFit.expand,
          children: [
            CustomPaint(painter: _TimelinePainter(pb, _drag)),
            Positioned(left: 8, bottom: 8, child: _Badge('𝄞 ${pb.keyLabel}')),
            if (pb.data.tempo != null)
              Positioned(
                right: 8,
                bottom: 8,
                child: _Badge('BPM ${pb.data.tempo}'),
              ),
          ],
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
    decoration: BoxDecoration(
      color: ChordColors.texto,
      borderRadius: BorderRadius.circular(6),
    ),
    child: Text(
      text,
      style: const TextStyle(
        color: Brand.azul,
        fontWeight: FontWeight.w700,
        fontSize: 15,
      ),
    ),
  );
}

class _TimelinePainter extends CustomPainter {
  _TimelinePainter(this.pb, this.drag)
    : super(repaint: Listenable.merge([pb.t, drag, pb]));
  final ChordsPlayback pb;
  final ValueNotifier<double?> drag;

  @override
  void paint(Canvas canvas, Size size) {
    const pps = _ChordTimelineState.pxPerSecond;
    final w = size.width, h = size.height;
    canvas.drawRect(Offset.zero & size, Paint()..color = Colors.black);
    final t = drag.value ?? pb.t.value;
    final cx = w * 0.4;
    final t0 = t - cx / pps, t1 = t + (w - cx) / pps;
    double xOf(double s) => cx + (s - t) * pps;
    const yRuler = 20.0;
    final yTags = h < 120 ? 26.0 : 30.0;
    final tagH = h < 120 ? 24.0 : 28.0;
    final yWave = h * 0.68, hWave = h * 0.26;

    // Loop A-B.
    final a = pb.loopA, b = pb.loopB;
    if (a != null) {
      canvas.drawRect(
        Rect.fromLTRB(xOf(a), yTags, b != null ? xOf(b) : cx, h),
        Paint()..color = Brand.azulClaro.withValues(alpha: 0.25),
      );
    }
    // Regla de tiempo.
    final tick = Paint()
      ..color = Colors.white54
      ..strokeWidth = 1;
    canvas.drawLine(const Offset(0, yRuler), Offset(w, yRuler), tick);
    for (var s = (t0 * 2).ceil() / 2; s < t1; s += 0.5) {
      final x = xOf(s);
      final whole = s == s.roundToDouble();
      canvas.drawLine(
        Offset(x, yRuler),
        Offset(x, yRuler - (whole ? 5 : 2)),
        tick,
      );
      if (whole && s >= 0) {
        _text(canvas, _mmss(s), Offset(x, 2), 10, Colors.white70, center: true);
      }
    }
    // Onda.
    final d = pb.data;
    final step = pps / d.peaksPerSecond;
    final bar = Paint()..color = const Color(0xFFD9D9D9);
    final i0 = (t0 * d.peaksPerSecond).floor().clamp(0, d.peaks.length);
    final i1 = (t1 * d.peaksPerSecond).ceil().clamp(0, d.peaks.length);
    for (var i = i0; i < i1; i++) {
      final x = xOf(i / d.peaksPerSecond);
      final ph = (d.peaks[i] * hWave).clamp(1.5, hWave);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, yWave - ph, step * 0.55, ph * 2),
          const Radius.circular(1),
        ),
        bar,
      );
    }
    // Acordes: etiqueta donde cambia; si se encima, baja una fila.
    final style = pb.style;
    String? prev;
    var lastEnd = -1e9;
    final tagPaint = Paint()..color = Brand.crema;
    for (final (s, c) in d.timeline) {
      final label = style.label(c);
      if (label == prev) continue;
      prev = label;
      if (s < t0 - 4 || s > t1) continue;
      final x = xOf(s);
      final tp = _layout(label, tagH * 0.62, Brand.azul, bold: true);
      final tw = tp.width + 14;
      final row = x < lastEnd + 4 ? 1 : 0;
      final y = yTags + row * (tagH + 3);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, y, tw, tagH),
          const Radius.circular(6),
        ),
        tagPaint,
      );
      tp.paint(canvas, Offset(x + 7, y + (tagH - tp.height) / 2));
      if (row == 0) lastEnd = x + tw;
    }
    // Cabezal.
    canvas.drawLine(
      Offset(cx, yRuler),
      Offset(cx, h),
      Paint()
        ..color = Brand.azulClaro
        ..strokeWidth = 2,
    );
  }

  TextPainter _layout(
    String s,
    double size,
    Color color, {
    bool bold = false,
  }) => TextPainter(
    text: TextSpan(
      text: s,
      style: TextStyle(
        color: color,
        fontSize: size,
        fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
        fontFamily: Brand.fuente,
      ),
    ),
    textDirection: TextDirection.ltr,
  )..layout();

  void _text(
    Canvas c,
    String s,
    Offset at,
    double size,
    Color color, {
    bool center = false,
  }) {
    final tp = _layout(s, size, color);
    tp.paint(c, center ? at - Offset(tp.width / 2, 0) : at);
  }

  @override
  bool shouldRepaint(_TimelinePainter old) => false;
}

String _mmss(double s) {
  final v = s.isFinite && s > 0 ? s : 0;
  return '${v ~/ 60}:${(v % 60).floor().toString().padLeft(2, '0')}';
}

// ---------------------------------------------------------------------------
// Acorde actual y siguiente, con diagramas.
// ---------------------------------------------------------------------------

class CurrentChords extends StatelessWidget {
  const CurrentChords({
    super.key,
    required this.playback,
    required this.compact,
  });
  final ChordsPlayback playback;
  final bool compact;

  /// (actual, siguiente) ya con el estilo aplicado.
  static (String?, String?) nowAndNext(ChordsPlayback pb) {
    final tl = pb.data.timeline;
    final k = pb.chord.value;
    final style = pb.style;
    final now = k >= 0 ? tl[k].$2 : null;
    String? next;
    for (var i = k + 1; i < tl.length; i++) {
      if (now == null || style.label(tl[i].$2) != style.label(now)) {
        next = tl[i].$2;
        break;
      }
    }
    return (now, next);
  }

  @override
  Widget build(BuildContext context) {
    final pb = playback;
    return ListenableBuilder(
      listenable: Listenable.merge([pb.chord, pb]),
      builder: (context, _) {
        final (now, next) = nowAndNext(pb);
        final style = pb.style;
        Widget card(
          String? raw, {
          required bool current,
          required double size,
        }) {
          final chord = raw == null ? null : style.apply(raw);
          return Container(
            padding: const EdgeInsets.symmetric(
              vertical: Space.xs,
              horizontal: Space.xxs,
            ),
            decoration: BoxDecoration(
              color: current ? ChordColors.panel : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  raw == null ? '–' : style.label(raw),
                  style: TextStyle(
                    color: current
                        ? Brand.dorado
                        : Brand.dorado.withValues(alpha: 0.7),
                    fontSize: size * 0.3,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                ChordDiagram(chord: chord, width: size),
              ],
            ),
          );
        }

        return LayoutBuilder(
          builder: (context, box) {
            // El diagrama crece con el espacio, sin pasarse.
            // El recuadro mide: nombre (~0,4 × size) + diagrama (1,1 × size) +
            // márgenes; en horizontal todo debe caber en el alto disponible.
            final size =
                (compact ? (box.maxHeight - 28) / 1.55 : box.maxWidth * 0.36)
                    .clamp(56.0, 170.0);
            final row = Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Semantics(
                  label: 'Ahora',
                  child: card(now, current: true, size: size),
                ),
                Semantics(
                  label: 'Sigue',
                  child: card(next, current: false, size: size * 0.85),
                ),
              ],
            );
            // Por si la letra del sistema es muy grande: nunca se sale del panel.
            if (compact) {
              return Center(child: FittedBox(fit: BoxFit.scaleDown, child: row));
            }
            return ListView(
              padding: const EdgeInsets.all(Space.s),
              children: [
                row,
                const SizedBox(height: Space.m),
                Align(
                  child: TextButton.icon(
                    onPressed: () => _showAll(context, pb),
                    icon: const Icon(Icons.grid_view_rounded),
                    label: const Text('Ver todos los acordes del himno'),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  static void _showAll(BuildContext context, ChordsPlayback pb) {
    final style = pb.style;
    final seen = <String>{};
    final chords = [
      for (final (_, c) in pb.data.timeline)
        if (seen.add(style.label(c))) c,
    ];
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: ChordColors.fondo,
      isScrollControlled: true,
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(Space.m),
          child: SingleChildScrollView(
            child: Wrap(
              spacing: Space.s,
              runSpacing: Space.s,
              alignment: WrapAlignment.center,
              children: [
                for (final c in chords)
                  Container(
                    padding: const EdgeInsets.all(Space.xs),
                    decoration: BoxDecoration(
                      color: ChordColors.panel,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      children: [
                        Text(
                          style.label(c),
                          style: const TextStyle(
                            color: Brand.dorado,
                            fontSize: 20,
                          ),
                        ),
                        ChordDiagram(chord: style.apply(c), width: 90),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Letra con acordes sobre cada sílaba, sincronizada.
// ---------------------------------------------------------------------------

class ChordLyrics extends StatefulWidget {
  const ChordLyrics({super.key, required this.playback});
  final ChordsPlayback playback;

  @override
  State<ChordLyrics> createState() => _ChordLyricsState();
}

class _ChordLyricsState extends State<ChordLyrics> {
  final _scroll = ScrollController();
  late List<GlobalKey> _keys = _makeKeys();
  DateTime _userScroll = DateTime(2000);

  List<GlobalKey> _makeKeys() => [
    for (final _ in widget.playback.data.lines) GlobalKey(),
  ];

  @override
  void initState() {
    super.initState();
    widget.playback.line.addListener(_follow);
  }

  @override
  void didUpdateWidget(ChordLyrics old) {
    super.didUpdateWidget(old);
    if (old.playback != widget.playback) {
      old.playback.line.removeListener(_follow);
      widget.playback.line.addListener(_follow);
      _keys = _makeKeys();
    }
  }

  @override
  void dispose() {
    widget.playback.line.removeListener(_follow);
    _scroll.dispose();
    super.dispose();
  }

  /// Lleva el renglón que se canta a un tercio de la vista (salvo que la
  /// persona esté desplazando la letra a mano).
  void _follow() {
    final l = widget.playback.line.value;
    if (l < 0 || l >= _keys.length) return;
    if (DateTime.now().difference(_userScroll).inSeconds < 4) return;
    final ctx = _keys[l].currentContext;
    if (ctx == null) return;
    Scrollable.ensureVisible(
      ctx,
      alignment: 0.3,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final pb = widget.playback;
    final fontSize = context
        .select<AppState, double>((s) => s.fontSize)
        .clamp(16.0, 34.0);
    final lines = pb.data.lines;
    return NotificationListener<UserScrollNotification>(
      onNotification: (_) {
        _userScroll = DateTime.now();
        return false;
      },
      child: ListenableBuilder(
        listenable: Listenable.merge([pb.line, pb.sung, pb.event, pb]),
        builder: (context, _) {
          final current = pb.line.value;
          final style = pb.style;
          return ListView.builder(
            controller: _scroll,
            padding: const EdgeInsets.fromLTRB(Space.m, Space.xs, Space.m, 120),
            itemCount: lines.length,
            itemBuilder: (context, i) {
              final li = lines[i];
              final showHeader =
                  i == 0 ||
                  lines[i - 1].header != li.header ||
                  lines[i - 1].stanza != li.stanza;
              final state = i == current ? 0 : (i < current ? -1 : 1);
              return Column(
                key: _keys[i],
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (showHeader)
                    Padding(
                      padding: const EdgeInsets.only(
                        top: Space.m,
                        bottom: Space.xxs,
                        left: Space.xs,
                      ),
                      child: Text(
                        li.header.toUpperCase(),
                        style: const TextStyle(
                          color: Brand.dorado,
                          fontSize: 12,
                          letterSpacing: 1.2,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: () => pb.seek(li.start),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(
                        horizontal: Space.xs,
                        vertical: Space.xxs,
                      ),
                      decoration: BoxDecoration(
                        color: state == 0
                            ? ChordColors.panel
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Opacity(
                        opacity: state < 0 ? 0.45 : 1,
                        child: ChordLineText(
                          line: li,
                          style: style,
                          fontSize: fontSize,
                          sung: state == 0
                              ? pb.sung.value
                              : (state < 0 ? li.syllables.length : 0),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

/// Un renglón: palabras que no se cortan, cada sílaba con su acorde encima.
class ChordLineText extends StatelessWidget {
  const ChordLineText({
    super.key,
    required this.line,
    required this.style,
    required this.fontSize,
    this.sung = 0,
    this.chordColor = Brand.crema,
    this.textColor = ChordColors.texto,
    this.sungColor = Brand.dorado,
  });

  final ChordLine line;
  final ChordStyle style;
  final double fontSize;

  /// Cuántas sílabas ya se cantaron (se pintan de [sungColor]).
  final int sung;
  final Color chordColor;
  final Color textColor;
  final Color sungColor;

  @override
  Widget build(BuildContext context) {
    final words = <Widget>[];
    var word = <Widget>[];
    // ¿La palabra que empieza en la sílaba i lleva algún acorde? Si ninguna
    // lleva, no se reserva el renglón de acordes (no quedan huecos).
    bool wordHasChords(int i) {
      for (var j = i; j < line.syllables.length; j++) {
        if (line.syllables[j].chords.isNotEmpty) return true;
        if (!line.syllables[j].joinNext) break;
      }
      return false;
    }

    var chordRow = wordHasChords(0);
    for (final (i, s) in line.syllables.indexed) {
      // Acordes repetidos en la misma sílaba (D y D/A en básico) se ven una vez.
      final labels = <String>[];
      for (final c in s.chords) {
        final l = style.label(c);
        if (labels.isEmpty || labels.last != l) labels.add(l);
      }
      word.add(
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (chordRow)
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Text(
                labels.join(' '),
                style: TextStyle(
                  color: chordColor,
                  fontSize: fontSize * 0.8,
                  fontWeight: FontWeight.w700,
                  height: 1.15,
                ),
              ),
            ),
            Text(
              s.text,
              style: TextStyle(
                color: i < sung ? sungColor : textColor,
                fontSize: fontSize,
                height: 1.2,
              ),
            ),
          ],
        ),
      );
      if (!s.joinNext || i == line.syllables.length - 1) {
        words.add(
          Padding(
            padding: EdgeInsets.only(right: fontSize * 0.3),
            // Una palabra no se corta... salvo que no quepa en todo el ancho
            // (palabra larga con acordes anchos en un celular angosto).
            child: Wrap(
              crossAxisAlignment: WrapCrossAlignment.end,
              children: word,
            ),
          ),
        );
        word = [];
        if (i + 1 < line.syllables.length) chordRow = wordHasChords(i + 1);
      }
    }
    return Semantics(
      label: line.syllables.map((s) => s.text + (s.joinNext ? '' : ' ')).join(),
      child: ExcludeSemantics(
        // Alineadas abajo: las palabras sin acorde quedan a la altura del texto.
        child: Wrap(
          runSpacing: fontSize * 0.25,
          crossAxisAlignment: WrapCrossAlignment.end,
          children: words,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Partitura con marcador sobre el acorde que suena.
// ---------------------------------------------------------------------------

class _ScoreTab extends StatefulWidget {
  const _ScoreTab({required this.playback});
  final ChordsPlayback playback;

  @override
  State<_ScoreTab> createState() => _ScoreTabState();
}

class _ScoreTabState extends State<_ScoreTab> {
  late final Future<List<ScorePage>> _pages = loadScorePages(
    context.read<MediaService>(),
    widget.playback.hymn,
  );
  final _scroll = ScrollController();
  DateTime _userScroll = DateTime(2000);
  List<double> _heights = const [];
  double _viewport = 0;

  @override
  void initState() {
    super.initState();
    widget.playback.event.addListener(_follow);
  }

  @override
  void dispose() {
    widget.playback.event.removeListener(_follow);
    _scroll.dispose();
    super.dispose();
  }

  void _follow() {
    final k = widget.playback.event.value;
    if (k < 0 || !_scroll.hasClients || _heights.isEmpty) return;
    if (DateTime.now().difference(_userScroll).inSeconds < 4) return;
    final e = widget.playback.data.events[k];
    if (e.page >= _heights.length) return;
    final top = _heights.take(e.page).fold<double>(0, (a, b) => a + b);
    final y = top + e.y * _heights[e.page];
    final offset = _scroll.offset;
    // Solo se mueve si el acorde sale del tercio central.
    if (y < offset + _viewport * 0.15 || y > offset + _viewport * 0.7) {
      _scroll.animateTo(
        (y - _viewport * 0.3).clamp(0, _scroll.position.maxScrollExtent),
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<ScorePage>>(
      future: _pages,
      builder: (context, snap) {
        if (snap.hasError) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(Space.xl),
              child: Text(
                'No se pudo cargar la partitura.\nRevisa tu conexión o descárgala para verla sin internet.',
                textAlign: TextAlign.center,
              ),
            ),
          );
        }
        final pages = snap.data;
        if (pages == null) {
          return const Center(child: CircularProgressIndicator());
        }
        return LayoutBuilder(
          builder: (context, box) {
            final width = box.maxWidth - 2 * Space.xs;
            _heights = [for (final p in pages) width / p.aspect + Space.xs];
            _viewport = box.maxHeight;
            return NotificationListener<UserScrollNotification>(
              onNotification: (_) {
                _userScroll = DateTime.now();
                return false;
              },
              child: InteractiveViewer(
                minScale: 1,
                maxScale: 4,
                child: ListView.builder(
                  controller: _scroll,
                  padding: const EdgeInsets.symmetric(horizontal: Space.xs),
                  itemCount: pages.length,
                  itemBuilder: (context, i) => Padding(
                    padding: const EdgeInsets.only(bottom: Space.xs),
                    child: AspectRatio(
                      aspectRatio: pages[i].aspect,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            Image.memory(
                              pages[i].png,
                              fit: BoxFit.fill,
                              gaplessPlayback: true,
                            ),
                            ValueListenableBuilder<int>(
                              valueListenable: widget.playback.event,
                              builder: (context, k, _) {
                                final ev = k >= 0
                                    ? widget.playback.data.events[k]
                                    : null;
                                return CustomPaint(
                                  painter: _ScoreMarkPainter(
                                    ev != null && ev.page == i ? ev : null,
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _ScoreMarkPainter extends CustomPainter {
  _ScoreMarkPainter(this.ev);
  final ChordEvent? ev;

  @override
  void paint(Canvas canvas, Size size) {
    final e = ev;
    if (e == null) return;
    final x = e.x * size.width, y = e.y * size.height;
    final box = Rect.fromLTWH(
      x - size.width * 0.007,
      y - size.height * 0.013,
      size.width * 0.06,
      size.height * 0.024,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(box, const Radius.circular(4)),
      Paint()..color = Brand.dorado.withValues(alpha: 0.3),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(box, const Radius.circular(4)),
      Paint()
        ..color = Brand.dorado
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    canvas.drawLine(
      Offset(x - size.width * 0.004, y + size.height * 0.013),
      Offset(x - size.width * 0.004, y + size.height * 0.165),
      Paint()
        ..color = Brand.azulClaro
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_ScoreMarkPainter old) => old.ev != ev;
}

// ---------------------------------------------------------------------------
// Cuadrícula de compases.
// ---------------------------------------------------------------------------

class _BarsGrid extends StatefulWidget {
  const _BarsGrid({required this.playback, required this.columns});
  final ChordsPlayback playback;
  final int columns;

  @override
  State<_BarsGrid> createState() => _BarsGridState();
}

class _BarsGridState extends State<_BarsGrid> {
  static const rowHeight = 52.0, gap = 6.0;
  final _scroll = ScrollController();
  int _lastRow = -1;

  @override
  void initState() {
    super.initState();
    widget.playback.beat.addListener(_follow);
  }

  @override
  void dispose() {
    widget.playback.beat.removeListener(_follow);
    _scroll.dispose();
    super.dispose();
  }

  void _follow() {
    final b = widget.playback.beat.value;
    if (b < 0 || !_scroll.hasClients) return;
    final row = b ~/ widget.playback.data.beatsPerBar ~/ widget.columns;
    if (row == _lastRow) return;
    _lastRow = row;
    _scroll.animateTo(
      (row * (rowHeight + gap) - _scroll.position.viewportDimension * 0.3)
          .clamp(0, _scroll.position.maxScrollExtent),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final pb = widget.playback;
    final d = pb.data;
    final per = d.beatsPerBar;
    final bars = (d.beats.length / per).ceil();
    return ListenableBuilder(
      listenable: Listenable.merge([pb.beat, pb]),
      builder: (context, _) {
        final style = pb.style;
        // Etiqueta por pulso: solo donde cambia el acorde.
        final labels = <String>[];
        String? prev;
        for (final (t, _) in d.beats) {
          final k = d.chordIndexAt(t + 0.05);
          final l = k >= 0 ? style.label(d.timeline[k].$2) : '';
          labels.add(l.isNotEmpty && l != prev ? l : '');
          if (l.isNotEmpty) prev = l;
        }
        final now = pb.beat.value;
        return GridView.builder(
          controller: _scroll,
          padding: const EdgeInsets.all(Space.xs),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: widget.columns,
            mainAxisExtent: rowHeight,
            mainAxisSpacing: gap,
            crossAxisSpacing: gap,
          ),
          itemCount: bars,
          itemBuilder: (context, bar) => ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: ColoredBox(
              color: ChordColors.panel,
              child: Row(
                children: [
                  for (var j = 0; j < per; j++)
                    if (bar * per + j < d.beats.length)
                      Expanded(
                        child: _beatCell(
                          pb,
                          bar * per + j,
                          labels[bar * per + j],
                          now,
                        ),
                      )
                    else
                      const Spacer(),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _beatCell(ChordsPlayback pb, int i, String label, int now) {
    final isNow = i == now;
    return InkWell(
      onTap: () => pb.seek(pb.data.beats[i].$1),
      child: Container(
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.only(left: 4),
        decoration: BoxDecoration(
          color: isNow ? Brand.azulClaro.withValues(alpha: 0.35) : null,
          border: Border(
            left: BorderSide(
              color: isNow ? Brand.dorado : Colors.white12,
              width: isNow ? 3 : 1,
            ),
          ),
        ),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.clip,
          style: TextStyle(
            color: i < now ? Brand.crema.withValues(alpha: 0.45) : Brand.crema,
            fontWeight: FontWeight.w700,
            fontSize: 15,
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Opciones, pestañas y controles.
// ---------------------------------------------------------------------------

class _Options extends StatelessWidget {
  const _Options({required this.playback});
  final ChordsPlayback playback;

  @override
  Widget build(BuildContext context) {
    final pb = playback;
    final seg = ButtonStyle(
      visualDensity: VisualDensity.compact,
      textStyle: const WidgetStatePropertyAll(TextStyle(fontSize: 13)),
      foregroundColor: WidgetStateProperty.resolveWith(
        (s) =>
            s.contains(WidgetState.selected) ? Brand.azul : ChordColors.texto,
      ),
      backgroundColor: WidgetStateProperty.resolveWith(
        (s) =>
            s.contains(WidgetState.selected) ? Brand.crema : Colors.transparent,
      ),
    );
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: Space.xs,
        vertical: Space.xxs,
      ),
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: Space.xs,
        runSpacing: Space.xxs,
        children: [
          SegmentedButton<bool>(
            style: seg,
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(
                value: true,
                label: Text('Básico'),
                tooltip: 'Solo mayores y menores',
              ),
              ButtonSegment(
                value: false,
                label: Text('Todos'),
                tooltip: 'Con séptimas e inversiones',
              ),
            ],
            selected: {pb.settings.basic},
            onSelectionChanged: (s) => pb.setBasic(s.first),
          ),
          SegmentedButton<bool>(
            style: seg,
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(value: false, label: Text('C D E')),
              ButtonSegment(value: true, label: Text('Do Re Mi')),
            ],
            selected: {pb.settings.latin},
            onSelectionChanged: (s) => pb.setLatin(s.first),
          ),
        ],
      ),
    );
  }
}

class _TabBar extends StatelessWidget {
  const _TabBar({
    required this.tabs,
    required this.selected,
    required this.onChanged,
  });
  final List<_Tab> tabs;
  final _Tab selected;
  final ValueChanged<_Tab> onChanged;

  static const _labels = {
    _Tab.acordes: 'Acordes',
    _Tab.letra: 'Letra',
    _Tab.partitura: 'Partitura',
    _Tab.cuadricula: 'Compases',
  };

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final t in tabs)
          Expanded(
            child: Semantics(
              selected: t == selected,
              button: true,
              child: InkWell(
                onTap: () => onChanged(t),
                child: Container(
                  height: Space.touch,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: t == selected ? Brand.dorado : Colors.white12,
                        width: t == selected ? 2.5 : 1,
                      ),
                    ),
                  ),
                  child: Text(
                    _labels[t]!,
                    style: TextStyle(
                      color: t == selected ? Brand.dorado : ChordColors.tenue,
                      fontWeight: t == selected
                          ? FontWeight.w700
                          : FontWeight.w400,
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

enum _Tool { tono, capo, velocidad, loop }

/// Reproductor: play, progreso y herramientas (Tono, Capo, Velocidad, Loop).
class _Controls extends StatefulWidget {
  const _Controls({required this.playback, required this.compact});
  final ChordsPlayback playback;
  final bool compact;

  @override
  State<_Controls> createState() => _ControlsState();
}

class _ControlsState extends State<_Controls> {
  _Tool? _tool;

  @override
  Widget build(BuildContext context) {
    final pb = widget.playback;
    final player = context.watch<PlayerService>();
    final active = pb.isActive;
    final playing = active && player.playing;
    final busy = active && player.loading;
    final error = active ? player.error : null;

    final play = SizedBox(
      width: 52,
      height: 52,
      child: Material(
        color: Brand.dorado,
        shape: const CircleBorder(),
        child: busy
            ? const Padding(
                padding: EdgeInsets.all(14),
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: Brand.azul,
                ),
              )
            : IconButton(
                tooltip: playing ? 'Pausar' : 'Reproducir pista instrumental',
                icon: Icon(
                  playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                  color: Brand.azul,
                  size: 30,
                ),
                onPressed: pb.togglePlay,
              ),
      ),
    );
    final progress = ValueListenableBuilder<double>(
      valueListenable: pb.t,
      builder: (context, t, _) {
        final total = pb.duration;
        return Row(
          children: [
            Expanded(
              child: SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  trackHeight: 3,
                  thumbShape: const RoundSliderThumbShape(
                    enabledThumbRadius: 7,
                  ),
                ),
                child: Slider(
                  value: total <= 0 ? 0 : t.clamp(0, total),
                  max: total <= 0 ? 1 : total,
                  activeColor: Brand.dorado,
                  inactiveColor: Colors.white24,
                  onChanged: total <= 0 ? null : pb.seek,
                ),
              ),
            ),
            Text(
              '${_mmss(t)} / ${_mmss(total)}',
              style: const TextStyle(
                fontSize: 12,
                color: ChordColors.tenue,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
          ],
        );
      },
    );
    final tools = Wrap(
      spacing: Space.xxs,
      children: [
        _chip(
          _Tool.tono,
          'Tono',
          pb.pitch == 0 ? '0' : (pb.pitch > 0 ? '+${pb.pitch}' : '${pb.pitch}'),
        ),
        _chip(_Tool.capo, 'Capo', pb.capo == 0 ? 'No' : '${pb.capo}'),
        _chip(_Tool.velocidad, 'Velocidad', '${(pb.speed * 100).round()}%'),
        _chip(
          _Tool.loop,
          'Loop',
          pb.loopB != null ? 'A-B' : (pb.loopA != null ? 'A…' : 'No'),
        ),
      ],
    );
    return Material(
      color: Brand.azul,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          Space.s,
          Space.xs,
          Space.s,
          Space.xs,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_tool != null) _adjuster(pb),
            if (error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: Space.xxs),
                child: Text(
                  error,
                  style: const TextStyle(color: Brand.coral, fontSize: 13),
                ),
              ),
            if (widget.compact)
              Row(
                children: [
                  play,
                  const SizedBox(width: Space.xs),
                  Expanded(child: progress),
                  const SizedBox(width: Space.xs),
                  tools,
                ],
              )
            else ...[
              Row(
                children: [
                  play,
                  const SizedBox(width: Space.xs),
                  Expanded(child: progress),
                ],
              ),
              const SizedBox(height: Space.xxs),
              tools,
            ],
          ],
        ),
      ),
    );
  }

  Widget _chip(_Tool t, String label, String value) {
    final on = _tool == t;
    return Tooltip(
      message: label,
      child: ChoiceChip(
        selected: on,
        showCheckmark: false,
        visualDensity: VisualDensity.compact,
        label: Text(
          '$label $value',
          style: TextStyle(
            fontSize: 12.5,
            color: on ? Brand.azul : ChordColors.texto,
          ),
        ),
        selectedColor: Brand.dorado,
        backgroundColor: ChordColors.panel,
        side: BorderSide.none,
        onSelected: (_) => setState(() => _tool = on ? null : t),
      ),
    );
  }

  Widget _adjuster(ChordsPlayback pb) {
    Widget round(IconData icon, String tip, VoidCallback onTap) => IconButton(
      tooltip: tip,
      onPressed: onTap,
      icon: Icon(icon),
      style: IconButton.styleFrom(
        side: const BorderSide(color: Colors.white38),
        minimumSize: const Size(44, 44),
      ),
    );
    Widget value(String s) => SizedBox(
      width: 150,
      child: Text(
        s,
        textAlign: TextAlign.center,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
    );
    final row = switch (_tool!) {
      _Tool.tono => [
        round(
          Icons.remove,
          'Bajar medio tono',
          () => pb.setPitch(pb.pitch - 1),
        ),
        value(
          pb.pitch == 0
              ? 'Tono original'
              : '${pb.pitch > 0 ? '+' : ''}${pb.pitch} semitono${pb.pitch.abs() == 1 ? '' : 's'}',
        ),
        round(Icons.add, 'Subir medio tono', () => pb.setPitch(pb.pitch + 1)),
      ],
      _Tool.capo => [
        round(Icons.remove, 'Bajar capo', () => pb.setCapo(pb.capo - 1)),
        value(pb.capo == 0 ? 'Sin capo' : 'Capo en traste ${pb.capo}'),
        round(Icons.add, 'Subir capo', () => pb.setCapo(pb.capo + 1)),
        if (pb.capo != pb.suggestedCapoValue)
          TextButton(
            onPressed: () => pb.setCapo(pb.suggestedCapoValue),
            child: Text(
              pb.suggestedCapoValue == 0
                  ? 'Sugerido: sin capo'
                  : 'Sugerido: ${pb.suggestedCapoValue}',
            ),
          ),
      ],
      _Tool.velocidad => [
        round(Icons.remove, 'Más lento', () => pb.setSpeed(pb.speed - 0.05)),
        value('Velocidad ${(pb.speed * 100).round()}%'),
        round(Icons.add, 'Más rápido', () => pb.setSpeed(pb.speed + 0.05)),
      ],
      _Tool.loop => [
        FilledButton.tonalIcon(
          onPressed: pb.toggleLoop,
          icon: const Icon(Icons.repeat_rounded),
          label: Text(
            pb.loopA == null
                ? 'Marcar inicio (A)'
                : (pb.loopB == null ? 'Marcar fin (B)' : 'Quitar repetición'),
          ),
        ),
      ],
    };
    return Padding(
      padding: const EdgeInsets.only(bottom: Space.xxs),
      child: Wrap(
        alignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: Space.xs,
        children: row,
      ),
    );
  }
}

/// Descarga la pista instrumental y la partitura para tocar sin internet.
/// Si ya están (aquí o en la otra app de la familia) lo indica.
class _OfflineButton extends StatelessWidget {
  const _OfflineButton({required this.hymn});
  final Hymn hymn;

  static const _kinds = [MediaKind.instrumental, MediaKind.partitura];

  @override
  Widget build(BuildContext context) {
    final media = context.watch<MediaService>();
    final busy = _kinds.any((k) => media.isDownloading(hymn, k));
    final ready = _kinds.every((k) => media.isOffline(hymn, k));
    final shared = _kinds.any((k) => media.isShared(hymn, k));
    if (busy) {
      return const Padding(
        padding: EdgeInsets.all(Space.s),
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(strokeWidth: 2.5),
        ),
      );
    }
    return IconButton(
      tooltip: ready
          ? (shared
                ? 'Disponible sin conexión (descargado en ${otherAppName()})'
                : 'Disponible sin conexión')
          : 'Descargar pista y partitura para usar sin internet',
      icon: Icon(
        ready ? Icons.offline_pin_rounded : Icons.download_rounded,
        color: ready ? Brand.dorado : null,
      ),
      onPressed: () async {
        if (ready) {
          showSnack(
            context,
            shared
                ? 'Ya está descargado en ${otherAppName()}: se usa sin volver a descargarlo.'
                : 'La pista y la partitura ya están en el teléfono.',
          );
          return;
        }
        try {
          for (final k in _kinds) {
            if (!media.isOffline(hymn, k)) await media.download(hymn, k);
          }
          if (context.mounted) showSnack(context, 'Listo para usar sin internet');
        } on MediaNotAvailable catch (e) {
          if (context.mounted) showSnack(context, e.message);
        } catch (_) {
          if (context.mounted) {
            showSnack(context, 'No se pudo descargar. Revisa tu conexión.');
          }
        }
      },
    );
  }
}
