import 'package:cached_network_image/cached_network_image.dart';
import 'package:chatty/api/apis.dart';
import 'package:chatty/helper/app_theme.dart';
import 'package:chatty/helper/my_date_util.dart';
import 'package:chatty/models/chat_user.dart';
import 'package:chatty/models/message.dart';
import 'package:chatty/screens/chat_screen.dart';
import 'package:flutter/material.dart';

class ChatUserCard extends StatefulWidget {
  final ChatUser user;

  const ChatUserCard({super.key, required this.user});

  @override
  State<ChatUserCard> createState() => _ChatUserCardState();
}

class _ChatUserCardState extends State<ChatUserCard> {
  Message? _message;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: context.borderColor, width: 1),
        boxShadow: context.softShadow,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () {
            Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => ChatScreen(user: widget.user)));
          },
          child: StreamBuilder(
            stream: APIs.getUserInfo(widget.user),
            builder: (context, userSnapshot) {
              final userData = userSnapshot.data?.docs;
              final userList = userData
                      ?.map((e) => ChatUser.fromJson(e.data()))
                      .toList() ??
                  [];
              final currentUser =
                  userList.isNotEmpty ? userList[0] : widget.user;

              return StreamBuilder(
                stream: APIs.getLastMessages(widget.user),
                builder: (context, msgSnapshot) {
                  final data = msgSnapshot.data?.docs;
                  final list = data
                          ?.map((e) => Message.fromJson(e.data()))
                          .toList() ??
                      [];
                  if (list.isNotEmpty) {
                    _message = list[0];
                  }

                  final bool isUnread = _message != null &&
                      _message!.read.isEmpty &&
                      _message!.fromId != APIs.user.uid;

                  return Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                    child: Row(
                      children: [
                        // Avatar with live online badge
                        Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                    color: context.borderColor, width: 2),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(26),
                                child: CachedNetworkImage(
                                  width: 50,
                                  height: 50,
                                  fit: BoxFit.cover,
                                  imageUrl: currentUser.image,
                                  placeholder: (context, url) => Container(
                                    width: 50,
                                    height: 50,
                                    color: context.surfaceMutedColor,
                                    child: const Center(
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2),
                                    ),
                                  ),
                                  errorWidget: (context, url, error) =>
                                      CircleAvatar(
                                    radius: 25,
                                    backgroundColor: context.primarySoftColor,
                                    child: Text(
                                      currentUser.name.isNotEmpty
                                          ? currentUser.name[0].toUpperCase()
                                          : '?',
                                      style: const TextStyle(
                                        fontFamily: 'Lexend',
                                        fontWeight: FontWeight.w700,
                                        color: AppTheme.primary,
                                        fontSize: 20,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            // Online indicator badge
                            if (currentUser.isOnline)
                              Positioned(
                                right: 0,
                                bottom: 0,
                                child: Container(
                                  width: 14,
                                  height: 14,
                                  decoration: BoxDecoration(
                                    color: AppTheme.success,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: context.surfaceColor,
                                      width: 2.5,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(width: 14),

                        // User Name & Last Message Subtitle
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                currentUser.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontFamily: 'Lexend',
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: context.textPrimaryColor,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _message != null
                                    ? _message!.type == Type.image
                                        ? '📷 Photo'
                                        : _message!.msg
                                    : currentUser.about,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontFamily: 'Lexend',
                                  fontSize: 13,
                                  fontWeight: isUnread
                                      ? FontWeight.w600
                                      : FontWeight.w400,
                                  color: isUnread
                                      ? context.textPrimaryColor
                                      : context.textSecondaryColor,
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Timestamp & Unread Badge
                        if (_message != null)
                          Padding(
                            padding: const EdgeInsets.only(left: 8),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  MyDateUtil.getLastMessageTime(
                                      context: context,
                                      time: _message!.sent),
                                  style: TextStyle(
                                    fontFamily: 'Lexend',
                                    fontSize: 11,
                                    fontWeight: isUnread
                                        ? FontWeight.w600
                                        : FontWeight.w400,
                                    color: isUnread
                                        ? AppTheme.primary
                                        : AppTheme.textMuted,
                                  ),
                                ),
                                if (isUnread) ...[
                                  const SizedBox(height: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 7, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: AppTheme.primary,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: const Text(
                                      'NEW',
                                      style: TextStyle(
                                        fontFamily: 'Lexend',
                                        color: Colors.white,
                                        fontSize: 9,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }
}
