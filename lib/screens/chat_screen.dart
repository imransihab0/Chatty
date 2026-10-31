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
import '../services/voice_recorder_service.dart';
import '../widgets/chat_wallpaper.dart';
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

class _ChatScreenState extends State<ChatScreen>
    with TickerProviderStateMixin {
  List<Message> _list = [];
  final _textController = TextEditingController();
  final _searchController = TextEditingController();
  bool _isUploading = false;
  bool _isSearching = false;
  String _searchQuery = '';
  Message? _replyMessage;
  Timer? _typingTimer;
  bool _isTyping = false;

  // ── Voice note recording states ──
  bool _isRecording = false;
  bool _isRecordingLocked = false; // swipe-up lock mode
  bool _isSendingVoice = false;
  int _recordSeconds = 0;
  Timer? _recordTimer;
  double _dragOffsetX = 0.0; // horizontal slide-to-cancel
  double _dragOffsetY = 0.0; // vertical swipe-up-to-lock
  bool _cancelThresholdCrossed = false;
  List<double> _liveAmplitudes = []; // rolling waveform amplitudes
  StreamSubscription<double>? _amplitudeSub;
  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;
  late final AnimationController _trashScaleController;
  late final Animation<double> _trashScaleAnimation;

  final VoiceRecorderService _voiceRecorder = VoiceRecorderService.instance;

  @override
  void initState() {
    super.initState();

    // Pulsing red dot animation
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _pulseAnimation = Tween<double>(begin: 0.35, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Trash icon scale-up animation
    _trashScaleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _trashScaleAnimation = Tween<double>(begin: 1.0, end: 1.4).animate(
      CurvedAnimation(
          parent: _trashScaleController, curve: Curves.elasticOut),
    );
  }

  @override
  void dispose() {
    _typingTimer?.cancel();
    _recordTimer?.cancel();
    _amplitudeSub?.cancel();
    _pulseController.dispose();
    _trashScaleController.dispose();
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
    AppHaptics.medium();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.surfaceColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Padding(
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
                      return const ChatMessagesSkeletonList();

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
                                  child: Icon(
                                    Icons.search_off_rounded,
                                    color: context.textPrimaryColor,
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
                                  final msg = displayedList[index];
                                  final bool isOldest =
                                      index == displayedList.length - 1;
                                  final bool showDateHeader = isOldest ||
                                      MyDateUtil.isDifferentDay(
                                          msg.sent,
                                          displayedList[index + 1].sent);

                                  return Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      if (showDateHeader)
                                        _buildDateHeader(msg.sent),
                                      MessageCard(
                                        message: msg,
                                        highlightQuery:
                                            _isSearching ? _searchQuery : null,
                                        onSwipeReply: (m) {
                                          setState(() => _replyMessage = m);
                                        },
                                      ),
                                    ],
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

            if (_replyMessage != null && !_isSearching) _replyBanner(),
            if (!_isSearching) _chatInput(),
          ],
        ),
      ),
    ),
  );
  }

  // Chat timeline date pill divider
  Widget _buildDateHeader(String timeMillis) {
    final label = MyDateUtil.getChatDateHeader(timeMillis);
    if (label.isEmpty) return const SizedBox.shrink();

    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
        decoration: BoxDecoration(
          color: context.isDark
              ? const Color(0xFF1E1E1E)
              : const Color(0xFFEEEEF0),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: context.borderColor,
            width: 0.8,
          ),
          boxShadow: context.softShadow,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: 'Lexend',
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.4,
            color: context.textSecondaryColor,
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
                                  style: TextStyle(
                                    fontFamily: 'Lexend',
                                    fontWeight: FontWeight.w700,
                                    color: context.textPrimaryColor,
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
                                  return const TypingWaveDots(
                                    dotSize: 3.5,
                                    label: 'typing...',
                                    showLabel: true,
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
              color: context.isDark ? Colors.white : Colors.black,
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
                    Icon(Icons.reply_rounded,
                        size: 14,
                        color: context.isDark ? Colors.white : Colors.black),
                    const SizedBox(width: 4),
                    Text(
                      'Replying to $senderName',
                      style: TextStyle(
                        fontFamily: 'Lexend',
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: context.isDark ? Colors.white : Colors.black,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  _replyMessage!.type == Type.text
                      ? _replyMessage!.msg
                      : _replyMessage!.type == Type.audio
                          ? '🎙️ Voice note'
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

  // ── Voice Recording: Start ──
  Future<void> _startRecording() async {
    final started = await _voiceRecorder.startRecording();
    if (!started) {
      if (mounted) {
        Dialogs.showSnackbar(context, 'Microphone permission required');
      }
      return;
    }

    AppHaptics.medium();
    _pulseController.repeat(reverse: true);

    // Subscribe to live amplitude for waveform
    _amplitudeSub?.cancel();
    _liveAmplitudes = [];
    _amplitudeSub = _voiceRecorder.amplitudeStream.listen((amp) {
      if (mounted) {
        setState(() {
          _liveAmplitudes.add(amp);
          // Keep only the last 40 samples for the visible strip
          if (_liveAmplitudes.length > 40) {
            _liveAmplitudes.removeAt(0);
          }
        });
      }
    });

    setState(() {
      _isRecording = true;
      _isRecordingLocked = false;
      _recordSeconds = 0;
      _dragOffsetX = 0.0;
      _dragOffsetY = 0.0;
      _cancelThresholdCrossed = false;
    });

    _recordTimer = Timer.periodic(
      const Duration(seconds: 1),
      (t) {
        if (mounted) setState(() => _recordSeconds++);
      },
    );
  }

  // ── Voice Recording: Stop & Send ──
  Future<void> _stopAndSendRecording() async {
    _recordTimer?.cancel();
    _amplitudeSub?.cancel();
    _pulseController.stop();
    _pulseController.reset();

    if (_recordSeconds < 1) {
      await _voiceRecorder.cancelRecording();
      setState(() {
        _isRecording = false;
        _isRecordingLocked = false;
      });
      if (mounted) {
        Dialogs.showSnackbar(context, 'Hold longer to record voice note');
      }
      return;
    }

    setState(() {
      _isSendingVoice = true;
    });

    final result = await _voiceRecorder.stopRecording();
    final durationMs = _recordSeconds * 1000;

    setState(() {
      _isRecording = false;
      _isRecordingLocked = false;
    });

    if (result != null) {
      AppHaptics.medium();
      final file = File(result.path);
      final success =
          await APIs.sendVoiceNote(widget.user, file, durationMs);
      if (!success && mounted) {
        Dialogs.showSnackbar(context, 'Failed to send voice note');
      }
    }

    if (mounted) {
      setState(() => _isSendingVoice = false);
    }
  }

  // ── Voice Recording: Cancel ──
  Future<void> _cancelRecording() async {
    _recordTimer?.cancel();
    _amplitudeSub?.cancel();
    _pulseController.stop();
    _pulseController.reset();
    _trashScaleController.reset();

    await _voiceRecorder.cancelRecording();

    AppHaptics.light();
    setState(() {
      _isRecording = false;
      _isRecordingLocked = false;
      _cancelThresholdCrossed = false;
    });

    if (mounted) {
      Dialogs.showSnackbar(context, 'Recording cancelled');
    }
  }

  // ── Recording HUD: Live waveform with pulsing dot ──
  Widget _buildRecordingHUD() {
    final int minutes = _recordSeconds ~/ 60;
    final int seconds = _recordSeconds % 60;
    final String timeStr = '$minutes:${seconds.toString().padLeft(2, '0')}';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          // Pulsing red dot
          FadeTransition(
            opacity: _pulseAnimation,
            child: Container(
              width: 10,
              height: 10,
              decoration: const BoxDecoration(
                color: Colors.red,
                shape: BoxShape.circle,
              ),
            ),
          ),
          const SizedBox(width: 10),

          // Timer
          Text(
            timeStr,
            style: TextStyle(
              fontFamily: 'Lexend',
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: context.textPrimaryColor,
            ),
          ),
          const SizedBox(width: 12),

          // Live waveform strip
          Expanded(
            child: SizedBox(
              height: 26,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final width = constraints.maxWidth;
                  const barWidth = 2.6;
                  final maxBars = (width / (barWidth + 2)).floor();
                  final visibleAmps = _liveAmplitudes.length > maxBars
                      ? _liveAmplitudes.sublist(
                          _liveAmplitudes.length - maxBars)
                      : _liveAmplitudes;

                  return Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: List.generate(
                      visibleAmps.length,
                      (i) {
                        final h = 3.0 + visibleAmps[i] * 21.0;
                        return Padding(
                          padding: const EdgeInsets.only(left: 1.8),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 60),
                            curve: Curves.easeOut,
                            width: barWidth,
                            height: h,
                            decoration: BoxDecoration(
                              color: context.textPrimaryColor
                                  .withValues(alpha: 0.5),
                              borderRadius: BorderRadius.circular(1.5),
                            ),
                          ),
                        );
                      },
                    ),
                  );
                },
              ),
            ),
          ),

          // Slide-to-cancel hint (only in non-locked mode)
          if (!_isRecordingLocked) ...[
            const SizedBox(width: 10),
            Transform.translate(
              offset: Offset(_dragOffsetX * 0.3, 0),
              child: Opacity(
                opacity: (1.0 + _dragOffsetX / 120).clamp(0.3, 1.0),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _cancelThresholdCrossed
                          ? Icons.delete_rounded
                          : Icons.chevron_left_rounded,
                      size: 16,
                      color: _cancelThresholdCrossed
                          ? AppTheme.danger
                          : context.textMutedColor,
                    ),
                    const SizedBox(width: 2),
                    Text(
                      _cancelThresholdCrossed
                          ? 'Release to cancel'
                          : 'Slide to cancel',
                      style: TextStyle(
                        fontFamily: 'Lexend',
                        fontSize: 11,
                        fontWeight: _cancelThresholdCrossed
                            ? FontWeight.w700
                            : FontWeight.w400,
                        color: _cancelThresholdCrossed
                            ? AppTheme.danger
                            : context.textMutedColor,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── Locked Recording HUD: Stop + Send buttons ──
  Widget _buildLockedRecordingHUD() {
    final int minutes = _recordSeconds ~/ 60;
    final int seconds = _recordSeconds % 60;
    final String timeStr = '$minutes:${seconds.toString().padLeft(2, '0')}';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          // Pulsing red dot
          FadeTransition(
            opacity: _pulseAnimation,
            child: Container(
              width: 10,
              height: 10,
              decoration: const BoxDecoration(
                color: Colors.red,
                shape: BoxShape.circle,
              ),
            ),
          ),
          const SizedBox(width: 10),

          // Timer
          Text(
            timeStr,
            style: TextStyle(
              fontFamily: 'Lexend',
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: context.textPrimaryColor,
            ),
          ),
          const SizedBox(width: 12),

          // Live waveform strip (smaller in locked mode)
          Expanded(
            child: SizedBox(
              height: 26,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final width = constraints.maxWidth;
                  const barWidth = 2.6;
                  final maxBars = (width / (barWidth + 2)).floor();
                  final visibleAmps = _liveAmplitudes.length > maxBars
                      ? _liveAmplitudes.sublist(
                          _liveAmplitudes.length - maxBars)
                      : _liveAmplitudes;

                  return Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: List.generate(
                      visibleAmps.length,
                      (i) {
                        final h = 3.0 + visibleAmps[i] * 21.0;
                        return Padding(
                          padding: const EdgeInsets.only(left: 1.8),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 60),
                            curve: Curves.easeOut,
                            width: barWidth,
                            height: h,
                            decoration: BoxDecoration(
                              color: context.textPrimaryColor
                                  .withValues(alpha: 0.5),
                              borderRadius: BorderRadius.circular(1.5),
                            ),
                          ),
                        );
                      },
                    ),
                  );
                },
              ),
            ),
          ),
          const SizedBox(width: 10),

          // Cancel (trash) button
          GestureDetector(
            onTap: _cancelRecording,
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppTheme.danger.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.delete_outline_rounded,
                color: AppTheme.danger,
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Standard Text Input Row
  Widget _buildTextInputRow() {
    return Row(
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
            final XFile? image =
                await picker.pickImage(source: ImageSource.camera, imageQuality: 30);
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
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
            ),
          ),
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  void _sendTextMessage() {
    final text = _textController.text.trim();
    if (text.isEmpty) return;

    AppHaptics.light();
    final replyMsg = _replyMessage != null
        ? (_replyMessage!.type == Type.text
            ? _replyMessage!.msg
            : _replyMessage!.type == Type.audio
                ? '🎙️ Voice note'
                : '📷 Photo')
        : '';
    final replyUser = _replyMessage != null
        ? (_replyMessage!.fromId == APIs.user.uid ? 'You' : widget.user.name)
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
  }

  // Modern Floating Input Bar with Telegram-Style Voice Notes
  Widget _chatInput() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 6, 14, 14),
      child: Row(
        children: [
          // Input pill container OR Recording Voice HUD
          Expanded(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutCubic,
              decoration: BoxDecoration(
                color: _isRecording
                    ? (context.isDark
                        ? const Color(0xFF1E1E1E)
                        : const Color(0xFFF4F4F5))
                    : context.surfaceColor,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: _isRecording
                      ? (_cancelThresholdCrossed
                          ? AppTheme.danger
                          : context.textPrimaryColor.withValues(alpha: 0.3))
                      : context.borderColor,
                  width: _isRecording ? 1.5 : 1,
                ),
                boxShadow: context.softShadow,
              ),
              child: _isRecording
                  ? (_isRecordingLocked
                      ? _buildLockedRecordingHUD()
                      : _buildRecordingHUD())
                  : _buildTextInputRow(),
            ),
          ),
          const SizedBox(width: 10),

          // ── Dynamic Send / Mic / Lock / Stop Button ──
          _buildActionButton(),
        ],
      ),
    );
  }

  Widget _buildActionButton() {
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: _textController,
      builder: (context, value, _) {
        final bool hasText = value.text.trim().isNotEmpty;

        // ── Locked mode: show Send button ──
        if (_isRecordingLocked) {
          return GestureDetector(
            onTap: _isSendingVoice ? null : _stopAndSendRecording,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: _isSendingVoice
                    ? context.surfaceMutedColor
                    : (context.isDark ? Colors.white : Colors.black),
                shape: BoxShape.circle,
                boxShadow: context.isDark ? null : AppTheme.buttonShadow,
              ),
              child: Center(
                child: _isSendingVoice
                    ? SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                              context.textPrimaryColor),
                        ),
                      )
                    : Icon(
                        Icons.arrow_upward_rounded,
                        color:
                            context.isDark ? Colors.black : Colors.white,
                        size: 24,
                      ),
              ),
            ),
          );
        }

        // ── Recording (not locked): hold-to-record mic button ──
        if (_isRecording) {
          return GestureDetector(
            onLongPressMoveUpdate: (details) {
              final dx =
                  details.offsetFromOrigin.dx.clamp(-160.0, 0.0);
              final dy =
                  details.offsetFromOrigin.dy.clamp(-120.0, 0.0);

              final wasCrossed = _cancelThresholdCrossed;
              final nowCrossed = dx < -80;

              if (nowCrossed && !wasCrossed) {
                AppHaptics.heavy();
                _trashScaleController.forward();
              } else if (!nowCrossed && wasCrossed) {
                _trashScaleController.reverse();
              }

              setState(() {
                _dragOffsetX = dx;
                _dragOffsetY = dy;
                _cancelThresholdCrossed = nowCrossed;
              });

              // Swipe up to lock threshold
              if (dy < -60 && !_isRecordingLocked) {
                AppHaptics.medium();
                setState(() => _isRecordingLocked = true);
              }
            },
            onLongPressEnd: (details) {
              if (_isRecordingLocked) return; // already locked, handled by buttons

              if (_cancelThresholdCrossed) {
                _cancelRecording();
              } else {
                _stopAndSendRecording();
              }
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              curve: Curves.easeOutCubic,
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                color: _cancelThresholdCrossed
                    ? AppTheme.danger
                    : (context.isDark ? Colors.white : Colors.black),
                shape: BoxShape.circle,
                boxShadow: context.isDark ? null : AppTheme.buttonShadow,
              ),
              child: Center(
                child: _cancelThresholdCrossed
                    ? ScaleTransition(
                        scale: _trashScaleAnimation,
                        child: const Icon(
                          Icons.delete_rounded,
                          color: Colors.white,
                          size: 26,
                        ),
                      )
                    : (_dragOffsetY < -30
                        ? Icon(
                            Icons.lock_rounded,
                            color: context.isDark
                                ? Colors.black
                                : Colors.white,
                            size: 22,
                          )
                        : Icon(
                            Icons.mic_rounded,
                            color: context.isDark
                                ? Colors.black
                                : Colors.white,
                            size: 26,
                          )),
              ),
            ),
          );
        }

        // ── Default: Send (text) or Mic (empty) button ──
        return GestureDetector(
          onTap: () {
            if (hasText) {
              _sendTextMessage();
            } else {
              Dialogs.showSnackbar(
                  context, 'Hold to record, slide up to lock');
            }
          },
          onLongPressStart: hasText
              ? null
              : (details) {
                  _startRecording();
                },
          onLongPressMoveUpdate: hasText
              ? null
              : (details) {
                  if (!_isRecording) return;
                  final dx =
                      details.offsetFromOrigin.dx.clamp(-160.0, 0.0);
                  final dy =
                      details.offsetFromOrigin.dy.clamp(-120.0, 0.0);

                  final wasCrossed = _cancelThresholdCrossed;
                  final nowCrossed = dx < -80;

                  if (nowCrossed && !wasCrossed) {
                    AppHaptics.heavy();
                    _trashScaleController.forward();
                  } else if (!nowCrossed && wasCrossed) {
                    _trashScaleController.reverse();
                  }

                  setState(() {
                    _dragOffsetX = dx;
                    _dragOffsetY = dy;
                    _cancelThresholdCrossed = nowCrossed;
                  });

                  // Swipe up to lock
                  if (dy < -60 && !_isRecordingLocked) {
                    AppHaptics.medium();
                    setState(() => _isRecordingLocked = true);
                  }
                },
          onLongPressEnd: hasText
              ? null
              : (details) {
                  if (!_isRecording) return;
                  if (_isRecordingLocked) return;

                  if (_cancelThresholdCrossed) {
                    _cancelRecording();
                  } else {
                    _stopAndSendRecording();
                  }
                },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: context.isDark ? Colors.white : Colors.black,
              shape: BoxShape.circle,
              boxShadow: context.isDark ? null : AppTheme.buttonShadow,
            ),
            child: Center(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                transitionBuilder: (child, anim) =>
                    ScaleTransition(scale: anim, child: child),
                child: _isSendingVoice
                    ? SizedBox(
                        key: const ValueKey('sending'),
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            context.isDark ? Colors.black : Colors.white,
                          ),
                        ),
                      )
                    : Icon(
                        hasText
                            ? Icons.arrow_upward_rounded
                            : Icons.mic_rounded,
                        key: ValueKey(hasText ? 'send' : 'mic'),
                        color: context.isDark
                            ? Colors.black
                            : Colors.white,
                        size: 24,
                      ),
              ),
            ),
          ),
        );
      },
    );
  }
}
