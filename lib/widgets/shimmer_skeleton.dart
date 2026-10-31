import 'package:chatty/helper/app_theme.dart';
import 'package:flutter/material.dart';

/// Lightweight, high-performance shimmer skeleton loader for monochrome themes
class ShimmerSkeleton extends StatefulWidget {
  final Widget child;

  const ShimmerSkeleton({super.key, required this.child});

  @override
  State<ShimmerSkeleton> createState() => _ShimmerSkeletonState();
}

class _ShimmerSkeletonState extends State<ShimmerSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = context.isDark;
    final highlight = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : Colors.white.withValues(alpha: 0.45);

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return ShaderMask(
          blendMode: BlendMode.srcOver,
          shaderCallback: (bounds) {
            return LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.transparent,
                highlight,
                Colors.transparent,
              ],
              stops: const [0.35, 0.50, 0.65],
              transform: _SlidingGradientTransform(slidePercent: _controller.value),
            ).createShader(bounds);
          },
          child: child,
        );
      },
      child: widget.child,
    );
  }
}

class _SlidingGradientTransform extends GradientTransform {
  const _SlidingGradientTransform({required this.slidePercent});

  final double slidePercent;

  @override
  Matrix4? transform(Rect bounds, {TextDirection? textDirection}) {
    return Matrix4.translationValues(bounds.width * (slidePercent * 2 - 1), 0.0, 0.0);
  }
}

/// Base rounded skeleton block
class SkeletonBox extends StatelessWidget {
  final double? width;
  final double? height;
  final double borderRadius;

  const SkeletonBox({
    super.key,
    this.width,
    this.height,
    this.borderRadius = 8,
  });

  @override
  Widget build(BuildContext context) {
    final color = context.isDark ? const Color(0xFF222222) : const Color(0xFFE4E4E7);
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(borderRadius),
      ),
    );
  }
}

/// Shimmer list placeholder for the Home conversation screen with zero layout shift
class HomeConversationSkeletonList extends StatelessWidget {
  const HomeConversationSkeletonList({super.key});

  @override
  Widget build(BuildContext context) {
    return ShimmerSkeleton(
      child: SingleChildScrollView(
        physics: const NeverScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Search Pill Placeholder
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Container(
                height: 48,
                decoration: BoxDecoration(
                  color: context.surfaceMutedColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: context.borderColor, width: 0.8),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: const Row(
                  children: [
                    SkeletonBox(
                      width: 18,
                      height: 18,
                      borderRadius: 9,
                    ),
                    SizedBox(width: 12),
                    SkeletonBox(
                      width: 130,
                      height: 14,
                      borderRadius: 6,
                    ),
                  ],
                ),
              ),
            ),

            // Active Friends Tray Carousel Placeholder
            Container(
              margin: const EdgeInsets.only(top: 6, bottom: 8),
              height: 104,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: 5,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemBuilder: (context, index) {
                  return const Padding(
                    padding: EdgeInsets.only(right: 14),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SkeletonBox(width: 56, height: 56, borderRadius: 28),
                        SizedBox(height: 8),
                        SkeletonBox(width: 48, height: 11, borderRadius: 4),
                      ],
                    ),
                  );
                },
              ),
            ),

            // Filter Chips Bar Placeholder
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                children: [
                  SkeletonBox(width: 58, height: 34, borderRadius: 17),
                  SizedBox(width: 8),
                  SkeletonBox(width: 82, height: 34, borderRadius: 17),
                  SizedBox(width: 8),
                  SkeletonBox(width: 78, height: 34, borderRadius: 17),
                  SizedBox(width: 8),
                  SkeletonBox(width: 74, height: 34, borderRadius: 17),
                ],
              ),
            ),
            const SizedBox(height: 8),

            // Conversation Tiles Placeholder
            ...List.generate(6, (index) {
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: context.surfaceColor,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: context.borderColor, width: 0.8),
                ),
                child: Row(
                  children: [
                    const SkeletonBox(width: 50, height: 50, borderRadius: 25),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              SkeletonBox(
                                width: (index % 2 == 0) ? 120 : 90,
                                height: 15,
                                borderRadius: 6,
                              ),
                              const SkeletonBox(width: 42, height: 11, borderRadius: 4),
                            ],
                          ),
                          const SizedBox(height: 8),
                          SkeletonBox(
                            width: (index % 3 == 0) ? 180 : 130,
                            height: 12,
                            borderRadius: 5,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

/// Shimmer list placeholder for the Chat screen message timeline
class ChatMessagesSkeletonList extends StatelessWidget {
  const ChatMessagesSkeletonList({super.key});

  @override
  Widget build(BuildContext context) {
    return ShimmerSkeleton(
      child: ListView.builder(
        reverse: true,
        itemCount: 7,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        physics: const NeverScrollableScrollPhysics(),
        itemBuilder: (context, index) {
          final bool isMe = index % 2 == 0;
          return Align(
            alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
            child: Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: isMe
                    ? (context.isDark ? const Color(0xFF2C2C2C) : const Color(0xFF1C1C1E))
                    : context.surfaceColor,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(18),
                  topRight: const Radius.circular(18),
                  bottomLeft: Radius.circular(isMe ? 18 : 4),
                  bottomRight: Radius.circular(isMe ? 4 : 18),
                ),
                border: isMe ? null : Border.all(color: context.borderColor),
              ),
              child: Column(
                crossAxisAlignment:
                    isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                children: [
                  SkeletonBox(
                    width: (index * 47 % 100 + 80).toDouble(),
                    height: 14,
                    borderRadius: 6,
                  ),
                  const SizedBox(height: 6),
                  const SkeletonBox(width: 36, height: 9, borderRadius: 4),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
