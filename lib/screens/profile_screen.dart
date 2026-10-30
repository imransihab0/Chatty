import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:chatty/api/apis.dart';
import 'package:chatty/helper/app_haptics.dart';
import 'package:chatty/helper/app_theme.dart';
import 'package:chatty/helper/dialogs.dart';
import 'package:chatty/models/chat_user.dart';
import 'package:chatty/screens/auth/login_screen.dart';
import 'package:chatty/screens/media_viewer_screen.dart';
import 'package:chatty/services/theme_controller.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:image_picker/image_picker.dart';

/// Clean, Minimalist Profile Screen (Apple / WhatsApp style)
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

  void _handleLogout() async {
    AppHaptics.heavy();
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: context.surfaceColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
              AppHaptics.medium();
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

    Dialogs.showProgressbar(context, color: AppTheme.primary);
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

  void _showPhotoPickerSheet() {
    AppHaptics.medium();
    showModalBottomSheet(
      context: context,
      backgroundColor: context.surfaceColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
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
                const SizedBox(height: 16),
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
                  leading: const Icon(Icons.camera_alt_outlined,
                      color: AppTheme.primary),
                  title: Text(
                    'Take Photo',
                    style: TextStyle(
                      fontFamily: 'Lexend',
                      fontSize: 15,
                      color: context.textPrimaryColor,
                    ),
                  ),
                  onTap: () async {
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
                  leading: const Icon(Icons.photo_library_outlined,
                      color: AppTheme.primary),
                  title: Text(
                    'Choose from Library',
                    style: TextStyle(
                      fontFamily: 'Lexend',
                      fontSize: 15,
                      color: context.textPrimaryColor,
                    ),
                  ),
                  onTap: () async {
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

  @override
  Widget build(BuildContext context) {
    const double avatarRadius = 54;

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        backgroundColor: context.backgroundColor,
        appBar: AppBar(
          backgroundColor: context.surfaceColor,
          elevation: 0,
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
            'Profile',
            style: TextStyle(
              fontFamily: 'Lexend',
              fontWeight: FontWeight.w700,
              fontSize: 19,
              color: context.textPrimaryColor,
            ),
          ),
        ),
        body: Form(
          key: _formKey,
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Column(
              children: [
                // Clean Centered Avatar with Camera Badge
                Padding(
                  padding: const EdgeInsets.only(top: 28, bottom: 24),
                  child: Center(
                    child: Stack(
                      children: [
                        GestureDetector(
                          onTap: () {
                            if (_image != null) {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => MediaViewerScreen(
                                    imageUrl: _image!,
                                    title: widget.user.name,
                                    timestamp: 'Profile Photo',
                                    heroTag: 'profile_hero_${widget.user.id}',
                                  ),
                                ),
                              );
                            } else if (widget.user.image.isNotEmpty) {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => MediaViewerScreen(
                                    imageUrl: widget.user.image,
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
                              child:
                                  (_image == null && widget.user.image.isEmpty)
                                      ? Text(
                                          widget.user.name.isNotEmpty
                                              ? widget.user.name[0].toUpperCase()
                                              : '?',
                                          style: const TextStyle(
                                            fontFamily: 'Lexend',
                                            fontSize: 38,
                                            fontWeight: FontWeight.w700,
                                            color: AppTheme.primary,
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
                                color: AppTheme.primary,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: context.surfaceColor,
                                  width: 3,
                                ),
                              ),
                              child: const Icon(
                                Icons.camera_alt_rounded,
                                color: Colors.white,
                                size: 16,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Inset Grouped Section: Profile Fields
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Material(
                    color: context.surfaceColor,
                    borderRadius: BorderRadius.circular(16),
                    clipBehavior: Clip.antiAlias,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(color: context.borderColor),
                    ),
                    child: Column(
                    children: [
                      // Display Name Field
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Name',
                              style: TextStyle(
                                fontFamily: 'Lexend',
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: context.textSecondaryColor,
                              ),
                            ),
                            TextFormField(
                              initialValue: widget.user.name,
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
                                    const EdgeInsets.only(top: 6, bottom: 4),
                                border: InputBorder.none,
                                hintText: 'Enter your name',
                                hintStyle: TextStyle(
                                  fontFamily: 'Lexend',
                                  fontSize: 14,
                                  color: context.textMutedColor,
                                ),
                              ),
                            ),
                            Text(
                              'This name will be visible to your Chatty contacts.',
                              style: TextStyle(
                                fontFamily: 'Lexend',
                                fontSize: 11,
                                color: context.textMutedColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Divider(height: 1, color: context.borderColor),

                      // About Field
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'About',
                              style: TextStyle(
                                fontFamily: 'Lexend',
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: context.textSecondaryColor,
                              ),
                            ),
                            TextFormField(
                              initialValue: widget.user.about,
                              maxLines: 2,
                              minLines: 1,
                              onSaved: (val) => APIs.me.about = val ?? '',
                              validator: (val) =>
                                  val != null && val.trim().isNotEmpty
                                      ? null
                                      : 'About cannot be empty',
                              style: TextStyle(
                                fontFamily: 'Lexend',
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                                color: context.textPrimaryColor,
                              ),
                              decoration: InputDecoration(
                                isDense: true,
                                contentPadding:
                                    const EdgeInsets.only(top: 6, bottom: 4),
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
                      Divider(height: 1, color: context.borderColor),

                      // Email Field (Read-only)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Email',
                                    style: TextStyle(
                                      fontFamily: 'Lexend',
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: context.textSecondaryColor,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    widget.user.email,
                                    style: TextStyle(
                                      fontFamily: 'Lexend',
                                      fontSize: 14,
                                      color: context.textSecondaryColor,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Icon(
                              Icons.lock_outline_rounded,
                              size: 16,
                              color: context.textMutedColor,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

                const SizedBox(height: 20),

                // Inset Grouped Section: Preferences
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Material(
                    color: context.surfaceColor,
                    borderRadius: BorderRadius.circular(16),
                    clipBehavior: Clip.antiAlias,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(color: context.borderColor),
                    ),
                    child: Column(
                    children: [
                      SwitchListTile.adaptive(
                        contentPadding:
                            const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                        title: Text(
                          'Dark Mode',
                          style: TextStyle(
                            fontFamily: 'Lexend',
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                            color: context.textPrimaryColor,
                          ),
                        ),
                        value: context.isDark,
                        activeThumbColor: AppTheme.primary,
                        onChanged: (_) {
                          AppHaptics.medium();
                          ThemeController.toggleTheme();
                        },
                      ),
                      Divider(height: 1, color: context.borderColor),
                      SwitchListTile.adaptive(
                        contentPadding:
                            const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                        title: Text(
                          'Haptic Feedback',
                          style: TextStyle(
                            fontFamily: 'Lexend',
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                            color: context.textPrimaryColor,
                          ),
                        ),
                        value: AppHaptics.enabled,
                        activeThumbColor: AppTheme.primary,
                        onChanged: (val) {
                          setState(() => AppHaptics.enabled = val);
                          AppHaptics.selection();
                        },
                      ),
                    ],
                  ),
                ),
              ),

                const SizedBox(height: 28),

                // Primary Save Button
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _isUpdating ? null : _saveProfile,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _isUpdating
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor:
                                    AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : const Text(
                              'Save',
                              style: TextStyle(
                                fontFamily: 'Lexend',
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                    ),
                  ),
                ),

                const SizedBox(height: 10),

                // Clean Understated Log Out Button
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: TextButton(
                      onPressed: _handleLogout,
                      style: TextButton.styleFrom(
                        foregroundColor: AppTheme.danger,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Log Out',
                        style: TextStyle(
                          fontFamily: 'Lexend',
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 36),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
