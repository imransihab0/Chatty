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
    final baseColor = isDark ? const Color(0xFF1E1E1E) : const Color(0xFFE4E4E7);
    final highlightColor =
        isDark ? const Color(0xFF2C2C2C) : const Color(0xFFF4F4F5);

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (bounds) {
            return LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                baseColor,
                highlightColor,
                baseColor,
              ],
              stops: const [0.0, 0.5, 1.0],
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

/// Shimmer list placeholder for the Home conversation screen
class HomeConversationSkeletonList extends StatelessWidget {
  const HomeConversationSkeletonList({super.key});

  @override
  Widget build(BuildContext context) {
    return ShimmerSkeleton(
      child: ListView.builder(
        itemCount: 8,
        padding: const EdgeInsets.symmetric(vertical: 8),
        physics: const NeverScrollableScrollPhysics(),
        itemBuilder: (context, index) {
          return Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: context.surfaceColor,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: context.borderColor),
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
                          const SkeletonBox(width: 40, height: 11, borderRadius: 4),
                        ],
                      ),
                      const SizedBox(height: 8),
                      SkeletonBox(
                        width: (index % 3 == 0) ? 180 : 140,
                        height: 12,
                        borderRadius: 5,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
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
