import 'dart:convert';
import 'dart:io';
import 'package:chatty/helper/app_haptics.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

/// Controller for managing pinned conversations and chat preferences
class ChatSettingsController {
  static final ValueNotifier<Set<String>> pinnedNotifier =
      ValueNotifier<Set<String>>({});

  static const String _fileName = 'chat_preferences.json';

  static Future<void> init() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/$_fileName');
      if (await file.exists()) {
        final content = await file.readAsString();
        final map = jsonDecode(content);
        final List<dynamic>? list = map['pinned_users'];
        if (list != null) {
          pinnedNotifier.value = list.map((e) => e.toString()).toSet();
        }
      }
    } catch (_) {}
  }

  static bool isPinned(String userId) {
    return pinnedNotifier.value.contains(userId);
  }

  static Future<void> togglePin(String userId) async {
    AppHaptics.medium();
    final updated = Set<String>.from(pinnedNotifier.value);
    if (updated.contains(userId)) {
      updated.remove(userId);
    } else {
      updated.add(userId);
    }
    pinnedNotifier.value = updated;

    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/$_fileName');
      final map = {'pinned_users': updated.toList()};
      await file.writeAsString(jsonEncode(map));
    } catch (_) {}
  }
}
