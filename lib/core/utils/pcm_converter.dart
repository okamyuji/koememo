import 'dart:typed_data';

class PcmConverter {
  PcmConverter._();

  /// Int16 PCM バイト列 (little-endian) を Float32 サンプル列に変換。
  /// sherpa_onnx が要求する -1.0〜1.0 の範囲に正規化する。
  static Float32List int16BytesToFloat32(Uint8List bytes) {
    // バイトアライメントが合わない場合はコピーして整列させる
    Uint8List aligned;
    if (bytes.offsetInBytes % 2 != 0) {
      aligned = Uint8List.fromList(bytes);
    } else {
      aligned = bytes;
    }
    final sampleCount = aligned.lengthInBytes ~/ 2;
    final int16Data = Int16List.view(
      aligned.buffer,
      aligned.offsetInBytes,
      sampleCount,
    );
    final float32Data = Float32List(sampleCount);
    for (var i = 0; i < sampleCount; i++) {
      float32Data[i] = int16Data[i] / 32768.0;
    }
    return float32Data;
  }
}
