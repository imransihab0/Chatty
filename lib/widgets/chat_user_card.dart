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
    with AutomaticKeepAliveClientMixin, TickerProviderStateMixin {
  @override
  bool get wantKeepAlive => true;

  Message? _message;
  late Stream<QuerySnapshot<Map<String, dynamic>>> _userInfoStream;
  late Stream<QuerySnapshot<Map<String, dynamic>>> _lastMessageStream;
  late Stream<DocumentSnapshot<Map<String, dynamic>>> _chatMetaStream;

  // Interactive Telegram / iOS Multi-Action Slidable Drawer
  late final AnimationController _dragController;
  Animation<double>? _dragAnimation;
  double _dragExtent = 0.0;
  static const double _actionThreshold = 148.0;

  @override
  void initState() {
    super.initState();
    _initStreams();
    _dragController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 240),
    );
    _dragController.addListener(() {
      setState(() {
        _dragExtent = _dragAnimation?.value ?? _dragExtent;
      });
    });
  }

  @override
  void dispose() {
    _dragController.dispose();
    super.dispose();
  }

  void _animateTo(double target) {
    _dragAnimation = Tween<double>(begin: _dragExtent, end: target).animate(
      CurvedAnimation(parent: _dragController, curve: Curves.easeOutCubic),
    );
    _dragController.forward(from: 0.0);
  }

  void _closeDrawer() {
    if (_dragExtent != 0.0) {
      _animateTo(0.0);
    }
  }

  void _onHorizontalDragUpdate(DragUpdateDetails details) {
    final double delta = details.primaryDelta ?? 0.0;
    double newExtent = _dragExtent + delta;

    // Smooth rubber-band damping beyond action threshold
    if (newExtent > _actionThreshold) {
      final over = newExtent - _actionThreshold;
      newExtent = _actionThreshold + (over * 0.25);
    } else if (newExtent < -_actionThreshold) {
      final over = newExtent + _actionThreshold;
      newExtent = -_actionThreshold + (over * 0.25);
    }

    if ((_dragExtent <= 0 && newExtent > 0) ||
        (_dragExtent >= 0 && newExtent < 0)) {
      AppHaptics.selection();
    }

    setState(() {
      _dragExtent = newExtent;
    });
  }

  void _onHorizontalDragEnd(DragEndDetails details) {
    final velocity = details.primaryVelocity ?? 0.0;

    if (velocity > 400 || _dragExtent > 74.0) {
      AppHaptics.light();
      _animateTo(_actionThreshold);
    } else if (velocity < -400 || _dragExtent < -74.0) {
      AppHaptics.light();
      _animateTo(-_actionThreshold);
    } else {
      _animateTo(0.0);
    }
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

  Widget _buildActionButton({
    required Color color,
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      width: 74,
      height: double.infinity,
      child: Material(
        color: color,
        child: InkWell(
          onTap: onTap,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: Colors.white, size: 22),
              const SizedBox(height: 4),
              Text(
                label,
                style: const TextStyle(
                  fontFamily: AppTypography.fontFamily,
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 11.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showDeleteConfirmation(ChatUser currentUser) {
    AppHaptics.heavy();
    showModalBottomSheet(
      context: context,
      backgroundColor: context.surfaceColor,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: const Color(0xFFDC2626).withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.delete_forever_rounded,
                    color: Color(0xFFDC2626),
                    size: 28,
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  'Delete Conversation?',
                  style: TextStyle(
                    fontFamily: AppTypography.fontFamily,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: context.textPrimaryColor,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'All messages, photos, and voice notes with ${currentUser.name} will be permanently removed for you.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: AppTypography.fontFamily,
                    fontSize: 13.5,
                    color: context.textSecondaryColor,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 22),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFDC2626),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onPressed: () async {
                      Navigator.pop(sheetContext);
                      AppHaptics.medium();
                      final success =
                          await APIs.deleteConversation(currentUser);
                      if (mounted) {
                        Dialogs.showSnackbar(
                          context,
                          success
                              ? 'Conversation deleted'
                              : 'Failed to delete conversation',
                        );
                      }
                    },
                    child: const Text(
                      'Delete Conversation',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  height: 46,
                  child: TextButton(
                    style: TextButton.styleFrom(
                      foregroundColor: context.textSecondaryColor,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onPressed: () => Navigator.pop(sheetContext),
                    child: const Text(
                      'Cancel',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
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
    final bool isUnread = ConversationController.isUnread(widget.user.id) ||
        (_message != null &&
            _message!.read.isEmpty &&
            _message!.fromId != APIs.myUid);

    return ClipRect(
      child: Stack(
        children: [
          // Background action drawer (revealed as tile is dragged)
          Positioned.fill(
            child: Row(
              children: [
                // Left Drawer Actions (Revealed on Swipe Right)
                if (_dragExtent > 0) ...[
                  _buildActionButton(
                    color: const Color(0xFFF59E0B),
                    icon: isPinned
                        ? Icons.push_pin_outlined
                        : Icons.push_pin_rounded,
                    label: isPinned ? 'Unpin' : 'Pin',
                    onTap: () {
                      _closeDrawer();
                      AppHaptics.medium();
                      ChatSettingsController.togglePin(widget.user.id);
                      Dialogs.showSnackbar(
                        context,
                        isPinned ? 'Unpinned conversation' : 'Pinned to top',
                      );
                    },
                  ),
                  _buildActionButton(
                    color: const Color(0xFF2563EB),
                    icon: isUnread
                        ? Icons.mark_chat_read_rounded
                        : Icons.mark_chat_unread_rounded,
                    label: isUnread ? 'Read' : 'Unread',
                    onTap: () async {
                      _closeDrawer();
                      AppHaptics.medium();
                      if (isUnread) {
                        await APIs.markConversationAsRead(widget.user);
                      } else {
                        ConversationController.toggleMarkUnread(widget.user.id);
                      }
                    },
                  ),
                ],
                const Spacer(),
                // Right Drawer Actions (Revealed on Swipe Left)
                if (_dragExtent < 0) ...[
                  _buildActionButton(
                    color: const Color(0xFF4B5563),
                    icon: Icons.more_horiz_rounded,
                    label: 'More',
                    onTap: () {
                      _closeDrawer();
                      _showChatOptions(isPinned, widget.user);
                    },
                  ),
                  _buildActionButton(
                    color: const Color(0xFFDC2626),
                    icon: Icons.delete_outline_rounded,
                    label: 'Delete',
                    onTap: () {
                      _closeDrawer();
                      _showDeleteConfirmation(widget.user);
                    },
                  ),
                ],
              ],
            ),
          ),

          // Sliding Foreground Tile Surface
          Transform.translate(
            offset: Offset(_dragExtent, 0.0),
            child: GestureDetector(
              onHorizontalDragUpdate: _onHorizontalDragUpdate,
              onHorizontalDragEnd: _onHorizontalDragEnd,
              behavior: HitTestBehavior.opaque,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Material(
                    color: isPinned
                        ? (context.isDark
                            ? const Color(0xFF1E1E22)
                            : const Color(0xFFF4F4F7))
                        : context.surfaceColor,
                    child: InkWell(
                      onLongPress: () {
                        if (_dragExtent != 0.0) {
                          _closeDrawer();
                          return;
                        }
                        AppHaptics.medium();
                        _showChatOptions(isPinned, widget.user);
                      },
                      onTap: () {
                        if (_dragExtent != 0.0) {
                          _closeDrawer();
                          return;
                        }
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
    ),
  ),
],
),
);
  }
}
