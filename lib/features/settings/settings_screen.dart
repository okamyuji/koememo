import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:koememo/features/settings/settings_controller.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeSettingProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('設定')),
      body: ListView(
        children: [
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text('テーマ', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          RadioGroup<ThemeMode>(
            groupValue: themeMode,
            onChanged: (mode) {
              if (mode != null) {
                ref.read(themeSettingProvider.notifier).setThemeMode(mode);
              }
            },
            child: Column(
              children: [
                RadioListTile<ThemeMode>(
                  title: const Text('ライト'),
                  value: ThemeMode.light,
                ),
                RadioListTile<ThemeMode>(
                  title: const Text('ダーク'),
                  value: ThemeMode.dark,
                ),
                RadioListTile<ThemeMode>(
                  title: const Text('システム'),
                  value: ThemeMode.system,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
