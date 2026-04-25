import 'package:flutter_test/flutter_test.dart';
import 'package:koememo/services/speech_recognition_service.dart';

void main() {
  group('SpeechRecognitionService', () {
    test('isInitialized is false before initialize', () {
      final service = SpeechRecognitionService();
      expect(service.isInitialized, isFalse);
    });

    test('results stream is broadcast', () {
      final service = SpeechRecognitionService();
      service.results.listen((_) {});
      service.results.listen((_) {});
      service.dispose();
    });

    test('combineTranscriptSegments joins Japanese without extra spaces', () {
      final text = SpeechRecognitionService.combineTranscriptSegments([
        '今日は',
        'いい天気です',
        '',
        '散歩しました',
      ]);

      expect(text, '今日はいい天気です散歩しました');
    });

    test('combineTranscriptSegments keeps spaces between ascii words', () {
      final text = SpeechRecognitionService.combineTranscriptSegments([
        'meeting',
        'memo',
        '2026',
      ]);

      expect(text, 'meeting memo 2026');
    });

    test('selectBetterTranscript keeps existing text over tiny regression', () {
      final text = SpeechRecognitionService.selectBetterTranscript(
        existing: '今日は体調がよく朝ごはんも食べました',
        candidate: 'う',
      );

      expect(text, '今日は体調がよく朝ごはんも食べました');
    });

    test('selectBetterTranscript accepts meaningfully longer candidate', () {
      final text = SpeechRecognitionService.selectBetterTranscript(
        existing: '今日は体調',
        candidate: '今日は体調がよく朝ごはんも食べました',
      );

      expect(text, '今日は体調がよく朝ごはんも食べました');
    });

    test(
      'selectBetterTranscript prefers shorter clean candidate over noisy long existing',
      () {
        // ストリーミング側が誤認識でノイズ的に長くなっているケース。
        // バッチ側のクリーンな結果を絶対長閾値以上なら採用する。
        final text = SpeechRecognitionService.selectBetterTranscript(
          existing: 'あああああああああああああああああああああああああああ',
          candidate: '今日は会議です',
        );

        expect(text, '今日は会議です');
      },
    );

    test('selectBetterTranscript keeps existing for empty candidate', () {
      final text = SpeechRecognitionService.selectBetterTranscript(
        existing: '今日は体調がよく朝ごはんも食べました',
        candidate: '   ',
      );

      expect(text, '今日は体調がよく朝ごはんも食べました');
    });

    test('selectBetterTranscript accepts candidate when existing is empty', () {
      final text = SpeechRecognitionService.selectBetterTranscript(
        existing: '',
        candidate: 'ABC',
      );

      expect(text, 'ABC');
    });
  });
}
