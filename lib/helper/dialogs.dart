import 'dart:async';
import 'dart:ui' show ImageFilter;
import 'package:chatty/helper/app_haptics.dart';
import 'package:chatty/helper/app_theme.dart';
import 'package:flutter/material.dart';

class Dialogs {
  static OverlayEntry? _activeToast;
  static _TelegramToastWidgetState? _activeToastState;

  /// Shows an ultra-sleek Telegram-style floating top toast notification capsule.
  ///
  /// Features:
  /// - Floats gracefully at the TOP just below the safe area / status bar
  /// - Never covers the keyboard, chat input bar, or voice recording controls
  /// - Apple Dynamic-Island / Telegram frosted glass pill styling
  /// - Spring entrance physics + smooth slide-and-fade exit
  /// - Context-aware icons (danger red, success green, clipboard copy, mic, info)
  /// - Interactive: swipe up or tap to dismiss immediately
  /// - Tactile haptic feedback on presentation
  static void showSnackbar(
    BuildContext context,
    String msg, {
    IconData? icon,
    bool isError = false,
  }) {
    AppHaptics.light();

    // If an active toast is showing, remove it cleanly
    if (_activeToast != null) {
      try {
        _activeToastState?.dismissImmediate();
        _activeToast?.remove();
      } catch (_) {}
      _activeToast = null;
      _activeToastState = null;
    }

    final overlay =
        Overlay.maybeOf(context, rootOverlay: true) ?? Overlay.maybeOf(context);
    if (overlay == null) return;

    late final OverlayEntry entry;
    final GlobalKey<_TelegramToastWidgetState> key = GlobalKey();

    entry = OverlayEntry(
      builder: (ctx) => _TelegramToastWidget(
        key: key,
        message: msg,
        customIcon: icon,
        isExplicitError: isError,
        onDismissed: () {
          if (_activeToast == entry) {
            try {
              _activeToast?.remove();
            } catch (_) {}
            _activeToast = null;
            _activeToastState = null;
          }
        },
      ),
    );

    _activeToast = entry;
    overlay.insert(entry);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _activeToastState = key.currentState;
    });
  }

  static void showProgressbar(BuildContext context, {Color? color}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Center(
        child: Container(
          width: 70,
          height: 70,
          decoration: BoxDecoration(
            color: context.surfaceColor,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: context.borderColor, width: 0.8),
            boxShadow: context.softShadow,
          ),
          padding: const EdgeInsets.all(18),
          child: CircularProgressIndicator(
            strokeWidth: 3,
            valueColor: AlwaysStoppedAnimation<Color>(
                color ?? (context.isDark ? Colors.white : Colors.black)),
          ),
        ),
      ),
    );
  }
}

/// Telegram-Grade Top Floating Toast Capsule with Glassmorphism & Spring Physics
class _TelegramToastWidget extends StatefulWidget {
  final String message;
  final IconData? customIcon;
  final bool isExplicitError;
  final VoidCallback onDismissed;

  const _TelegramToastWidget({
    super.key,
    required this.message,
    this.customIcon,
    this.isExplicitError = false,
    required this.onDismissed,
  });

  @override
  State<_TelegramToastWidget> createState() => _TelegramToastWidgetState();
}

class _TelegramToastWidgetState extends State<_TelegramToastWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fadeAnimation;
  late final Animation<Offset> _slideAnimation;
  late final Animation<double> _scaleAnimation;
  Timer? _autoDismissTimer;
  bool _isDismissing = false;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
      reverseDuration: const Duration(milliseconds: 200),
    );

    // Dynamic Island spring entrance
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -0.45),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOutBack,
        reverseCurve: Curves.easeInCubic,
      ),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOut,
        reverseCurve: Curves.easeIn,
      ),
    );

    _scaleAnimation = Tween<double>(begin: 0.92, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOutBack,
        reverseCurve: Curves.easeInCubic,
      ),
    );

    _controller.forward();

    // Auto dismiss after 2.6 seconds
    _autoDismissTimer = Timer(const Duration(milliseconds: 2600), () {
      dismiss();
    });
  }

  void dismiss() {
    if (_isDismissing || !mounted) return;
    _isDismissing = true;
    _autoDismissTimer?.cancel();
    _controller.reverse().then((_) {
      if (mounted) {
        widget.onDismissed();
      }
    });
  }

  void dismissImmediate() {
    _autoDismissTimer?.cancel();
    if (mounted) {
      widget.onDismissed();
    }
  }

  @override
  void dispose() {
    _autoDismissTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lower = widget.message.toLowerCase();
    final bool isError = widget.isExplicitError ||
        lower.contains('error') ||
        lower.contains('failed') ||
        lower.contains('denied') ||
        lower.contains('cannot') ||
        lower.contains('not found') ||
        lower.contains('permission required');

    final bool isSuccess = lower.contains('success') ||
        lower.contains('updated') ||
        lower.contains('saved');

    final bool isCopy = lower.contains('copied') || lower.contains('clipboard');
    final bool isVoice = lower.contains('mic') ||
        lower.contains('voice') ||
        lower.contains('record');

    final IconData icon = widget.customIcon ??
        (isError
            ? Icons.error_outline_rounded
            : isCopy
                ? Icons.copy_rounded
                : isVoice
                    ? Icons.mic_rounded
                    : isSuccess
                        ? Icons.check_circle_rounded
                        : Icons.info_outline_rounded);

    final Color iconColor = isError
        ? const Color(0xFFEF4444)
        : isSuccess
            ? const Color(0xFF22C55E)
            : Colors.white;

    return SafeArea(
      top: true,
      bottom: false,
      child: Align(
        alignment: Alignment.topCenter,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: SlideTransition(
            position: _slideAnimation,
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: ScaleTransition(
                scale: _scaleAnimation,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: dismiss,
                  onVerticalDragUpdate: (details) {
                    if (details.primaryDelta! < -2) {
                      dismiss();
                    }
                  },
                  child: Material(
                    type: MaterialType.transparency,
                    child: Container(
                      constraints: const BoxConstraints(
                        minHeight: 42,
                        maxWidth: 380,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF18181B).withValues(alpha: 0.92),
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.14),
                          width: 0.8,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.28),
                            blurRadius: 18,
                            spreadRadius: 1,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(22),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 10,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                // Context Icon with soft glow circle
                                Container(
                                  width: 26,
                                  height: 26,
                                  decoration: BoxDecoration(
                                    color: iconColor.withValues(alpha: 0.16),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Center(
                                    child: Icon(
                                      icon,
                                      size: 15,
                                      color: iconColor,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 9),

                                // Message Text
                                Flexible(
                                  child: Text(
                                    widget.message,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontFamily: 'Lexend',
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                      color: Colors.white,
                                      height: 1.25,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
