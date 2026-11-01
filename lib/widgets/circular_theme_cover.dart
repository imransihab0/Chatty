import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:chatty/helper/app_haptics.dart';
import 'package:chatty/services/theme_controller.dart';
import 'package:flutter/material.dart';

/// Translucent luminous radiant wave theme swap transition.
///
/// Sweeps a radiant, glowing shockwave band across the screen from the tap
/// origin (like an ethereal sonar ripple / aurora wave), washing over all
/// UI elements without blanking them out — leaving cards, avatars, and
/// text crystal clear while illuminating the new theme.
class CircularThemeCover extends StatefulWidget {
  final Widget child;

  const CircularThemeCover({super.key, required this.child});

  static _CircularThemeCoverState? _stateOf(BuildContext context) {
    return context.findAncestorStateOfType<_CircularThemeCoverState>();
  }

  /// Triggers the luminous radiant wave animation from the given origin
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
  bool _isGoingDark = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 520),
    );
    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
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
    _isGoingDark = !isDarkCurrently;
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
                    painter: _RadiantWavePainter(
                      progress: _animation.value,
                      origin: _origin,
                      isGoingDark: _isGoingDark,
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

class _RadiantWavePainter extends CustomPainter {
  final double progress;
  final Offset origin;
  final bool isGoingDark;

  _RadiantWavePainter({
    required this.progress,
    required this.origin,
    required this.isGoingDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0.0 || progress >= 1.0) return;

    // Calculate maximum radius to guarantee reaching all corners
    final double maxDistX = math.max(origin.dx, size.width - origin.dx);
    final double maxDistY = math.max(origin.dy, size.height - origin.dy);
    final double maxRadius =
        math.sqrt(maxDistX * maxDistX + maxDistY * maxDistY) * 1.08;

    final double currentRadius = maxRadius * progress;
    const double bandWidth = 160.0; // Width of the traveling luminous band
    final double innerRadius = math.max(0.0, currentRadius - bandWidth);

    // Smooth entry and exit opacity so the ripple starts and lands smoothly
    final double overallOpacity = progress < 0.12
        ? (progress / 0.12)
        : (progress > 0.82 ? ((1.0 - progress) / 0.18) : 1.0);

    // 1. Translucent Annular Radiant Shade
    // Travels outward as a hollow luminous ring:
    // UI elements INSIDE the ring and AHEAD of the ring are 100% visible!
    if (currentRadius > 10) {
      final Paint glowPaint = Paint()
        ..shader = ui.Gradient.radial(
          origin,
          currentRadius,
          [
            Colors.transparent,
            (isGoingDark ? const Color(0xFF18181B) : Colors.white).withValues(
              alpha: (isGoingDark ? 0.32 : 0.40) * overallOpacity,
            ),
            (isGoingDark ? const Color(0xFF3F3F46) : const Color(0xFFFFFFFF))
                .withValues(
              alpha: (isGoingDark ? 0.45 : 0.55) * overallOpacity,
            ),
            Colors.transparent,
          ],
          [
            math.max(0.0, innerRadius / currentRadius).clamp(0.0, 0.98),
            ((innerRadius + bandWidth * 0.55) / currentRadius).clamp(0.0, 0.98),
            0.98,
            1.0,
          ],
        );

      canvas.drawCircle(origin, currentRadius, glowPaint);
    }

    // 2. Soft Radiant Aura ahead of the wave crest
    // Creates a glowing lens flare / neon halo effect passing over the UI
    final Paint auraPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 9.0
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5.0)
      ..color = (isGoingDark ? const Color(0xFFA1A1AA) : Colors.white).withValues(
        alpha: (isGoingDark ? 0.22 : 0.42) * overallOpacity,
      );

    canvas.drawCircle(origin, currentRadius, auraPaint);

    // 3. Crisp Luminous Shockwave Crest Line
    // A high-contrast traveling wavefront ring that cleanly outlines the wave
    // as it sweeps across the avatars and cards, proving "that it is coming"
    final Paint crestPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..color = (isGoingDark ? Colors.white : const Color(0xFF09090B)).withValues(
        alpha: (isGoingDark ? 0.48 : 0.32) * overallOpacity,
      );

    canvas.drawCircle(origin, currentRadius, crestPaint);
  }

  @override
  bool shouldRepaint(covariant _RadiantWavePainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.origin != origin ||
        oldDelegate.isGoingDark != isGoingDark;
  }
}
