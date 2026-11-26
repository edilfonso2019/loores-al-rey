import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../services/chords_playback.dart';
import '../theme/app_theme.dart';
import '../widgets/chord_diagram.dart';
import 'chords_screen.dart';

/// Modo atril: pantalla completa en negro, el acorde que suena en grande con
/// su diagrama, el renglón que se canta y el siguiente. Se puede girar:
/// en horizontal el acorde va a la izquierda y la letra a la derecha.
/// Tocar la letra pausa o reanuda.
class ChordsStandScreen extends StatefulWidget {
  const ChordsStandScreen({super.key, required this.playback});
  final ChordsPlayback playback;

  @override
  State<ChordsStandScreen> createState() => _ChordsStandScreenState();
}

class _ChordsStandScreenState extends State<ChordsStandScreen> {
  /// Escala de la letra (A− / A+), relativa al alto disponible.
  double _scale = 1;

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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pb = widget.playback;
    final size = MediaQuery.sizeOf(context);
    final landscape = size.width > size.height;
    // Letra: proporcional al lado corto (en horizontal deben verse el renglón
    // actual y el siguiente), ajustable con A− / A+.
    final font = (size.shortestSide / (landscape ? 12 : 11) * _scale).clamp(
      18.0,
      80.0,
    );
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: ListenableBuilder(
          listenable: Listenable.merge([pb.line, pb.sung, pb.chord, pb]),
          builder: (context, _) {
            final (now, next) = CurrentChords.nowAndNext(pb);
            final style = pb.style;
            final chordName = Text(
              now == null ? '–' : style.label(now),
              style: TextStyle(
                color: Brand.dorado,
                fontWeight: FontWeight.w800,
                fontSize: (landscape ? size.height * 0.2 : size.width * 0.18)
                    .clamp(40, 120),
                height: 1,
              ),
            );
            final nextName = Text(
              next == null ? '' : 'Sigue: ${style.label(next)}',
              style: TextStyle(
                color: Colors.white60,
                fontSize: (font * 0.6).clamp(16, 32),
              ),
            );
            final diagram = ChordDiagram(
              chord: now == null ? null : style.apply(now),
              width: landscape ? size.height * 0.36 : size.width * 0.26,
            );
            final lyrics = GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: pb.togglePlay,
              child: _lyrics(pb, font),
            );
            final body = landscape
                ? Row(
                    children: [
                      SizedBox(
                        width: size.width * 0.3,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            chordName,
                            const SizedBox(height: Space.xs),
                            diagram,
                            const SizedBox(height: Space.xs),
                            nextName,
                          ],
                        ),
                      ),
                      // Arriba queda espacio para los botones.
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(top: 56),
                          child: lyrics,
                        ),
                      ),
                    ],
                  )
                : Column(
                    children: [
                      // En vertical, los botones van en su propia fila.
                      const SizedBox(height: 56),
                      Padding(
                        padding: const EdgeInsets.only(left: Space.xs),
                        child: Row(
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [chordName, nextName],
                            ),
                            const SizedBox(width: Space.m),
                            diagram,
                          ],
                        ),
                      ),
                      Expanded(child: lyrics),
                    ],
                  );
            return Stack(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    Space.m,
                    Space.s,
                    Space.m,
                    Space.m,
                  ),
                  child: body,
                ),
                Positioned(top: Space.xs, right: Space.xs, child: _buttons(pb)),
                Positioned(left: 0, right: 0, bottom: 0, child: _progress(pb)),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _lyrics(ChordsPlayback pb, double font) {
    final lines = pb.data.lines;
    final l = pb.line.value;
    if (lines.isEmpty) {
      return const Center(
        child: Text(
          'Este himno aún no tiene la letra con acordes.',
          style: TextStyle(color: Colors.white60),
        ),
      );
    }
    final i = l < 0 ? 0 : l;
    final li = lines[i];
    final next = i + 1 < lines.length ? lines[i + 1] : null;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l < 0 ? 'INTRODUCCIÓN' : li.header.toUpperCase(),
          style: const TextStyle(
            color: Brand.dorado,
            letterSpacing: 1.5,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: Space.xs),
        ChordLineText(
          line: li,
          style: pb.style,
          fontSize: font,
          sung: l < 0 ? 0 : pb.sung.value,
          chordColor: Brand.dorado,
          textColor: Colors.white,
          sungColor: Brand.crema,
        ),
        if (next != null) ...[
          SizedBox(height: font * 0.7),
          Opacity(
            opacity: 0.4,
            child: ChordLineText(
              line: next,
              style: pb.style,
              fontSize: font * 0.62,
              chordColor: Brand.dorado,
              textColor: Colors.white,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buttons(ChordsPlayback pb) {
    Widget b(String tip, Widget icon, VoidCallback onTap) => Padding(
      padding: const EdgeInsets.only(left: Space.xxs),
      child: IconButton(
        tooltip: tip,
        onPressed: onTap,
        icon: icon,
        color: Colors.white,
        style: IconButton.styleFrom(
          side: const BorderSide(color: Colors.white38),
          minimumSize: const Size(44, 44),
        ),
      ),
    );
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        b(
          'Letra más chica',
          const Text('A−', style: TextStyle(color: Colors.white)),
          () => setState(() => _scale = (_scale - 0.12).clamp(0.6, 1.8)),
        ),
        b(
          'Letra más grande',
          const Text('A+', style: TextStyle(color: Colors.white)),
          () => setState(() => _scale = (_scale + 0.12).clamp(0.6, 1.8)),
        ),
        b(
          pb.playing ? 'Pausar' : 'Reproducir',
          Icon(pb.playing ? Icons.pause_rounded : Icons.play_arrow_rounded),
          pb.togglePlay,
        ),
        b(
          'Salir del modo atril',
          const Icon(Icons.close_rounded),
          () => Navigator.pop(context),
        ),
      ],
    );
  }

  Widget _progress(ChordsPlayback pb) => ValueListenableBuilder<double>(
    valueListenable: pb.t,
    builder: (context, t, _) {
      final total = pb.duration;
      return LinearProgressIndicator(
        value: total > 0 ? (t / total).clamp(0, 1) : 0,
        minHeight: 4,
        color: Brand.dorado,
        backgroundColor: Colors.white12,
      );
    },
  );
}
