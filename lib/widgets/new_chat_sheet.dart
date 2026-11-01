import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:chatty/api/apis.dart';
import 'package:chatty/helper/app_haptics.dart';
import 'package:chatty/helper/app_theme.dart';
import 'package:chatty/models/chat_user.dart';
import 'package:chatty/screens/chat_screen.dart';
import 'package:flutter/material.dart';

/// Telegram / Apple-Grade New Chat & Add Contact Modal Sheet
class NewChatSheet extends StatefulWidget {
  const NewChatSheet({super.key});

  /// Presents the New Chat sheet with spring transition
  static Future<void> show(BuildContext context) {
    AppHaptics.selection();
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const NewChatSheet(),
    );
  }

  @override
  State<NewChatSheet> createState() => _NewChatSheetState();
}

class _NewChatSheetState extends State<NewChatSheet> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  Timer? _debounceTimer;

  List<ChatUser> _results = [];
  bool _isLoading = false;
  bool _hasSearched = false;
  String _lastQuery = '';

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  void _onQueryChanged(String query) {
    _debounceTimer?.cancel();
    final clean = query.trim();

    if (clean.isEmpty) {
      setState(() {
        _results.clear();
        _isLoading = false;
        _hasSearched = false;
        _lastQuery = '';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _lastQuery = clean;
    });

    _debounceTimer = Timer(const Duration(milliseconds: 250), () async {
      final matches = await APIs.searchUsers(clean);
      if (!mounted) return;
      setState(() {
        _results = matches;
        _isLoading = false;
        _hasSearched = true;
      });
    });
  }

  void _openChatWithUser(ChatUser user) {
    AppHaptics.light();
    Navigator.pop(context);
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ChatScreen(user: user)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final maxHeight = MediaQuery.sizeOf(context).height * 0.82;

    return Container(
      constraints: BoxConstraints(maxHeight: maxHeight),
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(
          top: BorderSide(color: context.borderColor, width: 0.8),
          left: BorderSide(color: context.borderColor, width: 0.8),
          right: BorderSide(color: context.borderColor, width: 0.8),
        ),
      ),
      padding: EdgeInsets.only(bottom: bottomInset),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Top Drag Handle
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 10, bottom: 8),
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: context.borderColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Header Row: Title & Close Button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
              child: Row(
                children: [
                  Text(
                    'New Chat',
                    style: TextStyle(
                      fontFamily: 'Lexend',
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: context.textPrimaryColor,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    splashRadius: 18,
                    visualDensity: VisualDensity.compact,
                    icon: Icon(
                      Icons.close_rounded,
                      color: context.textSecondaryColor,
                      size: 22,
                    ),
                    onPressed: () {
                      AppHaptics.light();
                      Navigator.pop(context);
                    },
                  ),
                ],
              ),
            ),

            // Search Input Field
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
              child: Container(
                height: 44,
                decoration: BoxDecoration(
                  color: context.surfaceMutedColor,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: context.borderColor, width: 0.6),
                ),
                child: TextField(
                  controller: _controller,
                  focusNode: _focusNode,
                  autofocus: true,
                  maxLines: 1,
                  textAlignVertical: TextAlignVertical.center,
                  textInputAction: TextInputAction.search,
                  keyboardType: TextInputType.emailAddress,
                  style: TextStyle(
                    fontFamily: 'Lexend',
                    fontSize: 14.5,
                    color: context.textPrimaryColor,
                  ),
                  onChanged: _onQueryChanged,
                  decoration: InputDecoration(
                    isDense: true,
                    hintText: 'Search username (@handle) or email...',
                    hintStyle: TextStyle(
                      fontFamily: 'Lexend',
                      fontSize: 13.5,
                      color: context.textMutedColor,
                      overflow: TextOverflow.ellipsis,
                    ),
                    prefixIconConstraints:
                        const BoxConstraints(minWidth: 40, minHeight: 44),
                    prefixIcon: Icon(
                      Icons.alternate_email_rounded,
                      color: context.textSecondaryColor,
                      size: 19,
                    ),
                    suffixIconConstraints:
                        const BoxConstraints(minWidth: 40, minHeight: 44),
                    suffixIcon: _isLoading
                        ? Center(
                            child: SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  context.textPrimaryColor,
                                ),
                              ),
                            ),
                          )
                        : _controller.text.isNotEmpty
                            ? GestureDetector(
                                onTap: () {
                                  _controller.clear();
                                  _onQueryChanged('');
                                },
                                child: Icon(
                                  Icons.cancel_rounded,
                                  color: context.textMutedColor,
                                  size: 18,
                                ),
                              )
                            : null,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 0,
                    ),
                  ),
                ),
              ),
            ),

            // Content Area: Results / Empty / Hint
            Flexible(
              child: _buildContent(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (_results.isNotEmpty) {
      return ListView.separated(
        shrinkWrap: true,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        itemCount: _results.length,
        separatorBuilder: (_, __) => Padding(
          padding: const EdgeInsets.only(left: 60),
          child: Divider(
            height: 1,
            thickness: 0.6,
            color: context.borderColor,
          ),
        ),
        itemBuilder: (context, index) {
          final user = _results[index];
          final handle = user.username.isNotEmpty
              ? '@${user.username}'
              : (user.email.isNotEmpty
                  ? '@${user.email.split('@').first}'
                  : '@${user.name.toLowerCase().replaceAll(' ', '')}');

          return InkWell(
            onTap: () => _openChatWithUser(user),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
              child: Row(
                children: [
                  // Avatar with online dot
                  Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(22),
                        child: user.image.isNotEmpty
                            ? CachedNetworkImage(
                                imageUrl: user.image,
                                width: 44,
                                height: 44,
                                fit: BoxFit.cover,
                                memCacheWidth: 88,
                                memCacheHeight: 88,
                                placeholder: (_, __) =>
                                    _buildAvatarFallback(user),
                                errorWidget: (_, __, ___) =>
                                    _buildAvatarFallback(user),
                              )
                            : _buildAvatarFallback(user),
                      ),
                      if (user.isOnline)
                        Positioned(
                          right: 0,
                          bottom: 0,
                          child: Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              color: AppTheme.success,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: context.surfaceColor,
                                width: 2,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(width: 14),

                  // Name & Handle
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          user.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: 'Lexend',
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: context.textPrimaryColor,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '$handle  •  ${user.email}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: 'Lexend',
                            fontSize: 12,
                            color: context.textMutedColor,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(width: 10),

                  // Lean "Chat" Action Pill
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: context.isDark ? Colors.white : Colors.black,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Text(
                      'Chat',
                      style: TextStyle(
                        fontFamily: 'Lexend',
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: context.isDark ? Colors.black : Colors.white,
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

    if (_hasSearched && !_isLoading) {
      return Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: context.surfaceMutedColor,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.person_search_rounded,
                color: context.textMutedColor,
                size: 28,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'No users found',
              style: TextStyle(
                fontFamily: 'Lexend',
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: context.textPrimaryColor,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'We couldn\'t find anyone matching "$_lastQuery".\nCheck the username or enter a full email address.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Lexend',
                fontSize: 12.5,
                color: context.textSecondaryColor,
                height: 1.35,
              ),
            ),
          ],
        ),
      );
    }

    // Default hint before typing
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 28),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: context.primarySoftColor,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              Icons.info_outline_rounded,
              color: context.textSecondaryColor,
              size: 20,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Add by Username or Email',
                  style: TextStyle(
                    fontFamily: 'Lexend',
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: context.textPrimaryColor,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'Type anyone\'s username (e.g. @imransihab) or email address to start a direct message.',
                  style: TextStyle(
                    fontFamily: 'Lexend',
                    fontSize: 12,
                    color: context.textMutedColor,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatarFallback(ChatUser user) {
    return Container(
      width: 44,
      height: 44,
      color: context.surfaceMutedColor,
      alignment: Alignment.center,
      child: Text(
        user.name.isNotEmpty ? user.name[0].toUpperCase() : '?',
        style: TextStyle(
          fontFamily: 'Lexend',
          fontSize: 17,
          fontWeight: FontWeight.w700,
          color: context.textPrimaryColor,
        ),
      ),
    );
  }
}
