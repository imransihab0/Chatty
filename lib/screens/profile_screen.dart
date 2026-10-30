import 'dart:developer';
import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:chatty/api/apis.dart';
import 'package:chatty/helper/app_haptics.dart';
import 'package:chatty/helper/app_theme.dart';
import 'package:chatty/helper/dialogs.dart';
import 'package:chatty/helper/my_date_util.dart';
import 'package:chatty/models/chat_user.dart';
import 'package:chatty/screens/auth/login_screen.dart';
import 'package:chatty/screens/media_viewer_screen.dart';
import 'package:chatty/services/theme_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:image_picker/image_picker.dart';

/// Ultra-Modern, Redesigned Profile Screen for Chatty
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
  bool _hapticsEnabled = true;

  void _handleLogout() async {
    AppHaptics.heavy();
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: context.surfaceColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.danger.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.logout_rounded,
                color: AppTheme.danger,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              'Log Out',
              style: TextStyle(
                fontFamily: 'Lexend',
                fontWeight: FontWeight.w700,
                fontSize: 19,
                color: context.textPrimaryColor,
              ),
            ),
          ],
        ),
        content: Text(
          'Are you sure you want to log out of your Chatty account?',
          style: TextStyle(
            fontFamily: 'Lexend',
            fontSize: 14,
            color: context.textSecondaryColor,
          ),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
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
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
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

  void _copyToClipboard(String text, String message) {
    Clipboard.setData(ClipboardData(text: text));
    AppHaptics.light();
    Dialogs.showSnackbar(context, message);
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context).size;
    final String joinedDate = MyDateUtil.getJoinedDate(widget.user.createdAt);

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
            'My Profile',
            style: TextStyle(
              fontFamily: 'Lexend',
              fontWeight: FontWeight.w700,
              fontSize: 20,
              color: context.textPrimaryColor,
            ),
          ),
          actions: [
            IconButton(
              splashRadius: 22,
              tooltip: context.isDark ? 'Light Mode' : 'Dark Mode',
              icon: Icon(
                context.isDark
                    ? Icons.light_mode_rounded
                    : Icons.dark_mode_rounded,
                color: context.textPrimaryColor,
                size: 22,
              ),
              onPressed: () {
                AppHaptics.medium();
                ThemeController.toggleTheme();
              },
            ),
            const SizedBox(width: 8),
          ],
        ),
        body: Form(
          key: _formKey,
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Top Cover Banner + Overlapping Avatar Hero
                _buildCoverAndAvatar(context, mq),

                // Name, Verified Badge & Email Chip
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Flexible(
                            child: Text(
                              widget.user.name,
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontFamily: 'Lexend',
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.5,
                                color: context.textPrimaryColor,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Icon(
                            Icons.verified_rounded,
                            color: AppTheme.primary,
                            size: 20,
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),

                      // Email copyable chip
                      InkWell(
                        borderRadius: BorderRadius.circular(20),
                        onTap: () => _copyToClipboard(
                            widget.user.email, 'Email copied to clipboard!'),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: context.surfaceMutedColor,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: context.borderColor),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.alternate_email_rounded,
                                size: 14,
                                color: context.textSecondaryColor,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                widget.user.email,
                                style: TextStyle(
                                  fontFamily: 'Lexend',
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  color: context.textSecondaryColor,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Icon(
                                Icons.copy_rounded,
                                size: 12,
                                color: context.textMutedColor,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // Quick Statistics Strip (Status, Member Since, Security)
                _buildStatsStrip(context, joinedDate),

                const SizedBox(height: 24),

                // Section 1: Account Information Card
                _buildSectionCard(
                  context,
                  title: 'ACCOUNT DETAILS',
                  children: [
                    _buildTextField(
                      label: 'Display Name',
                      initialValue: widget.user.name,
                      icon: Icons.person_outline_rounded,
                      hint: 'Your full name',
                      onSaved: (val) => APIs.me.name = val ?? '',
                      validator: (val) => val != null && val.trim().isNotEmpty
                          ? null
                          : 'Name cannot be empty',
                    ),
                    const SizedBox(height: 18),
                    _buildTextField(
                      label: 'About / Status Bio',
                      initialValue: widget.user.about,
                      icon: Icons.chat_bubble_outline_rounded,
                      hint: "Hey, I'm using Chatty!",
                      maxLines: 2,
                      onSaved: (val) => APIs.me.about = val ?? '',
                      validator: (val) => val != null && val.trim().isNotEmpty
                          ? null
                          : 'About cannot be empty',
                    ),
                    const SizedBox(height: 18),
                    _buildReadOnlyField(
                      context,
                      label: 'Google Account',
                      value: widget.user.email,
                      icon: Icons.mail_outline_rounded,
                      badge: 'Linked',
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                // Section 2: Preferences & Appearance Card
                _buildSectionCard(
                  context,
                  title: 'PREFERENCES & EXPERIENCE',
                  children: [
                    // Dark Mode Setting Tile
                    _buildSettingsTile(
                      context,
                      icon: context.isDark
                          ? Icons.dark_mode_rounded
                          : Icons.light_mode_rounded,
                      iconColor: AppTheme.primary,
                      title: 'Dark Theme',
                      subtitle: context.isDark
                          ? 'Deep contrast & dark slate UI'
                          : 'Clean bright daylight mode',
                      trailing: Switch.adaptive(
                        value: context.isDark,
                        activeThumbColor: AppTheme.primary,
                        onChanged: (_) {
                          AppHaptics.medium();
                          ThemeController.toggleTheme();
                        },
                      ),
                    ),
                    const Divider(height: 24),

                    // Tactile Haptic Feedback Tile
                    _buildSettingsTile(
                      context,
                      icon: Icons.vibration_rounded,
                      iconColor: const Color(0xFF0EA5E9),
                      title: 'Tactile Haptics',
                      subtitle: 'Subtle clicks on messages & buttons',
                      trailing: Switch.adaptive(
                        value: _hapticsEnabled,
                        activeThumbColor: AppTheme.primary,
                        onChanged: (val) {
                          AppHaptics.selection();
                          setState(() => _hapticsEnabled = val);
                        },
                      ),
                    ),
                    const Divider(height: 24),

                    // Chat Wallpaper Tile
                    _buildSettingsTile(
                      context,
                      icon: Icons.palette_outlined,
                      iconColor: const Color(0xFF10B981),
                      title: 'Chat Doodle Wallpaper',
                      subtitle: 'Adapts dynamically to Light & Dark themes',
                      trailing: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppTheme.success.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
                          'Active',
                          style: TextStyle(
                            fontFamily: 'Lexend',
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.success,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // Section 3: Action Buttons (Save Changes & Logout)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    children: [
                      // Save Changes Button
                      Container(
                        width: double.infinity,
                        height: 54,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [AppTheme.primary, Color(0xFF6366F1)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: AppTheme.buttonShadow,
                        ),
                        child: ElevatedButton(
                          onPressed: _isUpdating
                              ? null
                              : () async {
                                  if (_formKey.currentState!.validate()) {
                                    _formKey.currentState!.save();
                                    AppHaptics.medium();
                                    setState(() => _isUpdating = true);
                                    await APIs.updateUserInfo();
                                    setState(() => _isUpdating = false);
                                    if (!context.mounted) return;
                                    AppHaptics.light();
                                    Dialogs.showSnackbar(
                                      context,
                                      'Profile updated successfully!',
                                    );
                                  }
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: _isUpdating
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                        Colors.white),
                                  ),
                                )
                              : const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.check_circle_rounded, size: 20),
                                    SizedBox(width: 8),
                                    Text(
                                      'Save Changes',
                                      style: TextStyle(
                                        fontFamily: 'Lexend',
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      ),

                      const SizedBox(height: 14),

                      // Log Out Button
                      InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: _handleLogout,
                        child: Container(
                          width: double.infinity,
                          height: 52,
                          decoration: BoxDecoration(
                            color: AppTheme.danger.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: AppTheme.danger.withValues(alpha: 0.25),
                              width: 1.2,
                            ),
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.logout_rounded,
                                  color: AppTheme.danger, size: 20),
                              SizedBox(width: 8),
                              Text(
                                'Log Out of Chatty',
                                style: TextStyle(
                                  fontFamily: 'Lexend',
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.danger,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 28),

                // App Footer Tag
                Text(
                  'Chatty v2.4 • Clean Architecture',
                  style: TextStyle(
                    fontFamily: 'Lexend',
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: context.textMutedColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'End-to-End Encrypted Messaging',
                  style: TextStyle(
                    fontFamily: 'Lexend',
                    fontSize: 11,
                    color: context.textMutedColor.withValues(alpha: 0.7),
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

  // Cover Banner with Hero Avatar and Docked Camera Action Badge
  Widget _buildCoverAndAvatar(BuildContext context, Size mq) {
    const double avatarRadius = 58;

    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.center,
      children: [
        // Decorative Gradient Cover Banner
        Container(
          height: 110,
          width: double.infinity,
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppTheme.primary,
                AppTheme.primary.withValues(alpha: 0.8),
                const Color(0xFF0EA5E9),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: AppTheme.primary.withValues(alpha: 0.25),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Stack(
            children: [
              // Decorative ambient circles
              Positioned(
                top: -20,
                right: -20,
                child: Container(
                  width: 90,
                  height: 90,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.12),
                  ),
                ),
              ),
              Positioned(
                bottom: -15,
                left: 20,
                child: Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.08),
                  ),
                ),
              ),
            ],
          ),
        ),

        // Elevated Floating Avatar
        Padding(
          padding: const EdgeInsets.only(top: 48),
          child: Stack(
            children: [
              // Avatar container
              GestureDetector(
                onTap: () {
                  AppHaptics.light();
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
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: context.surfaceColor,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(
                              alpha: context.isDark ? 0.4 : 0.12),
                          blurRadius: 18,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(avatarRadius),
                      child: _image != null
                          ? Image.file(
                              File(_image!),
                              width: avatarRadius * 2,
                              height: avatarRadius * 2,
                              fit: BoxFit.cover,
                            )
                          : CachedNetworkImage(
                              width: avatarRadius * 2,
                              height: avatarRadius * 2,
                              fit: BoxFit.cover,
                              imageUrl: widget.user.image,
                              placeholder: (context, url) => Container(
                                width: avatarRadius * 2,
                                height: avatarRadius * 2,
                                color: context.surfaceMutedColor,
                                child: const Center(
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2.5),
                                ),
                              ),
                              errorWidget: (context, url, error) =>
                                  CircleAvatar(
                                radius: avatarRadius,
                                backgroundColor: context.primarySoftColor,
                                child: Text(
                                  widget.user.name.isNotEmpty
                                      ? widget.user.name[0].toUpperCase()
                                      : '?',
                                  style: const TextStyle(
                                    fontFamily: 'Lexend',
                                    fontSize: 42,
                                    fontWeight: FontWeight.w700,
                                    color: AppTheme.primary,
                                  ),
                                ),
                              ),
                            ),
                    ),
                  ),
                ),
              ),

              // Docked Camera Edit Badge Button
              Positioned(
                bottom: 2,
                right: 2,
                child: GestureDetector(
                  onTap: _showBottomSheet,
                  child: Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [AppTheme.primary, Color(0xFF6366F1)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      shape: BoxShape.circle,
                      border: Border.all(color: context.surfaceColor, width: 3),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.primary.withValues(alpha: 0.4),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
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
      ],
    );
  }

  // Quick Statistics / Metrics Row
  Widget _buildStatsStrip(BuildContext context, String joinedDate) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: context.borderColor),
        boxShadow: context.softShadow,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _statItem(
            context,
            icon: Icons.circle,
            iconColor: AppTheme.success,
            iconSize: 10,
            title: 'Status',
            value: 'Online',
          ),
          Container(width: 1, height: 32, color: context.borderColor),
          _statItem(
            context,
            icon: Icons.calendar_today_rounded,
            iconColor: AppTheme.primary,
            iconSize: 15,
            title: 'Joined',
            value: joinedDate,
          ),
          Container(width: 1, height: 32, color: context.borderColor),
          _statItem(
            context,
            icon: Icons.shield_rounded,
            iconColor: const Color(0xFF0EA5E9),
            iconSize: 16,
            title: 'Security',
            value: 'Verified',
          ),
        ],
      ),
    );
  }

  Widget _statItem(
    BuildContext context, {
    required IconData icon,
    required Color iconColor,
    required double iconSize,
    required String title,
    required String value,
  }) {
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: iconSize, color: iconColor),
            const SizedBox(width: 5),
            Text(
              value,
              style: TextStyle(
                fontFamily: 'Lexend',
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: context.textPrimaryColor,
              ),
            ),
          ],
        ),
        const SizedBox(height: 3),
        Text(
          title,
          style: TextStyle(
            fontFamily: 'Lexend',
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: context.textMutedColor,
          ),
        ),
      ],
    );
  }

  // Section Group Container Card
  Widget _buildSectionCard(
    BuildContext context, {
    required String title,
    required List<Widget> children,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 6, bottom: 8),
            child: Text(
              title,
              style: TextStyle(
                fontFamily: 'Lexend',
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
                color: context.textSecondaryColor,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: context.surfaceColor,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: context.borderColor),
              boxShadow: context.softShadow,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: children,
            ),
          ),
        ],
      ),
    );
  }

  // Reusable Form Text Field
  Widget _buildTextField({
    required String label,
    required String initialValue,
    required IconData icon,
    required String hint,
    int maxLines = 1,
    required FormFieldSetter<String> onSaved,
    required FormFieldValidator<String> validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontFamily: 'Lexend',
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: context.textSecondaryColor,
          ),
        ),
        const SizedBox(height: 7),
        TextFormField(
          initialValue: initialValue,
          maxLines: maxLines,
          onSaved: onSaved,
          validator: validator,
          style: TextStyle(
            fontFamily: 'Lexend',
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: context.textPrimaryColor,
          ),
          decoration: InputDecoration(
            prefixIcon: Icon(icon, color: AppTheme.primary, size: 20),
            filled: true,
            fillColor: context.surfaceMutedColor,
            hintText: hint,
            hintStyle: TextStyle(
              fontFamily: 'Lexend',
              fontSize: 13,
              color: context.textMutedColor,
            ),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: context.borderColor),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: context.borderColor),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: AppTheme.primary, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }

  // Read-only info tile (e.g., Google managed account)
  Widget _buildReadOnlyField(
    BuildContext context, {
    required String label,
    required String value,
    required IconData icon,
    required String badge,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontFamily: 'Lexend',
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: context.textSecondaryColor,
          ),
        ),
        const SizedBox(height: 7),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: context.surfaceMutedColor,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: context.borderColor),
          ),
          child: Row(
            children: [
              Icon(icon, color: context.textSecondaryColor, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  value,
                  style: TextStyle(
                    fontFamily: 'Lexend',
                    fontSize: 13,
                    color: context.textSecondaryColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: context.primarySoftColor,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.lock_rounded,
                        size: 11, color: AppTheme.primary),
                    const SizedBox(width: 4),
                    Text(
                      badge,
                      style: const TextStyle(
                        fontFamily: 'Lexend',
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // Settings Row Tile
  Widget _buildSettingsTile(
    BuildContext context, {
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required Widget trailing,
  }) {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: iconColor, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontFamily: 'Lexend',
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: context.textPrimaryColor,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(
                  fontFamily: 'Lexend',
                  fontSize: 12,
                  color: context.textSecondaryColor,
                ),
              ),
            ],
          ),
        ),
        trailing,
      ],
    );
  }

  // Modern Bottom Sheet for Image Picker & View
  void _showBottomSheet() {
    AppHaptics.medium();
    showModalBottomSheet(
      context: context,
      backgroundColor: context.surfaceColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Top drag pill
                Container(
                  width: 44,
                  height: 4.5,
                  decoration: BoxDecoration(
                    color: context.borderColor,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Change Profile Photo',
                  style: TextStyle(
                    fontFamily: 'Lexend',
                    fontSize: 19,
                    fontWeight: FontWeight.w700,
                    color: context.textPrimaryColor,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Upload a photo to represent your profile on Chatty',
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
                      icon: Icons.camera_alt_rounded,
                      color: AppTheme.primary,
                      label: 'Take Photo',
                      onTap: () async {
                        AppHaptics.selection();
                        Navigator.pop(context);
                        final ImagePicker picker = ImagePicker();
                        final XFile? image = await picker.pickImage(
                          source: ImageSource.camera,
                          imageQuality: 70,
                        );
                        if (image != null) {
                          log('Camera Image: ${image.path}');
                          setState(() => _image = image.path);
                          final success = await APIs.updateProfilePicture(
                              File(_image!));
                          if (!mounted) return;
                          if (success) {
                            AppHaptics.light();
                            Dialogs.showSnackbar(
                                context, 'Profile photo updated!');
                          } else {
                            Dialogs.showSnackbar(
                              context,
                              'Failed to upload photo. Storage quota may be exceeded.',
                            );
                          }
                        }
                      },
                    ),
                    _pickerOption(
                      icon: Icons.photo_library_rounded,
                      color: const Color(0xFF0EA5E9),
                      label: 'Choose Gallery',
                      onTap: () async {
                        AppHaptics.selection();
                        Navigator.pop(context);
                        final ImagePicker picker = ImagePicker();
                        final XFile? image = await picker.pickImage(
                          source: ImageSource.gallery,
                          imageQuality: 70,
                        );
                        if (image != null) {
                          log('Gallery Image: ${image.path}');
                          setState(() => _image = image.path);
                          final success = await APIs.updateProfilePicture(
                              File(_image!));
                          if (!mounted) return;
                          if (success) {
                            AppHaptics.light();
                            Dialogs.showSnackbar(
                                context, 'Profile photo updated!');
                          } else {
                            Dialogs.showSnackbar(
                              context,
                              'Failed to upload photo. Storage quota may be exceeded.',
                            );
                          }
                        }
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _pickerOption({
    required IconData icon,
    required Color color,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.40,
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: context.surfaceMutedColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: context.borderColor),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.14),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(height: 10),
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Lexend',
                fontSize: 13,
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
