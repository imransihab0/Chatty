import 'package:chatty/helper/app_theme.dart';
import 'package:flutter/material.dart';

/// Custom Background Wallpaper with subtle messaging doodles
class ChatWallpaper extends StatelessWidget {
  final Widget child;

  const ChatWallpaper({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _DoodlePatternPainter(
        color: context.isDark
            ? Colors.white.withValues(alpha: 0.035)
            : Colors.black.withValues(alpha: 0.035),
      ),
      child: child,
    );
  }
}

class _DoodlePatternPainter extends CustomPainter {
  final Color color;

  _DoodlePatternPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;

    const double stepX = 90.0;
    const double stepY = 100.0;

    for (double y = 20; y < size.height; y += stepY) {
      for (double x = 20; x < size.width; x += stepX) {
        final int pattern = ((x / stepX).floor() + (y / stepY).floor()) % 4;

        switch (pattern) {
          case 0:
            // Chat bubble
            final rect = RRect.fromRectAndRadius(
              Rect.fromLTWH(x, y, 22, 16),
              const Radius.circular(5),
            );
            canvas.drawRRect(rect, paint);
            break;
          case 1:
            // Heart outline
            final path = Path()
              ..moveTo(x + 10, y + 5)
              ..cubicTo(x + 5, y, x, y + 7, x + 10, y + 15)
              ..cubicTo(x + 20, y + 7, x + 15, y, x + 10, y + 5);
            canvas.drawPath(path, paint);
            break;
          case 2:
            // Paper plane outline
            final planePath = Path()
              ..moveTo(x, y)
              ..lineTo(x + 18, y + 8)
              ..lineTo(x + 6, y + 10)
              ..close()
              ..moveTo(x + 6, y + 10)
              ..lineTo(x + 10, y + 16);
            canvas.drawPath(planePath, paint);
            break;
          case 3:
            // Smiley circle
            canvas.drawCircle(Offset(x + 9, y + 8), 8, paint);
            break;
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DoodlePatternPainter oldDelegate) =>
      oldDelegate.color != color;
}
