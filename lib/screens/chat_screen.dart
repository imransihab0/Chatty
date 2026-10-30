import 'dart:developer';
import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../api/apis.dart';
import '../helper/app_theme.dart';
import '../helper/dialogs.dart';
import '../helper/my_date_util.dart';
import '../models/chat_user.dart';
import '../models/message.dart';
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
  bool _isUploading = false;

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
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
    return Scaffold(
      backgroundColor: context.backgroundColor,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(60),
        child: Container(
          decoration: BoxDecoration(
            color: context.surfaceColor,
            border: Border(bottom: BorderSide(color: context.borderColor, width: 1)),
          ),
          child: SafeArea(child: _appBar()),
        ),
      ),
      body: Column(
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

                    if (_list.isNotEmpty) {
                      return ListView.builder(
                        reverse: true,
                        itemCount: _list.length,
                        padding: const EdgeInsets.only(top: 10, bottom: 6),
                        physics: const BouncingScrollPhysics(),
                        itemBuilder: (context, index) {
                          return MessageCard(message: _list[index]);
                        },
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

          _chatInput(),
        ],
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
                            Text(
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

          // Send button
          GestureDetector(
            onTap: () {
              final text = _textController.text.trim();
              if (text.isNotEmpty) {
                APIs.sendMessage(widget.user, text, Type.text);
                _textController.clear();
              }
            },
            child: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppTheme.primary,
                shape: BoxShape.circle,
                boxShadow: AppTheme.buttonShadow,
              ),
              child: const Center(
                child: Icon(
                  Icons.arrow_upward_rounded,
                  color: Colors.white,
                  size: 24,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
