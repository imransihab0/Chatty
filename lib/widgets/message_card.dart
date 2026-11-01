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
    this.onSwipeReply,
    this.isPrevSame = false,
    this.isNextSame = false,
  });

  final Message message;
  final String? highlightQuery;
  final Function(Message)? onSwipeReply;
  final bool isPrevSame;
  final bool isNextSame;

  @override
  State<MessageCard> createState() => _MessageCardState();
}

class _MessageCardState extends State<MessageCard> {
  static final RegExp _urlRegex = RegExp(
    r'(https?:\/\/[^\s]+)',
    caseSensitive: false,
  );

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

  void _showMessageOptions() {
    AppHaptics.medium();
    final bool isMe = APIs.myUid == widget.message.fromId;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Floating Quick Reaction Emoji Capsule (Telegram / iOS Style with Frosted Blur)
                ClipRRect(
                  borderRadius: BorderRadius.circular(28),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: context.surfaceColor
                            .withValues(alpha: context.isDark ? 0.85 : 0.92),
                        borderRadius: BorderRadius.circular(28),
                        border:
                            Border.all(color: context.borderColor, width: 0.8),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(
                                alpha: context.isDark ? 0.35 : 0.08),
                            blurRadius: 16,
                            offset: const Offset(0, 4),
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
                              borderRadius: BorderRadius.circular(20),
                              onTap: () {
                                AppHaptics.selection();
                                Navigator.pop(context);
                                // Toggle emoji: tap again to remove reaction
                                APIs.setMessageReaction(
                                    widget.message, isSelected ? '' : emoji);
                              },
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 4),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? (context.isDark
                                          ? Colors.white.withValues(alpha: 0.2)
                                          : Colors.black.withValues(alpha: 0.1))
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(16),
                                  border: isSelected
                                      ? Border.all(
                                          color: context.textPrimaryColor,
                                          width: 1.5)
                                      : null,
                                ),
                                child: MediaQuery.withClampedTextScaling(
                                  maxScaleFactor: 1.2,
                                  child: Text(
                                    emoji,
                                    style: const TextStyle(fontSize: 22),
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                  ),
                ),
                AppSpacing.gapH10,

                // Clean Contextual Actions Card
                Container(
                  decoration: BoxDecoration(
                    color: context.surfaceColor,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: context.borderColor),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(
                            alpha: context.isDark ? 0.35 : 0.08),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      ListTile(
                        leading: Icon(Icons.reply_rounded,
                            color: context.textPrimaryColor),
                        title: Text(
                          'Reply',
                          style: TextStyle(
                            fontFamily: AppTypography.fontFamily,
                            color: context.textPrimaryColor,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        onTap: () {
                          AppHaptics.light();
                          Navigator.pop(context);
                          if (widget.onSwipeReply != null) {
                            widget.onSwipeReply!(widget.message);
                          }
                        },
                      ),
                      if (widget.message.type == Type.text) ...[
                        Divider(
                            height: 1,
                            indent: 54,
                            color: context.borderColor),
                        ListTile(
                          leading: Icon(Icons.copy_rounded,
                              color: context.textPrimaryColor),
                          title: Text(
                            'Copy Text',
                            style: TextStyle(
                              fontFamily: AppTypography.fontFamily,
                              color: context.textPrimaryColor,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          onTap: () {
                            AppHaptics.light();
                            Navigator.pop(context);
                            Clipboard.setData(
                                ClipboardData(text: widget.message.msg));
                            Dialogs.showSnackbar(
                                context, 'Text copied to clipboard!');
                          },
                        ),
                      ],
                      if (isMe && widget.message.type == Type.text) ...[
                        Divider(
                            height: 1,
                            indent: 54,
                            color: context.borderColor),
                        ListTile(
                          leading: Icon(Icons.edit_rounded,
                              color: context.textPrimaryColor),
                          title: Text(
                            'Edit Message',
                            style: TextStyle(
                              fontFamily: AppTypography.fontFamily,
                              color: context.textPrimaryColor,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          onTap: () {
                            Navigator.pop(context);
                            _showEditMessageDialog();
                          },
                        ),
                      ],
                      if (isMe) ...[
                        Divider(
                            height: 1,
                            indent: 54,
                            color: context.borderColor),
                        ListTile(
                          leading: const Icon(Icons.delete_outline_rounded,
                              color: AppTheme.danger),
                          title: const Text(
                            'Delete Message',
                            style: TextStyle(
                              fontFamily: AppTypography.fontFamily,
                              color: AppTheme.danger,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          onTap: () async {
                            AppHaptics.heavy();
                            Navigator.pop(context);
                            await APIs.deleteMessage(widget.message);
                            if (mounted) {
                              Dialogs.showSnackbar(context, 'Message deleted');
                            }
                          },
                        ),
                      ],
                    ],
                  ),
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
    final bool isMe = APIs.myUid == widget.message.fromId;

    return Padding(
      // Left inset of 20pt on incoming messages preserves the native iOS edge back-swipe gesture arena
      padding: EdgeInsets.only(
        left: isMe ? 14 : 20,
        right: 14,
        top: widget.isNextSame ? 1.5 : 4.0,
        bottom: widget.isNextSame ? 1.5 : 4.0,
      ),
      child: Dismissible(
        key: Key('msg_${widget.message.sent}'),
        direction: DismissDirection.startToEnd,
        confirmDismiss: (direction) async {
          AppHaptics.light();
          if (widget.onSwipeReply != null) {
            widget.onSwipeReply!(widget.message);
          }
          return false;
        },
        background: Container(
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.only(left: 10),
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: (context.isDark ? Colors.white : Colors.black)
                  .withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.reply_rounded,
              color: context.isDark ? Colors.white : Colors.black,
              size: 20,
            ),
          ),
        ),
        child: GestureDetector(
          onLongPress: _showMessageOptions,
          child: isMe ? _myMessage() : _otherMessage(),
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
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
    );
  }

  Widget _buildImageMessage(bool isMe) {
    final sentTime = MyDateUtil.getFormattedTime(
        context: context, time: widget.message.sent);
    final isRead = widget.message.read.isNotEmpty;

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
      child: Hero(
        tag: 'msg_img_${widget.message.sent}',
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Stack(
            children: [
              CachedNetworkImage(
                imageUrl: widget.message.msg,
                fit: BoxFit.cover,
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
    );
  }

  // Sent by other person (Left aligned)
  Widget _otherMessage() {
    if (widget.message.read.isEmpty) {
      APIs.updateMessageReadStatus(widget.message);
    }

    final borderColor = context.incomingBubbleBorderColor;

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
                  color: context.incomingBubbleColor,
                  borderRadius: _getIncomingBorderRadius(),
                  border: borderColor != null
                      ? Border.all(color: borderColor, width: 0.6)
                      : null,
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
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: context.isDark
                          ? const Color(0xFF27272A)
                          : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: context.isDark
                              ? const Color(0xFF38383C)
                              : const Color(0xFFE4E4E7),
                          width: 0.8),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.08),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Text(
                      widget.message.reaction,
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // Sent by me (Right aligned)
  Widget _myMessage() {
    final borderColor = context.outgoingBubbleBorderColor;

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
                  color: context.outgoingBubbleColor,
                  borderRadius: _getOutgoingBorderRadius(),
                  border: borderColor != null
                      ? Border.all(color: borderColor, width: 0.6)
                      : null,
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
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: context.isDark
                          ? const Color(0xFF27272A)
                          : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: context.isDark
                              ? const Color(0xFF38383C)
                              : const Color(0xFFE4E4E7),
                          width: 0.8),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.08),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Text(
                      widget.message.reaction,
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
