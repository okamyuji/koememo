import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:koememo/core/auth_lifecycle.dart';

void main() {
  group('AuthLifecycleManager', () {
    late int lockCount;
    late AuthLifecycleManager manager;

    setUp(() {
      lockCount = 0;
      manager = AuthLifecycleManager(onLock: () => lockCount++);
    });

    test('does not lock when unauthenticated and resumed', () {
      manager.handleLifecycleChange(AppLifecycleState.paused);
      manager.handleLifecycleChange(AppLifecycleState.resumed);
      expect(lockCount, 0);
    });

    test('locks when authenticated then background then resumed', () {
      manager.onAuthenticated();
      manager.handleLifecycleChange(AppLifecycleState.paused);
      manager.handleLifecycleChange(AppLifecycleState.resumed);
      expect(lockCount, 1);
    });

    test('does not lock twice on double resume', () {
      manager.onAuthenticated();
      manager.handleLifecycleChange(AppLifecycleState.paused);
      manager.handleLifecycleChange(AppLifecycleState.resumed);
      // Now in unauthenticated state after lock
      manager.handleLifecycleChange(AppLifecycleState.resumed);
      expect(lockCount, 1);
    });

    test('does not lock on resume without prior pause', () {
      manager.onAuthenticated();
      manager.handleLifecycleChange(AppLifecycleState.resumed);
      expect(lockCount, 0);
    });

    test('re-authenticating then background-resume locks again', () {
      manager.onAuthenticated();
      manager.handleLifecycleChange(AppLifecycleState.paused);
      manager.handleLifecycleChange(AppLifecycleState.resumed);
      expect(lockCount, 1);

      // Re-authenticate
      manager.onAuthenticated();
      manager.handleLifecycleChange(AppLifecycleState.paused);
      manager.handleLifecycleChange(AppLifecycleState.resumed);
      expect(lockCount, 2);
    });
  });
}
