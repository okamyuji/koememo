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
}

/// 未認証状態（認証画面を表示中）
/// → resumed されてもロックしない（無限ループ防止）
class UnauthenticatedState extends AuthLifecycleState {
  const UnauthenticatedState();

  @override
  AuthLifecycleState onPaused(AuthLifecycleContext context) => this;

  @override
  AuthLifecycleState onResumed(AuthLifecycleContext context) => this;
}

/// 認証済み・フォアグラウンド状態
/// → paused されたら BackgroundState に遷移
class AuthenticatedForegroundState extends AuthLifecycleState {
  const AuthenticatedForegroundState();

  @override
  AuthLifecycleState onPaused(AuthLifecycleContext context) =>
      const AuthenticatedBackgroundState();

  @override
  AuthLifecycleState onResumed(AuthLifecycleContext context) => this;
}

/// 認証済み・バックグラウンド状態
/// → resumed されたらロックして未認証に遷移
class AuthenticatedBackgroundState extends AuthLifecycleState {
  const AuthenticatedBackgroundState();

  @override
  AuthLifecycleState onPaused(AuthLifecycleContext context) => this;

  @override
  AuthLifecycleState onResumed(AuthLifecycleContext context) {
    context.lockAuth();
    return const UnauthenticatedState();
  }
}

/// AuthLifecycleState を管理するマネージャ
class AuthLifecycleManager implements AuthLifecycleContext {
  AuthLifecycleState _state;
  final VoidCallback _onLock;

  AuthLifecycleManager({required VoidCallback onLock})
    : _state = const UnauthenticatedState(),
      _onLock = onLock;

  void onAuthenticated() {
    _state = const AuthenticatedForegroundState();
  }

  void handleLifecycleChange(AppLifecycleState lifecycleState) {
    switch (lifecycleState) {
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
        _state = _state.onPaused(this);
      case AppLifecycleState.resumed:
        _state = _state.onResumed(this);
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        break;
    }
  }

  @override
  void lockAuth() => _onLock();
}
