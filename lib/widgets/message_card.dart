
import 'package:cached_network_image/cached_network_image.dart';
import 'package:chatty/api/apis.dart';
import 'package:chatty/helper/app_haptics.dart';
import 'package:chatty/helper/app_theme.dart';
import 'package:chatty/helper/dialogs.dart';
import 'package:chatty/helper/my_date_util.dart';
import 'package:chatty/main.dart';
import 'package:chatty/models/message.dart';
import 'package:chatty/screens/media_viewer_screen.dart';
import 'package:chatty/widgets/audio_waveform_player.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// Modern Chat Message Card with Long-press Actions, Reactions, and Swipe-to-Reply
class MessageCard extends StatefulWidget {
  const MessageCard({
    super.key,
    required this.message,
    this.highlightQuery,
    this.onSwipeReply,
  });

  final Message message;
  final String? highlightQuery;
  final Function(Message)? onSwipeReply;

  @override
  State<MessageCard> createState() => _MessageCardState();
}

class _MessageCardState extends State<MessageCard> {
  void _showMessageOptions() {
    AppHaptics.medium();
    final bool isMe = APIs.user.uid == widget.message.fromId;

    showModalBottomSheet(
      context: context,
      backgroundColor: context.surfaceColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) {
        return Material(
          color: Colors.transparent,
          child: SafeArea(
            child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: context.borderColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 14),

                // Floating Emoji Reaction Bar
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: context.surfaceMutedColor,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: context.borderColor),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: ['❤️', '👍', '😂', '😮', '😢', '🔥'].map((emoji) {
                      final bool isSelected = widget.message.reaction == emoji;
                      return InkWell(
                        borderRadius: BorderRadius.circular(20),
                        onTap: () {
                          AppHaptics.light();
                          Navigator.pop(context);
                          APIs.setMessageReaction(widget.message, emoji);
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 4),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppTheme.primary.withValues(alpha: 0.22)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(16),
                            border: isSelected
                                ? Border.all(
                                    color: AppTheme.primary, width: 1.5)
                                : null,
                          ),
                          child: Text(
                            emoji,
                            style: const TextStyle(fontSize: 24),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 8),
                // Reply Action
                ListTile(
                  leading: const Icon(Icons.reply_rounded, color: AppTheme.primary),
                  title: Text(
                    'Reply',
                    style: TextStyle(
                      fontFamily: 'Lexend',
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
                if (widget.message.type == Type.text)
                  ListTile(
                    leading: const Icon(Icons.copy_rounded, color: AppTheme.primary),
                    title: Text(
                      'Copy Text',
                      style: TextStyle(
                        fontFamily: 'Lexend',
                        color: context.textPrimaryColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    onTap: () {
                      AppHaptics.light();
                      Navigator.pop(context);
                      Clipboard.setData(ClipboardData(text: widget.message.msg));
                      Dialogs.showSnackbar(context, 'Text copied to clipboard!');
                    },
                  ),
                if (isMe)
                  ListTile(
                    leading: const Icon(Icons.delete_outline_rounded,
                        color: AppTheme.danger),
                    title: const Text(
                      'Delete Message',
                      style: TextStyle(
                        fontFamily: 'Lexend',
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
            ),
          ),
        ),
      );
    },
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isMe = APIs.user.uid == widget.message.fromId;

    return Dismissible(
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
        padding: const EdgeInsets.only(left: 20),
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppTheme.primary.withValues(alpha: 0.18),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.reply_rounded,
            color: AppTheme.primary,
            size: 20,
          ),
        ),
      ),
      child: GestureDetector(
        onLongPress: _showMessageOptions,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
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
            ? Colors.black.withValues(alpha: 0.18)
            : context.surfaceMutedColor,
        borderRadius: BorderRadius.circular(10),
        border: Border(
          left: BorderSide(
            color: isMe
                ? Colors.white
                : (context.isDark ? Colors.white : AppTheme.primary),
            width: 3.5,
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
            style: TextStyle(
              fontFamily: 'Lexend',
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: isMe
                  ? Colors.white
                  : (context.isDark ? Colors.white : AppTheme.primary),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            widget.message.replyMsg,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: 'Lexend',
              fontSize: 12,
              color: isMe
                  ? Colors.white.withValues(alpha: 0.85)
                  : context.textSecondaryColor,
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

  // Sent by other person (Left aligned)
  Widget _otherMessage() {
    if (widget.message.read.isEmpty) {
      APIs.updateMessageReadStatus(widget.message);
    }

    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: EdgeInsets.only(
            bottom: widget.message.reaction.isNotEmpty ? 8 : 0),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: mq.width * 0.78),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                decoration: BoxDecoration(
                  color: context.surfaceColor,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(18),
                    topRight: Radius.circular(18),
                    bottomRight: Radius.circular(18),
                    bottomLeft: Radius.circular(4),
                  ),
                  border: Border.all(color: context.borderColor, width: 1),
                  boxShadow: context.softShadow,
                ),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _replyQuoteHeader(false),
                      if (widget.message.type == Type.text)
                        _buildHighlightedText(
                          text: widget.message.msg,
                          baseStyle: TextStyle(
                            fontFamily: 'Lexend',
                            fontSize: 15,
                            color: context.textPrimaryColor,
                            height: 1.35,
                          ),
                          highlightColor: AppTheme.accent.withValues(alpha: 0.35),
                          highlightTextColor: AppTheme.primary,
                        )
                      else if (widget.message.type == Type.audio)
                        AudioWaveformPlayer(
                          isMe: false,
                          audioUrl: widget.message.msg,
                        )
                      else
                        GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => MediaViewerScreen(
                                  imageUrl: widget.message.msg,
                                  heroTag: 'msg_img_${widget.message.sent}',
                                  title: 'Photo',
                                  timestamp: MyDateUtil.getFormattedTime(
                                      context: context,
                                      time: widget.message.sent),
                                ),
                              ),
                            );
                          },
                          child: Hero(
                            tag: 'msg_img_${widget.message.sent}',
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: CachedNetworkImage(
                                imageUrl: widget.message.msg,
                                fit: BoxFit.cover,
                                placeholder: (context, url) => Container(
                                  height: 200,
                                  width: double.infinity,
                                  color: context.surfaceMutedColor,
                                  child: const Center(
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2),
                                  ),
                                ),
                                errorWidget: (context, url, error) => Container(
                                  height: 120,
                                  width: double.infinity,
                                  color: context.surfaceMutedColor,
                                  child: Icon(Icons.broken_image,
                                      size: 40, color: context.textMutedColor),
                                ),
                              ),
                            ),
                          ),
                        ),
                      const SizedBox(height: 4),
                      Align(
                        alignment: Alignment.bottomRight,
                        child: Text(
                          MyDateUtil.getFormattedTime(
                              context: context, time: widget.message.sent),
                          style: TextStyle(
                            fontFamily: 'Lexend',
                            fontSize: 10,
                            color: context.textMutedColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (widget.message.reaction.isNotEmpty)
                Positioned(
                  bottom: -8,
                  right: 8,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: context.surfaceColor,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: context.borderColor, width: 1),
                      boxShadow: context.softShadow,
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
    return Align(
      alignment: Alignment.centerRight,
      child: Padding(
        padding: EdgeInsets.only(
            bottom: widget.message.reaction.isNotEmpty ? 8 : 0),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: mq.width * 0.78),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                decoration: BoxDecoration(
                  gradient: context.isDark
                      ? const LinearGradient(
                          colors: [Color(0xFF2C2C2C), Color(0xFF222222)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        )
                      : const LinearGradient(
                          colors: [AppTheme.primary, AppTheme.primaryLight],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(18),
                    topRight: Radius.circular(18),
                    bottomLeft: Radius.circular(18),
                    bottomRight: Radius.circular(4),
                  ),
                  border: context.isDark
                      ? Border.all(color: const Color(0xFF383838), width: 0.8)
                      : null,
                  boxShadow: context.isDark
                      ? null
                      : [
                          BoxShadow(
                            color: AppTheme.primary.withValues(alpha: 0.22),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                ),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _replyQuoteHeader(true),
                      if (widget.message.type == Type.text)
                        _buildHighlightedText(
                          text: widget.message.msg,
                          baseStyle: const TextStyle(
                            fontFamily: 'Lexend',
                            fontSize: 15,
                            color: Colors.white,
                            height: 1.35,
                          ),
                          highlightColor: Colors.black26,
                          highlightTextColor: Colors.yellowAccent,
                        )
                      else if (widget.message.type == Type.audio)
                        AudioWaveformPlayer(
                          isMe: true,
                          audioUrl: widget.message.msg,
                        )
                      else
                        GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => MediaViewerScreen(
                                  imageUrl: widget.message.msg,
                                  heroTag: 'msg_img_${widget.message.sent}',
                                  title: 'You',
                                  timestamp: MyDateUtil.getFormattedTime(
                                      context: context,
                                      time: widget.message.sent),
                                ),
                              ),
                            );
                          },
                          child: Hero(
                            tag: 'msg_img_${widget.message.sent}',
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: CachedNetworkImage(
                                imageUrl: widget.message.msg,
                                fit: BoxFit.cover,
                                placeholder: (context, url) => Container(
                                  height: 200,
                                  width: double.infinity,
                                  color: Colors.white24,
                                  child: const Center(
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                          Colors.white),
                                    ),
                                  ),
                                ),
                                errorWidget: (context, url, error) => Container(
                                  height: 120,
                                  width: double.infinity,
                                  color: Colors.white24,
                                  child: const Icon(Icons.broken_image,
                                      size: 40, color: Colors.white70),
                                ),
                              ),
                            ),
                          ),
                        ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            MyDateUtil.getFormattedTime(
                                context: context, time: widget.message.sent),
                            style: TextStyle(
                              fontFamily: 'Lexend',
                              fontSize: 10,
                              color: Colors.white.withValues(alpha: 0.8),
                            ),
                          ),
                          const SizedBox(width: 4),
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 300),
                            transitionBuilder: (child, anim) =>
                                ScaleTransition(scale: anim, child: child),
                            child: widget.message.read.isNotEmpty
                                ? const Icon(
                                    Icons.done_all_rounded,
                                    key: ValueKey('read'),
                                    color: Color(0xFF67E8F9),
                                    size: 14,
                                  )
                                : Icon(
                                    Icons.done_rounded,
                                    key: const ValueKey('sent'),
                                    color: Colors.white.withValues(alpha: 0.75),
                                    size: 14,
                                  ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              if (widget.message.reaction.isNotEmpty)
                Positioned(
                  bottom: -8,
                  left: 8,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: context.surfaceColor,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: context.borderColor, width: 1),
                      boxShadow: context.softShadow,
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

