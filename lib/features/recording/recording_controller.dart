import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:koememo/database/daos/memo_dao.dart';
import 'package:koememo/models/memo_result.dart';
import 'package:koememo/models/recording_state.dart';
import 'package:koememo/services/audio_recording_service.dart';
import 'package:koememo/services/database_service.dart';
import 'package:koememo/services/speech_recognition_service.dart';

part 'recording_controller.g.dart';

@riverpod
class RecordingController extends _$RecordingController {
  AudioRecordingService? _recordingService;
  SpeechRecognitionService? _speechService;
  StreamSubscription<RecognitionResult>? _recognitionSubscription;
  String _currentTranscript = '';
  final _transcriptController = StreamController<String>.broadcast();
  DateTime? _recordingStartTime;

  Stream<String> get liveTranscript => _transcriptController.stream;
  String get currentTranscript => _currentTranscript;

  @override
  RecordingState build() => const RecordingState.idle();

  Future<void> startRecording() async {
    _recordingService = AudioRecordingService();
    _currentTranscript = '';

    final hasPermission = await _recordingService!.hasPermission();
    if (!hasPermission) {
      throw Exception('マイクのアクセス許可が必要です');
    }

    // 音声認識の初期化（モデル未配置の場合はスキップして録音のみ）
    try {
      _speechService = SpeechRecognitionService();
      await _speechService!.initialize();

      _recognitionSubscription = _speechService!.results.listen((result) {
        _currentTranscript += result.text;
        _transcriptController.add(_currentTranscript);
      });

      _recordingService!.onAudioData = (samples) {
        _speechService!.acceptWaveform(samples);
      };
    } catch (e) {
      debugPrint('Speech recognition init failed (recording only): $e');
      _speechService?.dispose();
      _speechService = null;
    }

    _recordingStartTime = DateTime.now();
    final filePath = await _recordingService!.startRecording();
    state = RecordingState.recording(filePath: filePath);
  }

  Future<MemoResult?> stopRecording() async {
    if (state is! Recording) return null;

    state = const RecordingState.processing();

    final filePath = await _recordingService?.stopRecording();
    _speechService?.flush();

    await Future.delayed(const Duration(milliseconds: 200));

    final durationMs = _recordingStartTime != null
        ? DateTime.now().difference(_recordingStartTime!).inMilliseconds
        : 0;

    final now = DateTime.now();
    final title =
        '${now.year}/${now.month.toString().padLeft(2, '0')}/${now.day.toString().padLeft(2, '0')} '
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')} のメモ';

    // 相対パスで保存（設計文書: Documents からの相対パス）
    final relativePath = _recordingService?.relativeFilePath;

    final db = ref.read(appDatabaseProvider);
    final memoDao = MemoDao(db);
    await memoDao.insertMemo(
      title: title,
      transcript: _currentTranscript,
      audioFilePath: relativePath,
      durationMs: durationMs,
    );

    _recognitionSubscription?.cancel();
    _recognitionSubscription = null;
    _speechService?.dispose();
    _speechService = null;
    _recordingService?.dispose();
    _recordingService = null;

    state = const RecordingState.idle();

    return MemoResult(
      filePath: filePath ?? '',
      transcript: _currentTranscript,
      durationMs: durationMs,
    );
  }

  void cancelRecording() {
    _recognitionSubscription?.cancel();
    _speechService?.dispose();
    _recordingService?.dispose();
    _recordingService = null;
    _speechService = null;
    state = const RecordingState.idle();
  }
}
