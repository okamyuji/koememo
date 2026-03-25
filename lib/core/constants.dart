class AppConstants {
  AppConstants._();

  static const String appName = 'こえメモ';
  static const int sampleRate = 16000;
  static const int numChannels = 1;
  static const int numThreads = 2;
  static const String modelAssetDir = 'assets/models/sense-voice';
  static const String modelFileName = 'model.int8.onnx';
  static const String tokensFileName = 'tokens.txt';
  static const String vadFileName = 'silero_vad.onnx';
  static const String language = 'ja';

  /// 録音の最大長（60分 × 16kHz × 1ch × 2bytes = ~115MB）
  static const int maxRecordingBytes = 60 * 60 * sampleRate * numChannels * 2;
}
