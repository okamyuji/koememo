import 'package:freezed_annotation/freezed_annotation.dart';

part 'memo_result.freezed.dart';

@freezed
sealed class MemoResult with _$MemoResult {
  const factory MemoResult({
    required String filePath,
    required String transcript,
    required int durationMs,
  }) = _MemoResult;
}
