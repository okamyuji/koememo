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

@Riverpod(keepAlive: true)
GoRouter router(Ref ref) {
  final authState = ref.watch(authStateProvider);

  return GoRouter(
    initialLocation: '/',
    redirect: (context, state) {
      final isAuthenticated = authState;
      final isAuthRoute = state.matchedLocation == '/auth';

      if (!isAuthenticated && !isAuthRoute) return '/auth';
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
