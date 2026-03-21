import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
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
    _recordingService = AudioRecordingService();
    _currentTranscript = '';
    ref.read(liveTranscriptProvider.notifier).reset();

    final hasPermission = await _recordingService!.hasPermission();
    if (!hasPermission) {
      _recordingService?.dispose();
      _recordingService = null;
      throw Exception('マイクのアクセス許可が必要です');
    }

    // まず録音を開始（UIが即座に反応するように）
    _recordingStartTime = DateTime.now();
    final filePath = await _recordingService!.startRecording();
    state = RecordingState.recording(filePath: filePath);

    // 音声認識の初期化（録音開始後に非同期で。モデル未配置の場合はスキップ）
    try {
      _speechService = SpeechRecognitionService();
      await _speechService!.initialize();

      _recognitionSubscription = _speechService!.results.listen((result) {
        _currentTranscript += result.text;
        ref.read(liveTranscriptProvider.notifier).update(_currentTranscript);
      });

      _recordingService!.onAudioData = (samples) {
        _speechService?.acceptWaveform(samples);
      };
    } catch (e) {
      debugPrint('Speech recognition init failed (recording only): $e');
      _speechService?.dispose();
      _speechService = null;
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
      transcript: _currentTranscript,
      audioFilePath: relativePath,
      durationMs: durationMs,
    );

    _cleanup();
    state = const RecordingState.idle();

    // メモ一覧を更新
    ref.invalidate(memoListProvider);
    ref.invalidate(tagListProvider);

    return MemoResult(
      filePath: filePath ?? '',
      transcript: _currentTranscript,
      durationMs: durationMs,
    );
  }

  void cancelRecording() {
    _cleanup();
    state = const RecordingState.idle();
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
