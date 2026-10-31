import 'package:chatty/helper/app_haptics.dart';
import 'package:chatty/helper/app_theme.dart';
import 'package:chatty/services/chat_settings_controller.dart';
import 'package:flutter/material.dart';

/// Customizable Background Wallpaper with presets:
/// - 'doodle': Messaging doodles pattern
/// - 'pureBlack': Solid minimalist OLED black
/// - 'graphite': Neutral charcoal monochrome gradient
/// - 'mesh': Minimalist slate depth gradient
class ChatWallpaper extends StatelessWidget {
  final Widget child;

  const ChatWallpaper({super.key, required this.child});

  static const List<Map<String, String>> presets = [
    {
      'id': 'doodle',
      'name': 'Telegram Doodle',
      'desc': 'Subtle monochrome patterns',
    },
    {
      'id': 'pureBlack',
      'name': 'Minimalist Pure OLED',
      'desc': 'Clean solid monochrome',
    },
    {
      'id': 'graphite',
      'name': 'Neutral Charcoal',
      'desc': 'Pure grey depth gradient',
    },
    {
      'id': 'mesh',
      'name': 'Minimalist Slate',
      'desc': 'Soft monochrome tone',
    },
  ];

  static void showWallpaperPicker(BuildContext context) {
    AppHaptics.medium();
    showModalBottomSheet(
      context: context,
      backgroundColor: context.surfaceColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 38,
                    height: 4,
                    decoration: BoxDecoration(
                      color: context.borderColor,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  'Chat Wallpaper Theme',
                  style: TextStyle(
                    fontFamily: 'Lexend',
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: context.textPrimaryColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Choose the background styling for your conversations',
                  style: TextStyle(
                    fontFamily: 'Lexend',
                    fontSize: 13,
                    color: context.textSecondaryColor,
                  ),
                ),
                const SizedBox(height: 18),
                ValueListenableBuilder<String>(
                  valueListenable:
                      ChatSettingsController.wallpaperThemeNotifier,
                  builder: (context, current, _) {
                    return Column(
                      children: presets.map((preset) {
                        final id = preset['id']!;
                        final isSelected = current == id;

                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? context.primarySoftColor
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: isSelected
                                  ? (context.isDark
                                      ? Colors.white
                                      : Colors.black)
                                  : context.borderColor,
                              width: isSelected ? 1.5 : 1,
                            ),
                          ),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 4),
                            leading: WallpaperThumbnail(
                              presetId: id,
                              isSelected: isSelected,
                              width: 44,
                              height: 52,
                              showChatBubbles: true,
                            ),
                            title: Text(
                              preset['name']!,
                              style: TextStyle(
                                fontFamily: 'Lexend',
                                fontSize: 14,
                                fontWeight: isSelected
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                                color: context.textPrimaryColor,
                              ),
                            ),
                            subtitle: Text(
                              preset['desc']!,
                              style: TextStyle(
                                fontFamily: 'Lexend',
                                fontSize: 11,
                                color: context.textSecondaryColor,
                              ),
                            ),
                            trailing: isSelected
                                ? Icon(
                                    Icons.check_circle_rounded,
                                    color: context.textPrimaryColor,
                                    size: 20,
                                  )
                                : null,
                            onTap: () {
                              ChatSettingsController.setWallpaperTheme(id);
                              Navigator.pop(context);
                            },
                          ),
                        );
                      }).toList(),
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: ChatSettingsController.wallpaperThemeNotifier,
      builder: (context, wallpaperTheme, _) {
        if (wallpaperTheme == 'pureBlack') {
          return Container(
            color: context.backgroundColor,
            child: child,
          );
        }

        if (wallpaperTheme == 'graphite' || wallpaperTheme == 'midnight') {
          return Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: context.isDark
                    ? const [
                        Color(0xFF18181B),
                        Color(0xFF09090B),
                        Color(0xFF000000),
                      ]
                    : const [
                        Color(0xFFF4F4F5),
                        Color(0xFFE4E4E7),
                        Color(0xFFFFFFFF),
                      ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
            child: child,
          );
        }

        if (wallpaperTheme == 'mesh' || wallpaperTheme == 'sunset') {
          return Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: context.isDark
                    ? const [
                        Color(0xFF27272A),
                        Color(0xFF18181B),
                        Color(0xFF000000),
                      ]
                    : const [
                        Color(0xFFFAFAFA),
                        Color(0xFFF0F0F2),
                        Color(0xFFFFFFFF),
                      ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: child,
          );
        }

        // Default: 'doodle'
        return Container(
          color: context.backgroundColor,
          child: CustomPaint(
            painter: _DoodlePatternPainter(
              color: context.isDark
                  ? Colors.white.withValues(alpha: 0.035)
                  : Colors.black.withValues(alpha: 0.035),
            ),
            child: child,
          ),
        );
      },
    );
  }
}

/// Miniature Preview Thumbnail representing a wallpaper with miniature bubbles
class WallpaperThumbnail extends StatelessWidget {
  final String presetId;
  final bool isSelected;
  final VoidCallback? onTap;
  final double width;
  final double height;
  final bool showChatBubbles;

  const WallpaperThumbnail({
    super.key,
    required this.presetId,
    this.isSelected = false,
    this.onTap,
    this.width = 56,
    this.height = 76,
    this.showChatBubbles = true,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: width,
        height: height,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected
                ? (context.isDark ? Colors.white : Colors.black)
                : context.borderColor,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: (context.isDark ? Colors.white : Colors.black)
                        .withValues(alpha: 0.16),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Stack(
            children: [
              Positioned.fill(child: _buildBackground(context)),
              if (showChatBubbles)
                Positioned.fill(
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 5, vertical: 8),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Container(
                            width: width * 0.52,
                            height: 6,
                            decoration: BoxDecoration(
                              color: context.isDark
                                  ? const Color(0xFF27272A)
                                  : const Color(0xFFE4E4E7),
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                        ),
                        Align(
                          alignment: Alignment.centerRight,
                          child: Container(
                            width: width * 0.44,
                            height: 6,
                            decoration: BoxDecoration(
                              color:
                                  context.isDark ? Colors.white : Colors.black,
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              if (isSelected)
                Positioned(
                  top: 3,
                  right: 3,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: context.isDark ? Colors.white : Colors.black,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.check,
                      size: 9,
                      color: context.isDark ? Colors.black : Colors.white,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBackground(BuildContext context) {
    if (presetId == 'pureBlack') {
      return Container(
        color:
            context.isDark ? const Color(0xFF000000) : const Color(0xFFF7F7F8),
      );
    }
    if (presetId == 'graphite' || presetId == 'midnight') {
      return Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: context.isDark
                ? const [
                    Color(0xFF18181B),
                    Color(0xFF09090B),
                    Color(0xFF000000),
                  ]
                : const [
                    Color(0xFFF4F4F5),
                    Color(0xFFE4E4E7),
                    Color(0xFFFFFFFF),
                  ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
      );
    }
    if (presetId == 'mesh' || presetId == 'sunset') {
      return Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: context.isDark
                ? const [
                    Color(0xFF27272A),
                    Color(0xFF18181B),
                    Color(0xFF000000),
                  ]
                : const [
                    Color(0xFFFAFAFA),
                    Color(0xFFF0F0F2),
                    Color(0xFFFFFFFF),
                  ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
      );
    }
    // Default 'doodle'
    return Container(
      color:
          context.isDark ? const Color(0xFF09090B) : const Color(0xFFF7F7F8),
      child: CustomPaint(
        painter: _DoodlePatternPainter(
          color: context.isDark
              ? Colors.white.withValues(alpha: 0.12)
              : Colors.black.withValues(alpha: 0.12),
        ),
      ),
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
