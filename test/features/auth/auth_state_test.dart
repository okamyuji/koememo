import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:koememo/core/router.dart';

void main() {
  group('AuthState', () {
    test('initial state is unauthenticated', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      expect(container.read(authStateProvider), isFalse);
    });

    test('authenticate sets state to true', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      container.read(authStateProvider.notifier).authenticate();
      expect(container.read(authStateProvider), isTrue);
    });

    test('lock sets state to false', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      container.read(authStateProvider.notifier).authenticate();
      container.read(authStateProvider.notifier).lock();
      expect(container.read(authStateProvider), isFalse);
    });
  });
}
