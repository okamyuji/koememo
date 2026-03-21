import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:koememo/core/utils/pcm_converter.dart';

void main() {
  group('PcmConverter', () {
    test('converts Int16 PCM bytes to Float32 samples', () {
      // Int16 little-endian: 0, 16384 (half max), -32768 (min)
      final bytes = Uint8List.fromList([
        0x00, 0x00, // 0
        0x00, 0x40, // 16384
        0x00, 0x80, // -32768
      ]);
      final result = PcmConverter.int16BytesToFloat32(bytes);
      expect(result.length, 3);
      expect(result[0], closeTo(0.0, 0.001));
      expect(result[1], closeTo(0.5, 0.001));
      expect(result[2], closeTo(-1.0, 0.001));
    });

    test('returns empty list for empty input', () {
      final result = PcmConverter.int16BytesToFloat32(Uint8List(0));
      expect(result, isEmpty);
    });

    test('max positive Int16 is close to 1.0', () {
      // 32767 = 0x7FFF
      final bytes = Uint8List.fromList([0xFF, 0x7F]);
      final result = PcmConverter.int16BytesToFloat32(bytes);
      expect(result[0], closeTo(1.0, 0.001));
      expect(result[0], lessThanOrEqualTo(1.0));
    });
  });
}
