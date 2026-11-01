import 'package:cached_network_image/cached_network_image.dart';
import 'package:chatty/helper/app_haptics.dart';
import 'package:chatty/helper/app_theme.dart';
import 'package:flutter/material.dart';

/// ---------------------------------------------------------------------------
/// REUSABLE COMPONENT STANDARDS (Chatty Design System)
/// Fully theme-adaptive, high-contrast monochrome, iOS/Telegram-grade tactile feel.
/// ---------------------------------------------------------------------------

enum AppButtonVariant { primary, secondary, danger, outline }

/// Premium Button with built-in tactile haptics, loading state, and smooth press feedback
class AppButton extends StatefulWidget {
  final String label;
  final VoidCallback? onPressed;
  final AppButtonVariant variant;
  final IconData? icon;
  final bool isLoading;
  final double? width;
  final double height;
  final BorderRadius? borderRadius;

  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = AppButtonVariant.primary,
    this.icon,
    this.isLoading = false,
    this.width,
    this.height = 48.0,
    this.borderRadius,
  });

  @override
  State<AppButton> createState() => _AppButtonState();
}

class _AppButtonState extends State<AppButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final bool isDark = context.isDark;
    final bool isEnabled = widget.onPressed != null && !widget.isLoading;

    Color bg;
    Color fg;
    Border? border;

    switch (widget.variant) {
      case AppButtonVariant.primary:
        bg = isDark ? Colors.white : Colors.black;
        fg = isDark ? Colors.black : Colors.white;
        break;
      case AppButtonVariant.secondary:
        bg = context.surfaceMutedColor;
        fg = context.textPrimaryColor;
        border = Border.all(color: context.borderColor, width: 0.8);
        break;
      case AppButtonVariant.danger:
        bg = AppTheme.danger;
        fg = Colors.white;
        break;
      case AppButtonVariant.outline:
        bg = Colors.transparent;
        fg = context.textPrimaryColor;
        border = Border.all(color: context.borderColor, width: 1.0);
        break;
    }

    if (!isEnabled) {
      bg = bg.withValues(alpha: 0.4);
      fg = fg.withValues(alpha: 0.4);
    }

    final effectiveRadius = widget.borderRadius ?? AppRadius.radiusPill;

    return GestureDetector(
      onTapDown: isEnabled
          ? (_) {
              setState(() => _isPressed = true);
            }
          : null,
      onTapUp: isEnabled
          ? (_) {
              setState(() => _isPressed = false);
            }
          : null,
      onTapCancel: isEnabled
          ? () {
              setState(() => _isPressed = false);
            }
          : null,
      onTap: isEnabled
          ? () {
              AppHaptics.light();
              widget.onPressed?.call();
            }
          : null,
      child: AnimatedScale(
        scale: _isPressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeOutCubic,
        child: Container(
          width: widget.width,
          height: widget.height,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: effectiveRadius,
            border: border,
          ),
          child: Center(
            child: widget.isLoading
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.2,
                      valueColor: AlwaysStoppedAnimation<Color>(fg),
                    ),
                  )
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (widget.icon != null) ...[
                        Icon(widget.icon, size: 18, color: fg),
                        AppSpacing.gapW8,
                      ],
                      Text(
                        widget.label,
                        style: TextStyle(
                          fontFamily: AppTypography.fontFamily,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: fg,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

/// Tactile Icon Button with guaranteed >= 44x44pt accessibility touch target
class AppIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;
  final String? tooltip;
  final double size;
  final double iconSize;
  final Color? color;
  final Color? backgroundColor;
  final Border? border;

  const AppIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.tooltip,
    this.size = 44.0,
    this.iconSize = 22.0,
    this.color,
    this.backgroundColor,
    this.border,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveColor = color ?? context.textPrimaryColor;

    Widget btn = InkWell(
      borderRadius: BorderRadius.circular(size / 2),
      onTap: onPressed != null
          ? () {
              AppHaptics.light();
              onPressed!();
            }
          : null,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: backgroundColor ?? Colors.transparent,
          shape: BoxShape.circle,
          border: border,
        ),
        child: Center(
          child: Icon(
            icon,
            size: iconSize,
            color: onPressed != null
                ? effectiveColor
                : effectiveColor.withValues(alpha: 0.35),
          ),
        ),
      ),
    );

    if (tooltip != null) {
      btn = Tooltip(message: tooltip!, child: btn);
    }

    return btn;
  }
}

/// Pill Badge for unread counts, total filters, and status tags
class AppBadge extends StatelessWidget {
  final String text;
  final bool isSelected;
  final Color? activeColor;
  final Color? textColor;

  const AppBadge({
    super.key,
    required this.text,
    this.isSelected = false,
    this.activeColor,
    this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    final bool isDark = context.isDark;
    final bg = isSelected
        ? (activeColor ?? (isDark ? Colors.black : Colors.white))
        : (isDark ? const Color(0xFF27272A) : const Color(0xFFE4E4E7));
    final fg = textColor ??
        (isSelected
            ? (isDark ? Colors.white : Colors.black)
            : context.textSecondaryColor);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontFamily: AppTypography.fontFamily,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: fg,
        ),
      ),
    );
  }
}

/// Knockout Online Indicator Dot
class AppOnlineDot extends StatelessWidget {
  final double size;
  final Color? knockoutColor;

  const AppOnlineDot({
    super.key,
    this.size = 13.0,
    this.knockoutColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppTheme.success,
        shape: BoxShape.circle,
        border: Border.all(
          color: knockoutColor ?? context.backgroundColor,
          width: 2.2,
        ),
      ),
    );
  }
}

/// Unified Avatar with Circular Clip, Cached Network Image, and Fallback Initials
class AppAvatar extends StatelessWidget {
  final String imageUrl;
  final String name;
  final double size;
  final bool isOnline;
  final VoidCallback? onTap;

  const AppAvatar({
    super.key,
    required this.imageUrl,
    required this.name,
    this.size = 52.0,
    this.isOnline = false,
    this.onTap,
  });

  Widget _buildFallback(BuildContext context) {
    final initial = name.trim().isNotEmpty ? name.trim()[0].toUpperCase() : '?';
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: context.primarySoftColor,
        border: Border.all(color: context.borderColor, width: 0.6),
      ),
      child: Center(
        child: Text(
          initial,
          style: TextStyle(
            fontFamily: AppTypography.fontFamily,
            fontWeight: FontWeight.w700,
            fontSize: size * 0.38,
            color: context.textPrimaryColor,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    Widget avatar = Stack(
      clipBehavior: Clip.none,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(size / 2),
          child: imageUrl.trim().isNotEmpty
              ? CachedNetworkImage(
                  imageUrl: imageUrl,
                  width: size,
                  height: size,
                  fit: BoxFit.cover,
                  memCacheWidth: (size * 2).toInt(),
                  memCacheHeight: (size * 2).toInt(),
                  placeholder: (_, __) => _buildFallback(context),
                  errorWidget: (_, __, ___) => _buildFallback(context),
                )
              : _buildFallback(context),
        ),
        if (isOnline)
          Positioned(
            right: 0,
            bottom: 0,
            child: AppOnlineDot(
              size: (size * 0.25).clamp(11.0, 15.0),
              knockoutColor: context.backgroundColor,
            ),
          ),
      ],
    );

    if (onTap != null) {
      avatar = GestureDetector(
        onTap: () {
          AppHaptics.light();
          onTap!();
        },
        child: avatar,
      );
    }

    return avatar;
  }
}

/// Premium Empty State with Minimalist Monochrome Badge and Friendly Guidance
class AppEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  const AppEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 36.0, vertical: 24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: context.surfaceMutedColor,
                shape: BoxShape.circle,
                border: Border.all(color: context.borderColor, width: 0.8),
              ),
              child: Center(
                child: Icon(
                  icon,
                  size: 32,
                  color: context.textSecondaryColor,
                ),
              ),
            ),
            AppSpacing.gapH20,
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: AppTypography.fontFamily,
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: context.textPrimaryColor,
                letterSpacing: -0.2,
              ),
            ),
            AppSpacing.gapH8,
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: AppTypography.fontFamily,
                fontSize: 14,
                fontWeight: FontWeight.w400,
                color: context.textMutedColor,
                height: 1.4,
              ),
            ),
            if (actionLabel != null && onAction != null) ...[
              AppSpacing.gapH24,
              AppButton(
                label: actionLabel!,
                onPressed: onAction,
                variant: AppButtonVariant.secondary,
                height: 42,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Minimalist Loading Indicator
class AppLoadingIndicator extends StatelessWidget {
  final double size;
  final Color? color;

  const AppLoadingIndicator({
    super.key,
    this.size = 24.0,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveColor =
        color ?? (context.isDark ? Colors.white : Colors.black);
    return Center(
      child: SizedBox(
        width: size,
        height: size,
        child: CircularProgressIndicator(
          strokeWidth: 2.2,
          valueColor: AlwaysStoppedAnimation<Color>(effectiveColor),
        ),
      ),
    );
  }
}
