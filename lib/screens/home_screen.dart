import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:chatty/api/apis.dart';
import 'package:chatty/helper/app_haptics.dart';
import 'package:chatty/helper/app_theme.dart';
import 'package:chatty/models/chat_user.dart';
import 'package:chatty/models/message.dart';
import 'package:chatty/screens/chat_screen.dart';
import 'package:chatty/screens/profile_screen.dart';
import 'package:chatty/services/chat_settings_controller.dart';
import 'package:chatty/services/conversation_controller.dart';
import 'package:chatty/services/theme_controller.dart';
import 'package:chatty/widgets/app_components.dart';
import 'package:chatty/widgets/chat_user_card.dart';
import 'package:chatty/widgets/circular_theme_cover.dart';
import 'package:chatty/widgets/new_chat_sheet.dart';
import 'package:chatty/widgets/shimmer_skeleton.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

enum HomeFilter { all, unread, online, media }

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

  late final Stream<QuerySnapshot<Map<String, dynamic>>> _usersStream;

  @override
  void initState() {
    super.initState();
    _usersStream = APIs.getAllUsers();
    APIs.getMyInfo();
    ConversationController.init();
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
          body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: _usersStream,
            builder: (context, snapshot) {
              if (snapshot.hasData) {
                final data = snapshot.data?.docs;
                _list = data
                        ?.map((e) => ChatUser.fromJson(e.data()))
                        .toList() ??
                    [];

                // Start observing latest messages across all users in background
                ConversationController.watchUsers(_list);

                return ValueListenableBuilder<Map<String, Message>>(
                  valueListenable: ConversationController.lastMessagesNotifier,
                  builder: (context, lastMessagesMap, _) {
                    final onlineCount =
                        _list.where((u) => u.isOnline).length;
                    final unreadCount = _list
                        .where((u) => ConversationController.isUnread(u.id))
                        .length;
                    final mediaCount = _list
                        .where((u) => ConversationController.hasMedia(u.id))
                        .length;
                    final totalCount = _list.length;

                    // Apply filter & search query
                    List<ChatUser> localFiltered = List.from(_list);

                    if (_selectedFilter == HomeFilter.unread) {
                      localFiltered = localFiltered
                          .where((u) => ConversationController.isUnread(u.id))
                          .toList();
                    } else if (_selectedFilter == HomeFilter.online) {
                      localFiltered =
                          localFiltered.where((u) => u.isOnline).toList();
                    } else if (_selectedFilter == HomeFilter.media) {
                      localFiltered = localFiltered
                          .where((u) => ConversationController.hasMedia(u.id))
                          .toList();
                    }

                    if (_searchQuery.isNotEmpty) {
                      localFiltered = localFiltered
                          .where((u) =>
                              u.name.toLowerCase().contains(_searchQuery) ||
                              u.username.toLowerCase().contains(_searchQuery) ||
                              u.email.toLowerCase().contains(_searchQuery) ||
                              u.about.toLowerCase().contains(_searchQuery))
                          .toList();
                    }

                    return ValueListenableBuilder<Set<String>>(
                      valueListenable: ChatSettingsController.pinnedNotifier,
                      builder: (context, pinnedSet, _) {
                        return ValueListenableBuilder<Map<String, int>>(
                          valueListenable:
                              ConversationController.lastMessageTimesNotifier,
                          builder: (context, messageTimes, _) {
                            // Sort conversations:
                            // 1. Pinned conversations to the top
                            // 2. Latest chat timestamp descending (most recent chat on top)
                            // 3. Fallback to lastActive descending, then alphabetical by name
                            localFiltered.sort((a, b) {
                              final bool aPinned = pinnedSet.contains(a.id);
                              final bool bPinned = pinnedSet.contains(b.id);
                              if (aPinned && !bPinned) return -1;
                              if (!aPinned && bPinned) return 1;

                              final int timeA = messageTimes[a.id] ?? 0;
                              final int timeB = messageTimes[b.id] ?? 0;

                              if (timeA > 0 || timeB > 0) {
                                if (timeA != timeB) {
                                  return timeB.compareTo(timeA); // latest chat on top
                                }
                              }

                              final int activeA =
                                  int.tryParse(a.lastActive) ?? 0;
                              final int activeB =
                                  int.tryParse(b.lastActive) ?? 0;
                              if (activeA != activeB) {
                                return activeB.compareTo(activeA);
                              }

                              return a.name
                                  .toLowerCase()
                                  .compareTo(b.name.toLowerCase());
                            });

                            return _buildScrollableContent(
                              localFiltered: localFiltered,
                              totalCount: totalCount,
                              unreadCount: unreadCount,
                              onlineCount: onlineCount,
                              mediaCount: mediaCount,
                            );
                          },
                        );
                      },
                    );
                  },
                );
              }

              // Shimmer skeleton placeholders during initial cold load
              return const HomeConversationSkeletonList();
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
            child: Center(
              child: Icon(
                Icons.chat_bubble_rounded,
                color: context.textPrimaryColor,
                size: 20,
              ),
            ),
          ),
          AppSpacing.gapW12,
          Text(
            'Chatty',
            style: TextStyle(
              fontFamily: AppTypography.fontFamily,
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: context.textPrimaryColor,
              letterSpacing: -0.5,
            ),
          ),
        ],
      ),
      actions: [
        Builder(
          builder: (btnContext) {
            return IconButton(
              splashRadius: 22,
              tooltip: context.isDark ? 'Switch to Light Mode' : 'Switch to Dark Mode',
              onPressed: () {
                final renderBox = btnContext.findRenderObject() as RenderBox?;
                final offset = renderBox?.localToGlobal(
                  renderBox.size.center(Offset.zero),
                );
                CircularThemeCover.trigger(
                  btnContext,
                  origin: offset,
                  onToggle: () {
                    ThemeController.toggleTheme();
                  },
                );
              },
              icon: AnimatedSwitcher(
                duration: const Duration(milliseconds: 450),
                switchInCurve: Curves.easeOutBack,
                switchOutCurve: Curves.easeInBack,
                transitionBuilder: (child, anim) => RotationTransition(
                  turns: anim.drive(Tween<double>(begin: 0.75, end: 1.0)),
                  child: ScaleTransition(scale: anim, child: child),
                ),
                child: Icon(
                  context.isDark
                      ? Icons.light_mode_rounded
                      : Icons.dark_mode_rounded,
                  key: ValueKey(context.isDark),
                  color: context.textPrimaryColor,
                  size: 22,
                ),
              ),
            );
          },
        ),
        IconButton(
          splashRadius: 22,
          tooltip: 'New Chat',
          onPressed: () => NewChatSheet.show(context),
          icon: Icon(
            Icons.person_add_outlined,
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
                  builder: (_) => ProfileScreen(user: APIs.me),
                ),
              );
            },
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: context.isDark
                      ? const Color(0xFF444444)
                      : const Color(0xFFCCCCCC),
                  width: 1.5,
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: CachedNetworkImage(
                  width: 32,
                  height: 32,
                  fit: BoxFit.cover,
                  imageUrl: APIs.me.image,
                  memCacheWidth: 64,
                  memCacheHeight: 64,
                  errorWidget: (context, url, error) => CircleAvatar(
                    radius: 16,
                    backgroundColor: context.primarySoftColor,
                    child: Text(
                      APIs.me.name.isNotEmpty
                          ? APIs.me.name[0].toUpperCase()
                          : '?',
                      style: TextStyle(
                        fontFamily: AppTypography.fontFamily,
                        fontWeight: FontWeight.w700,
                        color: context.textPrimaryColor,
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
            fontFamily: AppTypography.fontFamily,
            fontSize: 14,
            color: context.textPrimaryColor,
          ),
          decoration: InputDecoration(
            hintText: 'Search by name, @username, or email...',
            hintStyle: TextStyle(
              fontFamily: AppTypography.fontFamily,
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
                    color: hasLiveOnline
                        ? AppTheme.success
                        : (context.isDark
                            ? const Color(0xFF555555)
                            : const Color(0xFF999999)),
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
                AppSpacing.gapW8,
                Text(
                  hasLiveOnline
                      ? 'ACTIVE NOW (${onlineList.length})'
                      : 'RECENT FRIENDS',
                  style: TextStyle(
                    fontFamily: AppTypography.fontFamily,
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
              key: const PageStorageKey('active_now_horizontal_tray'),
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
                    AppHaptics.light();
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ChatScreen(user: user),
                      ),
                    );
                  },
                  child: Container(
                    width: 68,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        AppAvatar(
                          imageUrl: user.image,
                          name: user.name,
                          size: 48,
                          isOnline: user.isOnline,
                        ),
                        AppSpacing.gapH6,
                        Text(
                          firstName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: AppTypography.fontFamily,
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

  // Filter Chips Row (Chat Folders)
  Widget _filterChipsBar({
    required int totalCount,
    required int unreadCount,
    required int onlineCount,
    required int mediaCount,
  }) {
    return SingleChildScrollView(
      key: const PageStorageKey('home_filter_chips_scroll'),
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: [
          _filterChip(
            title: 'All',
            count: totalCount,
            isSelected: _selectedFilter == HomeFilter.all,
            onTap: () {
              if (_selectedFilter != HomeFilter.all) {
                setState(() => _selectedFilter = HomeFilter.all);
              }
            },
          ),
          AppSpacing.gapW8,
          _filterChip(
            title: 'Unread',
            count: unreadCount,
            isSelected: _selectedFilter == HomeFilter.unread,
            onTap: () {
              if (_selectedFilter != HomeFilter.unread) {
                setState(() => _selectedFilter = HomeFilter.unread);
              }
            },
          ),
          AppSpacing.gapW8,
          _filterChip(
            title: 'Online',
            count: onlineCount,
            isSelected: _selectedFilter == HomeFilter.online,
            onTap: () {
              if (_selectedFilter != HomeFilter.online) {
                setState(() => _selectedFilter = HomeFilter.online);
              }
            },
          ),
          AppSpacing.gapW8,
          _filterChip(
            title: 'Media',
            count: mediaCount,
            isSelected: _selectedFilter == HomeFilter.media,
            onTap: () {
              if (_selectedFilter != HomeFilter.media) {
                setState(() => _selectedFilter = HomeFilter.media);
              }
            },
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
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        AppHaptics.selection();
        onTap();
      },
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          constraints: const BoxConstraints(minHeight: 36),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: isSelected
                ? (context.isDark ? Colors.white : Colors.black)
                : context.surfaceMutedColor,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected
                  ? (context.isDark ? Colors.white : Colors.black)
                  : context.borderColor,
              width: 1,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: (context.isDark ? Colors.white : Colors.black)
                          .withValues(alpha: context.isDark ? 0.15 : 0.15),
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
                  fontFamily: AppTypography.fontFamily,
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  color: isSelected
                      ? (context.isDark ? Colors.black : Colors.white)
                      : context.textSecondaryColor,
                ),
              ),
              AppSpacing.gapW6,
              AppBadge(
                text: '$count',
                isSelected: isSelected,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Quick Search Trigger Pill when not searching
  Widget _searchTriggerPill() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Material(
        color: context.surfaceMutedColor,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: _startSearch,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: context.borderColor),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.search_rounded,
                  color: context.textMutedColor,
                  size: 20,
                ),
                AppSpacing.gapW10,
                Expanded(
                  child: Text(
                    'Search by name, @username, or email...',
                    style: TextStyle(
                      fontFamily: AppTypography.fontFamily,
                      fontSize: 13,
                      color: context.textMutedColor,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Main Unified Scrollable Content
  Widget _buildScrollableContent({
    required List<ChatUser> localFiltered,
    required int totalCount,
    required int unreadCount,
    required int onlineCount,
    required int mediaCount,
  }) {
    final bool hasLocal = localFiltered.isNotEmpty;
    final bool hasGlobal = _globalSearchResults.isNotEmpty;

    return ListView(
      addAutomaticKeepAlives: true,
      addRepaintBoundaries: true,
      padding: EdgeInsets.only(
        top: 4,
        bottom: 24 + MediaQuery.paddingOf(context).bottom,
      ),
      physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics()),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      children: [
        // Quick Search Trigger Pill & Active Friends (Scroll with list, hidden during active search)
        if (!_isSearching) ...[
          _searchTriggerPill(),
          _activeNowTray(_list),
        ],

        // Filter Chips Bar (Chat Folders)
        _filterChipsBar(
          totalCount: _isSearching ? localFiltered.length : totalCount,
          unreadCount: _isSearching
              ? localFiltered
                  .where((u) => ConversationController.isUnread(u.id))
                  .length
              : unreadCount,
          onlineCount: _isSearching
              ? localFiltered.where((u) => u.isOnline).length
              : onlineCount,
          mediaCount: _isSearching
              ? localFiltered
                  .where((u) => ConversationController.hasMedia(u.id))
                  .length
              : mediaCount,
        ),

        // Global search progress indicator
        AnimatedSize(
          duration: const Duration(milliseconds: 200),
          child: _isLoadingGlobal
              ? LinearProgressIndicator(
                  minHeight: 2,
                  backgroundColor: Colors.transparent,
                  valueColor:
                      AlwaysStoppedAnimation<Color>(context.textPrimaryColor),
                )
              : const SizedBox.shrink(),
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
                    Icon(Icons.people_alt_rounded,
                        size: 15, color: context.textPrimaryColor),
                    AppSpacing.gapW6,
                    Text(
                      'MY CONVERSATIONS (${localFiltered.length})',
                      style: TextStyle(
                        fontFamily: AppTypography.fontFamily,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.6,
                        color: context.textSecondaryColor,
                      ),
                    ),
                  ],
                ),
              ),
            ...localFiltered.map((user) => ChatUserCard(
                  key: ValueKey('chat_card_${user.id}'),
                  user: user,
                )),
          ],

          // Global Directory Discovery Section
          if (hasGlobal) ...[
            AppSpacing.gapH12,
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: Row(
                children: [
                  Icon(Icons.public_rounded,
                      size: 15, color: context.textPrimaryColor),
                  AppSpacing.gapW6,
                  Text(
                    'GLOBAL DIRECTORY (${_globalSearchResults.length})',
                    style: TextStyle(
                      fontFamily: AppTypography.fontFamily,
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

  // Dedicated High-End Empty States
  Widget _buildEmptyState() {
    if (_isSearching && _searchQuery.isNotEmpty) {
      return AppEmptyState(
        icon: Icons.search_off_rounded,
        title: 'No matches found',
        subtitle:
            'We couldn\'t find anyone matching "$_searchQuery". Try searching by unique @username or full email.',
        actionLabel: 'Clear Search',
        onAction: () {
          _searchController.clear();
          _onSearchChanged('');
        },
      );
    }

    if (_selectedFilter == HomeFilter.unread) {
      return const AppEmptyState(
        icon: Icons.mark_email_read_outlined,
        title: 'All caught up!',
        subtitle:
            'You have no unread messages. Select "All" to browse all your conversations.',
      );
    }

    if (_selectedFilter == HomeFilter.online) {
      return const AppEmptyState(
        icon: Icons.person_off_outlined,
        title: 'No friends online',
        subtitle:
            'None of your contacts are currently active. Switch to "All" to view all chats.',
      );
    }

    if (_selectedFilter == HomeFilter.media) {
      return const AppEmptyState(
        icon: Icons.perm_media_outlined,
        title: 'No media chats',
        subtitle:
            'Chats containing photos or voice notes will appear here automatically.',
      );
    }

    return AppEmptyState(
      icon: Icons.forum_outlined,
      title: 'No conversations yet',
      subtitle:
          'Search by username or email to start a conversation with your favorite people!',
      actionLabel: 'Start a Conversation',
      onAction: () => NewChatSheet.show(context),
    );
  }

  // Global Directory User Card with direct chat action
  Widget _globalUserCard(ChatUser u) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => ChatScreen(user: u)),
              );
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: [
                  AppAvatar(
                    imageUrl: u.image,
                    name: u.name,
                    size: 52,
                    isOnline: u.isOnline,
                  ),
                  AppSpacing.gapW14,
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          u.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: AppTypography.fontFamily,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: context.textPrimaryColor,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '@${u.username.isNotEmpty ? u.username : u.email}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: AppTypography.fontFamily,
                            fontSize: 13.5,
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
                              fontFamily: AppTypography.fontFamily,
                              fontSize: 11.5,
                              color: context.textMutedColor,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  AppSpacing.gapW8,
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                    decoration: BoxDecoration(
                      color: context.isDark ? Colors.white : Colors.black,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      'Chat',
                      style: TextStyle(
                        fontFamily: AppTypography.fontFamily,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: context.isDark ? Colors.black : Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
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
    );
  }
}
