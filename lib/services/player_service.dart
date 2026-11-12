import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';

import '../data/hymn_repository.dart';
import '../models/hymn.dart';
import 'app_state.dart';
import 'media_service.dart';

/// Reproductor único de la app (instrumental o cantado), con controles en
/// la notificación (just_audio_background) y "tocar continuamente".
class PlayerService extends ChangeNotifier {
  PlayerService(this._media, this._state) {
    _subs.add(player.playerStateStream.listen((s) {
      if (s.processingState == ProcessingState.completed) {
        _onCompleted();
      }
      notifyListeners();
    }));
  }

  final MediaService _media;
  final AppState _state;
  final AudioPlayer player = AudioPlayer();
  final List<StreamSubscription<dynamic>> _subs = [];

  Hymn? current;
  MediaKind kind = MediaKind.instrumental;

  /// Cola (lista de culto) y posición actual; vacía = himnario en orden.
  List<String> queue = const [];
  int queueIndex = -1;
  String? queueName;

  bool loading = false;
  String? error;

  bool get playing => player.playing;
  bool get hasQueue => queue.isNotEmpty;

  bool isCurrent(Hymn h, MediaKind k) => current?.id == h.id && kind == k;

  /// Carga y reproduce [h]. Si ya es el actual, alterna play/pausa.
  Future<void> play(Hymn h, MediaKind k, {bool keepQueue = false}) async {
    assert(k.isAudio);
    if (isCurrent(h, k) && player.processingState != ProcessingState.idle) {
      return toggle();
    }
    if (!keepQueue) {
      queue = const [];
      queueIndex = -1;
      queueName = null;
    }
    current = h;
    kind = k;
    error = null;
    loading = true;
    notifyListeners();
    final uri = _media.sourceUri(h, k);
    try {
      if (uri == null) {
        throw const MediaNotAvailable('Este himnario aún no tiene pistas.');
      }
      final hymnal = HymnRepository.instance.hymnal(h.book);
      await player.setAudioSource(AudioSource.uri(
        uri,
        tag: MediaItem(
          id: '${h.id}-${k.name}',
          title: '${h.number}. ${h.title}',
          album: '${hymnal?.nombre ?? 'Loores al Rey'} · ${k.label}',
          artist: h.autor ?? 'Loores al Rey',
        ),
      ));
      loading = false;
      notifyListeners();
      unawaited(player.play());
    } on MediaNotAvailable catch (e) {
      _fail(e.message);
    } catch (_) {
      _fail(_media.isDownloaded(h, k)
          ? 'No se pudo abrir el archivo descargado.'
          : '${k.label} del himno ${h.number} no disponible o sin conexión.');
    }
  }

  void _fail(String message) {
    loading = false;
    error = message;
    notifyListeners();
  }

  /// Reproduce una lista de culto desde [index].
  Future<void> playQueue(List<String> ids, {int index = 0, String? name, MediaKind k = MediaKind.instrumental}) async {
    if (ids.isEmpty) return;
    queue = List.of(ids);
    queueIndex = index.clamp(0, ids.length - 1);
    queueName = name;
    final h = HymnRepository.instance.byId(queue[queueIndex]);
    if (h != null) await play(h, k, keepQueue: true);
  }

  Future<void> toggle() async {
    if (player.playing) {
      await player.pause();
    } else {
      if (player.processingState == ProcessingState.completed) {
        await player.seek(Duration.zero);
      }
      unawaited(player.play());
    }
    notifyListeners();
  }

  Future<void> seek(Duration d) => player.seek(d);

  Future<void> stop() async {
    await player.stop();
    current = null;
    queue = const [];
    queueIndex = -1;
    queueName = null;
    error = null;
    notifyListeners();
  }

  /// Siguiente: en la cola si hay, si no el siguiente número del himnario.
  Future<bool> next() => _advance(1);
  Future<bool> previous() => _advance(-1);

  Future<bool> _advance(int delta) async {
    final cur = current;
    if (cur == null) return false;
    final start = queueIndex;
    // Hasta 5 intentos para saltar pistas que no existen en el servidor.
    for (var tries = 0; tries < 5; tries++) {
      Hymn? target;
      if (hasQueue) {
        final j = start + delta * (tries + 1);
        if (j < 0 || j >= queue.length) return false;
        target = HymnRepository.instance.byId(queue[j]);
        if (target == null) continue;
        queueIndex = j;
      } else {
        target = HymnRepository.instance.neighbor(cur, delta * (tries + 1));
        if (target == null) return false;
      }
      await play(target, kind, keepQueue: true);
      if (error == null) return true;
    }
    return false;
  }

  Future<void> _onCompleted() async {
    if (_state.continuousPlay || hasQueue) {
      final ok = await next();
      if (!ok) {
        await player.pause();
        await player.seek(Duration.zero);
      }
    } else {
      await player.pause();
      await player.seek(Duration.zero);
    }
  }

  @override
  void dispose() {
    for (final s in _subs) {
      s.cancel();
    }
    player.dispose();
    super.dispose();
  }
}
