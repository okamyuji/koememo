import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:koememo/core/constants.dart';
import 'package:koememo/services/model_manager.dart';
import 'package:sherpa_onnx/sherpa_onnx.dart' as sherpa;

class RecognitionResult {
  final String text;
  final bool isFinal;
  final String? detectedLanguage;

  const RecognitionResult({
    required this.text,
    required this.isFinal,
    this.detectedLanguage,
  });
}

class SpeechRecognitionService {
  sherpa.OfflineRecognizer? _recognizer;
  sherpa.VoiceActivityDetector? _vad;
  bool _isInitialized = false;
  Completer<void>? _initCompleter;
  bool _isProcessing = false;
  final List<Float32List> _segmentQueue = [];

  final _resultController = StreamController<RecognitionResult>.broadcast();
  Stream<RecognitionResult> get results => _resultController.stream;

  bool get isInitialized => _isInitialized;

  Future<void> initialize() async {
    if (_isInitialized) return;
    if (_initCompleter != null) return _initCompleter!.future;
    _initCompleter = Completer<void>();

    try {
      await _doInitialize();
      _initCompleter!.complete();
    } catch (e) {
      _initCompleter!.completeError(e);
      _initCompleter = null;
      rethrow;
    }
  }

  Future<void> _doInitialize() async {
    debugPrint('SpeechRecognitionService: initializing...');
    final modelDir = await ModelManager.ensureModelReady();
    debugPrint('SpeechRecognitionService: modelDir=$modelDir');

    final recognizerConfig = sherpa.OfflineRecognizerConfig(
      model: sherpa.OfflineModelConfig(
        senseVoice: sherpa.OfflineSenseVoiceModelConfig(
          model: '$modelDir/${AppConstants.modelFileName}',
          language: AppConstants.language,
          useInverseTextNormalization: true,
        ),
        tokens: '$modelDir/${AppConstants.tokensFileName}',
        numThreads: AppConstants.numThreads,
        debug: false,
      ),
    );
    debugPrint('SpeechRecognitionService: creating OfflineRecognizer...');
    _recognizer = sherpa.OfflineRecognizer(recognizerConfig);
    debugPrint('SpeechRecognitionService: OfflineRecognizer created');

    final vadConfig = sherpa.VadModelConfig(
      sileroVad: sherpa.SileroVadModelConfig(
        model: '$modelDir/${AppConstants.vadFileName}',
        threshold: 0.5,
        minSilenceDuration: 0.5,
        minSpeechDuration: 0.25,
        maxSpeechDuration: 30.0,
      ),
      sampleRate: AppConstants.sampleRate,
      numThreads: 1,
      debug: false,
    );
    debugPrint('SpeechRecognitionService: creating VoiceActivityDetector...');
    _vad = sherpa.VoiceActivityDetector(
      config: vadConfig,
      bufferSizeInSeconds: 60,
    );
    debugPrint('SpeechRecognitionService: initialized successfully');

    _isInitialized = true;
  }

  void acceptWaveform(Float32List samples) {
    if (!_isInitialized || _vad == null || _recognizer == null) return;

    _vad!.acceptWaveform(samples);
    _drainVadQueue();
  }

  void flush() {
    if (_vad == null || _recognizer == null) return;
    _vad!.flush();
    _drainVadQueue();
  }

  void _drainVadQueue() {
    while (!_vad!.isEmpty()) {
      final segment = _vad!.front();
      _vad!.pop();
      _segmentQueue.add(segment.samples);
    }
    _processNextSegment();
  }

  Future<void> _processNextSegment() async {
    if (_isProcessing || _segmentQueue.isEmpty) return;
    _isProcessing = true;

    while (_segmentQueue.isNotEmpty) {
      final samples = _segmentQueue.removeAt(0);
      _decodeSegment(samples);
      // イベントループに制御を返し、音声データの受信を妨げない
      await Future<void>.delayed(Duration.zero);
    }

    _isProcessing = false;
  }

  void _decodeSegment(Float32List samples) {
    if (_recognizer == null) return;
    final stream = _recognizer!.createStream();
    stream.acceptWaveform(
      samples: samples,
      sampleRate: AppConstants.sampleRate,
    );
    _recognizer!.decode(stream);

    final result = _recognizer!.getResult(stream);
    if (result.text.isNotEmpty) {
      _resultController.add(
        RecognitionResult(
          text: result.text,
          isFinal: true,
          detectedLanguage: result.lang,
        ),
      );
    }
    stream.free();
  }

  Future<String> transcribeFile(String filePath) async {
    if (!_isInitialized || _recognizer == null) {
      throw StateError('SpeechRecognitionService is not initialized');
    }

    final stream = _recognizer!.createStream();
    final waveData = sherpa.readWave(filePath);
    stream.acceptWaveform(
      samples: waveData.samples,
      sampleRate: waveData.sampleRate,
    );

    _recognizer!.decode(stream);
    final result = _recognizer!.getResult(stream);
    stream.free();

    return result.text;
  }

  void dispose() {
    _segmentQueue.clear();
    _resultController.close();
    _recognizer?.free();
    _vad?.free();
    _recognizer = null;
    _vad = null;
    _isInitialized = false;
  }
}
