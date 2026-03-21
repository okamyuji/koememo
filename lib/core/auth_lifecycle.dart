import 'package:flutter/material.dart';

/// State パターンによる認証ライフサイクル管理。
/// 各状態が onResumed / onPaused の振る舞いを決定する。
abstract class AuthLifecycleState {
  const AuthLifecycleState();

  AuthLifecycleState onPaused(AuthLifecycleContext context);
  AuthLifecycleState onResumed(AuthLifecycleContext context);
}

/// 状態遷移を実行するためのコンテキストインターフェース
abstract class AuthLifecycleContext {
  void lockAuth();
  bool isRecordingActive();
}

/// 未認証状態（認証画面を表示中）
class UnauthenticatedState extends AuthLifecycleState {
  const UnauthenticatedState();

  @override
  AuthLifecycleState onPaused(AuthLifecycleContext context) => this;

  @override
  AuthLifecycleState onResumed(AuthLifecycleContext context) => this;
}

/// 認証済み・フォアグラウンド状態
class AuthenticatedForegroundState extends AuthLifecycleState {
  const AuthenticatedForegroundState();

  @override
  AuthLifecycleState onPaused(AuthLifecycleContext context) =>
      const AuthenticatedBackgroundState();

  @override
  AuthLifecycleState onResumed(AuthLifecycleContext context) => this;
}

/// 認証済み・バックグラウンド状態
class AuthenticatedBackgroundState extends AuthLifecycleState {
  const AuthenticatedBackgroundState();

  @override
  AuthLifecycleState onPaused(AuthLifecycleContext context) => this;

  @override
  AuthLifecycleState onResumed(AuthLifecycleContext context) {
    // 録音中は認証をスキップしてフォアグラウンドに戻す
    if (context.isRecordingActive()) {
      return const AuthenticatedForegroundState();
    }
    context.lockAuth();
    return const UnauthenticatedState();
  }
}

/// AuthLifecycleState を管理するマネージャ
class AuthLifecycleManager implements AuthLifecycleContext {
  AuthLifecycleState _state;
  final VoidCallback _onLock;
  final bool Function() _isRecording;

  AuthLifecycleManager({
    required VoidCallback onLock,
    required bool Function() isRecording,
  }) : _state = const UnauthenticatedState(),
       _onLock = onLock,
       _isRecording = isRecording;

  void onAuthenticated() {
    _state = const AuthenticatedForegroundState();
  }

  void handleLifecycleChange(AppLifecycleState lifecycleState) {
    switch (lifecycleState) {
      case AppLifecycleState.paused:
        // paused のみをバックグラウンドとして扱う
        // inactive（システムダイアログ: Face ID, マイク許可等）は無視
        _state = _state.onPaused(this);
      case AppLifecycleState.resumed:
        _state = _state.onResumed(this);
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        break;
    }
  }

  @override
  void lockAuth() => _onLock();

  @override
  bool isRecordingActive() => _isRecording();
}
