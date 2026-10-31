import 'package:cached_network_image/cached_network_image.dart';
import 'package:chatty/api/apis.dart';
import 'package:chatty/helper/app_haptics.dart';
import 'package:chatty/helper/app_theme.dart';
import 'package:chatty/helper/dialogs.dart';
import 'package:chatty/helper/my_date_util.dart';
import 'package:chatty/models/chat_user.dart';
import 'package:chatty/models/message.dart';
import 'package:chatty/screens/chat_screen.dart';
import 'package:chatty/screens/profile_screen.dart';
import 'package:chatty/services/chat_settings_controller.dart';
import 'package:chatty/services/conversation_controller.dart';
import 'package:chatty/widgets/typing_wave_dots.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

/// Telegram-Grade Chat Conversation Card
/// Features:
/// - 50pt rounded avatar with knockout online dot and subtle gradient fallback
/// - Outgoing message delivery checkmarks (single check sent, double check read)
/// - Media snippet previews (voice note with formatted duration, photo icon)
/// - Pinned conversation badge and unread count pill
/// - Telegram-style swipe actions (Swipe right to Pin/Unpin, Swipe left for Actions)
class ChatUserCard extends StatefulWidget {
  final ChatUser user;

  const ChatUserCard({super.key, required this.user});

  @override
  State<ChatUserCard> createState() => _ChatUserCardState();
}

class _ChatUserCardState extends State<ChatUserCard> {
  Message? _message;
  late Stream<QuerySnapshot<Map<String, dynamic>>> _userInfoStream;
  late Stream<QuerySnapshot<Map<String, dynamic>>> _lastMessageStream;
  late Stream<DocumentSnapshot<Map<String, dynamic>>> _chatMetaStream;

  @override
  void initState() {
    super.initState();
    _initStreams();
  }

  void _initStreams() {
    _userInfoStream = APIs.getUserInfo(widget.user);
    _lastMessageStream = APIs.getLastMessages(widget.user);
    _chatMetaStream = APIs.getChatMeta(widget.user);
  }

  @override
  void didUpdateWidget(covariant ChatUserCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.user.id != widget.user.id) {
      _initStreams();
    }
  }

  String _formatVoiceDuration(int durationMs) {
    if (durationMs <= 0) return 'Voice note';
    final seconds = (durationMs / 1000).round();
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return 'Voice note ($m:${s.toString().padLeft(2, '0')})';
  }

  Widget _buildMessageStatusIcon(Message msg) {
    final isMe = msg.fromId == APIs.myUid;
    if (!isMe) return const SizedBox.shrink();
    final isRead = msg.read.isNotEmpty;
    return Padding(
      padding: const EdgeInsets.only(right: 4),
      child: Icon(
        isRead ? Icons.done_all_rounded : Icons.done_rounded,
        size: 15,
        color: isRead ? AppTheme.success : context.textMutedColor,
      ),
    );
  }

  void _showChatOptions(bool isPinned, ChatUser currentUser) {
    AppHaptics.medium();
    showModalBottomSheet(
      context: context,
      backgroundColor: context.surfaceColor,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) {
        return Material(
          color: Colors.transparent,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    leading: Icon(
                      isPinned ? Icons.push_pin_outlined : Icons.push_pin_rounded,
                      color: context.textPrimaryColor,
                    ),
                    title: Text(
                      isPinned ? 'Unpin from Top' : 'Pin to Top',
                      style: TextStyle(
                        fontFamily: 'Lexend',
                        color: context.textPrimaryColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      ChatSettingsController.togglePin(widget.user.id);
                      Dialogs.showSnackbar(
                        context,
                        isPinned ? 'Unpinned conversation' : 'Pinned to top',
                      );
                    },
                  ),
                  ListTile(
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    leading: Icon(Icons.person_outline_rounded,
                        color: context.textPrimaryColor),
                    title: Text(
                      'View Profile',
                      style: TextStyle(
                        fontFamily: 'Lexend',
                        color: context.textPrimaryColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => ProfileScreen(user: currentUser)),
                      );
                    },
                  ),
                  ListTile(
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    leading: Icon(Icons.notifications_off_outlined,
                        color: context.textPrimaryColor),
                    title: Text(
                      'Mute Notifications',
                      style: TextStyle(
                        fontFamily: 'Lexend',
                        color: context.textPrimaryColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      AppHaptics.light();
                      Dialogs.showSnackbar(
                        context,
                        'Muted notifications for ${currentUser.name}',
                      );
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
    final bool isPinned = ChatSettingsController.isPinned(widget.user.id);
    final swipeBgColor = context.isDark
        ? const Color(0xFF262626)
        : const Color(0xFFE4E4E7);
    final swipeFgColor =
        context.isDark ? Colors.white : Colors.black87;

    return Dismissible(
      key: Key('chat_card_${widget.user.id}'),
      direction: DismissDirection.horizontal,
      dismissThresholds: const {
        DismissDirection.startToEnd: 0.22,
        DismissDirection.endToStart: 0.22,
      },
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.startToEnd) {
          // Swipe Right: Pin / Unpin
          AppHaptics.medium();
          ChatSettingsController.togglePin(widget.user.id);
          Dialogs.showSnackbar(
            context,
            isPinned ? 'Unpinned conversation' : 'Pinned to top',
          );
        } else if (direction == DismissDirection.endToStart) {
          // Swipe Left: Quick Options sheet
          AppHaptics.medium();
          _showChatOptions(isPinned, widget.user);
        }
        return false;
      },
      background: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        alignment: Alignment.centerLeft,
        decoration: BoxDecoration(
          color: swipeBgColor,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          children: [
            Icon(
              isPinned ? Icons.push_pin_outlined : Icons.push_pin_rounded,
              color: swipeFgColor,
              size: 22,
            ),
            const SizedBox(width: 8),
            Text(
              isPinned ? 'Unpin' : 'Pin to Top',
              style: TextStyle(
                fontFamily: 'Lexend',
                color: swipeFgColor,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
      secondaryBackground: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        alignment: Alignment.centerRight,
        decoration: BoxDecoration(
          color: swipeBgColor,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Text(
              'Options',
              style: TextStyle(
                fontFamily: 'Lexend',
                color: swipeFgColor,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              Icons.more_horiz_rounded,
              color: swipeFgColor,
              size: 22,
            ),
          ],
        ),
      ),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
        decoration: BoxDecoration(
          color: isPinned ? context.surfaceMutedColor : context.surfaceColor,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isPinned
                ? (context.isDark
                    ? const Color(0xFF444444)
                    : const Color(0xFFD4D4D8))
                : context.borderColor,
            width: isPinned ? 1.5 : 1,
          ),
          boxShadow: context.softShadow,
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onLongPress: () {
              AppHaptics.medium();
              _showChatOptions(isPinned, widget.user);
            },
            onTap: () {
              Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => ChatScreen(user: widget.user)));
            },
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _userInfoStream,
              builder: (context, userSnapshot) {
                final userData = userSnapshot.data?.docs;
                final userList = userData
                        ?.map((e) => ChatUser.fromJson(e.data()))
                        .toList() ??
                    [];
                final currentUser =
                    userList.isNotEmpty ? userList[0] : widget.user;

                return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: _lastMessageStream,
                  builder: (context, msgSnapshot) {
                    final data = msgSnapshot.data?.docs;
                    final list = data
                            ?.map((e) => Message.fromJson(e.data()))
                            .toList() ??
                        [];
                    if (list.isNotEmpty) {
                      _message = list[0];
                      final sentTime = int.tryParse(_message!.sent) ?? 0;
                      if (sentTime > 0) {
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          ConversationController.updateLastMessage(
                              widget.user.id, _message!);
                        });
                      }
                    }

                    final bool isUnread = _message != null &&
                        _message!.read.isEmpty &&
                        _message!.fromId != APIs.myUid;

                    return Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12),
                      child: Row(
                        children: [
                          // 50pt Avatar with Knockout Online Dot
                          Stack(
                            clipBehavior: Clip.none,
                            children: [
                              Container(
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                      color: context.borderColor, width: 1.5),
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(25),
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
                                        Container(
                                      width: 50,
                                      height: 50,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        gradient: LinearGradient(
                                          colors: context.isDark
                                              ? const [
                                                  Color(0xFF2C2C2E),
                                                  Color(0xFF1C1C1E)
                                                ]
                                              : const [
                                                  Color(0xFFE4E4E7),
                                                  Color(0xFFF4F4F5)
                                                ],
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                        ),
                                      ),
                                      child: Center(
                                        child: Text(
                                          currentUser.name.isNotEmpty
                                              ? currentUser.name[0]
                                                  .toUpperCase()
                                              : '?',
                                          style: TextStyle(
                                            fontFamily: 'Lexend',
                                            fontWeight: FontWeight.w700,
                                            color: context.textPrimaryColor,
                                            fontSize: 20,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              // Knockout online indicator badge
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
                                        color: isPinned
                                            ? context.surfaceMutedColor
                                            : context.surfaceColor,
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
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
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
                                    ),
                                    if (isPinned) ...[
                                      const SizedBox(width: 4),
                                      Icon(
                                        Icons.push_pin_rounded,
                                        size: 14,
                                        color: context.textPrimaryColor,
                                      ),
                                    ],
                                  ],
                                ),
                                const SizedBox(height: 4),
                                StreamBuilder<
                                    DocumentSnapshot<Map<String, dynamic>>>(
                                  stream: _chatMetaStream,
                                  builder: (context, metaSnap) {
                                    final metaData = metaSnap.data?.data();
                                    final bool isTyping = metaData?[
                                            'typing_${widget.user.id}'] ==
                                        true;

                                    if (isTyping) {
                                      return const TypingWaveDots(
                                        dotSize: 4.5,
                                        showLabel: true,
                                        label: 'typing...',
                                      );
                                    }

                                    return Row(
                                      children: [
                                        if (_message != null)
                                          _buildMessageStatusIcon(_message!),
                                        Expanded(
                                          child: Text(
                                            _message != null
                                                ? _message!.type == Type.image
                                                    ? '📷 Photo'
                                                    : _message!.type ==
                                                            Type.audio
                                                        ? '🎙️ ${_formatVoiceDuration(_message!.durationMs)}'
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
                                        ),
                                      ],
                                    );
                                  },
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
                                          ? (context.isDark
                                              ? Colors.white
                                              : Colors.black)
                                          : context.textSecondaryColor,
                                    ),
                                  ),
                                  if (isUnread) ...[
                                    const SizedBox(height: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 7, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: context.isDark
                                            ? Colors.white
                                            : Colors.black,
                                        borderRadius:
                                            BorderRadius.circular(10),
                                      ),
                                      child: Text(
                                        'NEW',
                                        style: TextStyle(
                                          fontFamily: 'Lexend',
                                          color: context.isDark
                                              ? Colors.black
                                              : Colors.white,
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
      ),
    );
  }
}
