import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:koememo/core/auth_lifecycle.dart';

void main() {
  group('AuthLifecycleManager', () {
    late int lockCount;
    late bool isRecording;
    late AuthLifecycleManager manager;

    setUp(() {
      lockCount = 0;
      isRecording = false;
      manager = AuthLifecycleManager(
        onLock: () => lockCount++,
        isRecording: () => isRecording,
      );
    });

    test('does not lock when unauthenticated and resumed', () {
      manager.handleLifecycleChange(AppLifecycleState.paused);
      manager.handleLifecycleChange(AppLifecycleState.resumed);
      expect(lockCount, 0);
    });

    test('locks when authenticated then paused then resumed', () {
      manager.onAuthenticated();
      manager.handleLifecycleChange(AppLifecycleState.paused);
      manager.handleLifecycleChange(AppLifecycleState.resumed);
      expect(lockCount, 1);
    });

    test('does not lock on inactive→resumed (system dialog)', () {
      manager.onAuthenticated();
      manager.handleLifecycleChange(AppLifecycleState.inactive);
      manager.handleLifecycleChange(AppLifecycleState.resumed);
      expect(lockCount, 0);
    });

    test('does not lock twice on double resume', () {
      manager.onAuthenticated();
      manager.handleLifecycleChange(AppLifecycleState.paused);
      manager.handleLifecycleChange(AppLifecycleState.resumed);
      manager.handleLifecycleChange(AppLifecycleState.resumed);
      expect(lockCount, 1);
    });

    test('does not lock on resume without prior pause', () {
      manager.onAuthenticated();
      manager.handleLifecycleChange(AppLifecycleState.resumed);
      expect(lockCount, 0);
    });

    test('skips lock when recording is active', () {
      manager.onAuthenticated();
      isRecording = true;
      manager.handleLifecycleChange(AppLifecycleState.paused);
      manager.handleLifecycleChange(AppLifecycleState.resumed);
      expect(lockCount, 0);
    });

    test('locks after recording stops and background-resume', () {
      manager.onAuthenticated();
      isRecording = true;
      manager.handleLifecycleChange(AppLifecycleState.paused);
      manager.handleLifecycleChange(AppLifecycleState.resumed);
      expect(lockCount, 0);

      // Recording stops, then background again
      isRecording = false;
      manager.handleLifecycleChange(AppLifecycleState.paused);
      manager.handleLifecycleChange(AppLifecycleState.resumed);
      expect(lockCount, 1);
    });

    test('re-authenticating then background-resume locks again', () {
      manager.onAuthenticated();
      manager.handleLifecycleChange(AppLifecycleState.paused);
      manager.handleLifecycleChange(AppLifecycleState.resumed);
      expect(lockCount, 1);

      manager.onAuthenticated();
      manager.handleLifecycleChange(AppLifecycleState.paused);
      manager.handleLifecycleChange(AppLifecycleState.resumed);
      expect(lockCount, 2);
    });
  });
}
