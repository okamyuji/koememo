import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:koememo/features/settings/settings_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/shared_preferences'),
          (call) async {
            if (call.method == 'getAll') return <String, dynamic>{};
            return null;
          },
        );
  });

  group('ThemeSetting', () {
    test('default theme is system', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      expect(container.read(themeSettingProvider), ThemeMode.system);
    });
  });
}
