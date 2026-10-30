import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:chatty/api/apis.dart';
import 'package:chatty/helper/app_haptics.dart';
import 'package:chatty/helper/app_theme.dart';
import 'package:chatty/helper/dialogs.dart';
import 'package:chatty/models/chat_user.dart';
import 'package:chatty/screens/chat_screen.dart';
import 'package:chatty/screens/profile_screen.dart';
import 'package:chatty/services/chat_settings_controller.dart';
import 'package:chatty/services/theme_controller.dart';
import 'package:chatty/widgets/chat_user_card.dart';
import 'package:flutter/material.dart';

enum HomeFilter { all, online }

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  List<ChatUser> _list = [];
  bool _isSearching = false;
  HomeFilter _selectedFilter = HomeFilter.all;

  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  String _searchQuery = '';
  Timer? _debounceTimer;

  List<ChatUser> _globalSearchResults = [];
  bool _isLoadingGlobal = false;

  @override
  void initState() {
    super.initState();
    APIs.getMyInfo();
    WidgetsBinding.instance.addObserver(this);
    APIs.updateActiveStatus(true);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    _debounceTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (APIs.auth.currentUser != null) {
      if (state == AppLifecycleState.resumed) {
        APIs.updateActiveStatus(true);
      } else if (state == AppLifecycleState.paused ||
          state == AppLifecycleState.detached ||
          state == AppLifecycleState.inactive) {
        APIs.updateActiveStatus(false);
      }
    }
  }

  void _startSearch() {
    AppHaptics.selection();
    setState(() {
      _isSearching = true;
    });
    _searchFocusNode.requestFocus();
  }

  void _stopSearch() {
    AppHaptics.selection();
    _debounceTimer?.cancel();
    setState(() {
      _isSearching = false;
      _searchController.clear();
      _searchQuery = '';
      _globalSearchResults.clear();
      _isLoadingGlobal = false;
    });
    FocusScope.of(context).unfocus();
  }

  void _onSearchChanged(String val) {
    _debounceTimer?.cancel();
    final query = val.trim().toLowerCase();
    setState(() {
      _searchQuery = query;
    });

    if (query.length >= 2) {
      setState(() => _isLoadingGlobal = true);
      _debounceTimer = Timer(const Duration(milliseconds: 350), () async {
        final results = await APIs.searchUsers(query);
        if (mounted) {
          setState(() {
            _globalSearchResults = results
                .where((u) => !_list.any((local) => local.id == u.id))
                .toList();
            _isLoadingGlobal = false;
          });
        }
      });
    } else {
      setState(() {
        _globalSearchResults.clear();
        _isLoadingGlobal = false;
      });
    }
  }

  void _addChatUserDialog() {
    String email = '';

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: context.surfaceColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        contentPadding:
            const EdgeInsets.only(left: 24, right: 24, top: 20, bottom: 12),
        title: Row(
          children: [
            const Icon(Icons.person_add_rounded, color: AppTheme.primary, size: 26),
            const SizedBox(width: 10),
            Text(
              'Add Friend',
              style: TextStyle(
                fontFamily: 'Lexend',
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: context.textPrimaryColor,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Enter your friend\'s email to start a conversation:',
              style: TextStyle(
                fontFamily: 'Lexend',
                fontSize: 13,
                color: context.textSecondaryColor,
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              maxLines: 1,
              keyboardType: TextInputType.emailAddress,
              onChanged: (value) => email = value.trim(),
              style: TextStyle(
                fontFamily: 'Lexend',
                fontSize: 14,
                color: context.textPrimaryColor,
              ),
              decoration: InputDecoration(
                hintText: 'name@example.com',
                hintStyle: TextStyle(
                  fontFamily: 'Lexend',
                  color: context.textMutedColor,
                  fontSize: 14,
                ),
                prefixIcon: const Icon(Icons.email_outlined,
                    color: AppTheme.primary, size: 20),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                filled: true,
                fillColor: context.surfaceMutedColor,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: TextStyle(
                fontFamily: 'Lexend',
                color: context.textSecondaryColor,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              elevation: 0,
            ),
            onPressed: () async {
              Navigator.pop(context);
              if (email.isEmpty) return;
              if (email.toLowerCase() == APIs.user.email?.toLowerCase()) {
                Dialogs.showSnackbar(context, 'You cannot chat with yourself!');
                return;
              }

              final userSnapshot = await APIs.firestore
                  .collection('users')
                  .where('email', isEqualTo: email)
                  .get();
              if (userSnapshot.docs.isNotEmpty) {
                final chatUser =
                    ChatUser.fromJson(userSnapshot.docs.first.data());
                if (!mounted) return;
                Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => ChatScreen(user: chatUser)));
              } else {
                if (!mounted) return;
                Dialogs.showSnackbar(context, 'User not found!');
              }
            },
            child: const Text(
              'Chat',
              style: TextStyle(
                fontFamily: 'Lexend',
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: PopScope(
        canPop: !_isSearching,
        onPopInvokedWithResult: (didPop, result) {
          if (!didPop && _isSearching) {
            _stopSearch();
          }
        },
        child: Scaffold(
          backgroundColor: context.backgroundColor,
          appBar: _isSearching ? _searchAppBar() : _defaultAppBar(),
          floatingActionButton: _isSearching
              ? null
              : FloatingActionButton.extended(
                  onPressed: _addChatUserDialog,
                  backgroundColor: AppTheme.primary,
                  elevation: 4,
                  icon: const Icon(Icons.add_comment_rounded,
                      color: Colors.white, size: 20),
                  label: const Text(
                    'New Chat',
                    style: TextStyle(
                      fontFamily: 'Lexend',
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ),
          body: StreamBuilder(
            stream: APIs.getAllUsers(),
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
                          ?.map((e) => ChatUser.fromJson(e.data()))
                          .toList() ??
                      [];

                  final onlineCount =
                      _list.where((u) => u.isOnline).length;
                  final totalCount = _list.length;

                  // Apply filter & search query
                  List<ChatUser> localFiltered = _list;

                  if (_selectedFilter == HomeFilter.online) {
                    localFiltered =
                        localFiltered.where((u) => u.isOnline).toList();
                  }

                  if (_searchQuery.isNotEmpty) {
                    localFiltered = localFiltered
                        .where((u) =>
                            u.name.toLowerCase().contains(_searchQuery) ||
                            u.email.toLowerCase().contains(_searchQuery) ||
                            u.about.toLowerCase().contains(_searchQuery))
                        .toList();
                  }

                  return ValueListenableBuilder<Set<String>>(
                    valueListenable: ChatSettingsController.pinnedNotifier,
                    builder: (context, pinnedSet, _) {
                      // Sort pinned conversations to the top
                      localFiltered.sort((a, b) {
                        final bool aPinned = pinnedSet.contains(a.id);
                        final bool bPinned = pinnedSet.contains(b.id);
                        if (aPinned && !bPinned) return -1;
                        if (!aPinned && bPinned) return 1;
                        return 0;
                      });

                      return _buildScrollableContent(
                        localFiltered: localFiltered,
                        totalCount: totalCount,
                        onlineCount: onlineCount,
                      );
                },
              );
              }
            },
          ),
        ),
      ),
    );
  }

  // Normal App Bar
  AppBar _defaultAppBar() {
    return AppBar(
      backgroundColor: context.surfaceColor,
      elevation: 0,
      titleSpacing: 16,
      title: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: context.primarySoftColor,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Center(
              child: Icon(
                Icons.chat_bubble_rounded,
                color: AppTheme.primary,
                size: 20,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            'Chatty',
            style: TextStyle(
              fontFamily: 'Lexend',
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: context.textPrimaryColor,
              letterSpacing: -0.5,
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          splashRadius: 22,
          tooltip: context.isDark ? 'Switch to Light Mode' : 'Switch to Dark Mode',
          onPressed: () {
            AppHaptics.medium();
            ThemeController.toggleTheme();
          },
          icon: Icon(
            context.isDark
                ? Icons.light_mode_rounded
                : Icons.dark_mode_rounded,
            color: context.textPrimaryColor,
            size: 22,
          ),
        ),
        IconButton(
          splashRadius: 22,
          tooltip: 'Search friends',
          onPressed: _startSearch,
          icon: Icon(
            Icons.search_rounded,
            color: context.textPrimaryColor,
            size: 22,
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(right: 14, left: 2),
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: () {
              Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => ProfileScreen(user: APIs.me)));
            },
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: AppTheme.primary, width: 1.5),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: CachedNetworkImage(
                  width: 32,
                  height: 32,
                  fit: BoxFit.cover,
                  imageUrl: APIs.me.image,
                  errorWidget: (context, url, error) => CircleAvatar(
                    radius: 16,
                    backgroundColor: context.primarySoftColor,
                    child: Text(
                      APIs.me.name.isNotEmpty
                          ? APIs.me.name[0].toUpperCase()
                          : '?',
                      style: const TextStyle(
                        fontFamily: 'Lexend',
                        fontWeight: FontWeight.w700,
                        color: AppTheme.primary,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // Full-width Dedicated Search Bar
  AppBar _searchAppBar() {
    return AppBar(
      backgroundColor: context.surfaceColor,
      elevation: 0,
      leading: IconButton(
        splashRadius: 22,
        tooltip: 'Exit search',
        onPressed: _stopSearch,
        icon: Icon(
          Icons.arrow_back_rounded,
          color: context.textPrimaryColor,
        ),
      ),
      titleSpacing: 0,
      title: Container(
        height: 40,
        margin: const EdgeInsets.only(right: 16),
        decoration: BoxDecoration(
          color: context.surfaceMutedColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: context.borderColor),
        ),
        child: TextField(
          controller: _searchController,
          focusNode: _searchFocusNode,
          style: TextStyle(
            fontFamily: 'Lexend',
            fontSize: 14,
            color: context.textPrimaryColor,
          ),
          decoration: InputDecoration(
            hintText: 'Search chats, friends, or email...',
            hintStyle: TextStyle(
              fontFamily: 'Lexend',
              fontSize: 13,
              color: context.textMutedColor,
            ),
            border: InputBorder.none,
            prefixIcon: Icon(
              Icons.search_rounded,
              color: context.textSecondaryColor,
              size: 20,
            ),
            suffixIcon: _searchQuery.isNotEmpty
                ? IconButton(
                    splashRadius: 18,
                    icon: Icon(
                      Icons.clear_rounded,
                      color: context.textMutedColor,
                      size: 18,
                    ),
                    onPressed: () {
                      _searchController.clear();
                      _onSearchChanged('');
                    },
                  )
                : null,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            isDense: true,
          ),
          onChanged: _onSearchChanged,
        ),
      ),
    );
  }

  // Horizontal Active Now Live Avatars Strip
  Widget _activeNowTray(List<ChatUser> users) {
    if (users.isEmpty) return const SizedBox.shrink();

    final onlineList = users.where((u) => u.isOnline).toList();
    final displayList =
        onlineList.isNotEmpty ? onlineList : users.take(12).toList();
    final bool hasLiveOnline = onlineList.isNotEmpty;

    return Container(
      margin: const EdgeInsets.only(top: 8, bottom: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
            child: Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: hasLiveOnline ? AppTheme.success : AppTheme.primary,
                    shape: BoxShape.circle,
                    boxShadow: hasLiveOnline
                        ? [
                            BoxShadow(
                              color: AppTheme.success.withValues(alpha: 0.5),
                              blurRadius: 6,
                              spreadRadius: 1,
                            )
                          ]
                        : null,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  hasLiveOnline
                      ? 'ACTIVE NOW (${onlineList.length})'
                      : 'RECENT FRIENDS',
                  style: TextStyle(
                    fontFamily: 'Lexend',
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                    color: context.textSecondaryColor,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 96,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              itemCount: displayList.length,
              itemBuilder: (context, index) {
                final user = displayList[index];
                final firstName = user.name.split(' ').first;

                return InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => ChatScreen(user: user)),
                    );
                  },
                  child: Container(
                    width: 68,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Stack(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(2.5),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: user.isOnline
                                    ? const LinearGradient(
                                        colors: [
                                          Color(0xFF10B981),
                                          Color(0xFF34D399)
                                        ],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      )
                                    : LinearGradient(
                                        colors: [
                                          AppTheme.primary.withValues(alpha: 0.45),
                                          AppTheme.accent.withValues(alpha: 0.3)
                                        ],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      ),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(24),
                                child: CachedNetworkImage(
                                  width: 48,
                                  height: 48,
                                  fit: BoxFit.cover,
                                  imageUrl: user.image,
                                  errorWidget: (context, url, error) =>
                                      CircleAvatar(
                                    radius: 24,
                                    backgroundColor: context.primarySoftColor,
                                    child: Text(
                                      user.name.isNotEmpty
                                          ? user.name[0].toUpperCase()
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
                            ),
                            if (user.isOnline)
                              Positioned(
                                right: 2,
                                bottom: 2,
                                child: Container(
                                  width: 14,
                                  height: 14,
                                  decoration: BoxDecoration(
                                    color: AppTheme.success,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                        color: context.surfaceColor,
                                        width: 2.5),
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          firstName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: 'Lexend',
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: context.textPrimaryColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // Filter Chips Row
  Widget _filterChipsBar(int totalCount, int onlineCount) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: [
          _filterChip(
            title: 'All',
            count: totalCount,
            isSelected: _selectedFilter == HomeFilter.all,
            onTap: () => setState(() => _selectedFilter = HomeFilter.all),
          ),
          const SizedBox(width: 8),
          _filterChip(
            title: '🟢 Online',
            count: onlineCount,
            isSelected: _selectedFilter == HomeFilter.online,
            onTap: () => setState(() => _selectedFilter = HomeFilter.online),
          ),
        ],
      ),
    );
  }

  Widget _filterChip({
    required String title,
    required int count,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: () {
        AppHaptics.selection();
        onTap();
      },
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primary : context.surfaceMutedColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppTheme.primary : context.borderColor,
            width: 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppTheme.primary.withValues(alpha: 0.25),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  )
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              style: TextStyle(
                fontFamily: 'Lexend',
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: isSelected ? Colors.white : context.textSecondaryColor,
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: isSelected
                    ? Colors.white.withValues(alpha: 0.25)
                    : context.borderColor,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  fontFamily: 'Lexend',
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color:
                      isSelected ? Colors.white : context.textSecondaryColor,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Quick Search Trigger Pill when not searching
  Widget _searchTriggerPill() {
    return GestureDetector(
      onTap: _startSearch,
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          color: context.surfaceMutedColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: context.borderColor),
        ),
        child: Row(
          children: [
            Icon(Icons.search_rounded,
                color: context.textMutedColor, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Search chats, friends, or email...',
                style: TextStyle(
                  fontFamily: 'Lexend',
                  fontSize: 13,
                  color: context.textMutedColor,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Main Unified Scrollable Content (Messenger / WhatsApp style)
  // Search bar, active friends strip, and filter chips scroll naturally with conversations
  Widget _buildScrollableContent({
    required List<ChatUser> localFiltered,
    required int totalCount,
    required int onlineCount,
  }) {
    final bool hasLocal = localFiltered.isNotEmpty;
    final bool hasGlobal = _globalSearchResults.isNotEmpty;

    return ListView(
      padding: const EdgeInsets.only(top: 4, bottom: 84),
      physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics()),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      children: [
        // Quick Search Trigger Pill & Active Friends (Scroll with list, hidden during active search)
        if (!_isSearching) ...[
          _searchTriggerPill(),
          _activeNowTray(_list),
        ],

        // Filter Chips Bar (All vs Online)
        _filterChipsBar(
          _isSearching ? localFiltered.length : totalCount,
          _isSearching
              ? localFiltered.where((u) => u.isOnline).length
              : onlineCount,
        ),

        // Global search progress indicator
        if (_isLoadingGlobal)
          const LinearProgressIndicator(
            minHeight: 2,
            backgroundColor: Colors.transparent,
            valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primary),
          ),

        // Empty state when no matches/chats exist
        if (!hasLocal && !hasGlobal)
          _buildEmptyState()
        else ...[
          // Local Contacts Section
          if (hasLocal) ...[
            if (_isSearching && hasGlobal)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                child: Row(
                  children: [
                    const Icon(Icons.people_alt_rounded,
                        size: 15, color: AppTheme.primary),
                    const SizedBox(width: 6),
                    Text(
                      'MY CONVERSATIONS (${localFiltered.length})',
                      style: TextStyle(
                        fontFamily: 'Lexend',
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.6,
                        color: context.textSecondaryColor,
                      ),
                    ),
                  ],
                ),
              ),
            ...localFiltered.map((user) => ChatUserCard(user: user)),
          ],

          // Global Directory Discovery Section
          if (hasGlobal) ...[
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: Row(
                children: [
                  const Icon(Icons.public_rounded,
                      size: 15, color: AppTheme.primary),
                  const SizedBox(width: 6),
                  Text(
                    'GLOBAL DIRECTORY (${_globalSearchResults.length})',
                    style: TextStyle(
                      fontFamily: 'Lexend',
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.6,
                      color: context.textSecondaryColor,
                    ),
                  ),
                ],
              ),
            ),
            ..._globalSearchResults.map((user) => _globalUserCard(user)),
          ],
        ],
      ],
    );
  }

  // Empty State Widget
  Widget _buildEmptyState() {
    if (_isSearching && _searchQuery.isNotEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
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
                child: const Icon(
                  Icons.search_off_rounded,
                  color: AppTheme.primary,
                  size: 34,
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'No matches found',
                style: TextStyle(
                  fontFamily: 'Lexend',
                  fontSize: 19,
                  fontWeight: FontWeight.w700,
                  color: context.textPrimaryColor,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'We couldn\'t find anyone matching "$_searchQuery". Try checking for typos or searching by full email address.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Lexend',
                  fontSize: 13,
                  color: context.textSecondaryColor,
                ),
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: () {
                  _searchController.clear();
                  _onSearchChanged('');
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.primary,
                  side: const BorderSide(color: AppTheme.primary),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.clear_rounded, size: 16),
                label: const Text(
                  'Clear Search',
                  style: TextStyle(fontFamily: 'Lexend', fontSize: 13),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_selectedFilter == HomeFilter.online) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
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
                child: const Icon(
                  Icons.person_off_outlined,
                  color: AppTheme.primary,
                  size: 34,
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'No friends online',
                style: TextStyle(
                  fontFamily: 'Lexend',
                  fontSize: 19,
                  fontWeight: FontWeight.w700,
                  color: context.textPrimaryColor,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'None of your contacts are currently active. Switch to "All" to view all chats.',
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

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: context.primarySoftColor,
                borderRadius: BorderRadius.circular(40),
              ),
              child: const Icon(
                Icons.forum_outlined,
                color: AppTheme.primary,
                size: 36,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'No conversations yet',
              style: TextStyle(
                fontFamily: 'Lexend',
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: context.textPrimaryColor,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Tap "New Chat" below to start a conversation with a friend!',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Lexend',
                fontSize: 14,
                color: context.textSecondaryColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Global Directory User Card with direct chat action
  Widget _globalUserCard(ChatUser u) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: context.borderColor, width: 1),
        boxShadow: context.softShadow,
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: CachedNetworkImage(
              width: 48,
              height: 48,
              fit: BoxFit.cover,
              imageUrl: u.image,
              errorWidget: (context, url, error) => CircleAvatar(
                radius: 24,
                backgroundColor: context.primarySoftColor,
                child: Text(
                  u.name.isNotEmpty ? u.name[0].toUpperCase() : '?',
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
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  u.name,
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
                  u.email,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'Lexend',
                    fontSize: 12,
                    color: context.textSecondaryColor,
                  ),
                ),
                if (u.about.isNotEmpty &&
                    u.about != "Hey, I'm using Chatty!") ...[
                  const SizedBox(height: 2),
                  Text(
                    u.about,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: 'Lexend',
                      fontSize: 11,
                      fontStyle: FontStyle.italic,
                      color: context.textMutedColor,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => ChatScreen(user: u)),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 0,
              visualDensity: VisualDensity.compact,
            ),
            icon: const Icon(Icons.chat_bubble_rounded, size: 14),
            label: const Text(
              'Chat',
              style: TextStyle(
                fontFamily: 'Lexend',
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
