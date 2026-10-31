import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:chatty/api/apis.dart';
import 'package:chatty/helper/app_haptics.dart';
import 'package:chatty/helper/app_theme.dart';
import 'package:chatty/helper/dialogs.dart';
import 'package:chatty/helper/my_date_util.dart';
import 'package:chatty/models/chat_user.dart';
import 'package:chatty/screens/auth/login_screen.dart';
import 'package:chatty/screens/chat_screen.dart';
import 'package:chatty/screens/media_viewer_screen.dart';
import 'package:chatty/services/chat_settings_controller.dart';
import 'package:chatty/services/conversation_controller.dart';
import 'package:chatty/services/theme_controller.dart';
import 'package:chatty/widgets/chat_wallpaper.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:image_picker/image_picker.dart';

/// Telegram-Grade Profile & Settings Screen for Chatty
/// - For Self: Inset grouped cards (Account, Chat Settings, App Info & Actions)
/// - For Other Users: Telegram contact card with online indicator and copyable credentials
class ProfileScreen extends StatefulWidget {
  final ChatUser user;

  const ProfileScreen({super.key, required this.user});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  String? _image;
  bool _isUpdating = false;

  bool get _isMe => widget.user.id == APIs.myUid;

  void _handleLogout() async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: context.surfaceColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: context.borderColor, width: 0.8),
        ),
        title: Text(
          'Log Out',
          style: TextStyle(
            fontFamily: 'Lexend',
            fontWeight: FontWeight.w700,
            fontSize: 18,
            color: context.textPrimaryColor,
          ),
        ),
        content: Text(
          'Are you sure you want to log out of Chatty?',
          style: TextStyle(
            fontFamily: 'Lexend',
            fontSize: 14,
            color: context.textSecondaryColor,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              AppHaptics.light();
              Navigator.pop(context, false);
            },
            child: Text(
              'Cancel',
              style: TextStyle(
                fontFamily: 'Lexend',
                color: context.textSecondaryColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.danger,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () {
              AppHaptics.heavy();
              Navigator.pop(context, true);
            },
            child: const Text(
              'Log Out',
              style: TextStyle(
                fontFamily: 'Lexend',
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    Dialogs.showProgressbar(context);
    ConversationController.reset();
    await APIs.updateActiveStatus(false);
    await APIs.auth.signOut();
    await GoogleSignIn().signOut();
    if (!mounted) return;
    Navigator.pop(context);
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  void _saveProfile() async {
    if (!_isMe) return;
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();
      AppHaptics.medium();
      setState(() => _isUpdating = true);
      await APIs.updateUserInfo();
      setState(() => _isUpdating = false);
      if (!mounted) return;
      AppHaptics.light();
      Dialogs.showSnackbar(context, 'Profile updated successfully');
    }
  }

  void _copyToClipboard(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    AppHaptics.light();
    Dialogs.showSnackbar(context, '$label copied to clipboard');
  }

  void _showPhotoPickerSheet() {
    if (!_isMe) return;
    AppHaptics.medium();
    showModalBottomSheet(
      context: context,
      backgroundColor: context.surfaceColor,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Profile Photo',
                  style: TextStyle(
                    fontFamily: 'Lexend',
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: context.textPrimaryColor,
                  ),
                ),
                const SizedBox(height: 12),
                ListTile(
                  leading: _buildIconBadge(
                    context: context,
                    icon: Icons.camera_alt_outlined,
                  ),
                  title: Text(
                    'Take Photo',
                    style: TextStyle(
                      fontFamily: 'Lexend',
                      fontSize: 15,
                      color: context.textPrimaryColor,
                    ),
                  ),
                  onTap: () async {
                    AppHaptics.light();
                    Navigator.pop(context);
                    final ImagePicker picker = ImagePicker();
                    final XFile? image = await picker.pickImage(
                      source: ImageSource.camera,
                      imageQuality: 70,
                    );
                    if (image != null) {
                      setState(() => _image = image.path);
                      final success =
                          await APIs.updateProfilePicture(File(_image!));
                      if (!mounted) return;
                      if (success) {
                        Dialogs.showSnackbar(context, 'Profile photo updated');
                      }
                    }
                  },
                ),
                ListTile(
                  leading: _buildIconBadge(
                    context: context,
                    icon: Icons.photo_library_outlined,
                  ),
                  title: Text(
                    'Choose from Library',
                    style: TextStyle(
                      fontFamily: 'Lexend',
                      fontSize: 15,
                      color: context.textPrimaryColor,
                    ),
                  ),
                  onTap: () async {
                    AppHaptics.light();
                    Navigator.pop(context);
                    final ImagePicker picker = ImagePicker();
                    final XFile? image = await picker.pickImage(
                      source: ImageSource.gallery,
                      imageQuality: 70,
                    );
                    if (image != null) {
                      setState(() => _image = image.path);
                      final success =
                          await APIs.updateProfilePicture(File(_image!));
                      if (!mounted) return;
                      if (success) {
                        Dialogs.showSnackbar(context, 'Profile photo updated');
                      }
                    }
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ─────────────────────────────────────────────────────────────
  // UI Helpers: Inset Grouped Surface Cards & 32x32 Rounded Badges
  // ─────────────────────────────────────────────────────────────

  Widget _buildGroupCard({
    required BuildContext context,
    required List<Widget> children,
    String? headerTitle,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (headerTitle != null)
          Padding(
            padding: const EdgeInsets.only(left: 20, bottom: 8, top: 22),
            child: Text(
              headerTitle.toUpperCase(),
              style: TextStyle(
                fontFamily: 'Lexend',
                fontSize: 12,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.8,
                color: context.textMutedColor,
              ),
            ),
          ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Container(
            decoration: BoxDecoration(
              color: context.surfaceColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: context.borderColor, width: 0.8),
              boxShadow: context.softShadow,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: children,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildIconBadge({
    required BuildContext context,
    required IconData icon,
    Color? iconColor,
    Color? backgroundColor,
  }) {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: backgroundColor ?? context.badgeBackgroundColor,
        borderRadius: BorderRadius.circular(8),
      ),
      alignment: Alignment.center,
      child: Icon(
        icon,
        size: 17,
        color: iconColor ?? context.textPrimaryColor,
      ),
    );
  }

  Widget _buildDivider(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 60),
      child: Divider(
        height: 1,
        thickness: 0.6,
        color: context.borderColor,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        backgroundColor: context.backgroundColor,
        appBar: AppBar(
          backgroundColor: context.backgroundColor,
          elevation: 0,
          scrolledUnderElevation: 0,
          leading: IconButton(
            splashRadius: 22,
            icon: Icon(
              Icons.arrow_back_rounded,
              color: context.textPrimaryColor,
            ),
            onPressed: () {
              AppHaptics.light();
              Navigator.pop(context);
            },
          ),
          title: Text(
            _isMe ? 'Profile & Settings' : 'Contact Info',
            style: TextStyle(
              fontFamily: 'Lexend',
              fontWeight: FontWeight.w700,
              fontSize: 20,
              color: context.textPrimaryColor,
            ),
          ),
          actions: [
            if (_isMe)
              TextButton(
                onPressed: _isUpdating ? null : _saveProfile,
                child: _isUpdating
                    ? SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            context.textPrimaryColor,
                          ),
                        ),
                      )
                    : Text(
                        'Save',
                        style: TextStyle(
                          fontFamily: 'Lexend',
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: context.textPrimaryColor,
                        ),
                      ),
              ),
          ],
        ),
        body: _isMe ? _buildMyProfile() : _buildOtherUserProfile(),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // 1. My Own Profile & Settings (Telegram Inset Grouped Hierarchy)
  // ─────────────────────────────────────────────────────────────
  Widget _buildMyProfile() {
    const double avatarRadius = 50.0; // 100pt diameter
    final usernameHandle = widget.user.email.isNotEmpty
        ? '@${widget.user.email.split('@').first}'
        : '@${widget.user.name.toLowerCase().replaceAll(' ', '')}';

    return Form(
      key: _formKey,
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        child: Column(
          children: [
            // Header: Large Avatar (100pt) with Cutout Camera Badge + Name + Online Dot
            Padding(
              padding: const EdgeInsets.only(top: 20, bottom: 18),
              child: Center(
                child: Column(
                  children: [
                    Stack(
                      children: [
                        GestureDetector(
                          onTap: () {
                            final photoUrl = _image ?? widget.user.image;
                            if (photoUrl.isNotEmpty) {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => MediaViewerScreen(
                                    imageUrl: photoUrl,
                                    title: widget.user.name,
                                    timestamp: 'Profile Photo',
                                    heroTag: 'profile_hero_${widget.user.id}',
                                  ),
                                ),
                              );
                            }
                          },
                          child: Hero(
                            tag: 'profile_hero_${widget.user.id}',
                            child: CircleAvatar(
                              radius: avatarRadius,
                              backgroundColor: context.surfaceMutedColor,
                              backgroundImage: _image != null
                                  ? FileImage(File(_image!)) as ImageProvider
                                  : (widget.user.image.isNotEmpty
                                      ? CachedNetworkImageProvider(
                                          widget.user.image)
                                      : null),
                              child: (_image == null &&
                                      widget.user.image.isEmpty)
                                  ? Text(
                                      widget.user.name.isNotEmpty
                                          ? widget.user.name[0].toUpperCase()
                                          : '?',
                                      style: TextStyle(
                                        fontFamily: 'Lexend',
                                        fontSize: 36,
                                        fontWeight: FontWeight.w700,
                                        color: context.textPrimaryColor,
                                      ),
                                    )
                                  : null,
                            ),
                          ),
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: GestureDetector(
                            onTap: _showPhotoPickerSheet,
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: context.isDark
                                    ? Colors.white
                                    : Colors.black,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: context.backgroundColor,
                                  width: 3,
                                ),
                              ),
                              child: Icon(
                                Icons.camera_alt_rounded,
                                color: context.isDark
                                    ? Colors.black
                                    : Colors.white,
                                size: 15,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      widget.user.name.isNotEmpty
                          ? widget.user.name
                          : 'Chatty User',
                      style: TextStyle(
                        fontFamily: 'Lexend',
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: context.textPrimaryColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: AppTheme.success,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Text(
                          'online',
                          style: TextStyle(
                            fontFamily: 'Lexend',
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.success,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // ─────────────────────────────────────────────────────────────
            // Card 1: Account (Name, Bio, Username, Email)
            // ─────────────────────────────────────────────────────────────
            _buildGroupCard(
              context: context,
              headerTitle: 'Account',
              children: [
                // Name Field (Editable)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      _buildIconBadge(
                        context: context,
                        icon: Icons.person_outline_rounded,
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Display Name',
                              style: TextStyle(
                                fontFamily: 'Lexend',
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: context.textMutedColor,
                              ),
                            ),
                            TextFormField(
                              initialValue: widget.user.name,
                              textInputAction: TextInputAction.next,
                              scrollPadding: const EdgeInsets.only(bottom: 80),
                              onSaved: (val) => APIs.me.name = val ?? '',
                              validator: (val) =>
                                  val != null && val.trim().isNotEmpty
                                      ? null
                                      : 'Name cannot be empty',
                              style: TextStyle(
                                fontFamily: 'Lexend',
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                                color: context.textPrimaryColor,
                              ),
                              decoration: InputDecoration(
                                isDense: true,
                                contentPadding:
                                    const EdgeInsets.only(top: 4, bottom: 2),
                                border: InputBorder.none,
                                hintText: 'Enter your name',
                                hintStyle: TextStyle(
                                  fontFamily: 'Lexend',
                                  fontSize: 14,
                                  color: context.textMutedColor,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                _buildDivider(context),

                // Bio / About Field (Editable)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      _buildIconBadge(
                        context: context,
                        icon: Icons.info_outline_rounded,
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Bio',
                              style: TextStyle(
                                fontFamily: 'Lexend',
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: context.textMutedColor,
                              ),
                            ),
                            TextFormField(
                              initialValue: widget.user.about,
                              maxLines: 2,
                              minLines: 1,
                              textInputAction: TextInputAction.done,
                              scrollPadding: const EdgeInsets.only(bottom: 80),
                              onSaved: (val) => APIs.me.about = val ?? '',
                              validator: (val) =>
                                  val != null && val.trim().isNotEmpty
                                      ? null
                                      : 'Bio cannot be empty',
                              style: TextStyle(
                                fontFamily: 'Lexend',
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                                color: context.textPrimaryColor,
                              ),
                              decoration: InputDecoration(
                                isDense: true,
                                contentPadding:
                                    const EdgeInsets.only(top: 4, bottom: 2),
                                border: InputBorder.none,
                                hintText: "Hey, I'm using Chatty!",
                                hintStyle: TextStyle(
                                  fontFamily: 'Lexend',
                                  fontSize: 14,
                                  color: context.textMutedColor,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                _buildDivider(context),

                // Username (@handle with 'Tap to copy' feedback)
                ListTile(
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                  leading: _buildIconBadge(
                    context: context,
                    icon: Icons.alternate_email_rounded,
                  ),
                  title: Text(
                    usernameHandle,
                    style: TextStyle(
                      fontFamily: 'Lexend',
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: context.textPrimaryColor,
                    ),
                  ),
                  subtitle: Text(
                    'Username · Tap to copy',
                    style: TextStyle(
                      fontFamily: 'Lexend',
                      fontSize: 11,
                      color: context.textMutedColor,
                    ),
                  ),
                  trailing: Icon(
                    Icons.copy_rounded,
                    size: 16,
                    color: context.textMutedColor,
                  ),
                  onTap: () => _copyToClipboard(usernameHandle, 'Username'),
                ),
                _buildDivider(context),

                // Email with 'Tap to copy' feedback
                ListTile(
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                  leading: _buildIconBadge(
                    context: context,
                    icon: Icons.mail_outline_rounded,
                  ),
                  title: Text(
                    widget.user.email.isNotEmpty
                        ? widget.user.email
                        : 'No email registered',
                    style: TextStyle(
                      fontFamily: 'Lexend',
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: context.textPrimaryColor,
                    ),
                  ),
                  subtitle: Text(
                    'Email · Tap to copy',
                    style: TextStyle(
                      fontFamily: 'Lexend',
                      fontSize: 11,
                      color: context.textMutedColor,
                    ),
                  ),
                  trailing: Icon(
                    Icons.copy_rounded,
                    size: 16,
                    color: context.textMutedColor,
                  ),
                  onTap: () =>
                      _copyToClipboard(widget.user.email, 'Email address'),
                ),
              ],
            ),

            // ─────────────────────────────────────────────────────────────
            // Card 2: Chat Settings (Wallpaper, Theme, Visuals)
            // ─────────────────────────────────────────────────────────────
            _buildGroupCard(
              context: context,
              headerTitle: 'Chat Settings',
              children: [
                // Chat Wallpaper tile with active preview thumbnail
                ValueListenableBuilder<String>(
                  valueListenable:
                      ChatSettingsController.wallpaperThemeNotifier,
                  builder: (context, currentTheme, _) {
                    final currentPreset = ChatWallpaper.presets.firstWhere(
                      (p) => p['id'] == currentTheme,
                      orElse: () => ChatWallpaper.presets.first,
                    );

                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 4),
                      leading: _buildIconBadge(
                        context: context,
                        icon: Icons.wallpaper_rounded,
                      ),
                      title: Text(
                        'Chat Wallpaper',
                        style: TextStyle(
                          fontFamily: 'Lexend',
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          color: context.textPrimaryColor,
                        ),
                      ),
                      subtitle: Text(
                        currentPreset['name'] ?? 'Custom',
                        style: TextStyle(
                          fontFamily: 'Lexend',
                          fontSize: 11,
                          color: context.textMutedColor,
                        ),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          WallpaperThumbnail(
                            presetId: currentTheme,
                            isSelected: true,
                            width: 32,
                            height: 42,
                            showChatBubbles: false,
                          ),
                          const SizedBox(width: 8),
                          Icon(
                            Icons.chevron_right_rounded,
                            size: 20,
                            color: context.chevronColor,
                          ),
                        ],
                      ),
                      onTap: () => ChatWallpaper.showWallpaperPicker(context),
                    );
                  },
                ),
                _buildDivider(context),

                // Inline Horizontal Wallpaper Selector Strip
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Quick Wallpaper Presets',
                        style: TextStyle(
                          fontFamily: 'Lexend',
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: context.textMutedColor,
                        ),
                      ),
                      const SizedBox(height: 10),
                      ValueListenableBuilder<String>(
                        valueListenable:
                            ChatSettingsController.wallpaperThemeNotifier,
                        builder: (context, currentTheme, _) {
                          return Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: ChatWallpaper.presets.map((preset) {
                              final id = preset['id']!;
                              final isSelected = currentTheme == id;
                              return WallpaperThumbnail(
                                presetId: id,
                                isSelected: isSelected,
                                width: (MediaQuery.sizeOf(context).width - 80) / 4,
                                height: 68,
                                showChatBubbles: true,
                                onTap: () {
                                  ChatSettingsController.setWallpaperTheme(id);
                                },
                              );
                            }).toList(),
                          );
                        },
                      ),
                    ],
                  ),
                ),
                _buildDivider(context),

                // Theme Mode 3-Way Segmented Control (System / Light / Dark)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          _buildIconBadge(
                            context: context,
                            icon: Icons.brightness_6_rounded,
                          ),
                          const SizedBox(width: 14),
                          Text(
                            'Appearance',
                            style: TextStyle(
                              fontFamily: 'Lexend',
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                              color: context.textPrimaryColor,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      ValueListenableBuilder<ThemeMode>(
                        valueListenable: ThemeController.themeNotifier,
                        builder: (context, currentMode, _) {
                          return Container(
                            height: 38,
                            padding: const EdgeInsets.all(3),
                            decoration: BoxDecoration(
                              color: context.badgeBackgroundColor,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              children: [
                                _buildThemeSegment(
                                  label: 'System',
                                  icon: Icons.phone_iphone_rounded,
                                  isSelected: currentMode == ThemeMode.system,
                                  onTap: () =>
                                      ThemeController.setTheme(ThemeMode.system),
                                ),
                                _buildThemeSegment(
                                  label: 'Light',
                                  icon: Icons.light_mode_rounded,
                                  isSelected: currentMode == ThemeMode.light,
                                  onTap: () =>
                                      ThemeController.setTheme(ThemeMode.light),
                                ),
                                _buildThemeSegment(
                                  label: 'Dark',
                                  icon: Icons.dark_mode_rounded,
                                  isSelected: currentMode == ThemeMode.dark,
                                  onTap: () =>
                                      ThemeController.setTheme(ThemeMode.dark),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),

            // ─────────────────────────────────────────────────────────────
            // Card 3: App Info & Actions (Version, Attribution, Logout)
            // ─────────────────────────────────────────────────────────────
            _buildGroupCard(
              context: context,
              headerTitle: 'App Info & Actions',
              children: [
                ListTile(
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                  leading: _buildIconBadge(
                    context: context,
                    icon: Icons.verified_outlined,
                  ),
                  title: Text(
                    'Chatty Messenger',
                    style: TextStyle(
                      fontFamily: 'Lexend',
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: context.textPrimaryColor,
                    ),
                  ),
                  subtitle: Text(
                    'Version 1.2.0 (Build 42)',
                    style: TextStyle(
                      fontFamily: 'Lexend',
                      fontSize: 11,
                      color: context.textMutedColor,
                    ),
                  ),
                  trailing: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: context.badgeBackgroundColor,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'STABLE',
                      style: TextStyle(
                        fontFamily: 'Lexend',
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                        color: context.textPrimaryColor,
                      ),
                    ),
                  ),
                ),
                _buildDivider(context),
                ListTile(
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                  leading: _buildIconBadge(
                    context: context,
                    icon: Icons.code_rounded,
                  ),
                  title: Text(
                    'Crafted by FerTech',
                    style: TextStyle(
                      fontFamily: 'Lexend',
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: context.textPrimaryColor,
                    ),
                  ),
                  subtitle: Text(
                    'Ultra-fast, end-to-end real-time communication',
                    style: TextStyle(
                      fontFamily: 'Lexend',
                      fontSize: 11,
                      color: context.textMutedColor,
                    ),
                  ),
                ),
                _buildDivider(context),
                ListTile(
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                  leading: _buildIconBadge(
                    context: context,
                    icon: Icons.logout_rounded,
                    iconColor: AppTheme.danger,
                    backgroundColor: context.dangerSoftColor,
                  ),
                  title: const Text(
                    'Log Out',
                    style: TextStyle(
                      fontFamily: 'Lexend',
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.danger,
                    ),
                  ),
                  subtitle: Text(
                    'Disconnect this device securely',
                    style: TextStyle(
                      fontFamily: 'Lexend',
                      fontSize: 11,
                      color: context.textMutedColor,
                    ),
                  ),
                  onTap: _handleLogout,
                ),
              ],
            ),

            const SizedBox(height: 48),
          ],
        ),
      ),
    );
  }

  Widget _buildThemeSegment({
    required String label,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: () {
          AppHaptics.selection();
          onTap();
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isSelected
                ? (context.isDark ? const Color(0xFF3F3F46) : Colors.white)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 14,
                color: isSelected
                    ? context.textPrimaryColor
                    : context.textMutedColor,
              ),
              const SizedBox(width: 5),
              Text(
                label,
                style: TextStyle(
                  fontFamily: 'Lexend',
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  color: isSelected
                      ? context.textPrimaryColor
                      : context.textMutedColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // 2. Contact Profile (Telegram Contact Inspection View)
  // ─────────────────────────────────────────────────────────────
  Widget _buildOtherUserProfile() {
    const double avatarRadius = 50.0;
    final usernameHandle = widget.user.email.isNotEmpty
        ? '@${widget.user.email.split('@').first}'
        : '@${widget.user.name.toLowerCase().replaceAll(' ', '')}';

    return StreamBuilder(
      stream: APIs.getUserInfo(widget.user),
      builder: (context, snapshot) {
        final data = snapshot.data?.docs;
        final list =
            data?.map((e) => ChatUser.fromJson(e.data())).toList() ?? [];
        final user = list.isNotEmpty ? list[0] : widget.user;

        return SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            children: [
              // Contact Header
              Padding(
                padding: const EdgeInsets.only(top: 24, bottom: 20),
                child: Center(
                  child: Column(
                    children: [
                      GestureDetector(
                        onTap: () {
                          if (user.image.isNotEmpty) {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => MediaViewerScreen(
                                  imageUrl: user.image,
                                  title: user.name,
                                  timestamp: 'Profile Photo',
                                  heroTag: 'contact_hero_${user.id}',
                                ),
                              ),
                            );
                          }
                        },
                        child: Hero(
                          tag: 'contact_hero_${user.id}',
                          child: CircleAvatar(
                            radius: avatarRadius,
                            backgroundColor: context.surfaceMutedColor,
                            backgroundImage: user.image.isNotEmpty
                                ? CachedNetworkImageProvider(user.image)
                                : null,
                            child: user.image.isEmpty
                                ? Text(
                                    user.name.isNotEmpty
                                        ? user.name[0].toUpperCase()
                                        : '?',
                                    style: TextStyle(
                                      fontFamily: 'Lexend',
                                      fontSize: 36,
                                      fontWeight: FontWeight.w700,
                                      color: context.textPrimaryColor,
                                    ),
                                  )
                                : null,
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        user.name,
                        style: TextStyle(
                          fontFamily: 'Lexend',
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: context.textPrimaryColor,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (user.isOnline) ...[
                            Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                color: AppTheme.success,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                          ],
                          Text(
                            user.isOnline
                                ? 'online'
                                : MyDateUtil.getLastActiveTime(
                                    context: context,
                                    lastActive: user.lastActive,
                                  ),
                            style: TextStyle(
                              fontFamily: 'Lexend',
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: user.isOnline
                                  ? AppTheme.success
                                  : context.textMutedColor,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              // Action Buttons: Send Message CTA
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: SizedBox(
                  width: double.infinity,
                  height: 46,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          context.isDark ? Colors.white : Colors.black,
                      foregroundColor:
                          context.isDark ? Colors.black : Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    icon: const Icon(Icons.chat_bubble_outline_rounded, size: 18),
                    label: const Text(
                      'Send Message',
                      style: TextStyle(
                        fontFamily: 'Lexend',
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                    onPressed: () {
                      AppHaptics.light();
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ChatScreen(user: user),
                        ),
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Contact Info Card
              _buildGroupCard(
                context: context,
                headerTitle: 'Information',
                children: [
                  ListTile(
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                    leading: _buildIconBadge(
                      context: context,
                      icon: Icons.info_outline_rounded,
                    ),
                    title: Text(
                      user.about.isNotEmpty
                          ? user.about
                          : "Hey, I'm using Chatty!",
                      style: TextStyle(
                        fontFamily: 'Lexend',
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: context.textPrimaryColor,
                      ),
                    ),
                    subtitle: Text(
                      'Bio',
                      style: TextStyle(
                        fontFamily: 'Lexend',
                        fontSize: 11,
                        color: context.textMutedColor,
                      ),
                    ),
                  ),
                  _buildDivider(context),
                  ListTile(
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                    leading: _buildIconBadge(
                      context: context,
                      icon: Icons.alternate_email_rounded,
                    ),
                    title: Text(
                      usernameHandle,
                      style: TextStyle(
                        fontFamily: 'Lexend',
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: context.textPrimaryColor,
                      ),
                    ),
                    subtitle: Text(
                      'Username · Tap to copy',
                      style: TextStyle(
                        fontFamily: 'Lexend',
                        fontSize: 11,
                        color: context.textMutedColor,
                      ),
                    ),
                    trailing: Icon(
                      Icons.copy_rounded,
                      size: 16,
                      color: context.textMutedColor,
                    ),
                    onTap: () => _copyToClipboard(usernameHandle, 'Username'),
                  ),
                  _buildDivider(context),
                  ListTile(
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                    leading: _buildIconBadge(
                      context: context,
                      icon: Icons.mail_outline_rounded,
                    ),
                    title: Text(
                      user.email.isNotEmpty
                          ? user.email
                          : 'No email registered',
                      style: TextStyle(
                        fontFamily: 'Lexend',
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: context.textPrimaryColor,
                      ),
                    ),
                    subtitle: Text(
                      'Email · Tap to copy',
                      style: TextStyle(
                        fontFamily: 'Lexend',
                        fontSize: 11,
                        color: context.textMutedColor,
                      ),
                    ),
                    trailing: Icon(
                      Icons.copy_rounded,
                      size: 16,
                      color: context.textMutedColor,
                    ),
                    onTap: () =>
                        _copyToClipboard(user.email, 'Email address'),
                  ),
                ],
              ),

              const SizedBox(height: 48),
            ],
          ),
        );
      },
    );
  }
}
