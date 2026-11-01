import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sarv_authenticator/data/theme_controller.dart';

import 'support/throwing_storage.dart';

void main() {
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  test('defaults to the system theme', () async {
    final controller = ThemeController();
    await controller.load();
    expect(controller.mode, ThemeMode.system);
  });

  test('remembers the chosen theme across restarts', () async {
    for (final mode in [ThemeMode.light, ThemeMode.dark]) {
      await ThemeController().setMode(mode);
      final reloaded = ThemeController();
      await reloaded.load();
      expect(reloaded.mode, mode);
    }
  });

  test('notifies listeners only when the theme actually changes', () async {
    final controller = ThemeController();
    var notifications = 0;
    controller.addListener(() => notifications++);

    await controller.setMode(ThemeMode.system);
    expect(notifications, 0);
    await controller.setMode(ThemeMode.dark);
    expect(notifications, 1);
  });

  test('keeps working when storage fails', () async {
    final controller = ThemeController(storage: const ThrowingStorage());
    await controller.load();
    expect(controller.mode, ThemeMode.system);

    await controller.setMode(ThemeMode.dark);
    expect(controller.mode, ThemeMode.dark);
  });
}
