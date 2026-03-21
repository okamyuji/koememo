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

  final _resultController = StreamController<RecognitionResult>.broadcast();
  Stream<RecognitionResult> get results => _resultController.stream;

  bool get isInitialized => _isInitialized;

  Future<void> initialize() async {
    if (_isInitialized) return;

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

    while (!_vad!.isEmpty()) {
      final segment = _vad!.front();
      _vad!.pop();
      _processSegment(segment.samples);
    }
  }

  void flush() {
    if (_vad == null || _recognizer == null) return;
    _vad!.flush();
    while (!_vad!.isEmpty()) {
      final segment = _vad!.front();
      _vad!.pop();
      _processSegment(segment.samples);
    }
  }

  void _processSegment(Float32List samples) {
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
    _resultController.close();
    _recognizer?.free();
    _vad?.free();
    _recognizer = null;
    _vad = null;
    _isInitialized = false;
  }
}
