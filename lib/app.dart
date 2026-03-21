import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:koememo/core/auth_lifecycle.dart';
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
  late final AuthLifecycleManager _lifecycleManager;

  @override
  void initState() {
    super.initState();
    _lifecycleManager = AuthLifecycleManager(
      onLock: () => ref.read(authStateProvider.notifier).lock(),
      isRecording: () => ref.read(recordingActiveProvider),
    );
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _lifecycleManager.handleLifecycleChange(state);
  }

  @override
  Widget build(BuildContext context) {
    final goRouter = ref.watch(routerProvider);
    final themeMode = ref.watch(themeSettingProvider);

    ref.listen(authStateProvider, (_, isAuthenticated) {
      if (isAuthenticated) {
        _lifecycleManager.onAuthenticated();
      }
    });

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
