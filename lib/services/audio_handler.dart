import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';

/// Puente entre el reproductor y Android: publica el estado en la
/// notificación / pantalla de bloqueo y recibe sus botones.
///
/// La lógica de "qué himno sigue" vive en PlayerService; aquí solo se
/// reenvían los botones con [onNext], [onPrevious] y [onStop].
class HymnAudioHandler extends BaseAudioHandler with SeekHandler {
  HymnAudioHandler() {
    // Cada cambio del reproductor actualiza la notificación.
    player.playbackEventStream.listen(
      (_) => _broadcast(),
      onError: (Object _, StackTrace _) => _broadcast(),
    );
    player.playingStream.listen((_) => _broadcast());
  }

  final AudioPlayer player = AudioPlayer();

  Future<void> Function()? onNext;
  Future<void> Function()? onPrevious;
  Future<void> Function()? onStop;

  static const _states = {
    ProcessingState.idle: AudioProcessingState.idle,
    ProcessingState.loading: AudioProcessingState.loading,
    ProcessingState.buffering: AudioProcessingState.buffering,
    ProcessingState.ready: AudioProcessingState.ready,
    ProcessingState.completed: AudioProcessingState.completed,
  };

  void _broadcast() {
    final playing = player.playing;
    playbackState.add(
      playbackState.value.copyWith(
        controls: [
          MediaControl.skipToPrevious,
          if (playing) MediaControl.pause else MediaControl.play,
          MediaControl.skipToNext,
          MediaControl.stop,
        ],
        systemActions: const {
          MediaAction.seek,
          MediaAction.skipToPrevious,
          MediaAction.skipToNext,
        },
        // En la vista compacta: anterior, play/pausa, siguiente.
        androidCompactActionIndices: const [0, 1, 2],
        processingState: _states[player.processingState]!,
        playing: playing,
        updatePosition: player.position,
        bufferedPosition: player.bufferedPosition,
        speed: player.speed,
      ),
    );
  }

  /// Muestra en la notificación el himno que suena.
  void setNowPlaying(MediaItem item) => mediaItem.add(item);

  @override
  Future<void> play() => player.play();

  @override
  Future<void> pause() => player.pause();

  @override
  Future<void> seek(Duration position) => player.seek(position);

  @override
  Future<void> skipToNext() async => onNext?.call();

  /// Como en cualquier reproductor: si ya avanzó más de 3 s, vuelve al
  /// inicio del himno; si no, va al anterior.
  @override
  Future<void> skipToPrevious() async {
    if (player.position > const Duration(seconds: 3)) {
      await player.seek(Duration.zero);
    } else {
      await onPrevious?.call();
    }
  }

  @override
  Future<void> stop() async => onStop?.call();

  /// Quita la notificación (llamado por PlayerService al detener).
  Future<void> dismiss() async {
    await player.stop();
    playbackState.add(
      playbackState.value.copyWith(
        processingState: AudioProcessingState.idle,
        playing: false,
      ),
    );
    await super.stop();
  }
}
