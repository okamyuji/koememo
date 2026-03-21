import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:koememo/features/memo_edit/memo_edit_controller.dart';

void main() {
  group('MemoEditState', () {
    test('initial state is empty string', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      expect(container.read(memoEditStateProvider), '');
    });

    test('setText updates state', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      container.read(memoEditStateProvider.notifier).setText('hello');
      expect(container.read(memoEditStateProvider), 'hello');
    });
  });
}
