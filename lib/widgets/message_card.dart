import 'dart:ui';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:chatty/api/apis.dart';
import 'package:chatty/helper/app_haptics.dart';
import 'package:chatty/helper/app_theme.dart';
import 'package:chatty/helper/dialogs.dart';
import 'package:chatty/helper/my_date_util.dart';
import 'package:chatty/models/message.dart';
import 'package:chatty/screens/media_viewer_screen.dart';
import 'package:chatty/widgets/audio_waveform_player.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// ---------------------------------------------------------------------------
/// TELEGRAM-GRADE CHAT MESSAGE CARD
/// Features:
/// - Consecutive message clustering (dynamic corner radii & snug gaps)
/// - Single-line timestamp alignment optimization
/// - Audio waveform player with duration countdown
/// - High-resolution media viewer hero trigger
/// - Telegram frosted-glass reaction tray & context menu
/// - Haptic swipe-to-reply gesture
/// ---------------------------------------------------------------------------
class MessageCard extends StatefulWidget {
  const MessageCard({
    super.key,
    required this.message,
    this.highlightQuery,
    this.isCurrentMatch = false,
    this.onSwipeReply,
    this.isPrevSame = false,
    this.isNextSame = false,
  });

  final Message message;
  final String? highlightQuery;
  final bool isCurrentMatch;
  final Function(Message)? onSwipeReply;
  final bool isPrevSame;
  final bool isNextSame;

  @override
  State<MessageCard> createState() => _MessageCardState();
}

class _MessageCardState extends State<MessageCard>
    with SingleTickerProviderStateMixin {
  static final RegExp _urlRegex = RegExp(
    r'(https?:\/\/[^\s]+)',
    caseSensitive: false,
  );

  final GlobalKey _bubbleKey = GlobalKey();
  double _pressScale = 1.0;
  final ValueNotifier<double> _swipeProgress = ValueNotifier<double>(0.0);
  bool _swipeThresholdTriggered = false;

  late final AnimationController _heartAnimController;
  late final Animation<double> _heartScale;
  late final Animation<double> _heartOpacity;

  @override
  void initState() {
    super.initState();
    _heartAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );

    _heartScale = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.0, end: 1.35)
            .chain(CurveTween(curve: Curves.easeOutBack)),
        weight: 40,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.35, end: 1.0)
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: 30,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 0.0)
            .chain(CurveTween(curve: Curves.easeInQuad)),
        weight: 30,
      ),
    ]).animate(_heartAnimController);

    _heartOpacity = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.0, end: 1.0),
        weight: 20,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 1.0),
        weight: 50,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 0.0),
        weight: 30,
      ),
    ]).animate(_heartAnimController);
  }

  @override
  void dispose() {
    _heartAnimController.dispose();
    _swipeProgress.dispose();
    super.dispose();
  }

  Widget _buildHeartBurstOverlay() {
    return AnimatedBuilder(
      animation: _heartAnimController,
      builder: (context, child) {
        if (_heartAnimController.value == 0.0) {
          return const SizedBox.shrink();
        }
        return Positioned.fill(
          child: Center(
            child: Opacity(
              opacity: _heartOpacity.value,
              child: Transform.scale(
                scale: _heartScale.value,
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.35),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFFF2D55).withValues(alpha: 0.6),
                        blurRadius: 24,
                        spreadRadius: 4,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.favorite_rounded,
                    color: Color(0xFFFF2D55),
                    size: 38,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  BorderRadius _getIncomingBorderRadius() {
    const double outerR = 18.0;
    const double innerR = 6.0;
    const double tailR = 4.0;

    if (!widget.isPrevSame && !widget.isNextSame) {
      return const BorderRadius.only(
        topLeft: Radius.circular(outerR),
        topRight: Radius.circular(outerR),
        bottomRight: Radius.circular(outerR),
        bottomLeft: Radius.circular(tailR),
      );
    } else if (!widget.isPrevSame && widget.isNextSame) {
      return const BorderRadius.only(
        topLeft: Radius.circular(outerR),
        topRight: Radius.circular(outerR),
        bottomRight: Radius.circular(outerR),
        bottomLeft: Radius.circular(innerR),
      );
    } else if (widget.isPrevSame && widget.isNextSame) {
      return const BorderRadius.only(
        topLeft: Radius.circular(innerR),
        topRight: Radius.circular(outerR),
        bottomRight: Radius.circular(outerR),
        bottomLeft: Radius.circular(innerR),
      );
    } else {
      return const BorderRadius.only(
        topLeft: Radius.circular(innerR),
        topRight: Radius.circular(outerR),
        bottomRight: Radius.circular(outerR),
        bottomLeft: Radius.circular(tailR),
      );
    }
  }

  BorderRadius _getOutgoingBorderRadius() {
    const double outerR = 18.0;
    const double innerR = 6.0;
    const double tailR = 4.0;

    if (!widget.isPrevSame && !widget.isNextSame) {
      return const BorderRadius.only(
        topLeft: Radius.circular(outerR),
        topRight: Radius.circular(outerR),
        bottomLeft: Radius.circular(outerR),
        bottomRight: Radius.circular(tailR),
      );
    } else if (!widget.isPrevSame && widget.isNextSame) {
      return const BorderRadius.only(
        topLeft: Radius.circular(outerR),
        topRight: Radius.circular(outerR),
        bottomLeft: Radius.circular(outerR),
        bottomRight: Radius.circular(innerR),
      );
    } else if (widget.isPrevSame && widget.isNextSame) {
      return const BorderRadius.only(
        topLeft: Radius.circular(outerR),
        topRight: Radius.circular(innerR),
        bottomLeft: Radius.circular(outerR),
        bottomRight: Radius.circular(innerR),
      );
    } else {
      return const BorderRadius.only(
        topLeft: Radius.circular(outerR),
        topRight: Radius.circular(innerR),
        bottomLeft: Radius.circular(outerR),
        bottomRight: Radius.circular(tailR),
      );
    }
  }

  Widget _buildLinkPreviewIfNeeded(String text, bool isMe) {
    final match = _urlRegex.firstMatch(text);
    if (match == null) return const SizedBox.shrink();

    final urlString = match.group(0)!;
    final uri = Uri.tryParse(urlString);
    if (uri == null || uri.host.isEmpty) return const SizedBox.shrink();

    final host = uri.host.toLowerCase().replaceAll('www.', '');
    IconData icon = Icons.language_rounded;
    Color iconColor = isMe ? Colors.white70 : context.textPrimaryColor;

    if (host.contains('youtube') || host.contains('youtu.be')) {
      icon = Icons.play_circle_filled_rounded;
      iconColor = isMe ? Colors.white70 : context.textPrimaryColor;
    } else if (host.contains('github')) {
      icon = Icons.code_rounded;
    } else if (host.contains('twitter') || host.contains('x.com')) {
      icon = Icons.tag_rounded;
    }

    return GestureDetector(
      onTap: () {
        AppHaptics.light();
        Clipboard.setData(ClipboardData(text: urlString));
        Dialogs.showSnackbar(context, 'Link copied: $host');
      },
      child: Container(
        margin: const EdgeInsets.only(top: 8),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: isMe
              ? Colors.white.withValues(alpha: 0.15)
              : context.surfaceMutedColor,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isMe
                ? Colors.white.withValues(alpha: 0.25)
                : context.borderColor,
            width: 0.8,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 20, color: iconColor),
            AppSpacing.gapW8,
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    host,
                    style: TextStyle(
                      fontFamily: AppTypography.fontFamily,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: isMe ? Colors.white : context.textPrimaryColor,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 1),
                  Text(
                    urlString,
                    style: TextStyle(
                      fontFamily: AppTypography.fontFamily,
                      fontSize: 10,
                      color: isMe
                          ? Colors.white.withValues(alpha: 0.75)
                          : context.textSecondaryColor,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            AppSpacing.gapW6,
            Icon(
              Icons.open_in_new_rounded,
              size: 13,
              color: isMe ? Colors.white60 : context.textSecondaryColor,
            ),
          ],
        ),
      ),
    );
  }

  void _showEditMessageDialog() {
    String updatedMsg = widget.message.msg;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: context.surfaceColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Edit Message',
          style: TextStyle(
            fontFamily: AppTypography.fontFamily,
            fontWeight: FontWeight.w700,
            fontSize: 18,
            color: context.textPrimaryColor,
          ),
        ),
        content: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.35,
          ),
          child: SingleChildScrollView(
            child: TextFormField(
              initialValue: updatedMsg,
              maxLines: null,
              autofocus: true,
              onChanged: (val) => updatedMsg = val,
              style: TextStyle(
                fontFamily: AppTypography.fontFamily,
                fontSize: 14,
                color: context.textPrimaryColor,
              ),
              decoration: InputDecoration(
                hintText: 'Enter updated message...',
                hintStyle: TextStyle(
                  fontFamily: AppTypography.fontFamily,
                  fontSize: 13,
                  color: context.textMutedColor,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: context.borderColor),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide:
                      BorderSide(color: context.textPrimaryColor, width: 1.5),
                ),
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              AppHaptics.light();
              Navigator.pop(context);
            },
            child: Text(
              'Cancel',
              style: TextStyle(
                fontFamily: AppTypography.fontFamily,
                color: context.textSecondaryColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: context.isDark ? Colors.white : Colors.black,
              foregroundColor: context.isDark ? Colors.black : Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () async {
              Navigator.pop(context);
              final trimmed = updatedMsg.trim();
              if (trimmed.isNotEmpty && trimmed != widget.message.msg) {
                AppHaptics.medium();
                await APIs.updateMessage(widget.message, trimmed);
                if (mounted) {
                  Dialogs.showSnackbar(context, 'Message updated');
                }
              }
            },
            child: const Text('Save',
                style: TextStyle(
                    fontFamily: AppTypography.fontFamily,
                    fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuItem({
    required BuildContext context,
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    final color =
        isDestructive ? const Color(0xFFDC2626) : context.textPrimaryColor;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: TextStyle(
                fontFamily: AppTypography.fontFamily,
                fontSize: 14.5,
                fontWeight: isDestructive ? FontWeight.w600 : FontWeight.w500,
                color: color,
              ),
            ),
            Icon(icon, color: color, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuDivider(BuildContext context) {
    return Divider(
      height: 1,
      thickness: 0.6,
      color:
          context.isDark ? const Color(0xFF2C2C30) : const Color(0xFFE4E4E8),
    );
  }

  void _showMessageOptions() {
    AppHaptics.heavy();
    final bool isMe = APIs.myUid == widget.message.fromId;

    final RenderBox? renderBox =
        _bubbleKey.currentContext?.findRenderObject() as RenderBox?;
    final Offset globalOffset =
        renderBox?.localToGlobal(Offset.zero) ?? const Offset(20, 200);
    final Size bubbleSize = renderBox?.size ?? const Size(220, 60);

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Dismiss',
      barrierColor: Colors.transparent,
      transitionDuration: const Duration(milliseconds: 260),
      pageBuilder: (dialogContext, animation, secondaryAnimation) {
        return const SizedBox.shrink();
      },
      transitionBuilder: (dialogContext, animation, secondaryAnimation, child) {
        final isDark = dialogContext.isDark;
        final curvedAnim = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutBack,
          reverseCurve: Curves.easeInCubic,
        );

        final screenHeight = MediaQuery.sizeOf(dialogContext).height;
        final screenWidth = MediaQuery.sizeOf(dialogContext).width;
        final topPadding = MediaQuery.paddingOf(dialogContext).top;
        final bottomPadding = MediaQuery.paddingOf(dialogContext).bottom;

        const double reactionHeight = 50.0;
        const double menuWidth = 220.0;
        const double menuItemHeight = 44.0;
        int menuActionCount = 1; // Reply
        if (widget.message.type == Type.text) menuActionCount++; // Copy
        if (isMe && widget.message.type == Type.text) menuActionCount++; // Edit
        if (isMe) menuActionCount++; // Delete
        final double menuHeight = menuActionCount * menuItemHeight + 8;

        final double totalClusterHeight =
            reactionHeight + 10 + bubbleSize.height + 10 + menuHeight;
        final double availableHeight =
            screenHeight - topPadding - bottomPadding - 32;

        double targetY = globalOffset.dy - reactionHeight - 10;
        final double minY = topPadding + 16;
        final double maxY = screenHeight - bottomPadding - 16;

        if (totalClusterHeight <= availableHeight) {
          if (targetY < minY) {
            targetY = minY;
          } else if (targetY + totalClusterHeight > maxY) {
            targetY = maxY - totalClusterHeight;
          }
        } else {
          targetY = minY;
        }

        const double horizontalPadding = 16.0;

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            AppHaptics.light();
            if (dialogContext.mounted) {
              Navigator.pop(dialogContext);
            }
          },
          child: Stack(
            children: [
              // Full Screen Frosted Blur Backdrop
              Positioned.fill(
                child: AnimatedBuilder(
                  animation: animation,
                  builder: (context, _) {
                    return BackdropFilter(
                      filter: ImageFilter.blur(
                        sigmaX: (16.0 * animation.value).clamp(0.01, 16.0),
                        sigmaY: (16.0 * animation.value).clamp(0.01, 16.0),
                      ),
                      child: Container(
                        color: Colors.black.withValues(
                          alpha: (isDark ? 0.65 : 0.35) * animation.value,
                        ),
                      ),
                    );
                  },
                ),
              ),

            // Magnetic Floating Cluster
            Positioned(
              top: targetY,
              left: isMe ? null : horizontalPadding,
              right: isMe ? horizontalPadding : null,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: availableHeight,
                  maxWidth: screenWidth - 32,
                ),
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: FadeTransition(
                    opacity: animation,
                    child: ScaleTransition(
                      scale: Tween<double>(begin: 0.92, end: 1.0)
                          .animate(curvedAnim),
                      alignment: isMe ? Alignment.topRight : Alignment.topLeft,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: isMe
                            ? CrossAxisAlignment.end
                            : CrossAxisAlignment.start,
                        children: [
                          // 1. Floating Quick Reaction Emoji Capsule (iOS / Telegram Style)
                          ClipRRect(
                            borderRadius: BorderRadius.circular(28),
                            child: BackdropFilter(
                              filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                              child: Container(
                                height: reactionHeight,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: dialogContext.surfaceColor.withValues(
                                      alpha: isDark ? 0.85 : 0.94),
                                  borderRadius: BorderRadius.circular(28),
                                  border: Border.all(
                                    color: isDark
                                        ? Colors.white.withValues(alpha: 0.16)
                                        : Colors.black.withValues(alpha: 0.08),
                                    width: 0.8,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(
                                          alpha: isDark ? 0.45 : 0.12),
                                      blurRadius: 18,
                                      offset: const Offset(0, 6),
                                    ),
                                  ],
                                ),
                                child: SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  physics: const BouncingScrollPhysics(),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      '❤️',
                                      '👍',
                                      '👎',
                                      '🔥',
                                      '😂',
                                      '🎉',
                                      '😮',
                                      '😢',
                                      '🙏'
                                    ].map((emoji) {
                                      final bool isSelected =
                                          widget.message.reaction == emoji;
                                      return InkWell(
                                        borderRadius:
                                            BorderRadius.circular(20),
                                        onTap: () {
                                          AppHaptics.selection();
                                          Navigator.pop(dialogContext);
                                          APIs.setMessageReaction(
                                            widget.message,
                                            isSelected ? '' : emoji,
                                          );
                                        },
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 7, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: isSelected
                                                ? (isDark
                                                    ? Colors.white.withValues(
                                                        alpha: 0.22)
                                                    : Colors.black.withValues(
                                                        alpha: 0.10))
                                                : Colors.transparent,
                                            borderRadius:
                                                BorderRadius.circular(16),
                                          ),
                                          child: Text(
                                            emoji,
                                            style:
                                                const TextStyle(fontSize: 22),
                                          ),
                                        ),
                                      );
                                    }).toList(),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),

                          // 2. Magnetically Elevated Message Bubble Preview
                          IgnorePointer(
                            child: Container(
                              decoration: BoxDecoration(
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(
                                        alpha: isDark ? 0.55 : 0.22),
                                    blurRadius: 28,
                                    spreadRadius: 2,
                                    offset: const Offset(0, 8),
                                  ),
                                ],
                              ),
                              child: Transform.scale(
                                scale: 1.03,
                                alignment: isMe
                                    ? Alignment.centerRight
                                    : Alignment.centerLeft,
                                child: isMe ? _myMessage() : _otherMessage(),
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),

                          // 3. iOS Frosted Glass Context Menu Card
                          ClipRRect(
                            borderRadius: BorderRadius.circular(18),
                            child: BackdropFilter(
                              filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                              child: Container(
                                width: menuWidth,
                                decoration: BoxDecoration(
                                  color: dialogContext.surfaceColor.withValues(
                                      alpha: isDark ? 0.88 : 0.94),
                                  borderRadius: BorderRadius.circular(18),
                                  border: Border.all(
                                    color: isDark
                                        ? Colors.white.withValues(alpha: 0.15)
                                        : Colors.black.withValues(alpha: 0.08),
                                    width: 0.8,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(
                                          alpha: isDark ? 0.40 : 0.12),
                                      blurRadius: 18,
                                      offset: const Offset(0, 6),
                                    ),
                                  ],
                                ),
                                child: Material(
                                  color: Colors.transparent,
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      _buildMenuItem(
                                        context: dialogContext,
                                        icon: Icons.reply_rounded,
                                        label: 'Reply',
                                        onTap: () {
                                          Navigator.pop(dialogContext);
                                          AppHaptics.light();
                                          widget.onSwipeReply
                                              ?.call(widget.message);
                                        },
                                      ),
                                      if (widget.message.type ==
                                          Type.text) ...[
                                        _buildMenuDivider(dialogContext),
                                        _buildMenuItem(
                                          context: dialogContext,
                                          icon: Icons.copy_rounded,
                                          label: 'Copy',
                                          onTap: () {
                                            Navigator.pop(dialogContext);
                                            AppHaptics.light();
                                            Clipboard.setData(ClipboardData(
                                                text: widget.message.msg));
                                            Dialogs.showSnackbar(context,
                                                'Text copied to clipboard!');
                                          },
                                        ),
                                      ],
                                      if (isMe &&
                                          widget.message.type ==
                                              Type.text) ...[
                                        _buildMenuDivider(dialogContext),
                                        _buildMenuItem(
                                          context: dialogContext,
                                          icon: Icons.edit_rounded,
                                          label: 'Edit',
                                          onTap: () {
                                            Navigator.pop(dialogContext);
                                            AppHaptics.light();
                                            _showEditMessageDialog();
                                          },
                                        ),
                                      ],
                                      if (isMe) ...[
                                        _buildMenuDivider(dialogContext),
                                        _buildMenuItem(
                                          context: dialogContext,
                                          icon: Icons.delete_outline_rounded,
                                          label: 'Delete',
                                          isDestructive: true,
                                          onTap: () async {
                                            Navigator.pop(dialogContext);
                                            AppHaptics.heavy();
                                            await APIs.deleteMessage(
                                                widget.message);
                                            if (mounted) {
                                              Dialogs.showSnackbar(
                                                  context, 'Message deleted');
                                            }
                                          },
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isMe = APIs.myUid == widget.message.fromId;

    return Padding(
      // Left inset of 20pt on incoming messages preserves the native iOS edge back-swipe gesture arena
      padding: EdgeInsets.only(
        left: isMe ? 14 : 20,
        right: 14,
        top: widget.isPrevSame
            ? (widget.message.type == Type.image ? 1.0 : 1.5)
            : 4.0,
        bottom: widget.isNextSame
            ? (widget.message.type == Type.image ? 1.0 : 1.5)
            : 4.0,
      ),
      child: Dismissible(
        key: Key('msg_${widget.message.sent}'),
        direction: DismissDirection.startToEnd,
        dismissThresholds: const {DismissDirection.startToEnd: 0.18},
        onUpdate: (details) {
          _swipeProgress.value = details.progress;
          if (details.reached && !_swipeThresholdTriggered) {
            _swipeThresholdTriggered = true;
            AppHaptics.medium();
          } else if (!details.reached && _swipeThresholdTriggered) {
            _swipeThresholdTriggered = false;
          }
        },
        confirmDismiss: (direction) async {
          _swipeThresholdTriggered = false;
          _swipeProgress.value = 0.0;
          if (widget.onSwipeReply != null) {
            widget.onSwipeReply!(widget.message);
          }
          return false;
        },
        background: ValueListenableBuilder<double>(
          valueListenable: _swipeProgress,
          builder: (context, progress, child) {
            final activeThreshold = (progress / 0.18).clamp(0.0, 1.0);
            final scale = (progress * 5.0).clamp(0.0, 1.15);
            final isTriggered = progress >= 0.18;
            final isDark = context.isDark;

            return Container(
              alignment: Alignment.centerLeft,
              padding: const EdgeInsets.only(left: 8),
              child: Transform.scale(
                scale: scale,
                child: Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                    color: isTriggered
                        ? (isDark ? Colors.white : Colors.black)
                        : (isDark ? Colors.white : Colors.black)
                            .withValues(alpha: 0.12 + 0.18 * activeThreshold),
                    shape: BoxShape.circle,
                    boxShadow: isTriggered
                        ? [
                            BoxShadow(
                              color: (isDark ? Colors.white : Colors.black)
                                  .withValues(alpha: 0.25),
                              blurRadius: 10,
                              spreadRadius: 1,
                            ),
                          ]
                        : null,
                  ),
                  child: Transform.rotate(
                    angle: (1.0 - activeThreshold) * -0.4,
                    child: Icon(
                      Icons.reply_rounded,
                      color: isTriggered
                          ? (isDark ? Colors.black : Colors.white)
                          : (isDark ? Colors.white : Colors.black),
                      size: 20,
                    ),
                  ),
                ),
              ),
            );
          },
        ),
        child: GestureDetector(
          onTapDown: (_) => setState(() => _pressScale = 0.97),
          onTapUp: (_) => setState(() => _pressScale = 1.0),
          onTapCancel: () => setState(() => _pressScale = 1.0),
          onDoubleTap: () {
            setState(() => _pressScale = 1.0);
            AppHaptics.medium();
            _heartAnimController.forward(from: 0.0);
            APIs.setMessageReaction(widget.message, '❤️');
          },
          onLongPress: () {
            setState(() => _pressScale = 1.0);
            _showMessageOptions();
          },
          child: AnimatedScale(
            scale: _pressScale,
            duration: const Duration(milliseconds: 140),
            curve: Curves.easeOutCubic,
            child: KeyedSubtree(
              key: _bubbleKey,
              child: isMe ? _myMessage() : _otherMessage(),
            ),
          ),
        ),
      ),
    );
  }

  // Quoted Reply Preview block inside message bubble
  Widget _replyQuoteHeader(bool isMe) {
    if (widget.message.replyMsg.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isMe
            ? Colors.white.withValues(alpha: 0.12)
            : (context.isDark
                ? const Color(0xFF141416)
                : const Color(0xFFDDDEE3)),
        borderRadius: BorderRadius.circular(9),
        border: Border(
          left: BorderSide(
            color: isMe
                ? Colors.white
                : (context.isDark ? Colors.white : Colors.black),
            width: 3.0,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            widget.message.replyUser.isNotEmpty
                ? widget.message.replyUser
                : 'Reply',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: AppTypography.fontFamily,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: isMe
                  ? Colors.white
                  : (context.isDark ? Colors.white : Colors.black),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            widget.message.replyMsg,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: AppTypography.fontFamily,
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: isMe
                  ? Colors.white.withValues(alpha: 0.90)
                  : (context.isDark
                      ? const Color(0xFFD4D4D8)
                      : const Color(0xFF3F3F46)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHighlightedText({
    required String text,
    required TextStyle baseStyle,
    required Color highlightColor,
    required Color highlightTextColor,
  }) {
    final query = widget.highlightQuery?.trim().toLowerCase() ?? '';
    if (query.isEmpty || !text.toLowerCase().contains(query)) {
      return Text(text, style: baseStyle);
    }

    final List<TextSpan> spans = [];
    final lowerText = text.toLowerCase();
    int start = 0;

    while (true) {
      final index = lowerText.indexOf(query, start);
      if (index == -1) {
        spans.add(TextSpan(text: text.substring(start), style: baseStyle));
        break;
      }
      if (index > start) {
        spans.add(TextSpan(text: text.substring(start, index), style: baseStyle));
      }
      final matchEnd = index + query.length;
      spans.add(TextSpan(
        text: text.substring(index, matchEnd),
        style: baseStyle.copyWith(
          backgroundColor: highlightColor,
          color: highlightTextColor,
          fontWeight: FontWeight.w700,
        ),
      ));
      start = matchEnd;
    }

    return RichText(text: TextSpan(children: spans));
  }

  Widget _buildTimestampRow({
    required bool isMe,
    required String sentTime,
    required bool isRead,
    required TextStyle timeStyle,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          sentTime,
          style: timeStyle,
        ),
        if (isMe) ...[
          const SizedBox(width: 3.5),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            transitionBuilder: (child, anim) =>
                ScaleTransition(scale: anim, child: child),
            child: isRead
                ? const Icon(
                    Icons.done_all_rounded,
                    key: ValueKey('read'),
                    color: AppTheme.success,
                    size: 13.5,
                  )
                : Icon(
                    Icons.done_rounded,
                    key: const ValueKey('sent'),
                    color: Colors.white.withValues(alpha: 0.70),
                    size: 13.5,
                  ),
          ),
        ],
      ],
    );
  }

  Widget _buildTextMessage(bool isMe) {
    final text = widget.message.msg;
    final sentTime = MyDateUtil.getFormattedTime(
        context: context, time: widget.message.sent);
    final isRead = widget.message.read.isNotEmpty;
    final hasLink = _urlRegex.hasMatch(text);
    final hasReply = widget.message.replyMsg.isNotEmpty;

    final TextStyle textStyle = TextStyle(
      fontFamily: AppTypography.fontFamily,
      fontSize: 15,
      height: 1.35,
      color: isMe
          ? context.outgoingBubbleTextColor
          : context.incomingBubbleTextColor,
    );

    final TextStyle timeStyle = TextStyle(
      fontFamily: AppTypography.fontFamily,
      fontSize: 10,
      fontWeight: FontWeight.w500,
      color: isMe
          ? Colors.white.withValues(alpha: 0.65)
          : (context.isDark
              ? const Color(0xFFA1A1AA)
              : const Color(0xFF71717A)),
    );

    final maxBubbleWidth = MediaQuery.sizeOf(context).width * 0.76;
    final maxTextWidth = maxBubbleWidth - 26;

    bool fitsOnSingleLine = false;
    if (!hasLink && !hasReply && !text.contains('\n')) {
      final textPainter = TextPainter(
        text: TextSpan(text: text, style: textStyle),
        maxLines: 1,
        textDirection: TextDirection.ltr,
      )..layout();

      final timestampWidth = isMe ? 68.0 : 48.0;
      const spacing = 8.0;

      if (textPainter.width + timestampWidth + spacing <= maxTextWidth) {
        fitsOnSingleLine = true;
      }
    }

    if (fitsOnSingleLine) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Flexible(
            child: _buildHighlightedText(
              text: text,
              baseStyle: textStyle,
              highlightColor: isMe
                  ? Colors.white.withValues(alpha: 0.25)
                  : (context.isDark
                      ? const Color(0xFF333333)
                      : const Color(0xFFE4E4E7)),
              highlightTextColor:
                  isMe ? Colors.white : context.textPrimaryColor,
            ),
          ),
          AppSpacing.gapW8,
          Padding(
            padding: const EdgeInsets.only(bottom: 1),
            child: _buildTimestampRow(
              isMe: isMe,
              sentTime: sentTime,
              isRead: isRead,
              timeStyle: timeStyle,
            ),
          ),
        ],
      );
    }

    return IntrinsicWidth(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildHighlightedText(
            text: text,
            baseStyle: textStyle,
            highlightColor: isMe
                ? Colors.white.withValues(alpha: 0.25)
                : (context.isDark
                    ? const Color(0xFF333333)
                    : const Color(0xFFE4E4E7)),
            highlightTextColor: isMe ? Colors.white : context.textPrimaryColor,
          ),
          if (hasLink) _buildLinkPreviewIfNeeded(text, isMe),
          const SizedBox(height: 2),
          Align(
            alignment: Alignment.bottomRight,
            child: _buildTimestampRow(
              isMe: isMe,
              sentTime: sentTime,
              isRead: isRead,
              timeStyle: timeStyle,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImageMessage(bool isMe) {
    final sentTime = MyDateUtil.getFormattedTime(
        context: context, time: widget.message.sent);
    final isRead = widget.message.read.isNotEmpty;

    final urls = widget.message.msg
        .split('|||')
        .where((u) => u.trim().isNotEmpty)
        .toList();
    if (urls.length > 1) {
      return _buildImageCollage(urls, isMe, sentTime, isRead);
    }

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => MediaViewerScreen(
              imageUrl: widget.message.msg,
              heroTag: 'msg_img_${widget.message.sent}',
              title: isMe ? 'You' : 'Photo',
              timestamp: sentTime,
            ),
          ),
        );
      },
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.72,
          maxHeight: 260,
        ),
        child: Hero(
          tag: 'msg_img_${widget.message.sent}',
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Stack(
              children: [
                CachedNetworkImage(
                  imageUrl: widget.message.msg,
                  fit: BoxFit.cover,
                  width: double.infinity,
                  height: 220,
                  placeholder: (context, url) => Container(
                    height: 200,
                    width: double.infinity,
                    color: isMe ? Colors.white24 : context.surfaceMutedColor,
                    child: Center(
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          isMe ? Colors.white : context.textPrimaryColor,
                        ),
                      ),
                    ),
                  ),
                  errorWidget: (context, url, error) => Container(
                    height: 120,
                    width: double.infinity,
                    color: isMe ? Colors.white24 : context.surfaceMutedColor,
                    child: Icon(
                      Icons.broken_image,
                      size: 40,
                      color: isMe ? Colors.white70 : context.textMutedColor,
                    ),
                  ),
                ),
                Positioned(
                  bottom: 6,
                  right: 8,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.65),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          sentTime,
                          style: const TextStyle(
                            fontFamily: AppTypography.fontFamily,
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                            color: Colors.white,
                          ),
                        ),
                        if (isMe) ...[
                          const SizedBox(width: 3.5),
                          Icon(
                            isRead
                                ? Icons.done_all_rounded
                                : Icons.done_rounded,
                            color: isRead
                                ? AppTheme.success
                                : Colors.white.withValues(alpha: 0.85),
                            size: 13,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Telegram-style Multi-Photo Masonry Collage
  Widget _buildImageCollage(
    List<String> urls,
    bool isMe,
    String sentTime,
    bool isRead,
  ) {
    final double maxWidth = MediaQuery.sizeOf(context).width * 0.72;
    const double gap = 3.0;

    Widget collageBody;
    if (urls.length == 2) {
      final double cellWidth = (maxWidth - gap) / 2;
      const double cellHeight = 160.0;
      collageBody = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildCollageCell(
            url: urls[0],
            index: 0,
            width: cellWidth,
            height: cellHeight,
            borderRadius:
                const BorderRadius.horizontal(left: Radius.circular(12)),
            isMe: isMe,
            sentTime: sentTime,
          ),
          const SizedBox(width: gap),
          _buildCollageCell(
            url: urls[1],
            index: 1,
            width: cellWidth,
            height: cellHeight,
            borderRadius:
                const BorderRadius.horizontal(right: Radius.circular(12)),
            isMe: isMe,
            sentTime: sentTime,
          ),
        ],
      );
    } else if (urls.length == 3) {
      final double halfWidth = (maxWidth - gap) / 2;
      collageBody = Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildCollageCell(
            url: urls[0],
            index: 0,
            width: maxWidth,
            height: 130.0,
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(12)),
            isMe: isMe,
            sentTime: sentTime,
          ),
          const SizedBox(height: gap),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildCollageCell(
                url: urls[1],
                index: 1,
                width: halfWidth,
                height: 100.0,
                borderRadius:
                    const BorderRadius.only(bottomLeft: Radius.circular(12)),
                isMe: isMe,
                sentTime: sentTime,
              ),
              const SizedBox(width: gap),
              _buildCollageCell(
                url: urls[2],
                index: 2,
                width: halfWidth,
                height: 100.0,
                borderRadius:
                    const BorderRadius.only(bottomRight: Radius.circular(12)),
                isMe: isMe,
                sentTime: sentTime,
              ),
            ],
          ),
        ],
      );
    } else {
      // 4 or more photos (2x2 grid)
      final double cellWidth = (maxWidth - gap) / 2;
      const double cellHeight = 110.0;
      final int extra = urls.length > 4 ? urls.length - 3 : 0;

      collageBody = Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildCollageCell(
                url: urls[0],
                index: 0,
                width: cellWidth,
                height: cellHeight,
                borderRadius:
                    const BorderRadius.only(topLeft: Radius.circular(12)),
                isMe: isMe,
                sentTime: sentTime,
              ),
              const SizedBox(width: gap),
              _buildCollageCell(
                url: urls[1],
                index: 1,
                width: cellWidth,
                height: cellHeight,
                borderRadius:
                    const BorderRadius.only(topRight: Radius.circular(12)),
                isMe: isMe,
                sentTime: sentTime,
              ),
            ],
          ),
          const SizedBox(height: gap),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildCollageCell(
                url: urls[2],
                index: 2,
                width: cellWidth,
                height: cellHeight,
                borderRadius:
                    const BorderRadius.only(bottomLeft: Radius.circular(12)),
                isMe: isMe,
                sentTime: sentTime,
              ),
              const SizedBox(width: gap),
              _buildCollageCell(
                url: urls[3],
                index: 3,
                width: cellWidth,
                height: cellHeight,
                borderRadius:
                    const BorderRadius.only(bottomRight: Radius.circular(12)),
                isMe: isMe,
                sentTime: sentTime,
                extraCount: extra,
              ),
            ],
          ),
        ],
      );
    }

    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Stack(
          children: [
            collageBody,
            Positioned(
              bottom: 6,
              right: 8,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.65),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      sentTime,
                      style: const TextStyle(
                        fontFamily: AppTypography.fontFamily,
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                        color: Colors.white,
                      ),
                    ),
                    if (isMe) ...[
                      const SizedBox(width: 3.5),
                      Icon(
                        isRead
                            ? Icons.done_all_rounded
                            : Icons.done_rounded,
                        color: isRead
                            ? AppTheme.success
                            : Colors.white.withValues(alpha: 0.85),
                        size: 13,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCollageCell({
    required String url,
    required int index,
    required double width,
    required double height,
    required BorderRadius borderRadius,
    required bool isMe,
    required String sentTime,
    int? extraCount,
  }) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => MediaViewerScreen(
              imageUrl: url,
              heroTag: 'msg_img_${widget.message.sent}_$index',
              title: isMe ? 'You' : 'Photo',
              timestamp: sentTime,
            ),
          ),
        );
      },
      child: ClipRRect(
        borderRadius: borderRadius,
        child: SizedBox(
          width: width,
          height: height,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Hero(
                tag: 'msg_img_${widget.message.sent}_$index',
                child: CachedNetworkImage(
                  imageUrl: url,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Container(
                    color: isMe ? Colors.white24 : context.surfaceMutedColor,
                    child: const Center(
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                  errorWidget: (context, url, error) => Container(
                    color: isMe ? Colors.white24 : context.surfaceMutedColor,
                    child: const Icon(Icons.broken_image, size: 28),
                  ),
                ),
              ),
              if (extraCount != null && extraCount > 0)
                Container(
                  color: Colors.black.withValues(alpha: 0.55),
                  child: Center(
                    child: Text(
                      '+$extraCount',
                      style: const TextStyle(
                        fontFamily: AppTypography.fontFamily,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // Sent by other person (Left aligned)
  Widget _otherMessage() {
    if (widget.message.read.isEmpty) {
      APIs.updateMessageReadStatus(widget.message);
    }

    final isDark = context.isDark;

    // Liquid Glass / Frosted Glass dual-tone translucent gradient
    final incomingGradient = isDark
        ? const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF28282E), Color(0xFF1D1D22)],
          )
        : const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFFFFFFF), Color(0xFFECECEF)],
          );

    final incomingBorder = Border.all(
      color: isDark
          ? Colors.white.withValues(alpha: 0.16)
          : Colors.white.withValues(alpha: 0.85),
      width: 0.75,
    );

    final incomingShadow = [
      if (widget.isCurrentMatch)
        BoxShadow(
          color: (isDark ? Colors.amberAccent : Colors.amber).withValues(alpha: 0.65),
          blurRadius: 18,
          spreadRadius: 2.5,
        )
      else ...[
        BoxShadow(
          color: Colors.black.withValues(alpha: isDark ? 0.32 : 0.06),
          blurRadius: 10,
          offset: const Offset(0, 3),
        ),
        if (isDark)
          BoxShadow(
            color: Colors.white.withValues(alpha: 0.04),
            blurRadius: 1,
            offset: const Offset(0, -0.5),
          ),
      ],
    ];

    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: EdgeInsets.only(
            bottom: widget.message.reaction.isNotEmpty ? 8 : 0),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minWidth: widget.message.reaction.isNotEmpty ? 80 : 0,
            maxWidth: MediaQuery.sizeOf(context).width * 0.76,
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                decoration: BoxDecoration(
                  gradient: incomingGradient,
                  borderRadius: _getIncomingBorderRadius(),
                  border: incomingBorder,
                  boxShadow: incomingShadow,
                ),
                child: Padding(
                  padding: (widget.message.type == Type.image &&
                          widget.message.replyMsg.isEmpty)
                      ? const EdgeInsets.all(4)
                      : (widget.message.type == Type.audio &&
                              widget.message.replyMsg.isEmpty)
                          ? const EdgeInsets.fromLTRB(10, 8, 10, 8)
                          : const EdgeInsets.fromLTRB(13, 8, 13, 7),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _replyQuoteHeader(false),
                      if (widget.message.type == Type.text)
                        _buildTextMessage(false)
                      else if (widget.message.type == Type.audio)
                        AudioWaveformPlayer(
                          isMe: false,
                          audioUrl: widget.message.msg,
                          durationMs: widget.message.durationMs,
                          sentTime: MyDateUtil.getFormattedTime(
                              context: context, time: widget.message.sent),
                          isRead: widget.message.read.isNotEmpty,
                        )
                      else
                        _buildImageMessage(false),
                    ],
                  ),
                ),
              ),
              if (widget.message.reaction.isNotEmpty)
                Positioned(
                  bottom: -8,
                  left: 10,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF232328).withValues(alpha: 0.95)
                          : Colors.white.withValues(alpha: 0.95),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.18)
                            : Colors.black.withValues(alpha: 0.08),
                        width: 0.8,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black
                              .withValues(alpha: isDark ? 0.35 : 0.08),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Text(
                      widget.message.reaction,
                      style: const TextStyle(fontSize: 13.5),
                    ),
                  ),
                ),
              _buildHeartBurstOverlay(),
            ],
          ),
        ),
      ),
    );
  }

  // Sent by me (Right aligned)
  Widget _myMessage() {
    final isDark = context.isDark;

    // Liquid Glass / Obsidian dual-tone translucent gradient
    final outgoingGradient = isDark
        ? const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF38383F), Color(0xFF28282E)],
          )
        : const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF27272A), Color(0xFF141416)],
          );

    final outgoingBorder = Border.all(
      color: Colors.white.withValues(alpha: isDark ? 0.26 : 0.22),
      width: 0.85,
    );

    final outgoingShadow = [
      if (widget.isCurrentMatch)
        BoxShadow(
          color: (isDark ? Colors.amberAccent : Colors.amber).withValues(alpha: 0.65),
          blurRadius: 18,
          spreadRadius: 2.5,
        )
      else ...[
        BoxShadow(
          color: Colors.black.withValues(alpha: isDark ? 0.40 : 0.18),
          blurRadius: 10,
          offset: const Offset(0, 3),
        ),
        BoxShadow(
          color: Colors.white.withValues(alpha: isDark ? 0.06 : 0.05),
          blurRadius: 1,
          offset: const Offset(0, -0.5),
        ),
      ],
    ];

    return Align(
      alignment: Alignment.centerRight,
      child: Padding(
        padding: EdgeInsets.only(
            bottom: widget.message.reaction.isNotEmpty ? 8 : 0),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minWidth: widget.message.reaction.isNotEmpty ? 80 : 0,
            maxWidth: MediaQuery.sizeOf(context).width * 0.76,
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                decoration: BoxDecoration(
                  gradient: outgoingGradient,
                  borderRadius: _getOutgoingBorderRadius(),
                  border: outgoingBorder,
                  boxShadow: outgoingShadow,
                ),
                child: Padding(
                  padding: (widget.message.type == Type.image &&
                          widget.message.replyMsg.isEmpty)
                      ? const EdgeInsets.all(4)
                      : (widget.message.type == Type.audio &&
                              widget.message.replyMsg.isEmpty)
                          ? const EdgeInsets.fromLTRB(10, 8, 10, 8)
                          : const EdgeInsets.fromLTRB(13, 8, 13, 7),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _replyQuoteHeader(true),
                      if (widget.message.type == Type.text)
                        _buildTextMessage(true)
                      else if (widget.message.type == Type.audio)
                        AudioWaveformPlayer(
                          isMe: true,
                          audioUrl: widget.message.msg,
                          durationMs: widget.message.durationMs,
                          sentTime: MyDateUtil.getFormattedTime(
                              context: context, time: widget.message.sent),
                          isRead: widget.message.read.isNotEmpty,
                        )
                      else
                        _buildImageMessage(true),
                    ],
                  ),
                ),
              ),
              if (widget.message.reaction.isNotEmpty)
                Positioned(
                  bottom: -8,
                  right: 10,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF232328).withValues(alpha: 0.95)
                          : Colors.white.withValues(alpha: 0.95),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.18)
                            : Colors.black.withValues(alpha: 0.08),
                        width: 0.8,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black
                              .withValues(alpha: isDark ? 0.35 : 0.08),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Text(
                      widget.message.reaction,
                      style: const TextStyle(fontSize: 13.5),
                    ),
                  ),
                ),
              _buildHeartBurstOverlay(),
            ],
          ),
        ),
      ),
    );
  }
}
