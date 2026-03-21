import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:koememo/features/auth/auth_screen.dart';
import 'package:koememo/features/memo_list/memo_list_screen.dart';
import 'package:koememo/features/recording/recording_screen.dart';
import 'package:koememo/features/memo_detail/memo_detail_screen.dart';
import 'package:koememo/features/memo_edit/memo_edit_screen.dart';
import 'package:koememo/features/settings/settings_screen.dart';

part 'router.g.dart';

@Riverpod(keepAlive: true)
class AuthState extends _$AuthState {
  @override
  bool build() => false;

  void authenticate() => state = true;
  void lock() => state = false;
}

/// 録音中フラグ（認証スキップ判定用）
/// AuthLifecycleManager と GoRouter redirect の両方から参照される
@Riverpod(keepAlive: true)
class RecordingActive extends _$RecordingActive {
  @override
  bool build() => false;

  void start() => state = true;
  void stop() => state = false;
}

@Riverpod(keepAlive: true)
Raw<GoRouter> router(Ref ref) {
  final notifier = ValueNotifier(0);

  ref.listen(authStateProvider, (_, _) {
    notifier.value++;
  });
  ref.listen(recordingActiveProvider, (_, _) {
    notifier.value++;
  });

  return GoRouter(
    initialLocation: '/auth',
    refreshListenable: notifier,
    redirect: (context, state) {
      final isAuthenticated = ref.read(authStateProvider);
      final isRecording = ref.read(recordingActiveProvider);
      final isAuthRoute = state.matchedLocation == '/auth';

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
}
