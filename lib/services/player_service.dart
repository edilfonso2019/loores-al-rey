import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:audio_service/audio_service.dart';

import '../data/hymn_repository.dart';
import '../models/hymn.dart';
import 'app_state.dart';
import 'audio_handler.dart';
import 'media_service.dart';
import 'notification_permission.dart';

/// Reproductor único de la app (instrumental o cantado), con controles en
/// la notificación ([HymnAudioHandler]) y "tocar continuamente".
class PlayerService extends ChangeNotifier {
  PlayerService(this._media, this._state, [this._handler])
    : player = _handler?.player ?? AudioPlayer() {
    // Botones de la notificación / pantalla de bloqueo.
    _handler?.onNext = () async {
      await next();
    };
    _handler?.onPrevious = () async {
      await previous();
    };
    _handler?.onStop = stop;
    _subs.add(
      player.playerStateStream.listen((s) {
        if (s.processingState == ProcessingState.completed) {
          _onCompleted();
        }
        notifyListeners();
      }),
    );
  }

  final MediaService _media;
  final AppState _state;
  final HymnAudioHandler? _handler;
  final AudioPlayer player;
  final List<StreamSubscription<dynamic>> _subs = [];

  Hymn? current;
  MediaKind kind = MediaKind.instrumental;

  /// Cola (lista de culto) y posición actual; vacía = himnario en orden.
  List<String> queue = const [];
  int queueIndex = -1;
  String? queueName;

  /// Id de la lista de culto que suena (para resaltarla); null = ninguna.
  String? queueId;

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
      queueId = null;
    }
    // Que no siga sonando el himno anterior mientras se carga este (o si
    // este no está disponible).
    if (player.playing) unawaited(player.pause());
    current = h;
    kind = k;
    error = null;
    loading = true;
    notifyListeners();
    // Sin este permiso, Android oculta los controles en la notificación.
    await NotificationPermission.ensure();
    final uri = _media.sourceUri(h, k);
    try {
      if (uri == null) {
        throw const MediaNotAvailable('Este himnario aún no tiene pistas.');
      }
      if (!_media.isDownloaded(h, k)) {
        final ok = await _media.checkAvailable(h, k);
        if (ok == false) {
          throw MediaNotAvailable(MediaService.notAvailableMessage(h, k));
        }
        if (ok == null) {
          throw MediaNotAvailable(
            _media.serverFailed(h, k)
                ? 'El servidor no responde. Inténtalo más tarde.'
                : 'Sin conexión. Descarga la pista para escucharla sin internet.',
          );
        }
      }
      // Si mientras se consultaba el usuario eligió otro himno, no sigas.
      if (!isCurrent(h, k)) return;
      final hymnal = HymnRepository.instance.hymnal(h.book);
      _handler?.setNowPlaying(
        MediaItem(
          id: '${h.id}-${k.name}',
          title: '${h.number}. ${h.title}',
          album: '${hymnal?.nombre ?? 'Loores al Rey'} · ${k.label}',
          artist: queueName ?? h.autor ?? 'Loores al Rey',
        ),
      );
      final duration = await player.setAudioSource(AudioSource.uri(uri));
      if (duration != null && _handler != null) {
        _handler.setNowPlaying(
          _handler.mediaItem.value!.copyWith(duration: duration),
        );
      }
      loading = false;
      notifyListeners();
      unawaited(player.play());
    } on MediaNotAvailable catch (e) {
      if (isCurrent(h, k)) _fail(e.message);
    } catch (_) {
      // Una carga vieja interrumpida por otra más nueva no es un error.
      if (!isCurrent(h, k)) return;
      _fail(
        _media.isDownloaded(h, k)
            ? 'No se pudo abrir el archivo descargado.'
            : 'No se pudo reproducir. Revisa tu conexión.',
      );
    }
  }

  void _fail(String message) {
    loading = false;
    error = message;
    notifyListeners();
  }

  /// Reproduce una lista de culto desde [index].
  Future<void> playQueue(
    List<String> ids, {
    int index = 0,
    String? name,
    String? id,
    MediaKind k = MediaKind.instrumental,
  }) async {
    if (ids.isEmpty) return;
    queueId = id;
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
    if (_handler != null) {
      await _handler.dismiss(); // detiene y quita la notificación
    } else {
      await player.stop();
    }
    current = null;
    queue = const [];
    queueIndex = -1;
    queueName = null;
    queueId = null;
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
