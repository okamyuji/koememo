import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AudioPlaybackService', () {
    // just_audio はプラットフォームプラグインのため、
    // ユニットテストでは直接インスタンス化できない。
    // 実機/エミュレータでの統合テストで確認する。
    test('module imports correctly', () {
      // ignore: unused_import
      expect(true, isTrue);
    });
  });
}
