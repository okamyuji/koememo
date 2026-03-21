import 'package:freezed_annotation/freezed_annotation.dart';

part 'recording_state.freezed.dart';

@freezed
sealed class RecordingState with _$RecordingState {
  const factory RecordingState.idle() = RecordingIdle;
  const factory RecordingState.initializing() = RecordingInitializing;
  const factory RecordingState.recording({required String filePath}) =
      Recording;
  const factory RecordingState.processing() = RecordingProcessing;
}
