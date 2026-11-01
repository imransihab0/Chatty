import 'dart:math' as math;
import 'package:chatty/helper/app_haptics.dart';
import 'package:chatty/helper/app_theme.dart';
import 'package:chatty/services/theme_controller.dart';
import 'package:flutter/material.dart';

/// Full-screen circular wide-cover theme swap transition.
///
/// Sweeps an expanding circular disk across the entire screen from
/// the tap origin (like Telegram & modern iOS), cleanly unveiling the
/// new light/dark theme in a fluid, non-jarring motion.
class CircularThemeCover extends StatefulWidget {
  final Widget child;

  const CircularThemeCover({super.key, required this.child});

  static _CircularThemeCoverState? _stateOf(BuildContext context) {
    return context.findAncestorStateOfType<_CircularThemeCoverState>();
  }

  /// Triggers the circular expanding cover animation from the given origin
  static void trigger(
    BuildContext context, {
    Offset? origin,
    required VoidCallback onToggle,
  }) {
    final state = _stateOf(context);
    if (state != null) {
      state.startTransition(origin: origin, onToggle: onToggle);
    } else {
      onToggle();
    }
  }

  @override
  State<CircularThemeCover> createState() => _CircularThemeCoverState();
}

class _CircularThemeCoverState extends State<CircularThemeCover>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;

  Offset _origin = Offset.zero;
  bool _isTransitioning = false;
  Color _coverColor = Colors.black;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 460),
    );
    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOutCubic,
    );
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        setState(() {
          _isTransitioning = false;
        });
        _controller.reset();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void startTransition({Offset? origin, required VoidCallback onToggle}) {
    if (_isTransitioning) {
      onToggle();
      return;
    }

    final size = MediaQuery.sizeOf(context);
    final isDarkCurrently = ThemeController.isDark(context);
    // The incoming color will be the target theme's background:
    _coverColor = isDarkCurrently ? AppTheme.background : AppTheme.darkBackground;
    _origin = origin ?? Offset(size.width - 44, 56);

    AppHaptics.medium();

    setState(() {
      _isTransitioning = true;
    });

    onToggle();
    _controller.forward(from: 0.0);
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        if (_isTransitioning)
          Positioned.fill(
            child: IgnorePointer(
              child: AnimatedBuilder(
                animation: _animation,
                builder: (context, _) {
                  return CustomPaint(
                    painter: _CircularCoverPainter(
                      progress: _animation.value,
                      origin: _origin,
                      coverColor: _coverColor,
                    ),
                  );
                },
              ),
            ),
          ),
      ],
    );
  }
}

class _CircularCoverPainter extends CustomPainter {
  final double progress;
  final Offset origin;
  final Color coverColor;

  _CircularCoverPainter({
    required this.progress,
    required this.origin,
    required this.coverColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0.0) return;

    // Calculate maximum radius to guarantee covering all 4 screen corners
    final double maxDistX = math.max(origin.dx, size.width - origin.dx);
    final double maxDistY = math.max(origin.dy, size.height - origin.dy);
    final double maxRadius = math.sqrt(maxDistX * maxDistX + maxDistY * maxDistY) * 1.06;

    final double currentRadius = maxRadius * progress;
    // Fade out smoothly at the very tail (from 0.82 to 1.0) so handoff is imperceptible
    final double opacity = progress > 0.82 ? ((1.0 - progress) / 0.18).clamp(0.0, 1.0) : 1.0;

    final paint = Paint()
      ..color = coverColor.withValues(alpha: opacity)
      ..style = PaintingStyle.fill;

    canvas.drawCircle(origin, currentRadius, paint);

    // Subtle edge highlight ring for a tactile liquid sweep feel
    if (progress < 0.92 && opacity > 0.2) {
      final ringPaint = Paint()
        ..color = (coverColor == AppTheme.darkBackground
                ? Colors.white
                : Colors.black)
            .withValues(alpha: (0.10 * (1.0 - progress)).clamp(0.0, 0.12))
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0;

      canvas.drawCircle(origin, currentRadius, ringPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _CircularCoverPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.origin != origin ||
        oldDelegate.coverColor != coverColor;
  }
}
