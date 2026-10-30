import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

/// Reactive Theme Controller with persistence
class ThemeController {
  static final ValueNotifier<ThemeMode> themeNotifier =
      ValueNotifier<ThemeMode>(ThemeMode.system);

  static const String _fileName = 'app_settings.json';

  /// Initialize theme from local storage
  static Future<void> init() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/$_fileName');
      if (await file.exists()) {
        final content = await file.readAsString();
        final map = jsonDecode(content);
        final themeStr = map['theme_mode']?.toString();
        if (themeStr == 'dark') {
          themeNotifier.value = ThemeMode.dark;
        } else if (themeStr == 'light') {
          themeNotifier.value = ThemeMode.light;
        } else if (themeStr == 'system') {
          themeNotifier.value = ThemeMode.system;
        }
      }
    } catch (e) {
      // Fallback to light mode silently
    }
  }

  /// Toggle between Light and Dark
  static Future<void> toggleTheme() async {
    if (themeNotifier.value == ThemeMode.dark) {
      await setTheme(ThemeMode.light);
    } else {
      await setTheme(ThemeMode.dark);
    }
  }

  /// Explicitly set theme mode
  static Future<void> setTheme(ThemeMode mode) async {
    themeNotifier.value = mode;
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/$_fileName');
      final map = {'theme_mode': mode.name};
      await file.writeAsString(jsonEncode(map));
    } catch (_) {}
  }

  /// Helper to check if currently dark mode
  static bool isDark(BuildContext context) {
    if (themeNotifier.value == ThemeMode.system) {
      return MediaQuery.of(context).platformBrightness == Brightness.dark;
    }
    return themeNotifier.value == ThemeMode.dark;
  }
}
