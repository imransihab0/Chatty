import 'dart:developer';
import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:chatty/api/apis.dart';
import 'package:chatty/helper/app_theme.dart';
import 'package:chatty/helper/dialogs.dart';
import 'package:chatty/main.dart';
import 'package:chatty/models/chat_user.dart';
import 'package:chatty/screens/auth/login_screen.dart';
import 'package:chatty/services/theme_controller.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:image_picker/image_picker.dart';

// Modern Profile Screen
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
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Log Out',
          style: TextStyle(
            fontFamily: 'Lexend',
            fontWeight: FontWeight.w700,
            color: AppTheme.textPrimary,
          ),
        ),
        content: const Text(
          'Are you sure you want to log out of Chatty?',
          style: TextStyle(
            fontFamily: 'Lexend',
            fontSize: 14,
            color: AppTheme.textSecondary,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(
              'Cancel',
              style: TextStyle(
                fontFamily: 'Lexend',
                color: AppTheme.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.danger,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
              elevation: 0,
            ),
            onPressed: () => Navigator.pop(context, true),
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
        (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        backgroundColor: context.backgroundColor,
        appBar: AppBar(
          backgroundColor: context.surfaceColor,
          elevation: 0,
          leading: IconButton(
            splashRadius: 22,
            icon: Icon(Icons.arrow_back_rounded,
                color: context.textPrimaryColor),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(
            'Profile',
            style: TextStyle(
              fontFamily: 'Lexend',
              fontWeight: FontWeight.w700,
              fontSize: 20,
              color: context.textPrimaryColor,
            ),
          ),
        ),
        body: Form(
          key: _formKey,
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: EdgeInsets.symmetric(
                horizontal: mq.width * .06, vertical: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Avatar with Edit Button
                Center(
                  child: Stack(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                              color: AppTheme.primaryLight, width: 2.5),
                          boxShadow: context.softShadow,
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(65),
                          child: _image != null
                              ? Image.file(
                                  File(_image!),
                                  width: 120,
                                  height: 120,
                                  fit: BoxFit.cover,
                                )
                              : CachedNetworkImage(
                                  width: 120,
                                  height: 120,
                                  fit: BoxFit.cover,
                                  imageUrl: widget.user.image,
                                  placeholder: (context, url) => Container(
                                    width: 120,
                                    height: 120,
                                    color: context.surfaceMutedColor,
                                    child: const Center(
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2.5),
                                    ),
                                  ),
                                  errorWidget: (context, url, error) =>
                                      CircleAvatar(
                                    radius: 60,
                                    backgroundColor: context.primarySoftColor,
                                    child: Text(
                                      widget.user.name.isNotEmpty
                                          ? widget.user.name[0].toUpperCase()
                                          : '?',
                                      style: const TextStyle(
                                        fontFamily: 'Lexend',
                                        fontSize: 44,
                                        fontWeight: FontWeight.w700,
                                        color: AppTheme.primary,
                                      ),
                                    ),
                                  ),
                                ),
                        ),
                      ),
                      Positioned(
                        bottom: 0,
                        right: 4,
                        child: GestureDetector(
                          onTap: _showBottomSheet,
                          child: Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: AppTheme.primary,
                              shape: BoxShape.circle,
                              border: Border.all(color: context.surfaceColor, width: 3),
                              boxShadow: context.softShadow,
                            ),
                            child: const Icon(
                              Icons.camera_alt_rounded,
                              color: Colors.white,
                              size: 18,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Name & Email Header
                Text(
                  widget.user.name,
                  style: TextStyle(
                    fontFamily: 'Lexend',
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: context.textPrimaryColor,
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
                const SizedBox(height: 30),

                // Form Fields Container
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: context.surfaceColor,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: context.borderColor, width: 1),
                    boxShadow: context.softShadow,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Display Name',
                        style: TextStyle(
                          fontFamily: 'Lexend',
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: context.textSecondaryColor,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        initialValue: widget.user.name,
                        onSaved: (val) => APIs.me.name = val ?? '',
                        validator: (val) =>
                            val != null && val.trim().isNotEmpty
                                ? null
                                : 'Name cannot be empty',
                        style: TextStyle(
                          fontFamily: 'Lexend',
                          fontSize: 14,
                          color: context.textPrimaryColor,
                        ),
                        decoration: InputDecoration(
                          prefixIcon: const Icon(Icons.person_outline_rounded,
                              color: AppTheme.primary, size: 20),
                          filled: true,
                          fillColor: context.surfaceMutedColor,
                          hintText: 'Enter your name',
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 14),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),

                      Text(
                        'About',
                        style: TextStyle(
                          fontFamily: 'Lexend',
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: context.textSecondaryColor,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        initialValue: widget.user.about,
                        onSaved: (val) => APIs.me.about = val ?? '',
                        validator: (val) =>
                            val != null && val.trim().isNotEmpty
                                ? null
                                : 'About cannot be empty',
                        style: TextStyle(
                          fontFamily: 'Lexend',
                          fontSize: 14,
                          color: context.textPrimaryColor,
                        ),
                        decoration: InputDecoration(
                          prefixIcon: const Icon(Icons.info_outline_rounded,
                              color: AppTheme.primary, size: 20),
                          filled: true,
                          fillColor: context.surfaceMutedColor,
                          hintText: "Hey, I'm using Chatty!",
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 14),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Appearance Card (Dark Mode Toggle)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  decoration: BoxDecoration(
                    color: context.surfaceColor,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: context.borderColor, width: 1),
                    boxShadow: context.softShadow,
                  ),
                  child: SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      'Dark Mode',
                      style: TextStyle(
                        fontFamily: 'Lexend',
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: context.textPrimaryColor,
                      ),
                    ),
                    subtitle: Text(
                      'Switch between light and dark theme',
                      style: TextStyle(
                        fontFamily: 'Lexend',
                        fontSize: 12,
                        color: context.textSecondaryColor,
                      ),
                    ),
                    secondary: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: context.primarySoftColor,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        context.isDark
                            ? Icons.dark_mode_rounded
                            : Icons.light_mode_rounded,
                        color: AppTheme.primary,
                        size: 20,
                      ),
                    ),
                    activeThumbColor: AppTheme.primary,
                    value: context.isDark,
                    onChanged: (_) => ThemeController.toggleTheme(),
                  ),
                ),
                const SizedBox(height: 24),

                // Save button
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _isUpdating
                        ? null
                        : () async {
                            if (_formKey.currentState!.validate()) {
                              _formKey.currentState!.save();
                              setState(() => _isUpdating = true);
                              await APIs.updateUserInfo();
                              setState(() => _isUpdating = false);
                              if (!context.mounted) return;
                              Dialogs.showSnackbar(
                                  context, 'Profile updated successfully!');
                            }
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      elevation: 0,
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
                        : const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.check_rounded, size: 20),
                              SizedBox(width: 8),
                              Text(
                                'Save Changes',
                                style: TextStyle(
                                  fontFamily: 'Lexend',
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
                const SizedBox(height: 16),

                // Logout button
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: OutlinedButton.icon(
                    onPressed: _handleLogout,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.danger,
                      side: BorderSide(
                          color: AppTheme.danger.withValues(alpha: 0.3), width: 1.5),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    icon: const Icon(Icons.logout_rounded, size: 20),
                    label: const Text(
                      'Log Out',
                      style: TextStyle(
                        fontFamily: 'Lexend',
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Modern Bottom Sheet for Image Picker
  void _showBottomSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: context.surfaceColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: context.borderColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  'Change Profile Picture',
                  style: TextStyle(
                    fontFamily: 'Lexend',
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: context.textPrimaryColor,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Select a photo from your gallery or capture a new one',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'Lexend',
                    fontSize: 13,
                    color: context.textSecondaryColor,
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _pickerOption(
                      icon: Icons.photo_library_rounded,
                      label: 'Gallery',
                      onTap: () async {
                        Navigator.pop(context);
                        final ImagePicker picker = ImagePicker();
                        final XFile? image = await picker.pickImage(
                            source: ImageSource.gallery, imageQuality: 40);
                        if (image != null) {
                          log('Image Path: ${image.path}');
                          setState(() => _image = image.path);
                          final success = await APIs.updateProfilePicture(File(_image!));
                          if (!mounted) return;
                          if (success) {
                            Dialogs.showSnackbar(
                                context, 'Profile picture updated!');
                          } else {
                            Dialogs.showSnackbar(
                                context, 'Failed to update photo. Storage quota may be exceeded.');
                          }
                        }
                      },
                    ),
                    _pickerOption(
                      icon: Icons.camera_alt_rounded,
                      label: 'Camera',
                      onTap: () async {
                        Navigator.pop(context);
                        final ImagePicker picker = ImagePicker();
                        final XFile? image = await picker.pickImage(
                            source: ImageSource.camera, imageQuality: 40);
                        if (image != null) {
                          log('Image Path: ${image.path}');
                          setState(() => _image = image.path);
                          final success = await APIs.updateProfilePicture(File(_image!));
                          if (!mounted) return;
                          if (success) {
                            Dialogs.showSnackbar(
                                context, 'Profile picture updated!');
                          } else {
                            Dialogs.showSnackbar(
                                context, 'Failed to update photo. Storage quota may be exceeded.');
                          }
                        }
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _pickerOption({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: mq.width * 0.38,
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: context.surfaceMutedColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: context.borderColor),
        ),
        child: Column(
          children: [
            Icon(icon, color: AppTheme.primary, size: 36),
            const SizedBox(height: 10),
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Lexend',
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: context.textPrimaryColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}