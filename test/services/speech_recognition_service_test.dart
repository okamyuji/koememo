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
  });
}
