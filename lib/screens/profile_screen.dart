import 'dart:async';
import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:chatty/api/apis.dart';
import 'package:chatty/helper/app_haptics.dart';
import 'package:chatty/helper/app_theme.dart';
import 'package:chatty/helper/dialogs.dart';
import 'package:chatty/helper/my_date_util.dart';
import 'package:chatty/models/chat_user.dart';
import 'package:chatty/models/message.dart';
import 'package:chatty/screens/auth/login_screen.dart';
import 'package:chatty/screens/chat_screen.dart';
import 'package:chatty/screens/media_viewer_screen.dart';
import 'package:chatty/services/conversation_controller.dart';
import 'package:chatty/services/theme_controller.dart';
import 'package:chatty/services/wallpaper_controller.dart';
import 'package:chatty/widgets/audio_waveform_player.dart';
import 'package:chatty/widgets/circular_theme_cover.dart';
import 'package:chatty/widgets/new_chat_sheet.dart';
import 'package:chatty/widgets/wallpaper_picker_sheet.dart';
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
  int _selectedSharedTab = 0;

  static final RegExp _urlRegex = RegExp(
    r'(https?:\/\/[^\s]+)',
    caseSensitive: false,
  );

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

  void _showEditUsernameSheet() {
    AppHaptics.light();
    final TextEditingController usernameController =
        TextEditingController(text: widget.user.username);
    Timer? debounce;
    bool isChecking = false;
    bool? isAvailable;
    String status = '';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetBuilderCtx, setSheetState) {
            void checkUsername(String val) {
              debounce?.cancel();
              final clean = val.trim().toLowerCase().replaceAll('@', '');

              if (clean == widget.user.username.toLowerCase()) {
                setSheetState(() {
                  isChecking = false;
                  isAvailable = null;
                  status = 'This is your current username.';
                });
                return;
              }

              if (clean.length < 3) {
                setSheetState(() {
                  isChecking = false;
                  isAvailable = false;
                  status = 'Must be at least 3 characters.';
                });
                return;
              }

              if (clean.length > 20) {
                setSheetState(() {
                  isChecking = false;
                  isAvailable = false;
                  status = 'Cannot exceed 20 characters.';
                });
                return;
              }

              if (!RegExp(r'^[a-z0-9_]+$').hasMatch(clean)) {
                setSheetState(() {
                  isChecking = false;
                  isAvailable = false;
                  status = 'Letters, numbers, and underscores only.';
                });
                return;
              }

              setSheetState(() {
                isChecking = true;
                status = 'Checking availability...';
              });

              debounce = Timer(const Duration(milliseconds: 300), () async {
                final available = await APIs.isUsernameAvailable(clean);
                if (!sheetContext.mounted) return;
                setSheetState(() {
                  isChecking = false;
                  isAvailable = available;
                  status = available
                      ? '✓ @$clean is available'
                      : '❌ @$clean is already taken';
                });
              });
            }

            final bottomInset = MediaQuery.viewInsetsOf(sheetContext).bottom;
            final canSave = isAvailable == true && !isChecking;

            return Padding(
              padding: EdgeInsets.only(bottom: bottomInset),
              child: Container(
                decoration: BoxDecoration(
                  color: sheetBuilderCtx.surfaceColor,
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(24)),
                  border: Border(
                    top: BorderSide(color: sheetBuilderCtx.borderColor, width: 0.8),
                  ),
                ),
                child: SafeArea(
                  top: false,
                  child: SingleChildScrollView(
                    physics: const ClampingScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: sheetBuilderCtx.borderColor,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Text(
                        'Edit Username',
                        style: TextStyle(
                          fontFamily: 'Lexend',
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: sheetBuilderCtx.textPrimaryColor,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        icon: Icon(Icons.close_rounded,
                            color: sheetBuilderCtx.textSecondaryColor),
                        onPressed: () => Navigator.pop(sheetContext),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Choose a unique handle so people can find you. Letters, numbers, and underscores (3-20 characters).',
                    style: TextStyle(
                      fontFamily: 'Lexend',
                      fontSize: 13,
                      color: sheetBuilderCtx.textSecondaryColor,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 2),
                    decoration: BoxDecoration(
                      color: sheetBuilderCtx.surfaceMutedColor,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isAvailable == true
                            ? AppTheme.success
                            : (isAvailable == false && !isChecking)
                                ? AppTheme.danger
                                : sheetBuilderCtx.borderColor,
                        width: 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Text(
                          '@',
                          style: TextStyle(
                            fontFamily: 'Lexend',
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: sheetBuilderCtx.textPrimaryColor,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: TextField(
                            controller: usernameController,
                            autofocus: true,
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(
                                  RegExp(r'[a-zA-Z0-9_]')),
                              LengthLimitingTextInputFormatter(20),
                            ],
                            onChanged: checkUsername,
                            style: TextStyle(
                              fontFamily: 'Lexend',
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: sheetBuilderCtx.textPrimaryColor,
                            ),
                            decoration: const InputDecoration(
                              border: InputBorder.none,
                              hintText: 'username',
                            ),
                          ),
                        ),
                        if (isChecking)
                          const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        else if (isAvailable == true)
                          const Icon(Icons.check_circle_rounded,
                              color: AppTheme.success, size: 18)
                        else if (isAvailable == false)
                          const Icon(Icons.error_outline_rounded,
                              color: AppTheme.danger, size: 18),
                      ],
                    ),
                  ),
                  if (status.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8, left: 4),
                      child: Text(
                        status,
                        style: TextStyle(
                          fontFamily: 'Lexend',
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: isAvailable == true
                              ? AppTheme.success
                              : (isAvailable == false && !isChecking)
                                  ? AppTheme.danger
                                  : sheetBuilderCtx.textMutedColor,
                        ),
                      ),
                    ),
                  const SizedBox(height: 22),
                  ElevatedButton(
                    onPressed: canSave
                        ? () async {
                            final clean = usernameController.text
                                .trim()
                                .toLowerCase()
                                .replaceAll('@', '');
                            Navigator.pop(sheetContext);
                            final success = await APIs.updateUsername(clean);
                            if (!mounted) return;
                            if (success) {
                              setState(() {
                                widget.user.username = clean;
                              });
                              Dialogs.showSnackbar(
                                  context, 'Username updated to @$clean');
                            } else {
                              Dialogs.showSnackbar(context,
                                  'Failed to update username. Try another.');
                            }
                          }
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          sheetBuilderCtx.isDark ? Colors.white : Colors.black,
                      foregroundColor:
                          sheetBuilderCtx.isDark ? Colors.black : Colors.white,
                      disabledBackgroundColor: (sheetBuilderCtx.isDark
                              ? Colors.white
                              : Colors.black)
                          .withValues(alpha: 0.35),
                      disabledForegroundColor: (sheetBuilderCtx.isDark
                              ? Colors.black
                              : Colors.white)
                          .withValues(alpha: 0.5),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      elevation: 0,
                    ),
                    child: const Text(
                      'Save Username',
                      style: TextStyle(
                        fontFamily: 'Lexend',
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
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
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: context.borderColor, width: 0.8),
              boxShadow: context.softShadow,
            ),
            child: Material(
              color: context.surfaceColor,
              borderRadius: BorderRadius.circular(16),
              clipBehavior: Clip.antiAlias,
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
                              inputFormatters: [
                                LengthLimitingTextInputFormatter(25),
                              ],
                              maxLength: 25,
                              buildCounter: (_,
                                      {required currentLength,
                                      required isFocused,
                                      maxLength}) =>
                                  null,
                              onSaved: (val) => APIs.me.name = val ?? '',
                              validator: (val) {
                                if (val == null || val.trim().isEmpty) {
                                  return 'Name cannot be empty';
                                }
                                if (val.trim().length > 25) {
                                  return 'Name cannot exceed 25 characters';
                                }
                                return null;
                              },
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
                                hintText: 'Enter your name (max 25)',
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

                // Username (@handle with Edit option)
                ListTile(
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                  leading: _buildIconBadge(
                    context: context,
                    icon: Icons.alternate_email_rounded,
                  ),
                  title: Text(
                    '@${widget.user.username.isNotEmpty ? widget.user.username : (APIs.me.username.isNotEmpty ? APIs.me.username : usernameHandle.replaceAll('@', ''))}',
                    style: TextStyle(
                      fontFamily: 'Lexend',
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: context.textPrimaryColor,
                    ),
                  ),
                  subtitle: Text(
                    'Unique Username · Tap to edit',
                    style: TextStyle(
                      fontFamily: 'Lexend',
                      fontSize: 11,
                      color: context.textMutedColor,
                    ),
                  ),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: context.primarySoftColor,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'Edit',
                      style: TextStyle(
                        fontFamily: 'Lexend',
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: context.textPrimaryColor,
                      ),
                    ),
                  ),
                  onTap: _showEditUsernameSheet,
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
            // Card 2: People & Contacts (New Chat / Add Contact by Username or Email)
            // ─────────────────────────────────────────────────────────────
            _buildGroupCard(
              context: context,
              headerTitle: 'People & Contacts',
              children: [
                ListTile(
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  leading: _buildIconBadge(
                    context: context,
                    icon: Icons.person_add_outlined,
                    backgroundColor: context.badgeBackgroundColor,
                    iconColor: context.textPrimaryColor,
                  ),
                  title: Text(
                    'New Chat / Add Contact',
                    style: TextStyle(
                      fontFamily: 'Lexend',
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: context.textPrimaryColor,
                    ),
                  ),
                  subtitle: Text(
                    'Search by username (@handle) or email',
                    style: TextStyle(
                      fontFamily: 'Lexend',
                      fontSize: 12.5,
                      color: context.textMutedColor,
                    ),
                  ),
                  trailing: Icon(
                    Icons.chevron_right_rounded,
                    color: context.chevronColor,
                    size: 20,
                  ),
                  onTap: () => NewChatSheet.show(context),
                ),
              ],
            ),

            // ─────────────────────────────────────────────────────────────
            // Card 3: Appearance & Theme
            // ─────────────────────────────────────────────────────────────
            _buildGroupCard(
              context: context,
              headerTitle: 'Appearance',
              children: [
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
                                  onTap: (origin) {
                                    CircularThemeCover.trigger(
                                      context,
                                      origin: origin,
                                      onToggle: () =>
                                          ThemeController.setTheme(ThemeMode.system),
                                    );
                                  },
                                ),
                                _buildThemeSegment(
                                  label: 'Light',
                                  icon: Icons.light_mode_rounded,
                                  isSelected: currentMode == ThemeMode.light,
                                  onTap: (origin) {
                                    CircularThemeCover.trigger(
                                      context,
                                      origin: origin,
                                      onToggle: () =>
                                          ThemeController.setTheme(ThemeMode.light),
                                    );
                                  },
                                ),
                                _buildThemeSegment(
                                  label: 'Dark',
                                  icon: Icons.dark_mode_rounded,
                                  isSelected: currentMode == ThemeMode.dark,
                                  onTap: (origin) {
                                    CircularThemeCover.trigger(
                                      context,
                                      origin: origin,
                                      onToggle: () =>
                                          ThemeController.setTheme(ThemeMode.dark),
                                    );
                                  },
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
                _buildDivider(context),
                ListTile(
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
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
                  subtitle: ValueListenableBuilder<ChatWallpaper>(
                    valueListenable: WallpaperController.wallpaperNotifier,
                    builder: (context, w, _) => Text(
                      w.title,
                      style: TextStyle(
                        fontFamily: 'Lexend',
                        fontSize: 11,
                        color: context.textMutedColor,
                      ),
                    ),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ValueListenableBuilder<ChatWallpaper>(
                        valueListenable: WallpaperController.wallpaperNotifier,
                        builder: (context, w, _) {
                          return Container(
                            width: 20,
                            height: 20,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: w.buildGradient(context.isDark),
                              border: Border.all(
                                color: context.borderColor,
                                width: 1,
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        Icons.chevron_right_rounded,
                        color: context.chevronColor,
                        size: 20,
                      ),
                    ],
                  ),
                  onTap: () => WallpaperPickerSheet.show(context),
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
    required Function(Offset offset) onTap,
  }) {
    return Expanded(
      child: Builder(
        builder: (segContext) {
          return GestureDetector(
            onTap: () {
              AppHaptics.selection();
              final box = segContext.findRenderObject() as RenderBox?;
              final offset = box != null
                  ? box.localToGlobal(box.size.center(Offset.zero))
                  : Offset.zero;
              onTap(offset);
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
          );
        },
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

              // Action Buttons: Send Message CTA + Wallpaper Picker
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Expanded(
                      child: SizedBox(
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
                          icon: const Icon(Icons.chat_bubble_outline_rounded,
                              size: 18),
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
                    const SizedBox(width: 10),
                    SizedBox(
                      height: 46,
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: context.textPrimaryColor,
                          side: BorderSide(
                              color: context.borderColor, width: 0.8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        icon: const Icon(Icons.wallpaper_rounded, size: 18),
                        label: const Text(
                          'Wallpaper',
                          style: TextStyle(
                            fontFamily: 'Lexend',
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                        onPressed: () => WallpaperPickerSheet.show(context),
                      ),
                    ),
                  ],
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
                      user.username.isNotEmpty
                          ? '@${user.username}'
                          : usernameHandle,
                      style: TextStyle(
                        fontFamily: 'Lexend',
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: context.textPrimaryColor,
                      ),
                    ),
                    subtitle: Text(
                      'Unique Username · Tap to copy',
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
                    onTap: () {
                      final handle = user.username.isNotEmpty
                          ? '@${user.username}'
                          : usernameHandle;
                      _copyToClipboard(handle, 'Username');
                    },
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

              // Shared Content Hub (Media, Voice Notes, Links)
              StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: APIs.getAllMessages(widget.user),
                builder: (context, msgSnapshot) {
                  final allDocs = msgSnapshot.data?.docs ?? [];
                  final allMessages = allDocs
                      .map((e) => Message.fromJson(e.data()))
                      .toList();
                  return _buildSharedContentSection(allMessages);
                },
              ),

              const SizedBox(height: 48),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSharedContentSection(List<Message> allMessages) {
    final mediaMessages =
        allMessages.where((m) => m.type == Type.image).toList();
    final audioMessages =
        allMessages.where((m) => m.type == Type.audio).toList();

    final List<_SharedLink> linkMessages = [];
    for (final m in allMessages) {
      if (m.type == Type.text) {
        final matches = _urlRegex.allMatches(m.msg);
        for (final match in matches) {
          final url = match.group(0)!;
          final uri = Uri.tryParse(url);
          final host = uri?.host.isNotEmpty == true
              ? uri!.host.toLowerCase().replaceAll('www.', '')
              : url;
          linkMessages.add(_SharedLink(
            url: url,
            host: host,
            sent: m.sent,
            isMe: m.fromId == APIs.myUid,
          ));
        }
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 20, bottom: 8, top: 22),
          child: Text(
            'SHARED CONTENT',
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
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: context.borderColor, width: 0.8),
              boxShadow: context.softShadow,
            ),
            child: Material(
              color: context.surfaceColor,
              borderRadius: BorderRadius.circular(16),
              clipBehavior: Clip.antiAlias,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Segmented Tabs Header
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
                    child: Container(
                      height: 38,
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        color: context.badgeBackgroundColor,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          _buildSharedTabPill(
                            label: 'Media',
                            count: mediaMessages.length,
                            icon: Icons.photo_library_outlined,
                            index: 0,
                          ),
                          _buildSharedTabPill(
                            label: 'Voice',
                            count: audioMessages.length,
                            icon: Icons.mic_none_rounded,
                            index: 1,
                          ),
                          _buildSharedTabPill(
                            label: 'Links',
                            count: linkMessages.length,
                            icon: Icons.link_rounded,
                            index: 2,
                          ),
                        ],
                      ),
                    ),
                  ),
                  _buildDivider(context),

                  // Tab View Content
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: _buildSelectedTabContent(
                      mediaMessages: mediaMessages,
                      audioMessages: audioMessages,
                      linkMessages: linkMessages,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSharedTabPill({
    required String label,
    required int count,
    required IconData icon,
    required int index,
  }) {
    final isSelected = _selectedSharedTab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          AppHaptics.selection();
          setState(() => _selectedSharedTab = index);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
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
                size: 13,
                color: isSelected
                    ? context.textPrimaryColor
                    : context.textMutedColor,
              ),
              const SizedBox(width: 5),
              Text(
                count > 0 ? '$label ($count)' : label,
                style: TextStyle(
                  fontFamily: 'Lexend',
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
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

  Widget _buildSelectedTabContent({
    required List<Message> mediaMessages,
    required List<Message> audioMessages,
    required List<_SharedLink> linkMessages,
  }) {
    if (_selectedSharedTab == 0) {
      if (mediaMessages.isEmpty) {
        return _buildEmptyState(
          key: const ValueKey('empty_media'),
          icon: Icons.photo_library_outlined,
          title: 'No Shared Photos',
          subtitle: 'Photos exchanged with this contact will appear here.',
        );
      }
      return Padding(
        key: const ValueKey('tab_media'),
        padding: const EdgeInsets.all(12),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: mediaMessages.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 3,
              mainAxisSpacing: 3,
              childAspectRatio: 1,
            ),
            itemBuilder: (context, i) {
              final msg = mediaMessages[i];
              final isMe = msg.fromId == APIs.myUid;
              final timeStr = MyDateUtil.getFormattedTime(
                  context: context, time: msg.sent);
              return GestureDetector(
                onTap: () {
                  AppHaptics.light();
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => MediaViewerScreen(
                        imageUrl: msg.msg,
                        title: isMe ? 'You' : widget.user.name,
                        timestamp: timeStr,
                        heroTag: 'profile_shared_img_${msg.sent}',
                      ),
                    ),
                  );
                },
                child: Hero(
                  tag: 'profile_shared_img_${msg.sent}',
                  child: CachedNetworkImage(
                    imageUrl: msg.msg,
                    fit: BoxFit.cover,
                    placeholder: (_, __) => Container(
                      color: context.surfaceMutedColor,
                      child: Center(
                        child: SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 1.5,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              context.textPrimaryColor,
                            ),
                          ),
                        ),
                      ),
                    ),
                    errorWidget: (_, __, ___) => Container(
                      color: context.surfaceMutedColor,
                      child: Icon(
                        Icons.broken_image,
                        size: 20,
                        color: context.textMutedColor,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      );
    } else if (_selectedSharedTab == 1) {
      if (audioMessages.isEmpty) {
        return _buildEmptyState(
          key: const ValueKey('empty_voice'),
          icon: Icons.mic_none_rounded,
          title: 'No Voice Notes',
          subtitle: 'Voice recordings exchanged will appear here.',
        );
      }
      return ListView.separated(
        key: const ValueKey('tab_voice'),
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: audioMessages.length,
        separatorBuilder: (_, __) => _buildDivider(context),
        itemBuilder: (context, i) {
          final msg = audioMessages[i];
          final isMe = msg.fromId == APIs.myUid;
          final timeStr =
              MyDateUtil.getFormattedTime(context: context, time: msg.sent);
          final dateStr = MyDateUtil.getChatDateHeader(msg.sent);
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: isMe
                            ? (context.isDark
                                ? Colors.white24
                                : Colors.black12)
                            : context.primarySoftColor,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        isMe ? 'You' : widget.user.name,
                        style: TextStyle(
                          fontFamily: 'Lexend',
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                          color: context.textPrimaryColor,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '$dateStr · $timeStr',
                      style: TextStyle(
                        fontFamily: 'Lexend',
                        fontSize: 11,
                        color: context.textMutedColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                AudioWaveformPlayer(
                  isMe: isMe,
                  audioUrl: msg.msg,
                  durationMs: msg.durationMs,
                  sentTime: timeStr,
                  isRead: msg.read.isNotEmpty,
                ),
              ],
            ),
          );
        },
      );
    } else {
      if (linkMessages.isEmpty) {
        return _buildEmptyState(
          key: const ValueKey('empty_links'),
          icon: Icons.link_rounded,
          title: 'No Links Shared',
          subtitle: 'Web links and URLs exchanged will appear here.',
        );
      }
      return ListView.separated(
        key: const ValueKey('tab_links'),
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: linkMessages.length,
        separatorBuilder: (_, __) => _buildDivider(context),
        itemBuilder: (context, i) {
          final item = linkMessages[i];
          IconData icon = Icons.language_rounded;
          if (item.host.contains('youtube') ||
              item.host.contains('youtu.be')) {
            icon = Icons.play_circle_filled_rounded;
          } else if (item.host.contains('github')) {
            icon = Icons.code_rounded;
          } else if (item.host.contains('twitter') ||
              item.host.contains('x.com')) {
            icon = Icons.tag_rounded;
          }

          final timeStr =
              MyDateUtil.getFormattedTime(context: context, time: item.sent);

          return ListTile(
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            leading: _buildIconBadge(
              context: context,
              icon: icon,
            ),
            title: Text(
              item.host,
              style: TextStyle(
                fontFamily: 'Lexend',
                fontSize: 14.5,
                fontWeight: FontWeight.w600,
                color: context.textPrimaryColor,
              ),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 2),
                Text(
                  item.url,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'Lexend',
                    fontSize: 12,
                    color: context.textSecondaryColor,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${item.isMe ? 'You' : widget.user.name} · $timeStr',
                  style: TextStyle(
                    fontFamily: 'Lexend',
                    fontSize: 10.5,
                    color: context.textMutedColor,
                  ),
                ),
              ],
            ),
            trailing: IconButton(
              icon: Icon(Icons.copy_rounded,
                  size: 17, color: context.textMutedColor),
              onPressed: () => _copyToClipboard(item.url, 'Link'),
            ),
            onTap: () => _copyToClipboard(item.url, 'Link'),
          );
        },
      );
    }
  }

  Widget _buildEmptyState({
    Key? key,
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Container(
      key: key,
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: context.badgeBackgroundColor,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 22, color: context.textMutedColor),
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: TextStyle(
              fontFamily: 'Lexend',
              fontSize: 14.5,
              fontWeight: FontWeight.w600,
              color: context.textPrimaryColor,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Lexend',
              fontSize: 12,
              color: context.textMutedColor,
            ),
          ),
        ],
      ),
    );
  }
}

class _SharedLink {
  final String url;
  final String host;
  final String sent;
  final bool isMe;

  const _SharedLink({
    required this.url,
    required this.host,
    required this.sent,
    required this.isMe,
  });
}
