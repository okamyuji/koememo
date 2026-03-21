import 'dart:typed_data';

class PcmConverter {
  PcmConverter._();

  /// Int16 PCM バイト列 (little-endian) を Float32 サンプル列に変換。
  /// sherpa_onnx が要求する -1.0〜1.0 の範囲に正規化する。
  static Float32List int16BytesToFloat32(Uint8List bytes) {
    final int16Data = Int16List.view(
      bytes.buffer,
      bytes.offsetInBytes,
      bytes.lengthInBytes ~/ 2,
    );
    final float32Data = Float32List(int16Data.length);
    for (var i = 0; i < int16Data.length; i++) {
      float32Data[i] = int16Data[i] / 32768.0;
    }
    return float32Data;
  }
}
