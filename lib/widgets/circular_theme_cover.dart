import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:chatty/helper/app_haptics.dart';
import 'package:chatty/services/theme_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

/// Telegram-grade Circular Reveal Theme Transition.
///
/// When the user toggles Light/Dark Mode:
/// 1. Captures a pixel-perfect GPU snapshot of the active application screen.
/// 2. Switches the application theme state.
/// 3. Sweeps an expanding circular clipping mask (`ClipPath`) from the exact
///    global coordinates of the toggle button across the entire screen.
/// 4. As the circular mask expands outward, it reveals the new theme underneath
///    in real-time across AppBar, message cards, avatars, and bottom bars.
/// 5. Ensures zero widget rebuild overhead during animation ticks for 60/120 FPS.
class CircularThemeCover extends StatefulWidget {
  final Widget child;

  const CircularThemeCover({super.key, required this.child});

  static _CircularThemeCoverState? _stateOf(BuildContext context) {
    return context.findAncestorStateOfType<_CircularThemeCoverState>();
  }

  /// Triggers the circular reveal transition from the given origin.
  static void trigger(
    BuildContext context, {
    Offset? origin,
    required VoidCallback onToggle,
  }) {
    final state = _stateOf(context);
    if (state != null) {
      state.startReveal(origin: origin, onToggle: onToggle);
    } else {
      onToggle();
    }
  }

  @override
  State<CircularThemeCover> createState() => _CircularThemeCoverState();
}

class _CircularThemeCoverState extends State<CircularThemeCover>
    with SingleTickerProviderStateMixin {
  final GlobalKey _repaintKey = GlobalKey();

  late final AnimationController _controller;
  late final Animation<double> _animation;

  ui.Image? _oldThemeSnapshot;
  Offset _origin = Offset.zero;
  bool _isTransitioning = false;
  bool _isGoingDark = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOutCubic,
    );
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _finishTransition();
      }
    });
  }

  void _finishTransition() {
    if (!mounted) return;
    setState(() {
      _isTransitioning = false;
      _oldThemeSnapshot?.dispose();
      _oldThemeSnapshot = null;
    });
    _controller.reset();
  }

  @override
  void dispose() {
    _controller.dispose();
    _oldThemeSnapshot?.dispose();
    super.dispose();
  }

  Future<void> startReveal({
    Offset? origin,
    required VoidCallback onToggle,
  }) async {
    // Prevent multiple rapid taps from triggering conflicting transitions
    if (_isTransitioning) return;

    // Check system accessibility preferences
    final bool reduceMotion =
        MediaQuery.maybeOf(context)?.accessibleNavigation ??
        MediaQuery.maybeOf(context)?.disableAnimations ??
        false;

    if (reduceMotion) {
      AppHaptics.medium();
      onToggle();
      return;
    }

    try {
      final boundary = _repaintKey.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;

      if (boundary == null) {
        AppHaptics.medium();
        onToggle();
        return;
      }

      final pixelRatio = View.of(context).devicePixelRatio;
      final size = MediaQuery.sizeOf(context);
      final isDarkCurrently = ThemeController.isDark(context);

      if (!mounted) return;

      ui.Image image;
      try {
        image = await boundary.toImage(pixelRatio: pixelRatio);
      } catch (_) {
        // Wait for frame rendering to settle before taking snapshot
        await WidgetsBinding.instance.endOfFrame;
        if (!mounted) return;
        image = await boundary.toImage(pixelRatio: pixelRatio);
      }

      if (!mounted) {
        image.dispose();
        return;
      }

      AppHaptics.medium();

      setState(() {
        _isGoingDark = !isDarkCurrently;
        _origin = origin ?? Offset(size.width - 44, 56);
        _oldThemeSnapshot = image;
        _isTransitioning = true;
      });

      // Switch active application theme now that the old snapshot is securely layered on top
      onToggle();

      // Begin the expanding circular reveal animation
      _controller.forward(from: 0.0);
    } catch (e) {
      debugPrint('CircularThemeCover transition fallback: $e');
      _finishTransition();
      onToggle();
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);

    // Calculate maximum radius to guarantee covering all 4 screen corners
    final double maxDistX = math.max(_origin.dx, size.width - _origin.dx);
    final double maxDistY = math.max(_origin.dy, size.height - _origin.dy);
    final double maxRadius =
        math.sqrt(maxDistX * maxDistX + maxDistY * maxDistY) + 12.0;

    return RepaintBoundary(
      key: _repaintKey,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // When NOT transitioning, simply render the live application directly
          if (!_isTransitioning)
            widget.child
          else ...[
            // Layer 1 (Bottom): Pixel-perfect GPU snapshot of the PREVIOUS theme
            if (_oldThemeSnapshot != null)
              Positioned.fill(
                child: RawImage(
                  image: _oldThemeSnapshot,
                  width: size.width,
                  height: size.height,
                  fit: BoxFit.fill,
                ),
              ),

            // Layer 2 (Top): Live application in the NEW theme, clipped by the expanding circle
            Positioned.fill(
              child: AbsorbPointer(
                absorbing: _isTransitioning,
                child: AnimatedBuilder(
                  animation: _animation,
                  builder: (context, child) {
                    return ClipPath(
                      clipper: _CircularRevealClipper(
                        fraction: _animation.value,
                        center: _origin,
                        maxRadius: maxRadius,
                      ),
                      child: child,
                    );
                  },
                  child: widget.child,
                ),
              ),
            ),

            // Layer 3 (Overlay): Subtle high-precision luminous highlight ring along the circular cutting edge
            Positioned.fill(
              child: IgnorePointer(
                child: AnimatedBuilder(
                  animation: _animation,
                  builder: (context, _) {
                    return CustomPaint(
                      painter: _CircularRevealRimPainter(
                        fraction: _animation.value,
                        center: _origin,
                        maxRadius: maxRadius,
                        isGoingDark: _isGoingDark,
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _CircularRevealClipper extends CustomClipper<Path> {
  final double fraction;
  final Offset center;
  final double maxRadius;

  _CircularRevealClipper({
    required this.fraction,
    required this.center,
    required this.maxRadius,
  });

  @override
  Path getClip(Size size) {
    final Path path = Path();
    if (fraction <= 0.0) {
      return path; // Empty clip
    }
    if (fraction >= 1.0) {
      path.addRect(Rect.fromLTWH(0, 0, size.width, size.height));
      return path;
    }
    final double currentRadius = maxRadius * fraction;
    path.addOval(Rect.fromCircle(center: center, radius: currentRadius));
    return path;
  }

  @override
  bool shouldReclip(covariant _CircularRevealClipper oldClipper) {
    return oldClipper.fraction != fraction ||
        oldClipper.center != center ||
        oldClipper.maxRadius != maxRadius;
  }
}

class _CircularRevealRimPainter extends CustomPainter {
  final double fraction;
  final Offset center;
  final double maxRadius;
  final bool isGoingDark;

  _CircularRevealRimPainter({
    required this.fraction,
    required this.center,
    required this.maxRadius,
    required this.isGoingDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (fraction <= 0.002 || fraction >= 0.998) return;

    final double currentRadius = maxRadius * fraction;
    final double opacity = fraction < 0.08
        ? (fraction / 0.08)
        : (fraction > 0.88 ? ((1.0 - fraction) / 0.12) : 1.0);

    // 1. Soft subtle ambient glow behind the edge
    final Paint glowPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.5)
      ..color = (isGoingDark ? Colors.white : Colors.black).withValues(
        alpha: (isGoingDark ? 0.22 : 0.14) * opacity,
      );
    canvas.drawCircle(center, currentRadius, glowPaint);

    // 2. Crisp hairline edge defining the boundary wave
    final Paint linePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..color = (isGoingDark ? Colors.white : const Color(0xFF18181B)).withValues(
        alpha: (isGoingDark ? 0.42 : 0.28) * opacity,
      );
    canvas.drawCircle(center, currentRadius, linePaint);
  }

  @override
  bool shouldRepaint(covariant _CircularRevealRimPainter oldDelegate) {
    return oldDelegate.fraction != fraction ||
        oldDelegate.center != center ||
        oldDelegate.maxRadius != maxRadius ||
        oldDelegate.isGoingDark != isGoingDark;
  }
}
