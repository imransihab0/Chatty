import 'dart:math' as math;
import 'package:chatty/helper/app_theme.dart';
import 'package:flutter/material.dart';

/// Animated 3-dot pulsing wave indicator for typing status
class TypingWaveDots extends StatefulWidget {
  final Color? color;
  final double dotSize;
  final bool showLabel;
  final String label;

  const TypingWaveDots({
    super.key,
    this.color,
    this.dotSize = 4.0,
    this.showLabel = true,
    this.label = 'typing...',
  });

  @override
  State<TypingWaveDots> createState() => _TypingWaveDotsState();
}

class _TypingWaveDotsState extends State<TypingWaveDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Widget _buildDot(int index) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        // Smooth harmonic sine wave for natural organic bounce
        final double phase = (_controller.value * 2 * math.pi) - (index * 0.8);
        final double bounce = (math.sin(phase) + 1.0) / 2.0;
        final double offsetY = -3.2 * bounce;

        final Color dotColor = widget.color ??
            (context.isDark ? AppTheme.success : const Color(0xFF047857));

        return Transform.translate(
          offset: Offset(0, offsetY),
          child: Container(
            width: widget.dotSize,
            height: widget.dotSize,
            margin: const EdgeInsets.symmetric(horizontal: 1.2),
            decoration: BoxDecoration(
              color: dotColor,
              shape: BoxShape.circle,
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final activeColor = widget.color ??
        (context.isDark ? AppTheme.success : const Color(0xFF047857));

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (widget.showLabel) ...[
          Text(
            widget.label,
            style: TextStyle(
              fontFamily: 'Lexend',
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: activeColor,
            ),
          ),
          const SizedBox(width: 4),
        ],
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildDot(0),
            _buildDot(1),
            _buildDot(2),
          ],
        ),
      ],
    );
  }
}
