import 'package:freezed_annotation/freezed_annotation.dart';

part 'transcription_result.freezed.dart';

@freezed
sealed class TranscriptionResult with _$TranscriptionResult {
  const factory TranscriptionResult({
    required String text,
    required bool isFinal,
    String? detectedLanguage,
  }) = _TranscriptionResult;
}
