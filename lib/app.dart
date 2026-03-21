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

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // TODO: 録音中かどうかを RecordingController から確認し、
      // 録音中でなければ認証をロックする
      ref.read(authStateProvider.notifier).lock();
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
