import 'dart:async';
import 'dart:developer';
import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../api/apis.dart';
import '../helper/app_haptics.dart';
import '../helper/app_theme.dart';
import '../helper/dialogs.dart';
import '../helper/my_date_util.dart';
import '../models/chat_user.dart';
import '../models/message.dart';
import '../widgets/app_components.dart';
import '../widgets/chat_voice_input_bar.dart';
import '../widgets/message_card.dart';
import '../widgets/shimmer_skeleton.dart';
import '../widgets/typing_wave_dots.dart';
import 'media_viewer_screen.dart';

class ChatScreen extends StatefulWidget {
  final ChatUser user;

  const ChatScreen({super.key, required this.user});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  List<Message> _list = [];
  final _textController = TextEditingController();
  final _searchController = TextEditingController();
  late final ScrollController _scrollController;

  bool _isUploading = false;
  bool _isSearching = false;
  String _searchQuery = '';
  Message? _replyMessage;
  Timer? _typingTimer;
  bool _isTyping = false;
  int _lastTypingSentTime = 0;

  late final Stream<QuerySnapshot<Map<String, dynamic>>> _messagesStream;
  late final Stream<QuerySnapshot<Map<String, dynamic>>> _userInfoStream;
  late final Stream<DocumentSnapshot<Map<String, dynamic>>> _chatMetaStream;

  // Scroll to Bottom & Unread Badge (ValueNotifiers isolate scroll state from StreamBuilder)
  final ValueNotifier<bool> _showScrollToBottomNotifier = ValueNotifier<bool>(false);
  final ValueNotifier<int> _newMessagesWhileScrolledNotifier = ValueNotifier<int>(0);
  int _lastKnownCount = 0;

  // Sticky Floating Date Header
  final ValueNotifier<String?> _floatingDateNotifier = ValueNotifier<String?>(null);
  final ValueNotifier<bool> _showFloatingDateNotifier = ValueNotifier<bool>(false);
  Timer? _floatingDateTimer;

  // In-Chat Search Stepper
  List<int> _matchIndices = [];
  int _currentMatchIndex = 0;

  @override
  void initState() {
    super.initState();
    _messagesStream = APIs.getAllMessages(widget.user);
    _userInfoStream = APIs.getUserInfo(widget.user);
    _chatMetaStream = APIs.getChatMeta(widget.user);
    _scrollController = ScrollController();
    _scrollController.addListener(_onChatScroll);
  }

  void _onChatScroll() {
    if (!mounted || !_scrollController.hasClients) return;
    final offset = _scrollController.offset;
    final shouldShow = offset > 240;
    if (shouldShow != _showScrollToBottomNotifier.value) {
      _showScrollToBottomNotifier.value = shouldShow;
      if (!shouldShow) _newMessagesWhileScrolledNotifier.value = 0;
    }

    if (_list.isNotEmpty) {
      final safeOffset =
          offset.clamp(0.0, _scrollController.position.maxScrollExtent);
      final viewportHeight = _scrollController.position.hasViewportDimension
          ? _scrollController.position.viewportDimension
          : 0.0;
      final topOffset = (safeOffset + viewportHeight * 0.7)
          .clamp(0.0, _scrollController.position.maxScrollExtent);
      final approxIndex =
          (topOffset / 72.0).floor().clamp(0, _list.length - 1);
      final header = MyDateUtil.getDateHeader(context, _list[approxIndex].sent);
      if (header != _floatingDateNotifier.value) {
        _floatingDateNotifier.value = header;
      }
      if (!_showFloatingDateNotifier.value) {
        _showFloatingDateNotifier.value = true;
      }
      _floatingDateTimer?.cancel();
      _floatingDateTimer = Timer(const Duration(milliseconds: 1600), () {
        if (mounted) _showFloatingDateNotifier.value = false;
      });
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onChatScroll);
    _scrollController.dispose();
    _showScrollToBottomNotifier.dispose();
    _newMessagesWhileScrolledNotifier.dispose();
    _floatingDateNotifier.dispose();
    _showFloatingDateNotifier.dispose();
    _floatingDateTimer?.cancel();
    _typingTimer?.cancel();
    if (_isTyping) {
      APIs.updateTypingStatus(widget.user, false);
    }
    _textController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onTextChanged(String val) {
    if (val.trim().isNotEmpty) {
      final int now = DateTime.now().millisecondsSinceEpoch;
      // Notify typing immediately, and pulse every 1200ms while active
      if (!_isTyping || (now - _lastTypingSentTime > 1200)) {
        _isTyping = true;
        _lastTypingSentTime = now;
        APIs.updateTypingStatus(widget.user, true);
      }
      _typingTimer?.cancel();
      // Interactive stop-typing detection: 1.4 seconds after stopping typing
      _typingTimer = Timer(const Duration(milliseconds: 1400), () {
        if (_isTyping) {
          _isTyping = false;
          APIs.updateTypingStatus(widget.user, false);
        }
      });
    } else {
      if (_isTyping) {
        _isTyping = false;
        _typingTimer?.cancel();
        APIs.updateTypingStatus(widget.user, false);
      }
    }
  }

  void _goToPreviousMatch() {
    if (_matchIndices.isEmpty) return;
    AppHaptics.selection();
    setState(() {
      _currentMatchIndex =
          (_currentMatchIndex - 1 + _matchIndices.length) % _matchIndices.length;
    });
    _scrollToMatch(_matchIndices[_currentMatchIndex]);
  }

  void _goToNextMatch() {
    if (_matchIndices.isEmpty) return;
    AppHaptics.selection();
    setState(() {
      _currentMatchIndex = (_currentMatchIndex + 1) % _matchIndices.length;
    });
    _scrollToMatch(_matchIndices[_currentMatchIndex]);
  }

  void _scrollToMatch(int itemIndex) {
    if (!_scrollController.hasClients) return;
    final targetOffset =
        (itemIndex * 72.0).clamp(0.0, _scrollController.position.maxScrollExtent);
    _scrollController.animateTo(
      targetOffset,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

  void _updateMatches(List<Message> list) {
    if (!_isSearching || _searchQuery.isEmpty) {
      _matchIndices = [];
      return;
    }
    final matches = <int>[];
    for (int i = 0; i < list.length; i++) {
      if (list[i].type == Type.text &&
          list[i].msg.toLowerCase().contains(_searchQuery)) {
        matches.add(i);
      }
    }
    _matchIndices = matches;
    if (_matchIndices.isNotEmpty && _currentMatchIndex >= _matchIndices.length) {
      _currentMatchIndex = 0;
    }
  }

  Widget _buildScrollToBottomButton() {
    return ValueListenableBuilder<bool>(
      valueListenable: _showScrollToBottomNotifier,
      builder: (context, showBtn, _) {
        return AnimatedPositioned(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          bottom: showBtn ? 16 : -60,
          right: 16,
          child: IgnorePointer(
            ignoring: !showBtn,
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 180),
              opacity: showBtn ? 1.0 : 0.0,
              child: GestureDetector(
                onTap: () {
                  AppHaptics.light();
                  _newMessagesWhileScrolledNotifier.value = 0;
                  _scrollController.animateTo(
                    0,
                    duration: const Duration(milliseconds: 320),
                    curve: Curves.easeOutCubic,
                  );
                },
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: context.surfaceColor,
                        shape: BoxShape.circle,
                        border: Border.all(color: context.borderColor, width: 1),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.16),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: context.textPrimaryColor,
                        size: 26,
                      ),
                    ),
                    ValueListenableBuilder<int>(
                      valueListenable: _newMessagesWhileScrolledNotifier,
                      builder: (context, newCount, _) {
                        if (newCount <= 0) return const SizedBox.shrink();
                        return Positioned(
                          top: -4,
                          right: -4,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppTheme.danger,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                  color: context.surfaceColor, width: 2),
                            ),
                            child: Text(
                              '$newCount',
                              style: const TextStyle(
                                fontFamily: 'Lexend',
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildStickyDateHeader() {
    return ValueListenableBuilder<String?>(
      valueListenable: _floatingDateNotifier,
      builder: (context, dateText, _) {
        if (dateText == null || dateText.isEmpty) {
          return const SizedBox.shrink();
        }

        return ValueListenableBuilder<bool>(
          valueListenable: _showFloatingDateNotifier,
          builder: (context, showDate, _) {
            return AnimatedPositioned(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut,
              top: showDate ? 10 : -45,
              left: 0,
              right: 0,
              child: IgnorePointer(
                ignoring: !showDate,
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 180),
                  opacity: showDate ? 1.0 : 0.0,
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 5),
                      decoration: BoxDecoration(
                        color: context.isDark
                            ? const Color(0xFF1E1E20)
                            : const Color(0xFFE4E4E7),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: context.isDark
                              ? const Color(0xFF2C2C2E)
                              : const Color(0xFFD4D4D8),
                          width: 0.8,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(
                                alpha: context.isDark ? 0.35 : 0.08),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Text(
                        dateText,
                        style: TextStyle(
                          fontFamily: 'Lexend',
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: context.isDark
                              ? const Color(0xFFE4E4E7)
                              : const Color(0xFF18181B),
                          letterSpacing: 0.4,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildSearchStepperBar() {
    if (!_isSearching || _searchQuery.isEmpty) return const SizedBox.shrink();

    final total = _matchIndices.length;
    final current = total > 0 ? _currentMatchIndex + 1 : 0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: context.surfaceColor,
        border:
            Border(bottom: BorderSide(color: context.borderColor, width: 1)),
      ),
      child: Row(
        children: [
          Icon(Icons.search_rounded,
              size: 16, color: context.textSecondaryColor),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              total > 0 ? '$current of $total matches' : 'No matches found',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: 'Lexend',
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: context.textSecondaryColor,
              ),
            ),
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.keyboard_arrow_up_rounded, size: 22),
            splashRadius: 18,
            color: total > 0 ? context.textPrimaryColor : context.textMutedColor,
            onPressed: total > 0 ? _goToPreviousMatch : null,
          ),
          IconButton(
            icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 22),
            splashRadius: 18,
            color: total > 0 ? context.textPrimaryColor : context.textMutedColor,
            onPressed: total > 0 ? _goToNextMatch : null,
          ),
        ],
      ),
    );
  }

  void _stopSearch() {
    FocusScope.of(context).unfocus();
    setState(() {
      _isSearching = false;
      _searchController.clear();
      _searchQuery = '';
      _matchIndices = [];
      _currentMatchIndex = 0;
    });
  }

  Future<void> _sendImageFile(File file) async {
    try {
      setState(() => _isUploading = true);
      final success = await APIs.sendChatImage(widget.user, file);
      if (!success && mounted) {
        Dialogs.showSnackbar(
            context, 'Failed to send image. Storage limit may be reached.');
      }
    } catch (e) {
      log('Error sending image: $e');
      if (mounted) {
        Dialogs.showSnackbar(context, 'Error uploading photo.');
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  void _showUserProfileDialog(ChatUser currentUser) {
    AppHaptics.medium();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.surfaceColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: context.borderColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),

              // Clean Circular Avatar
              GestureDetector(
                onTap: () {
                  if (currentUser.image.isNotEmpty) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => MediaViewerScreen(
                          imageUrl: currentUser.image,
                          title: currentUser.name,
                          timestamp: 'Profile Photo',
                          heroTag: 'chat_user_avatar_${currentUser.id}',
                        ),
                      ),
                    );
                  }
                },
                child: CircleAvatar(
                  radius: 46,
                  backgroundColor: context.surfaceMutedColor,
                  backgroundImage: currentUser.image.isNotEmpty
                      ? CachedNetworkImageProvider(currentUser.image)
                      : null,
                  child: currentUser.image.isEmpty
                      ? Text(
                          currentUser.name.isNotEmpty
                              ? currentUser.name[0].toUpperCase()
                              : '?',
                          style: TextStyle(
                            fontFamily: 'Lexend',
                            fontSize: 32,
                            fontWeight: FontWeight.w700,
                            color: context.textPrimaryColor,
                          ),
                        )
                      : null,
                ),
              ),
              const SizedBox(height: 12),

              Text(
                currentUser.name,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: 'Lexend',
                  fontSize: 19,
                  fontWeight: FontWeight.w700,
                  color: context.textPrimaryColor,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                currentUser.email,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Lexend',
                  fontSize: 13,
                  color: context.textSecondaryColor,
                ),
              ),
              const SizedBox(height: 16),

              // About Box
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: context.surfaceMutedColor,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'About',
                      style: TextStyle(
                        fontFamily: 'Lexend',
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: context.textSecondaryColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      currentUser.about.isNotEmpty
                          ? currentUser.about
                          : "Hey, I'm using Chatty!",
                      style: TextStyle(
                        fontFamily: 'Lexend',
                        fontSize: 14,
                        color: context.textPrimaryColor,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_isSearching,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && _isSearching) {
          _stopSearch();
        }
      },
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: context.systemOverlayStyle,
        child: Scaffold(
          backgroundColor: context.backgroundColor,
          appBar: PreferredSize(
            preferredSize: Size.fromHeight(
              (58.0 * MediaQuery.textScalerOf(context).scale(1.0)).clamp(58.0, 76.0),
            ),
            child: Container(
              decoration: BoxDecoration(
                color: context.surfaceColor,
                border: Border(bottom: BorderSide(color: context.borderColor, width: 1)),
              ),
              child: SafeArea(child: _isSearching ? _searchAppBar() : _appBar()),
            ),
          ),
        body: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: () => FocusScope.of(context).unfocus(),
          child: Column(
            children: [
              _buildSearchStepperBar(),
            Expanded(
              key: const ValueKey('chat_messages_expanded'),
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                key: const ValueKey('chat_messages_stream_builder'),
                stream: _messagesStream,
                builder: (context, snapshot) {
                  if (snapshot.hasData) {
                    final data = snapshot.data?.docs;
                    final prevCount = _lastKnownCount;
                    _list = data
                            ?.map((e) => Message.fromJson(e.data()))
                            .toList() ??
                        [];
                    _updateMatches(_list);

                    if (prevCount > 0 &&
                        _list.length > prevCount &&
                        _showScrollToBottomNotifier.value) {
                      _newMessagesWhileScrolledNotifier.value +=
                          (_list.length - prevCount);
                    }
                    _lastKnownCount = _list.length;
                  }

                  // If messages are already in memory, NEVER drop them to show a skeleton.
                  // Only show skeleton on initial cold load before any data has arrived.
                  if (_list.isEmpty) {
                    if (snapshot.connectionState == ConnectionState.waiting ||
                        snapshot.connectionState == ConnectionState.none) {
                      return const ChatMessagesSkeletonList();
                    }
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 32),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 72,
                              height: 72,
                              decoration: BoxDecoration(
                                color: context.primarySoftColor,
                                borderRadius: BorderRadius.circular(36),
                              ),
                              child: const Center(
                                child: Text('👋',
                                    style: TextStyle(fontSize: 32)),
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Say hello to ${widget.user.name}!',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontFamily: 'Lexend',
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: context.textPrimaryColor,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Send a message or photo to start your conversation.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontFamily: 'Lexend',
                                fontSize: 13,
                                color: context.textSecondaryColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  return Stack(
                    children: [
                      ListView.builder(
                        controller: _scrollController,
                        reverse: true,
                        itemCount: _list.length,
                        padding: const EdgeInsets.only(top: 10, bottom: 6),
                        physics: const BouncingScrollPhysics(
                            parent: AlwaysScrollableScrollPhysics()),
                        keyboardDismissBehavior:
                            ScrollViewKeyboardDismissBehavior.onDrag,
                        itemBuilder: (context, index) {
                          final msg = _list[index];
                          final bool isOldest =
                              index == _list.length - 1;
                          final bool showDateHeader = isOldest ||
                              MyDateUtil.isDifferentDay(
                                  msg.sent,
                                  _list[index + 1].sent);

                          // In reverse list: index + 1 is above (earlier), index - 1 is below (later)
                          final bool isPrevSame = index + 1 < _list.length &&
                              _list[index + 1].fromId == msg.fromId &&
                              !MyDateUtil.isDifferentDay(msg.sent, _list[index + 1].sent);

                          final bool isNextSame = index - 1 >= 0 &&
                              _list[index - 1].fromId == msg.fromId &&
                              !MyDateUtil.isDifferentDay(msg.sent, _list[index - 1].sent);

                          return Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (showDateHeader)
                                _buildDateHeader(msg.sent),
                              MessageCard(
                                message: msg,
                                highlightQuery:
                                    _isSearching ? _searchQuery : null,
                                isPrevSame: isPrevSame,
                                isNextSame: isNextSame,
                                onSwipeReply: (m) {
                                  setState(() => _replyMessage = m);
                                },
                              ),
                            ],
                          );
                        },
                      ),
                      _buildStickyDateHeader(),
                      _buildScrollToBottomButton(),
                    ],
                  );
                },
              ),
            ),

            // Uploading photo indicator
            if (_isUploading)
              Align(
                alignment: Alignment.centerRight,
                child: Container(
                  margin: const EdgeInsets.only(right: 16, bottom: 8),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: context.surfaceColor,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: context.borderColor),
                    boxShadow: context.softShadow,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                              context.isDark ? Colors.white : Colors.black),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Uploading photo...',
                        style: TextStyle(
                          fontFamily: 'Lexend',
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: context.textSecondaryColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            Offstage(
              offstage: _isSearching,
              child: ChatVoiceInputBar(
                key: const ValueKey('chat_voice_input_bar'),
                user: widget.user,
                textController: _textController,
                replyMessage: _replyMessage,
                onClearReply: () => setState(() => _replyMessage = null),
                onSendText: (text, replyMsg, replyUser) {
                  APIs.sendMessage(
                    widget.user,
                    text,
                    Type.text,
                    replyMsg: replyMsg,
                    replyUser: replyUser,
                  );
                  if (_scrollController.hasClients && _scrollController.offset > 0) {
                    _scrollController.animateTo(
                      0,
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeOutCubic,
                    );
                  }
                  if (_isTyping) {
                    _isTyping = false;
                    _typingTimer?.cancel();
                    APIs.updateTypingStatus(widget.user, false);
                  }
                },
                onSendVoice: (audioFile, durationMs) async {
                  if (_scrollController.hasClients && _scrollController.offset > 0) {
                    _scrollController.animateTo(
                      0,
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeOutCubic,
                    );
                  }
                  final success = await APIs.sendVoiceNote(
                      widget.user, audioFile, durationMs);
                  if (!success && context.mounted) {
                    Dialogs.showSnackbar(context, 'Failed to send voice note');
                  }
                },
                onSendImage: (file) {
                  if (_scrollController.hasClients && _scrollController.offset > 0) {
                    _scrollController.animateTo(
                      0,
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeOutCubic,
                    );
                  }
                  _sendImageFile(file);
                },
                onTextChanged: _onTextChanged,
              ),
            ),
          ],
        ),
      ),
    ),
  ),
);
}

  // Crisp Solid Date Separator Header (Zero blur distortion on iOS Impeller)
  Widget _buildDateHeader(String timeMillis) {
    final label = MyDateUtil.getChatDateHeader(timeMillis);
    if (label.isEmpty) return const SizedBox.shrink();

    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
        decoration: BoxDecoration(
          color: context.isDark
              ? const Color(0xFF1E1E20)
              : const Color(0xFFE4E4E7),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: context.isDark
                ? const Color(0xFF2C2C2E)
                : const Color(0xFFD4D4D8),
            width: 0.8,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: context.isDark ? 0.3 : 0.06),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: 'Lexend',
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.4,
            color: context.isDark
                ? const Color(0xFFE4E4E7)
                : const Color(0xFF18181B),
          ),
        ),
      ),
    );
  }

  // App Bar
  Widget _appBar() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _userInfoStream,
      builder: (context, snapshot) {
        final data = snapshot.data?.docs;
        final list =
            data?.map((e) => ChatUser.fromJson(e.data())).toList() ?? [];
        final currentUser = list.isNotEmpty ? list[0] : widget.user;

        return Row(
          children: [
            IconButton(
              splashRadius: 22,
              onPressed: () => Navigator.pop(context),
              icon: Icon(
                Icons.arrow_back_rounded,
                color: context.textPrimaryColor,
              ),
            ),
            Expanded(
              child: InkWell(
                onTap: () => _showUserProfileDialog(currentUser),
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                  child: Row(
                    children: [
                      // Avatar with online dot
                      AppAvatar(
                        imageUrl: currentUser.image,
                        name: currentUser.name,
                        size: 40,
                        isOnline: currentUser.isOnline,
                      ),
                      AppSpacing.gapW12,

                      // Name & Status
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              currentUser.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontFamily: 'Lexend',
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: context.textPrimaryColor,
                              ),
                            ),
                            const SizedBox(height: 2),
                            StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                              stream: _chatMetaStream,
                              builder: (context, metaSnapshot) {
                                final metaData = metaSnapshot.data?.data();
                                final bool isTypingRaw =
                                    metaData?['typing_${widget.user.id}'] ==
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
                                final bool isOtherTyping = isTypingRaw &&
                                    (lastTypingTime == 0 ||
                                        (now - lastTypingTime < 2400));

                                return AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 180),
                                  child: isOtherTyping
                                      ? const TypingWaveDots(
                                          key: ValueKey('typing'),
                                          dotSize: 3.5,
                                          label: 'typing',
                                          showLabel: true,
                                        )
                                      : Text(
                                          currentUser.isOnline
                                              ? 'Active now'
                                              : MyDateUtil.getLastActiveTime(
                                                  context: context,
                                                  lastActive:
                                                      currentUser.lastActive),
                                          key: const ValueKey('status'),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontFamily: 'Lexend',
                                            fontSize: 11,
                                            fontWeight: FontWeight.w500,
                                            color: currentUser.isOnline
                                                ? AppTheme.success
                                                : (context.isDark
                                                    ? const Color(0xFFA1A1AA)
                                                    : const Color(0xFF71717A)),
                                          ),
                                        ),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            IconButton(
              splashRadius: 22,
              tooltip: 'Search messages',
              onPressed: () => setState(() => _isSearching = true),
              icon: Icon(
                Icons.search_rounded,
                color: context.textPrimaryColor,
              ),
            ),
            PopupMenuButton<String>(
              icon: Icon(
                Icons.more_vert_rounded,
                color: context.textPrimaryColor,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: context.borderColor, width: 1),
              ),
              color: context.surfaceColor,
              elevation: 4,
              onSelected: (val) {
                if (val == 'info') {
                  _showUserProfileDialog(currentUser);
                }
              },
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'info',
                  child: Row(
                    children: [
                      Icon(Icons.info_outline_rounded,
                          size: 20, color: context.textPrimaryColor),
                      const SizedBox(width: 12),
                      Text(
                        'Contact Info',
                        style: TextStyle(
                          fontFamily: 'Lexend',
                          color: context.textPrimaryColor,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  // Dedicated In-Chat Search Bar
  Widget _searchAppBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Row(
        children: [
          IconButton(
            splashRadius: 22,
            tooltip: 'Close search',
            onPressed: _stopSearch,
            icon: Icon(
              Icons.arrow_back_rounded,
              color: context.textPrimaryColor,
            ),
          ),
          Expanded(
            child: Container(
              height: 40,
              decoration: BoxDecoration(
                color: context.surfaceMutedColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: TextField(
                controller: _searchController,
                autofocus: true,
                maxLines: 1,
                textAlignVertical: TextAlignVertical.center,
                style: TextStyle(
                  fontFamily: 'Lexend',
                  fontSize: 14,
                  color: context.textPrimaryColor,
                ),
                decoration: InputDecoration(
                  isDense: true,
                  hintText: 'Search in conversation...',
                  hintStyle: TextStyle(
                    fontFamily: 'Lexend',
                    fontSize: 13,
                    color: context.textMutedColor,
                    overflow: TextOverflow.ellipsis,
                  ),
                  prefixIconConstraints:
                      const BoxConstraints(minWidth: 38, minHeight: 40),
                  prefixIcon: Icon(
                    Icons.search_rounded,
                    color: context.textSecondaryColor,
                    size: 20,
                  ),
                  suffixIconConstraints:
                      const BoxConstraints(minWidth: 38, minHeight: 40),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          splashRadius: 16,
                          padding: EdgeInsets.zero,
                          icon: Icon(Icons.clear_rounded,
                              color: context.textMutedColor, size: 18),
                          onPressed: () {
                            _searchController.clear();
                            setState(() {
                              _searchQuery = '';
                              _matchIndices = [];
                              _currentMatchIndex = 0;
                            });
                          },
                        )
                      : null,
                  border: InputBorder.none,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                ),
                onChanged: (val) {
                  setState(() {
                    _searchQuery = val.trim().toLowerCase();
                    _updateMatches(_list);
                  });
                  if (_matchIndices.isNotEmpty) {
                    _scrollToMatch(_matchIndices.first);
                  }
                },
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
    );
  }
}
