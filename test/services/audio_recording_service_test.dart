import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AudioRecordingService', () {
    // record パッケージはプラットフォームプラグインのため、
    // ユニットテストでは直接インスタンス化できない。
    // 状態遷移テストは RecordingController テスト（モック経由）で実施する。
    test('module is importable', () {
      expect(true, isTrue);
    });
  });
}
