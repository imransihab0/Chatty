import 'package:flutter/services.dart';

// Centralized Haptic Feedback utility for consistent tactile UX
class AppHaptics {
  // Soft tap on sending messages, avatar taps, and subtle UI events
  static void light() {
    HapticFeedback.lightImpact();
  }

  // Medium impact on theme changes, long-press triggers, and sheet openings
  static void medium() {
    HapticFeedback.mediumImpact();
  }

  // Heavy feedback on critical actions like message deletion and logout
  static void heavy() {
    HapticFeedback.heavyImpact();
  }

  // Crisp click on filter chip switches and tab selection
  static void selection() {
    HapticFeedback.selectionClick();
  }
}
