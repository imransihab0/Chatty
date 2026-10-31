
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
  static final RegExp _urlRegex = RegExp(
    r'(https?:\/\/[^\s]+)',
    caseSensitive: false,
  );

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
            const SizedBox(width: 8),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    host,
                    style: TextStyle(
                      fontFamily: 'Lexend',
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
                      fontFamily: 'Lexend',
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
            const SizedBox(width: 6),
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
            fontFamily: 'Lexend',
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
                fontFamily: 'Lexend',
                fontSize: 14,
                color: context.textPrimaryColor,
              ),
              decoration: InputDecoration(
                hintText: 'Enter updated message...',
                hintStyle: TextStyle(
                  fontFamily: 'Lexend',
                  fontSize: 13,
                  color: context.textMutedColor,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: context.borderColor),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: context.textPrimaryColor, width: 1.5),
                ),
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: TextStyle(
                fontFamily: 'Lexend',
                color: context.textSecondaryColor,
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
                style:
                    TextStyle(fontFamily: 'Lexend', fontWeight: FontWeight.w600)),
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
                      padding:
                          const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: context.surfaceColor.withValues(
                            alpha: context.isDark ? 0.85 : 0.92),
                        borderRadius: BorderRadius.circular(28),
                        border: Border.all(
                            color: context.borderColor, width: 0.8),
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
                const SizedBox(height: 10),

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
                      if (widget.message.type == Type.text) ...[
                        Divider(height: 1, indent: 54, color: context.borderColor),
                        ListTile(
                          leading: Icon(Icons.copy_rounded,
                              color: context.textPrimaryColor),
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
                            Clipboard.setData(
                                ClipboardData(text: widget.message.msg));
                            Dialogs.showSnackbar(
                                context, 'Text copied to clipboard!');
                          },
                        ),
                      ],
                      if (isMe && widget.message.type == Type.text) ...[
                        Divider(height: 1, indent: 54, color: context.borderColor),
                        ListTile(
                          leading: Icon(Icons.edit_rounded,
                              color: context.textPrimaryColor),
                          title: Text(
                            'Edit Message',
                            style: TextStyle(
                              fontFamily: 'Lexend',
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
                        Divider(height: 1, indent: 54, color: context.borderColor),
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
        top: 4,
        bottom: 4,
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
            ? Colors.black.withValues(alpha: 0.18)
            : context.surfaceMutedColor,
        borderRadius: BorderRadius.circular(10),
        border: Border(
          left: BorderSide(
            color: isMe
                ? Colors.white
                : (context.isDark ? Colors.white : Colors.black),
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
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: 'Lexend',
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
          constraints: BoxConstraints(
            minWidth: widget.message.reaction.isNotEmpty ? 92 : 0,
            maxWidth: MediaQuery.sizeOf(context).width * 0.76,
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                decoration: BoxDecoration(
                  color: context.isDark
                      ? const Color(0xFF222224)
                      : context.surfaceColor,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(18),
                    topRight: Radius.circular(18),
                    bottomRight: Radius.circular(18),
                    bottomLeft: Radius.circular(4),
                  ),
                  border: Border.all(
                    color: context.isDark
                        ? const Color(0xFF2E2E32)
                        : context.borderColor,
                    width: 0.8,
                  ),
                  boxShadow: context.softShadow,
                ),
                child: Padding(
                  padding: (widget.message.type == Type.image &&
                          widget.message.replyMsg.isEmpty)
                      ? const EdgeInsets.all(4)
                      : const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _replyQuoteHeader(false),
                      if (widget.message.type == Type.text) ...[
                        _buildHighlightedText(
                          text: widget.message.msg,
                          baseStyle: TextStyle(
                            fontFamily: 'Lexend',
                            fontSize: 15,
                            color: context.textPrimaryColor,
                            height: 1.35,
                          ),
                          highlightColor: context.isDark
                              ? const Color(0xFF333333)
                              : const Color(0xFFE4E4E7),
                          highlightTextColor: context.textPrimaryColor,
                        ),
                        _buildLinkPreviewIfNeeded(widget.message.msg, false),
                      ]
                      else if (widget.message.type == Type.audio)
                        AudioWaveformPlayer(
                          isMe: false,
                          audioUrl: widget.message.msg,
                          durationMs: widget.message.durationMs,
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
                              child: Stack(
                                children: [
                                  CachedNetworkImage(
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
                                    errorWidget: (context, url, error) =>
                                        Container(
                                      height: 120,
                                      width: double.infinity,
                                      color: context.surfaceMutedColor,
                                      child: Icon(Icons.broken_image,
                                          size: 40,
                                          color: context.textMutedColor),
                                    ),
                                  ),
                                  Positioned(
                                    bottom: 6,
                                    right: 8,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color:
                                            Colors.black.withValues(alpha: 0.6),
                                        borderRadius:
                                            BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        MyDateUtil.getFormattedTime(
                                            context: context,
                                            time: widget.message.sent),
                                        style: const TextStyle(
                                          fontFamily: 'Lexend',
                                          fontSize: 10,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      if (widget.message.type != Type.image) ...[
                        const SizedBox(height: 3),
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
          constraints: BoxConstraints(
            minWidth: widget.message.reaction.isNotEmpty ? 92 : 0,
            maxWidth: MediaQuery.sizeOf(context).width * 0.76,
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                decoration: BoxDecoration(
                  gradient: context.isDark
                      ? const LinearGradient(
                          colors: [Color(0xFF242426), Color(0xFF1C1C1E)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        )
                      : const LinearGradient(
                          colors: [Color(0xFF1C1C1E), Color(0xFF09090B)],
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
                      ? Border.all(color: const Color(0xFF38383C), width: 0.8)
                      : null,
                  boxShadow: context.isDark
                      ? null
                      : [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.12),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                ),
                child: Padding(
                  padding: (widget.message.type == Type.image &&
                          widget.message.replyMsg.isEmpty)
                      ? const EdgeInsets.all(4)
                      : const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _replyQuoteHeader(true),
                      if (widget.message.type == Type.text) ...[
                        _buildHighlightedText(
                          text: widget.message.msg,
                          baseStyle: const TextStyle(
                            fontFamily: 'Lexend',
                            fontSize: 15,
                            color: Colors.white,
                            height: 1.35,
                          ),
                          highlightColor: Colors.white.withValues(alpha: 0.25),
                          highlightTextColor: Colors.white,
                        ),
                        _buildLinkPreviewIfNeeded(widget.message.msg, true),
                      ]
                      else if (widget.message.type == Type.audio)
                        AudioWaveformPlayer(
                          isMe: true,
                          audioUrl: widget.message.msg,
                          durationMs: widget.message.durationMs,
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
                              child: Stack(
                                children: [
                                  CachedNetworkImage(
                                    imageUrl: widget.message.msg,
                                    fit: BoxFit.cover,
                                    placeholder: (context, url) => Container(
                                      height: 200,
                                      width: double.infinity,
                                      color: Colors.white24,
                                      child: const Center(
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor:
                                              AlwaysStoppedAnimation<Color>(
                                                  Colors.white),
                                        ),
                                      ),
                                    ),
                                    errorWidget: (context, url, error) =>
                                        Container(
                                      height: 120,
                                      width: double.infinity,
                                      color: Colors.white24,
                                      child: const Icon(Icons.broken_image,
                                          size: 40, color: Colors.white70),
                                    ),
                                  ),
                                  Positioned(
                                    bottom: 6,
                                    right: 8,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color:
                                            Colors.black.withValues(alpha: 0.6),
                                        borderRadius:
                                            BorderRadius.circular(8),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            MyDateUtil.getFormattedTime(
                                                context: context,
                                                time: widget.message.sent),
                                            style: const TextStyle(
                                              fontFamily: 'Lexend',
                                              fontSize: 10,
                                              color: Colors.white,
                                            ),
                                          ),
                                          const SizedBox(width: 3),
                                          AnimatedSwitcher(
                                            duration: const Duration(
                                                milliseconds: 300),
                                            transitionBuilder: (child, anim) =>
                                                ScaleTransition(
                                                    scale: anim, child: child),
                                            child: widget.message.read.isNotEmpty
                                                ? const Icon(
                                                    Icons.done_all_rounded,
                                                    key: ValueKey('read'),
                                                    color: Colors.white,
                                                    size: 13,
                                                  )
                                                : Icon(
                                                    Icons.done_rounded,
                                                    key: const ValueKey('sent'),
                                                    color: Colors.white
                                                        .withValues(alpha: 0.7),
                                                    size: 13,
                                                  ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      if (widget.message.type != Type.image) ...[
                        const SizedBox(height: 3),
                        Align(
                          alignment: Alignment.bottomRight,
                          child: Row(
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
                                        color: Colors.white,
                                        size: 14,
                                      )
                                    : Icon(
                                        Icons.done_rounded,
                                        key: const ValueKey('sent'),
                                        color:
                                            Colors.white.withValues(alpha: 0.75),
                                        size: 14,
                                      ),
                              ),
                            ],
                          ),
                        ),
                      ],
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

