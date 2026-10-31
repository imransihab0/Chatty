import 'dart:async';
import 'dart:convert';
import 'dart:developer';
import 'dart:io';
import 'package:chatty/api/apis.dart';
import 'package:chatty/models/chat_user.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// Manages last message timestamps for all conversations to power
/// dynamic sorting where the latest chat is always placed on top.
class ConversationController {
  /// Reactive notifier containing Map of { userId: lastMessageTimestampMillis }
  static final ValueNotifier<Map<String, int>> lastMessageTimesNotifier =
      ValueNotifier<Map<String, int>>({});

  static final Map<String, StreamSubscription<QuerySnapshot<Map<String, dynamic>>>>
      _subscriptions = {};

  static Timer? _saveDebounce;

  static String get _fileName {
    final uid = APIs.auth.currentUser?.uid ?? 'default';
    return 'conversation_meta_$uid.json';
  }

  /// Initialize and load cached message timestamps from local persistent storage
  static Future<void> init() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/$_fileName');
      if (await file.exists()) {
        final content = await file.readAsString();
        final map = jsonDecode(content);
        if (map is Map) {
          final Map<String, int> loaded = {};
          map.forEach((key, value) {
            final intVal = int.tryParse(value.toString()) ?? 0;
            if (intVal > 0) {
              loaded[key.toString()] = intVal;
            }
          });
          lastMessageTimesNotifier.value = loaded;
        }
      }
    } catch (e) {
      log('Error ConversationController.init: $e');
    }
  }

  /// Returns the latest message timestamp in milliseconds for a user, or 0 if none
  static int getLastMessageTime(String userId) {
    return lastMessageTimesNotifier.value[userId] ?? 0;
  }

  /// Sets the exact timestamp for a user (called when last message stream emits)
  static void setLastMessageTime(String userId, int timestamp) {
    final current = Map<String, int>.from(lastMessageTimesNotifier.value);
    if (current[userId] == timestamp) return;

    if (timestamp <= 0) {
      current.remove(userId);
    } else {
      current[userId] = timestamp;
    }

    lastMessageTimesNotifier.value = current;
    _scheduleSave();
  }

  /// Updates timestamp only if the new timestamp is higher than current
  static void updateLastMessageTime(String userId, int timestamp) {
    if (timestamp <= 0) return;
    final currentVal = getLastMessageTime(userId);
    if (timestamp > currentVal) {
      setLastMessageTime(userId, timestamp);
    }
  }

  /// Subscribes to the last message streams of all active users
  static void watchUsers(List<ChatUser> users) {
    for (final user in users) {
      if (user.id.isEmpty) continue;
      if (_subscriptions.containsKey(user.id)) continue;

      _subscriptions[user.id] = APIs.getLastMessages(user).listen(
        (snapshot) {
          if (snapshot.docs.isNotEmpty) {
            final data = snapshot.docs.first.data();
            final sentStr = data['sent']?.toString() ?? '';
            final sentInt = int.tryParse(sentStr) ?? 0;
            setLastMessageTime(user.id, sentInt);
          } else {
            // No messages in this conversation
            setLastMessageTime(user.id, 0);
          }
        },
        onError: (e) {
          log('Error watching last message for ${user.id}: $e');
        },
      );
    }
  }

  /// Schedule debounced write to local disk
  static void _scheduleSave() {
    _saveDebounce?.cancel();
    _saveDebounce = Timer(const Duration(milliseconds: 300), () async {
      try {
        final dir = await getApplicationDocumentsDirectory();
        final file = File('${dir.path}/$_fileName');
        await file.writeAsString(jsonEncode(lastMessageTimesNotifier.value));
      } catch (e) {
        log('Error saving conversation meta: $e');
      }
    });
  }

  /// Cancel all subscriptions and clean up
  static void dispose() {
    for (final sub in _subscriptions.values) {
      sub.cancel();
    }
    _subscriptions.clear();
    _saveDebounce?.cancel();
  }

  /// Reset state on user logout
  static void reset() {
    dispose();
    lastMessageTimesNotifier.value = {};
  }
}
