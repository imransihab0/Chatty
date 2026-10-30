import 'package:cached_network_image/cached_network_image.dart';
import 'package:chatty/api/apis.dart';
import 'package:chatty/helper/app_theme.dart';
import 'package:chatty/helper/dialogs.dart';
import 'package:chatty/models/chat_user.dart';
import 'package:chatty/screens/chat_screen.dart';
import 'package:chatty/screens/profile_screen.dart';
import 'package:chatty/services/theme_controller.dart';
import 'package:chatty/widgets/chat_user_card.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  List<ChatUser> _list = [];
  final List<ChatUser> _searchList = [];
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();

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
            setState(() {
              _isSearching = false;
              _searchController.clear();
              _searchList.clear();
            });
          }
        },
        child: Scaffold(
          backgroundColor: context.backgroundColor,
          appBar: AppBar(
            backgroundColor: context.surfaceColor,
            elevation: 0,
            titleSpacing: 16,
            title: _isSearching
                ? TextField(
                    controller: _searchController,
                    autofocus: true,
                    style: TextStyle(
                      fontFamily: 'Lexend',
                      fontSize: 15,
                      color: context.textPrimaryColor,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Search friends or messages...',
                      hintStyle: TextStyle(
                        fontFamily: 'Lexend',
                        color: context.textMutedColor,
                        fontSize: 14,
                      ),
                      border: InputBorder.none,
                      isDense: true,
                      prefixIcon: Icon(CupertinoIcons.search,
                          color: context.textSecondaryColor, size: 20),
                      suffixIcon: IconButton(
                        icon: Icon(CupertinoIcons.clear_circled_solid,
                            color: context.textMutedColor, size: 18),
                        onPressed: () {
                          _searchController.clear();
                          _searchList.clear();
                          _searchList.addAll(_list);
                          setState(() {});
                        },
                      ),
                    ),
                    onChanged: (val) {
                      _searchList.clear();
                      final query = val.trim().toLowerCase();
                      if (query.isEmpty) {
                        _searchList.addAll(_list);
                      } else {
                        for (var i in _list) {
                          if (i.name.toLowerCase().contains(query) ||
                              i.email.toLowerCase().contains(query)) {
                            _searchList.add(i);
                          }
                        }
                      }
                      setState(() {});
                    },
                  )
                : Row(
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
              // Theme toggle button
              IconButton(
                splashRadius: 22,
                tooltip: context.isDark ? 'Switch to Light Mode' : 'Switch to Dark Mode',
                onPressed: () => ThemeController.toggleTheme(),
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
                onPressed: () {
                  setState(() {
                    _isSearching = !_isSearching;
                    if (_isSearching) {
                      _searchList.clear();
                      _searchList.addAll(_list);
                    } else {
                      _searchController.clear();
                      _searchList.clear();
                    }
                  });
                },
                icon: Icon(
                  _isSearching
                      ? CupertinoIcons.clear
                      : CupertinoIcons.search,
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
          ),
          floatingActionButton: FloatingActionButton.extended(
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

                  final currentList =
                      _isSearching ? _searchList : _list;

                  if (currentList.isNotEmpty) {
                    return ListView.builder(
                      itemCount: currentList.length,
                      padding: const EdgeInsets.only(top: 8, bottom: 80),
                      physics: const BouncingScrollPhysics(),
                      itemBuilder: (context, index) {
                        return ChatUserCard(user: currentList[index]);
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
                              width: 80,
                              height: 80,
                              decoration: BoxDecoration(
                                color: context.primarySoftColor,
                                borderRadius: BorderRadius.circular(40),
                              ),
                              child: Icon(
                                _isSearching
                                    ? CupertinoIcons.search
                                    : Icons.forum_outlined,
                                color: AppTheme.primary,
                                size: 36,
                              ),
                            ),
                            const SizedBox(height: 20),
                            Text(
                              _isSearching
                                  ? 'No matches found'
                                  : 'No conversations yet',
                              style: TextStyle(
                                fontFamily: 'Lexend',
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                                color: context.textPrimaryColor,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _isSearching
                                  ? 'Check your search query and try again.'
                                  : 'Tap "New Chat" below to start a conversation with a friend!',
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
              }
            },
          ),
        ),
      ),
    );
  }
}