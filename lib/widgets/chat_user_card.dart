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
import 'package:chatty/widgets/app_components.dart';
import 'package:chatty/widgets/typing_wave_dots.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

/// ---------------------------------------------------------------------------
/// TELEGRAM-GRADE CHAT CONVERSATION TILE
/// Features:
/// - 52pt rounded avatar with knockout online dot and fallback initials
/// - Pinned conversation tint and pin icon badge
/// - Outgoing delivery checkmarks (single sent, double read)
/// - Media snippet icons (Photo, Voice Note with duration)
/// - Telegram swipe actions (Swipe right to Pin/Unpin, Swipe left for Options)
/// - Smooth haptic feedback and context sheet
/// ---------------------------------------------------------------------------
class ChatUserCard extends StatefulWidget {
  final ChatUser user;

  const ChatUserCard({super.key, required this.user});

  @override
  State<ChatUserCard> createState() => _ChatUserCardState();
}

class _ChatUserCardState extends State<ChatUserCard>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

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
        color: isRead
            ? AppTheme.success
            : (context.isDark ? const Color(0xFFD4D4D8) : const Color(0xFF52525B)),
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
                        fontFamily: AppTypography.fontFamily,
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
                        fontFamily: AppTypography.fontFamily,
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
                        fontFamily: AppTypography.fontFamily,
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
    super.build(context);
    final bool isPinned = ChatSettingsController.isPinned(widget.user.id);
    final swipeBgColor = context.isDark
        ? const Color(0xFF262626)
        : const Color(0xFFE4E4E7);
    final swipeFgColor = context.isDark ? Colors.white : Colors.black87;

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
        padding: const EdgeInsets.symmetric(horizontal: 24),
        alignment: Alignment.centerLeft,
        color: swipeBgColor,
        child: Row(
          children: [
            Icon(
              isPinned ? Icons.push_pin_outlined : Icons.push_pin_rounded,
              color: swipeFgColor,
              size: 22,
            ),
            AppSpacing.gapW8,
            Text(
              isPinned ? 'Unpin' : 'Pin to Top',
              style: TextStyle(
                fontFamily: AppTypography.fontFamily,
                color: swipeFgColor,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
      secondaryBackground: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        alignment: Alignment.centerRight,
        color: swipeBgColor,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Text(
              'Options',
              style: TextStyle(
                fontFamily: AppTypography.fontFamily,
                color: swipeFgColor,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
            AppSpacing.gapW8,
            Icon(
              Icons.more_horiz_rounded,
              color: swipeFgColor,
              size: 22,
            ),
          ],
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Material(
            color: isPinned
                ? (context.isDark ? const Color(0xFF1E1E22) : const Color(0xFFF4F4F7))
                : Colors.transparent,
            child: InkWell(
              onLongPress: () {
                AppHaptics.medium();
                _showChatOptions(isPinned, widget.user);
              },
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ChatScreen(user: widget.user),
                  ),
                );
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
                      }

                      final bool isUnread = _message != null &&
                          _message!.read.isEmpty &&
                          _message!.fromId != APIs.myUid;

                      return Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 10),
                        child: Row(
                          children: [
                            // 52pt Avatar with Knockout Online Dot
                            AppAvatar(
                              imageUrl: currentUser.image,
                              name: currentUser.name,
                              size: 52,
                              isOnline: currentUser.isOnline,
                            ),
                            AppSpacing.gapW14,

                            // User Name & Subtitle Snippet
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
                                      fontFamily: AppTypography.fontFamily,
                                      fontSize: 16,
                                      fontWeight: isUnread
                                          ? FontWeight.w700
                                          : FontWeight.w600,
                                      color: context.textPrimaryColor,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  StreamBuilder<
                                      DocumentSnapshot<Map<String, dynamic>>>(
                                    stream: _chatMetaStream,
                                    builder: (context, metaSnap) {
                                      final metaData = metaSnap.data?.data();
                                      final bool isTypingRaw = metaData?[
                                              'typing_${widget.user.id}'] ==
                                          true;
                                      final int lastTypingTime = metaData?[
                                                  'typing_time_${widget.user.id}']
                                              is int
                                          ? metaData![
                                                  'typing_time_${widget.user.id}']
                                              as int
                                          : (metaData?['typing_time'] is int
                                              ? metaData!['typing_time'] as int
                                              : 0);
                                      final int now =
                                          DateTime.now().millisecondsSinceEpoch;
                                      final bool isTyping = isTypingRaw &&
                                          (lastTypingTime == 0 ||
                                              (now - lastTypingTime < 2400));

                                      if (isTyping) {
                                        return const TypingWaveDots(
                                          dotSize: 4.0,
                                          showLabel: true,
                                          label: 'typing',
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
                                                fontFamily:
                                                    AppTypography.fontFamily,
                                                fontSize: 13.5,
                                                fontWeight: isUnread
                                                    ? FontWeight.w600
                                                    : FontWeight.w400,
                                                color: isUnread
                                                    ? context.textPrimaryColor
                                                    : context
                                                        .textSecondaryColor,
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

                            // Timestamp & Unread / Pin Indicators
                            if (_message != null)
                              Padding(
                                padding: const EdgeInsets.only(left: 10),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      MyDateUtil.getLastMessageTime(
                                          context: context,
                                          time: _message!.sent),
                                      style: TextStyle(
                                        fontFamily: AppTypography.fontFamily,
                                        fontSize: 11.5,
                                        fontWeight: isUnread
                                            ? FontWeight.w600
                                            : FontWeight.w400,
                                        color: isUnread
                                            ? (context.isDark
                                                ? Colors.white
                                                : Colors.black)
                                            : context.textMutedColor,
                                      ),
                                    ),
                                    const SizedBox(height: 5),
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        if (isPinned) ...[
                                          Icon(
                                            Icons.push_pin_rounded,
                                            size: 13,
                                            color: context.textMutedColor,
                                          ),
                                          if (isUnread) AppSpacing.gapW4,
                                        ],
                                        if (isUnread)
                                          Container(
                                            width: 8,
                                            height: 8,
                                            decoration: BoxDecoration(
                                              color: context.isDark
                                                  ? Colors.white
                                                  : Colors.black,
                                              shape: BoxShape.circle,
                                            ),
                                          ),
                                      ],
                                    ),
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
          // Subtle hairline divider indented 82pt after avatar
          Divider(
            height: 0.8,
            thickness: 0.6,
            indent: 82,
            endIndent: 0,
            color: context.isDark
                ? const Color(0xFF27272A)
                : const Color(0xFFE4E4E8),
          ),
        ],
      ),
    );
  }
}
