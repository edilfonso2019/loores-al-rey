import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';

import '../models/chords.dart';
import '../models/hymn.dart';
import 'media_service.dart';
import 'player_service.dart';

/// Ajustes de cómo se muestran los acordes. Se recuerdan durante la sesión.
class ChordSettings {
  bool basic = true;
  bool latin = false;
  static final ChordSettings session = ChordSettings();
}

/// Sigue la pista instrumental de un himno cuadro a cuadro y expone lo que
/// suena: segundo, acorde, renglón, sílabas cantadas, evento de la partitura
/// y pulso. Lo comparten la pantalla de acordes y el modo atril.
class ChordsPlayback extends ChangeNotifier {
  ChordsPlayback(this.hymn, this.data, this.player) {
    _ticker = Ticker(_onTick)..start();
    final tonic = data.timeline.isEmpty
        ? null
        : Chord.parse(data.timeline.last.$2);
    _tonic = tonic ?? const Chord(0, '');
    // Siempre abre sin capo: el sugerido solo se ofrece (botón "Sugerido").
    capo = 0;
    _suggested = suggestedCapo(_uniqueChords, basic: settings.basic);
  }

  final Hymn hymn;
  final HymnChords data;
  final PlayerService player;
  final ChordSettings settings = ChordSettings.session;
  late final Ticker _ticker;
  late final Chord _tonic;
  late int _suggested;

  /// Segundo actual de la pista (se actualiza cada cuadro).
  final t = ValueNotifier<double>(0);
  final chord = ValueNotifier<int>(-1);
  final line = ValueNotifier<int>(-1);

  /// Sílabas ya cantadas del renglón actual.
  final sung = ValueNotifier<int>(0);
  final event = ValueNotifier<int>(-1);
  final beat = ValueNotifier<int>(-1);

  /// Semitonos que se sube/baja el audio (y los acordes).
  int pitch = 0;
  int capo = 0;
  double speed = 1;
  double? loopA;
  double? loopB;

  int get suggestedCapoValue => _suggested;

  Iterable<String> get _uniqueChords => {for (final e in data.timeline) e.$2};

  ChordStyle get style {
    final shift = pitch - capo;
    return ChordStyle(
      basic: settings.basic,
      latin: settings.latin,
      shift: shift,
      flats: ChordStyle.keyUsesFlats(_tonic.transposed(shift)),
    );
  }

  /// Tonalidad que se toca (con tono y capo), p. ej. "D" o "Do".
  String get keyLabel {
    final s = style;
    final c = _tonic.transposed(s.shift);
    return '${s.note(c.root)}${c.isMinor ? 'm' : ''}';
  }

  bool get isActive => player.isCurrent(hymn, MediaKind.instrumental);
  bool get playing => isActive && player.playing;
  double get duration => (player.player.duration?.inMilliseconds ?? 0) / 1000.0;

  Future<void> togglePlay() => player.play(hymn, MediaKind.instrumental);

  Future<void> seek(double seconds) async {
    if (!isActive) {
      await player.play(hymn, MediaKind.instrumental);
    }
    await player.seek(Duration(milliseconds: (seconds * 1000).round()));
    _onTick(Duration.zero);
  }

  void _onTick(Duration _) {
    if (!isActive) return;
    var s = player.player.position.inMilliseconds / 1000.0;
    final a = loopA, b = loopB;
    if (a != null && b != null && s >= b) {
      player.seek(Duration(milliseconds: (a * 1000).round()));
      s = a;
    }
    if ((s - t.value).abs() < 0.008) return;
    t.value = s;
    chord.value = data.chordIndexAt(s);
    beat.value = HymnChords.indexAt(data.beats, (x) => x.$1, s);
    final l = data.lineAt(s);
    line.value = l;
    if (l >= 0) {
      final syl = data.lines[l].syllables;
      var n = 0;
      while (n < syl.length && syl[n].t <= s + 0.05) {
        n++;
      }
      sung.value = n;
    } else {
      sung.value = 0;
    }
    event.value = data.eventAt(s);
  }

  // ---- ajustes ----
  void setBasic(bool v) {
    settings.basic = v;
    notifyListeners();
  }

  void setLatin(bool v) {
    settings.latin = v;
    notifyListeners();
  }

  void setCapo(int v) {
    capo = v.clamp(0, 9);
    notifyListeners();
  }

  /// Sube o baja el tono del audio (Android) y transporta los acordes.
  Future<void> setPitch(int semitones) async {
    pitch = semitones.clamp(-6, 6);
    notifyListeners();
    try {
      await player.player.setPitch(math.pow(2, pitch / 12).toDouble());
    } catch (_) {
      // Si el dispositivo no puede cambiar el tono, al menos se transportan.
    }
  }

  /// Más lento para practicar (sin cambiar el tono).
  Future<void> setSpeed(double v) async {
    speed = double.parse(v.clamp(0.5, 1.5).toStringAsFixed(2));
    notifyListeners();
    await player.player.setSpeed(speed);
  }

  /// Toca 1: marca A; toca 2: marca B y repite; toca 3: quita el loop.
  void toggleLoop() {
    final now = t.value;
    if (loopA == null) {
      loopA = now;
    } else if (loopB == null) {
      loopB = math.max(now, loopA! + 1);
      seek(loopA!);
    } else {
      loopA = loopB = null;
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _ticker.dispose();
    // El reproductor es compartido: se deja como estaba.
    if (speed != 1) player.player.setSpeed(1);
    if (pitch != 0) player.player.setPitch(1).catchError((Object _) {});
    for (final n in [t, chord, line, sung, event, beat]) {
      n.dispose();
    }
    super.dispose();
  }
}
