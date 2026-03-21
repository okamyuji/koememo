import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:koememo/core/router.dart';
import 'package:koememo/core/theme.dart';
import 'package:koememo/features/settings/settings_controller.dart';

class KoememoApp extends ConsumerStatefulWidget {
  const KoememoApp({super.key});

  @override
  ConsumerState<KoememoApp> createState() => _KoememoAppState();
}

class _KoememoAppState extends ConsumerState<KoememoApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  bool _wasInBackground = false;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _wasInBackground = true;
    } else if (state == AppLifecycleState.resumed && _wasInBackground) {
      _wasInBackground = false;
      final isAuthenticated = ref.read(authStateProvider);
      if (isAuthenticated) {
        // 認証済み状態からバックグラウンド復帰した場合のみロック
        // （未認証=認証画面表示中はロックしない→無限ループ防止）
        ref.read(authStateProvider.notifier).lock();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final goRouter = ref.watch(routerProvider);
    final themeMode = ref.watch(themeSettingProvider);

    return MaterialApp.router(
      title: 'こえメモ',
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: themeMode,
      routerConfig: goRouter,
      debugShowCheckedModeBanner: false,
    );
  }
}
