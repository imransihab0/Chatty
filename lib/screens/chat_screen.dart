import 'dart:async';
import 'dart:developer';
import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../api/apis.dart';
import '../helper/app_haptics.dart';
import '../helper/app_theme.dart';
import '../helper/dialogs.dart';
import '../helper/my_date_util.dart';
import '../models/chat_user.dart';
import '../models/message.dart';
import '../widgets/chat_wallpaper.dart';
import '../widgets/message_card.dart';

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
  bool _isUploading = false;
  bool _isSearching = false;
  String _searchQuery = '';
  Message? _replyMessage;
  Timer? _typingTimer;
  bool _isTyping = false;

  @override
  void dispose() {
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
      if (!_isTyping) {
        _isTyping = true;
        APIs.updateTypingStatus(widget.user, true);
      }
      _typingTimer?.cancel();
      _typingTimer = Timer(const Duration(seconds: 3), () {
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

  void _stopSearch() {
    setState(() {
      _isSearching = false;
      _searchController.clear();
      _searchQuery = '';
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
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: context.surfaceColor,
        contentPadding: const EdgeInsets.all(20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(50),
              child: CachedNetworkImage(
                width: 100,
                height: 100,
                fit: BoxFit.cover,
                imageUrl: currentUser.image,
                errorWidget: (context, url, error) => CircleAvatar(
                  radius: 50,
                  backgroundColor: context.primarySoftColor,
                  child: Text(
                    currentUser.name.isNotEmpty
                        ? currentUser.name[0].toUpperCase()
                        : '?',
                    style: const TextStyle(
                      fontFamily: 'Lexend',
                      fontSize: 36,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.primary,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              currentUser.name,
              style: TextStyle(
                fontFamily: 'Lexend',
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: context.textPrimaryColor,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              currentUser.email,
              style: TextStyle(
                fontFamily: 'Lexend',
                fontSize: 13,
                color: context.textSecondaryColor,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: context.surfaceMutedColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                currentUser.about.isNotEmpty
                    ? currentUser.about
                    : "Hey, I'm using Chatty!",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Lexend',
                  fontSize: 13,
                  color: context.textPrimaryColor,
                ),
              ),
            ),
          ],
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
      child: Scaffold(
        backgroundColor: context.backgroundColor,
        appBar: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Container(
            decoration: BoxDecoration(
              color: context.surfaceColor,
              border: Border(bottom: BorderSide(color: context.borderColor, width: 1)),
            ),
            child: SafeArea(child: _isSearching ? _searchAppBar() : _appBar()),
          ),
        ),
        body: ChatWallpaper(
          child: Column(
            children: [
            Expanded(
              child: StreamBuilder(
                stream: APIs.getAllMessages(widget.user),
                builder: (context, snapshot) {
                  switch (snapshot.connectionState) {
                    case ConnectionState.waiting:
                    case ConnectionState.none:
                      return const Center(
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(AppTheme.primary),
                        ),
                      );

                    case ConnectionState.active:
                    case ConnectionState.done:
                      final data = snapshot.data?.docs;
                      _list = data
                              ?.map((e) => Message.fromJson(e.data()))
                              .toList() ??
                          [];

                      final List<Message> displayedList = _searchQuery.isEmpty
                          ? _list
                          : _list
                              .where((m) =>
                                  m.type == Type.text &&
                                  m.msg.toLowerCase().contains(_searchQuery))
                              .toList();

                      if (_isSearching &&
                          _searchQuery.isNotEmpty &&
                          displayedList.isEmpty) {
                        return Center(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 32),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 68,
                                  height: 68,
                                  decoration: BoxDecoration(
                                    color: context.primarySoftColor,
                                    borderRadius: BorderRadius.circular(34),
                                  ),
                                  child: const Icon(
                                    Icons.search_off_rounded,
                                    color: AppTheme.primary,
                                    size: 32,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'No messages found',
                                  style: TextStyle(
                                    fontFamily: 'Lexend',
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                    color: context.textPrimaryColor,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'No messages matching "$_searchQuery" were found in this chat.',
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

                      if (displayedList.isNotEmpty) {
                        return Column(
                          children: [
                            if (_isSearching && _searchQuery.isNotEmpty)
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(
                                    vertical: 7, horizontal: 16),
                                color: context.surfaceMutedColor,
                                child: Row(
                                  children: [
                                    Icon(Icons.search_rounded,
                                        size: 16,
                                        color: context.textSecondaryColor),
                                    const SizedBox(width: 8),
                                    Text(
                                      '${displayedList.length} ${displayedList.length == 1 ? 'match' : 'matches'} found',
                                      style: TextStyle(
                                        fontFamily: 'Lexend',
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: context.textSecondaryColor,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            Expanded(
                              child: ListView.builder(
                                reverse: true,
                                itemCount: displayedList.length,
                                padding: const EdgeInsets.only(top: 10, bottom: 6),
                                physics: const BouncingScrollPhysics(),
                                itemBuilder: (context, index) {
                                  return MessageCard(
                                    message: displayedList[index],
                                    highlightQuery:
                                        _isSearching ? _searchQuery : null,
                                    onSwipeReply: (msg) {
                                      setState(() => _replyMessage = msg);
                                    },
                                  );
                                },
                              ),
                            ),
                          ],
                        );
                      } else {
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
                  }
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
                      const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(AppTheme.primary),
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

            if (_replyMessage != null && !_isSearching) _replyBanner(),
            if (!_isSearching) _chatInput(),
          ],
        ),
      ),
    ),
  );
  }

  // App Bar
  Widget _appBar() {
    return StreamBuilder(
      stream: APIs.getUserInfo(widget.user),
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
                      Stack(
                        clipBehavior: Clip.none,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(20),
                            child: CachedNetworkImage(
                              width: 40,
                              height: 40,
                              fit: BoxFit.cover,
                              imageUrl: currentUser.image,
                              errorWidget: (context, url, error) =>
                                  CircleAvatar(
                                radius: 20,
                                backgroundColor: context.primarySoftColor,
                                child: Text(
                                  currentUser.name.isNotEmpty
                                      ? currentUser.name[0].toUpperCase()
                                      : '?',
                                  style: const TextStyle(
                                    fontFamily: 'Lexend',
                                    fontWeight: FontWeight.w700,
                                    color: AppTheme.primary,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          if (currentUser.isOnline)
                            Positioned(
                              right: 0,
                              bottom: 0,
                              child: Container(
                                width: 11,
                                height: 11,
                                decoration: BoxDecoration(
                                  color: AppTheme.success,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                      color: context.surfaceColor, width: 2),
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(width: 12),

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
                            StreamBuilder(
                              stream: APIs.getChatMeta(widget.user),
                              builder: (context, metaSnapshot) {
                                final metaData = metaSnapshot.data?.data();
                                final bool isOtherTyping =
                                    metaData?['typing_${widget.user.id}'] ==
                                        true;

                                if (isOtherTyping) {
                                  return const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        'typing...',
                                        style: TextStyle(
                                          fontFamily: 'Lexend',
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                          color: AppTheme.success,
                                        ),
                                      ),
                                      SizedBox(width: 4),
                                      SizedBox(
                                        width: 8,
                                        height: 8,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 1.5,
                                          valueColor:
                                              AlwaysStoppedAnimation<
                                                  Color>(AppTheme.success),
                                        ),
                                      ),
                                    ],
                                  );
                                }

                                return Text(
                                  currentUser.isOnline
                                      ? 'Active now'
                                      : MyDateUtil.getLastActiveTime(
                                          context: context,
                                          lastActive: currentUser.lastActive),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontFamily: 'Lexend',
                                    fontSize: 11,
                                    fontWeight: currentUser.isOnline
                                        ? FontWeight.w600
                                        : FontWeight.w400,
                                    color: currentUser.isOnline
                                        ? AppTheme.success
                                        : context.textMutedColor,
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
                color: context.textSecondaryColor,
              ),
            ),
            IconButton(
              splashRadius: 22,
              onPressed: () => _showUserProfileDialog(currentUser),
              icon: Icon(
                Icons.info_outline_rounded,
                color: context.textSecondaryColor,
              ),
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
                style: TextStyle(
                  fontFamily: 'Lexend',
                  fontSize: 14,
                  color: context.textPrimaryColor,
                ),
                decoration: InputDecoration(
                  hintText: 'Search in conversation...',
                  hintStyle: TextStyle(
                    fontFamily: 'Lexend',
                    fontSize: 13,
                    color: context.textMutedColor,
                  ),
                  prefixIcon: Icon(
                    Icons.search_rounded,
                    color: context.textSecondaryColor,
                    size: 20,
                  ),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          splashRadius: 16,
                          icon: Icon(Icons.clear_rounded,
                              color: context.textMutedColor, size: 18),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                          },
                        )
                      : null,
                  border: InputBorder.none,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                  isDense: true,
                ),
                onChanged: (val) {
                  setState(() => _searchQuery = val.trim().toLowerCase());
                },
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
    );
  }

  // Docked Reply Preview Banner above input
  Widget _replyBanner() {
    if (_replyMessage == null) return const SizedBox.shrink();

    final bool isMe = _replyMessage!.fromId == APIs.user.uid;
    final String senderName = isMe ? 'You' : widget.user.name;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        border: Border.all(color: context.borderColor),
        boxShadow: context.softShadow,
      ),
      child: Row(
        children: [
          Container(
            width: 3.5,
            height: 36,
            decoration: BoxDecoration(
              color: AppTheme.primary,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    const Icon(Icons.reply_rounded,
                        size: 14, color: AppTheme.primary),
                    const SizedBox(width: 4),
                    Text(
                      'Replying to $senderName',
                      style: const TextStyle(
                        fontFamily: 'Lexend',
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.primary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  _replyMessage!.type == Type.text
                      ? _replyMessage!.msg
                      : '📷 Photo',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'Lexend',
                    fontSize: 12,
                    color: context.textSecondaryColor,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            splashRadius: 16,
            onPressed: () => setState(() => _replyMessage = null),
            icon: Icon(Icons.close_rounded,
                size: 18, color: context.textMutedColor),
          ),
        ],
      ),
    );
  }

  // Modern Floating Input Bar
  Widget _chatInput() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 6, 14, 14),
      child: Row(
        children: [
          // Input pill container
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: context.surfaceColor,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: context.borderColor, width: 1),
                boxShadow: context.softShadow,
              ),
              child: Row(
                children: [
                  IconButton(
                    splashRadius: 20,
                    onPressed: () async {
                      AppHaptics.selection();
                      final ImagePicker picker = ImagePicker();
                      final List<XFile> images =
                          await picker.pickMultiImage(imageQuality: 30);
                      for (var i in images) {
                        await _sendImageFile(File(i.path));
                      }
                    },
                    icon: Icon(
                      Icons.photo_library_outlined,
                      color: context.textSecondaryColor,
                      size: 22,
                    ),
                  ),
                  IconButton(
                    splashRadius: 20,
                    onPressed: () async {
                      AppHaptics.selection();
                      final ImagePicker picker = ImagePicker();
                      final XFile? image = await picker.pickImage(
                          source: ImageSource.camera, imageQuality: 30);
                      if (image != null) {
                        await _sendImageFile(File(image.path));
                      }
                    },
                    icon: Icon(
                      Icons.camera_alt_outlined,
                      color: context.textSecondaryColor,
                      size: 22,
                    ),
                  ),
                  Expanded(
                    child: TextField(
                      controller: _textController,
                      onChanged: _onTextChanged,
                      keyboardType: TextInputType.multiline,
                      maxLines: null,
                      style: TextStyle(
                        fontFamily: 'Lexend',
                        fontSize: 14,
                        color: context.textPrimaryColor,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Message...',
                        hintStyle: TextStyle(
                          fontFamily: 'Lexend',
                          fontSize: 14,
                          color: context.textMutedColor,
                        ),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 4, vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
              ),
            ),
          ),
          const SizedBox(width: 10),

          // Dynamic Send / Mic Voice Action Button
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: _textController,
            builder: (context, value, _) {
              final bool hasText = value.text.trim().isNotEmpty;

              return GestureDetector(
                onTap: () {
                  final text = _textController.text.trim();
                  if (hasText) {
                    AppHaptics.light();
                    final replyMsg = _replyMessage != null
                        ? (_replyMessage!.type == Type.text
                            ? _replyMessage!.msg
                            : '📷 Photo')
                        : '';
                    final replyUser = _replyMessage != null
                        ? (_replyMessage!.fromId == APIs.user.uid
                            ? 'You'
                            : widget.user.name)
                        : '';

                    APIs.sendMessage(
                      widget.user,
                      text,
                      Type.text,
                      replyMsg: replyMsg,
                      replyUser: replyUser,
                    );

                    if (_isTyping) {
                      _isTyping = false;
                      _typingTimer?.cancel();
                      APIs.updateTypingStatus(widget.user, false);
                    }

                    _textController.clear();
                    setState(() => _replyMessage = null);
                  } else {
                    // Send voice audio note
                    AppHaptics.medium();
                    APIs.sendMessage(
                      widget.user,
                      'https://chatty.audio/note_${DateTime.now().millisecondsSinceEpoch}.m4a',
                      Type.audio,
                    );
                    Dialogs.showSnackbar(context, 'Voice note sent!');
                  }
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppTheme.primary,
                    shape: BoxShape.circle,
                    boxShadow: AppTheme.buttonShadow,
                  ),
                  child: Center(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      transitionBuilder: (child, anim) =>
                          ScaleTransition(scale: anim, child: child),
                      child: Icon(
                        hasText ? Icons.arrow_upward_rounded : Icons.mic_rounded,
                        key: ValueKey(hasText ? 'send' : 'mic'),
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
