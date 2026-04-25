import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:koememo/core/router.dart';
import 'package:koememo/database/daos/memo_dao.dart';
import 'package:koememo/features/memo_list/memo_list_controller.dart';
import 'package:koememo/models/memo_result.dart';
import 'package:koememo/models/recording_state.dart';
import 'package:koememo/services/audio_recording_service.dart';
import 'package:koememo/services/database_service.dart';
import 'package:koememo/services/speech_recognition_service.dart';

part 'recording_controller.g.dart';

class LiveTranscriptNotifier extends Notifier<String> {
  @override
  String build() => '';

  void update(String text) => state = text;
  void reset() => state = '';
}

final liveTranscriptProvider = NotifierProvider<LiveTranscriptNotifier, String>(
  LiveTranscriptNotifier.new,
);

@riverpod
class RecordingController extends _$RecordingController {
  AudioRecordingService? _recordingService;
  SpeechRecognitionService? _speechService;
  StreamSubscription<RecognitionResult>? _recognitionSubscription;
  String _currentTranscript = '';
  DateTime? _recordingStartTime;

  @override
  RecordingState build() => const RecordingState.idle();

  Future<void> startRecording() async {
    _currentTranscript = '';
    ref.read(liveTranscriptProvider.notifier).reset();

    // 初期化中の状態を表示
    state = const RecordingState.initializing();

    // マイク権限チェック
    _recordingService = AudioRecordingService();
    final hasPermission = await _recordingService!.hasPermission();
    if (!hasPermission) {
      _recordingService?.dispose();
      _recordingService = null;
      state = const RecordingState.idle();
      throw Exception('マイクのアクセス許可が必要です');
    }

    // 音声認識の初期化（モデルロード含む）
    try {
      _speechService = SpeechRecognitionService();
      await _speechService!.initialize();
    } catch (e, stack) {
      debugPrint('Speech recognition init failed: $e');
      debugPrint('Stack: $stack');
      // 音声認識なしでも録音は続行
      _speechService?.dispose();
      _speechService = null;
    }

    // 録音を開始
    _recordingStartTime = DateTime.now();
    final filePath = await _recordingService!.startRecording();
    state = RecordingState.recording(filePath: filePath);
    ref.read(recordingActiveProvider.notifier).start();

    // 音声認識が利用可能ならストリーミング接続
    if (_speechService != null) {
      _recognitionSubscription = _speechService!.results.listen((result) {
        _currentTranscript += result.text;
        ref.read(liveTranscriptProvider.notifier).update(_currentTranscript);
      });

      _recordingService!.onAudioData = (samples) {
        _speechService?.acceptWaveform(samples);
      };
    } else {
      ref
          .read(liveTranscriptProvider.notifier)
          .update('[文字起こし利用不可: モデル初期化に失敗]');
    }
  }

  Future<MemoResult?> stopRecording() async {
    if (state is! Recording) return null;

    state = const RecordingState.processing();

    final filePath = await _recordingService?.stopRecording();

    if (_speechService != null) {
      _speechService!.flush();
      await Future.delayed(const Duration(milliseconds: 300));
    }

    // バッチ認識中にストリーミング側のコールバックが _currentTranscript を
    // 書き換えてレース条件を起こさないよう、ここで購読を停止しスナップショットを取る。
    await _recognitionSubscription?.cancel();
    _recognitionSubscription = null;
    final streamingTranscript = _currentTranscript;

    // 録音終了後にフル WAV ファイルを再認識し、ライブストリーミングより
    // 文脈の保たれた高精度な書き起こしを最終結果として採用する。
    // 失敗時はストリーミング中の結果にフォールバックする。
    var finalTranscript = streamingTranscript;
    if (_speechService != null && filePath != null) {
      try {
        final batchTranscript = await _speechService!.transcribeFile(filePath);
        final selectedTranscript =
            SpeechRecognitionService.selectBetterTranscript(
              existing: streamingTranscript,
              candidate: batchTranscript,
            );
        finalTranscript = selectedTranscript;
        ref.read(liveTranscriptProvider.notifier).update(selectedTranscript);
      } catch (e, stack) {
        debugPrint('Batch transcription failed: $e');
        debugPrint('Stack: $stack');
      }
    }

    final durationMs = _recordingStartTime != null
        ? DateTime.now().difference(_recordingStartTime!).inMilliseconds
        : 0;

    final now = DateTime.now();
    final title =
        '${now.year}/${now.month.toString().padLeft(2, '0')}/${now.day.toString().padLeft(2, '0')} '
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')} のメモ';

    final relativePath = _recordingService?.relativeFilePath;

    final db = ref.read(appDatabaseProvider);
    final memoDao = MemoDao(db);
    await memoDao.insertMemo(
      title: title,
      transcript: finalTranscript,
      audioFilePath: relativePath,
      durationMs: durationMs,
    );

    _cleanup();
    state = const RecordingState.idle();
    ref.read(recordingActiveProvider.notifier).stop();

    ref.invalidate(memoListProvider);
    ref.invalidate(tagListProvider);

    return MemoResult(
      filePath: filePath ?? '',
      transcript: finalTranscript,
      durationMs: durationMs,
    );
  }

  void cancelRecording() {
    _cleanup();
    state = const RecordingState.idle();
    ref.read(recordingActiveProvider.notifier).stop();
  }

  void _cleanup() {
    _recognitionSubscription?.cancel();
    _recognitionSubscription = null;
    _speechService?.dispose();
    _speechService = null;
    _recordingService?.dispose();
    _recordingService = null;
  }
}
