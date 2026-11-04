import 'dart:convert';
import 'dart:io';
import 'package:chatty/helper/app_haptics.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

/// Ambient Chat Wallpaper presets
enum ChatWallpaper {
  obsidian,
  titanium,
  midnight,
  pearl,
}

extension ChatWallpaperExt on ChatWallpaper {
  String get id {
    switch (this) {
      case ChatWallpaper.obsidian:
        return 'obsidian';
      case ChatWallpaper.titanium:
        return 'titanium';
      case ChatWallpaper.midnight:
        return 'midnight';
      case ChatWallpaper.pearl:
        return 'pearl';
    }
  }

  String get title {
    switch (this) {
      case ChatWallpaper.obsidian:
        return 'OLED Obsidian';
      case ChatWallpaper.titanium:
        return 'Titanium Frosted';
      case ChatWallpaper.midnight:
        return 'Midnight Slate';
      case ChatWallpaper.pearl:
        return 'Minimal Pearl';
    }
  }

  String get subtitle {
    switch (this) {
      case ChatWallpaper.obsidian:
        return 'True pitch black with infinite OLED contrast';
      case ChatWallpaper.titanium:
        return 'Brushed titanium slate with soft ambient tones';
      case ChatWallpaper.midnight:
        return 'Deep twilight zinc & indigo evening mood';
      case ChatWallpaper.pearl:
        return 'Ultra-clean frosted ceramic silk finish';
    }
  }

  IconData get icon {
    switch (this) {
      case ChatWallpaper.obsidian:
        return Icons.dark_mode_rounded;
      case ChatWallpaper.titanium:
        return Icons.blur_on_rounded;
      case ChatWallpaper.midnight:
        return Icons.nights_stay_rounded;
      case ChatWallpaper.pearl:
        return Icons.auto_awesome_rounded;
    }
  }

  List<Color> gradientColors(bool isDark) {
    switch (this) {
      case ChatWallpaper.obsidian:
        return isDark
            ? const [
                Color(0xFF000000),
                Color(0xFF070709),
                Color(0xFF0C0C10),
              ]
            : const [
                Color(0xFF1C1D21),
                Color(0xFF141517),
                Color(0xFF0B0C0E),
              ];
      case ChatWallpaper.titanium:
        return isDark
            ? const [
                Color(0xFF15161A),
                Color(0xFF22242B),
                Color(0xFF141518),
              ]
            : const [
                Color(0xFFF7F7F9),
                Color(0xFFECECF1),
                Color(0xFFE2E2E8),
              ];
      case ChatWallpaper.midnight:
        return isDark
            ? const [
                Color(0xFF090D17),
                Color(0xFF111827),
                Color(0xFF0A0D15),
              ]
            : const [
                Color(0xFFF0F4F9),
                Color(0xFFE2E8F0),
                Color(0xFFD3DDE8),
              ];
      case ChatWallpaper.pearl:
        return isDark
            ? const [
                Color(0xFF18181B),
                Color(0xFF24242A),
                Color(0xFF18181B),
              ]
            : const [
                Color(0xFFFFFFFF),
                Color(0xFFF8F8FB),
                Color(0xFFF0F0F5),
              ];
    }
  }

  LinearGradient buildGradient(bool isDark) {
    return LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: gradientColors(isDark),
    );
  }

  BoxDecoration buildDecoration(bool isDark) {
    return BoxDecoration(
      gradient: buildGradient(isDark),
    );
  }
}

/// Controller for persisting and streaming ambient chat wallpaper preferences
class WallpaperController {
  static final ValueNotifier<ChatWallpaper> wallpaperNotifier =
      ValueNotifier<ChatWallpaper>(ChatWallpaper.obsidian);

  static const String _fileName = 'wallpaper_settings.json';

  /// Initialize wallpaper setting from local storage
  static Future<void> init() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/$_fileName');
      if (await file.exists()) {
        final content = await file.readAsString();
        final map = jsonDecode(content);
        final id = map['chat_wallpaper']?.toString();
        for (final w in ChatWallpaper.values) {
          if (w.id == id) {
            wallpaperNotifier.value = w;
            break;
          }
        }
      }
    } catch (_) {}
  }

  /// Change wallpaper, trigger micro-haptic feedback, and persist to disk
  static Future<void> setWallpaper(ChatWallpaper wallpaper) async {
    if (wallpaperNotifier.value == wallpaper) return;
    AppHaptics.selection();
    wallpaperNotifier.value = wallpaper;
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/$_fileName');
      final map = {'chat_wallpaper': wallpaper.id};
      await file.writeAsString(jsonEncode(map));
    } catch (_) {}
  }
}
