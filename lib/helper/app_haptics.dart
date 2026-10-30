import 'package:flutter/services.dart';

// Centralized Haptic Feedback utility for consistent tactile UX
class AppHaptics {
  // Global toggle for tactile feedback (can be toggled in profile settings)
  static bool enabled = true;

  // Soft tap on sending messages, avatar taps, and subtle UI events
  static void light() {
    if (!enabled) return;
    try {
      HapticFeedback.lightImpact();
    } catch (_) {}
  }

  // Medium impact on theme changes, long-press triggers, and sheet openings
  static void medium() {
    if (!enabled) return;
    try {
      HapticFeedback.mediumImpact();
    } catch (_) {}
  }

  // Heavy feedback on critical actions like message deletion and logout
  static void heavy() {
    if (!enabled) return;
    try {
      HapticFeedback.heavyImpact();
    } catch (_) {}
  }

  // Crisp click on filter chip switches and tab selection
  static void selection() {
    if (!enabled) return;
    try {
      HapticFeedback.selectionClick();
    } catch (_) {}
  }
}
