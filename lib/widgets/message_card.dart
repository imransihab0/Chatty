
import 'package:cached_network_image/cached_network_image.dart';
import 'package:chatty/api/apis.dart';
import 'package:chatty/helper/app_theme.dart';
import 'package:chatty/helper/dialogs.dart';
import 'package:chatty/helper/my_date_util.dart';
import 'package:chatty/main.dart';
import 'package:chatty/models/message.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// Modern Chat Message Card with Long-press Actions
class MessageCard extends StatefulWidget {
  const MessageCard({super.key, required this.message});

  final Message message;

  @override
  State<MessageCard> createState() => _MessageCardState();
}

class _MessageCardState extends State<MessageCard> {
  void _showMessageOptions() {
    final bool isMe = APIs.user.uid == widget.message.fromId;

    showModalBottomSheet(
      context: context,
      backgroundColor: context.surfaceColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) {
        return SafeArea(
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
                const SizedBox(height: 16),
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
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isMe = APIs.user.uid == widget.message.fromId;
    return GestureDetector(
      onLongPress: _showMessageOptions,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        child: isMe ? _myMessage() : _otherMessage(),
      ),
    );
  }

  // Sent by other person (Left aligned)
  Widget _otherMessage() {
    if (widget.message.read.isEmpty) {
      APIs.updateMessageReadStatus(widget.message);
    }

    return Align(
      alignment: Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: mq.width * 0.78),
        child: Container(
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
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (widget.message.type == Type.text)
                  Text(
                    widget.message.msg,
                    style: TextStyle(
                      fontFamily: 'Lexend',
                      fontSize: 15,
                      color: context.textPrimaryColor,
                      height: 1.35,
                    ),
                  )
                else
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: CachedNetworkImage(
                      imageUrl: widget.message.msg,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Container(
                        height: 200,
                        width: double.infinity,
                        color: context.surfaceMutedColor,
                        child: const Center(
                          child: CircularProgressIndicator(strokeWidth: 2),
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
      ),
    );
  }

  // Sent by me (Right aligned)
  Widget _myMessage() {
    return Align(
      alignment: Alignment.centerRight,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: mq.width * 0.78),
        child: Container(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
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
            boxShadow: [
              BoxShadow(
                color: AppTheme.primary.withValues(alpha: 0.22),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (widget.message.type == Type.text)
                  Text(
                    widget.message.msg,
                    style: const TextStyle(
                      fontFamily: 'Lexend',
                      fontSize: 15,
                      color: Colors.white,
                      height: 1.35,
                    ),
                  )
                else
                  ClipRRect(
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
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
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
                    Icon(
                      widget.message.read.isNotEmpty
                          ? Icons.done_all_rounded
                          : Icons.done_rounded,
                      color: Colors.white,
                      size: 14,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

