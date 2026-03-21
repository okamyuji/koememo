import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:koememo/features/auth/auth_screen.dart';
import 'package:koememo/features/memo_list/memo_list_screen.dart';
import 'package:koememo/features/recording/recording_screen.dart';
import 'package:koememo/features/memo_detail/memo_detail_screen.dart';
import 'package:koememo/features/memo_edit/memo_edit_screen.dart';
import 'package:koememo/features/settings/settings_screen.dart';
import 'package:koememo/features/recording/recording_controller.dart';
import 'package:koememo/models/recording_state.dart';

part 'router.g.dart';

@Riverpod(keepAlive: true)
class AuthState extends _$AuthState {
  @override
  bool build() => false;

  void authenticate() => state = true;
  void lock() => state = false;
}

/// GoRouter の redirect を再評価させるための Listenable
class RouterRefreshNotifier extends ChangeNotifier {
  void notify() => notifyListeners();
}

final routerRefreshProvider = Provider<RouterRefreshNotifier>((ref) {
  final notifier = RouterRefreshNotifier();

  // authState が変わったら GoRouter を再評価
  ref.listen(authStateProvider, (_, _) => notifier.notify());

  return notifier;
});

final routerProvider = Provider<GoRouter>((ref) {
  final refreshNotifier = ref.watch(routerRefreshProvider);

  return GoRouter(
    initialLocation: '/auth',
    refreshListenable: refreshNotifier,
    redirect: (context, state) {
      // redirect 時に最新の状態を read（watch ではない）
      final isAuthenticated = ref.read(authStateProvider);
      final recordingState = ref.read(recordingControllerProvider);
      final isRecording = recordingState is Recording;
      final isAuthRoute = state.matchedLocation == '/auth';

      // 録音中は認証をバイパス
      if (isRecording && isAuthRoute) return '/recording';

      if (!isAuthenticated && !isRecording && !isAuthRoute) return '/auth';
      if (isAuthenticated && isAuthRoute) return '/';
      return null;
    },
    routes: [
      GoRoute(path: '/auth', builder: (context, state) => const AuthScreen()),
      GoRoute(path: '/', builder: (context, state) => const MemoListScreen()),
      GoRoute(
        path: '/recording',
        builder: (context, state) => const RecordingScreen(),
      ),
      GoRoute(
        path: '/memo/:id',
        builder: (context, state) {
          final id = int.parse(state.pathParameters['id']!);
          return MemoDetailScreen(memoId: id);
        },
        routes: [
          GoRoute(
            path: 'edit',
            builder: (context, state) {
              final id = int.parse(state.pathParameters['id']!);
              return MemoEditScreen(memoId: id);
            },
          ),
        ],
      ),
      GoRoute(
        path: '/settings',
        builder: (context, state) => const SettingsScreen(),
      ),
    ],
  );
});
