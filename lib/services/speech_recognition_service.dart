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
  String? _modelDir;
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
    _modelDir = modelDir;
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

    debugPrint('SpeechRecognitionService: creating VoiceActivityDetector...');
    _vad = _createVoiceActivityDetector(modelDir);
    debugPrint('SpeechRecognitionService: initialized successfully');

    _isInitialized = true;
  }

  sherpa.VoiceActivityDetector _createVoiceActivityDetector(String modelDir) {
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
    return sherpa.VoiceActivityDetector(
      config: vadConfig,
      bufferSizeInSeconds: 60,
    );
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
    final result = _decodeSamples(samples, AppConstants.sampleRate);
    if (result.text.isNotEmpty) {
      _resultController.add(result);
    }
  }

  RecognitionResult _decodeSamples(Float32List samples, int sampleRate) {
    if (_recognizer == null) {
      return const RecognitionResult(text: '', isFinal: true);
    }
    final stream = _recognizer!.createStream();
    stream.acceptWaveform(samples: samples, sampleRate: sampleRate);
    _recognizer!.decode(stream);

    final result = _recognizer!.getResult(stream);
    stream.free();
    return RecognitionResult(
      text: result.text,
      isFinal: true,
      detectedLanguage: result.lang,
    );
  }

  Future<String> transcribeFile(String filePath) async {
    if (!_isInitialized || _recognizer == null) {
      throw StateError('SpeechRecognitionService is not initialized');
    }

    final waveData = sherpa.readWave(filePath);
    if (waveData.samples.isEmpty) return '';

    final modelDir = _modelDir;
    if (modelDir != null && waveData.sampleRate == AppConstants.sampleRate) {
      sherpa.VoiceActivityDetector? batchVad;
      try {
        batchVad = _createVoiceActivityDetector(modelDir);
        batchVad.acceptWaveform(waveData.samples);
        batchVad.flush();

        final segments = <String>[];
        while (!batchVad.isEmpty()) {
          final segment = batchVad.front();
          batchVad.pop();
          final result = _decodeSamples(segment.samples, waveData.sampleRate);
          if (result.text.trim().isNotEmpty) {
            segments.add(result.text);
          }
        }

        final segmentedTranscript = combineTranscriptSegments(segments);
        final fullTranscript = _decodeSamples(
          waveData.samples,
          waveData.sampleRate,
        ).text;
        return selectBetterTranscript(
          existing: fullTranscript,
          candidate: segmentedTranscript,
        );
      } finally {
        batchVad?.free();
      }
    }

    return _decodeSamples(waveData.samples, waveData.sampleRate).text;
  }

  static String selectBetterTranscript({
    required String existing,
    required String candidate,
  }) {
    final normalizedExisting = existing.trim();
    final normalizedCandidate = candidate.trim();

    if (normalizedExisting.isEmpty) return normalizedCandidate;
    if (normalizedCandidate.isEmpty) return normalizedExisting;

    final existingLength = _meaningfulLength(normalizedExisting);
    final candidateLength = _meaningfulLength(normalizedCandidate);

    if (candidateLength < 3 && existingLength >= 3) {
      return normalizedExisting;
    }

    if (candidateLength * 2 < existingLength) {
      return normalizedExisting;
    }

    return normalizedCandidate;
  }

  static String combineTranscriptSegments(Iterable<String> segments) {
    final buffer = StringBuffer();

    for (final rawSegment in segments) {
      final segment = rawSegment.trim();
      if (segment.isEmpty) continue;

      final current = buffer.toString();
      if (current.isNotEmpty && _needsAsciiSeparator(current, segment)) {
        buffer.write(' ');
      }
      buffer.write(segment);
    }

    return buffer.toString();
  }

  static int _meaningfulLength(String text) {
    return text.replaceAll(RegExp(r'\s+'), '').length;
  }

  static bool _needsAsciiSeparator(String left, String right) {
    if (left.isEmpty || right.isEmpty) return false;
    return _isAsciiAlphaNumeric(left.codeUnitAt(left.length - 1)) &&
        _isAsciiAlphaNumeric(right.codeUnitAt(0));
  }

  static bool _isAsciiAlphaNumeric(int codeUnit) {
    return (codeUnit >= 0x30 && codeUnit <= 0x39) ||
        (codeUnit >= 0x41 && codeUnit <= 0x5A) ||
        (codeUnit >= 0x61 && codeUnit <= 0x7A);
  }

  void dispose() {
    _segmentQueue.clear();
    _resultController.close();
    _recognizer?.free();
    _vad?.free();
    _recognizer = null;
    _vad = null;
    _modelDir = null;
    _isInitialized = false;
  }
}
