import 'package:freezed_annotation/freezed_annotation.dart';

part 'playback_state.freezed.dart';

@freezed
sealed class PlaybackState with _$PlaybackState {
  const factory PlaybackState.stopped() = PlaybackStopped;
  const factory PlaybackState.playing({
    required Duration position,
    required Duration duration,
  }) = Playing;
  const factory PlaybackState.paused({
    required Duration position,
    required Duration duration,
  }) = Paused;
}
