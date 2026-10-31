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
        // Staggered sine wave for smooth bouncing
        final double progress = (_controller.value - (index * 0.18)) % 1.0;
        final double bounce = progress < 0.5 ? progress * 2 : (1.0 - progress) * 2;
        final double offsetY = -3.5 * bounce;

        return Transform.translate(
          offset: Offset(0, offsetY),
          child: Container(
            width: widget.dotSize,
            height: widget.dotSize,
            margin: const EdgeInsets.symmetric(horizontal: 1.2),
            decoration: BoxDecoration(
              color: widget.color ?? AppTheme.success,
              shape: BoxShape.circle,
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final activeColor = widget.color ?? AppTheme.success;

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
