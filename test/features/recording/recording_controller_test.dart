import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:koememo/features/recording/recording_controller.dart';
import 'package:koememo/models/recording_state.dart';

void main() {
  group('RecordingController', () {
    test('initial state is idle', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final state = container.read(recordingControllerProvider);
      expect(state, isA<RecordingIdle>());
    });
  });
}
