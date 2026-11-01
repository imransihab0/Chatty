import 'dart:async';
import 'package:chatty/api/apis.dart';
import 'package:chatty/helper/app_haptics.dart';
import 'package:chatty/helper/app_theme.dart';
import 'package:chatty/helper/dialogs.dart';
import 'package:chatty/screens/home_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// First-Login Username Selection Screen for New Google Users
class UsernameSetupScreen extends StatefulWidget {
  const UsernameSetupScreen({super.key});

  @override
  State<UsernameSetupScreen> createState() => _UsernameSetupScreenState();
}

class _UsernameSetupScreenState extends State<UsernameSetupScreen> {
  final TextEditingController _controller = TextEditingController();
  Timer? _debounceTimer;

  bool _isChecking = false;
  bool? _isAvailable;
  String _statusMessage = '';
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _initSuggestedUsername();
  }

  void _initSuggestedUsername() {
    final curUser = APIs.auth.currentUser;
    final base = curUser?.email?.split('@').first ??
        curUser?.displayName?.toLowerCase().replaceAll(' ', '') ??
        'user';
    final sanitized =
        base.toLowerCase().replaceAll(RegExp(r'[^a-z0-9_]'), '');
    final initial =
        sanitized.length > 20 ? sanitized.substring(0, 20) : sanitized;

    _controller.text = initial;
    _checkAvailability(initial);
  }

  @override
  void dispose() {
    _controller.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  void _onChanged(String val) {
    _debounceTimer?.cancel();
    final clean = val.trim().toLowerCase().replaceAll('@', '');

    if (clean.length < 3) {
      setState(() {
        _isChecking = false;
        _isAvailable = false;
        _statusMessage = 'Username must be at least 3 characters.';
      });
      return;
    }

    if (clean.length > 20) {
      setState(() {
        _isChecking = false;
        _isAvailable = false;
        _statusMessage = 'Username cannot exceed 20 characters.';
      });
      return;
    }

    if (!RegExp(r'^[a-z0-9_]+$').hasMatch(clean)) {
      setState(() {
        _isChecking = false;
        _isAvailable = false;
        _statusMessage =
            'Only lowercase letters, numbers, and underscores allowed.';
      });
      return;
    }

    setState(() {
      _isChecking = true;
      _statusMessage = 'Checking availability...';
    });

    _debounceTimer = Timer(const Duration(milliseconds: 320), () {
      _checkAvailability(clean);
    });
  }

  Future<void> _checkAvailability(String username) async {
    final available = await APIs.isUsernameAvailable(username);
    if (!mounted) return;

    setState(() {
      _isChecking = false;
      _isAvailable = available;
      _statusMessage =
          available ? '✓ @$username is available' : '❌ @$username is taken';
    });
  }

  Future<void> _submitChosen() async {
    final clean = _controller.text.trim().toLowerCase().replaceAll('@', '');
    if (_isAvailable != true) return;

    AppHaptics.medium();
    setState(() => _isSubmitting = true);

    try {
      await APIs.createUser(chosenUsername: clean);
      if (!mounted) return;
      Dialogs.showSnackbar(context, 'Welcome to Chatty, @$clean!');
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
    } catch (e) {
      if (!mounted) return;
      Dialogs.showSnackbar(context, 'Error creating account. Please try again.');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _skipWithRandom() async {
    AppHaptics.light();
    setState(() => _isSubmitting = true);

    try {
      await APIs.createUser();
      if (!mounted) return;
      Dialogs.showSnackbar(
          context, 'Assigned username @${APIs.me.username}. You can change it anytime in Profile.');
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
    } catch (e) {
      if (!mounted) return;
      Dialogs.showSnackbar(context, 'Error creating account. Please try again.');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final canSubmit = _isAvailable == true && !_isChecking && !_isSubmitting;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: context.systemOverlayStyle,
      child: Scaffold(
        backgroundColor: context.backgroundColor,
        appBar: AppBar(
          backgroundColor: context.backgroundColor,
          elevation: 0,
          automaticallyImplyLeading: false,
          actions: [
            TextButton(
              onPressed: _isSubmitting ? null : _skipWithRandom,
              child: Text(
                'Skip',
                style: TextStyle(
                  fontFamily: 'Lexend',
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: context.textSecondaryColor,
                ),
              ),
            ),
          ],
        ),
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                physics: const ClampingScrollPhysics(),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                    child: IntrinsicHeight(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Spacer(flex: 1),

                // Icon Badge
                Center(
                  child: Container(
                    width: 76,
                    height: 76,
                    decoration: BoxDecoration(
                      color: context.surfaceMutedColor,
                      shape: BoxShape.circle,
                      border: Border.all(color: context.borderColor, width: 1),
                    ),
                    child: Center(
                      child: Icon(
                        Icons.alternate_email_rounded,
                        size: 38,
                        color: context.textPrimaryColor,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Heading
                Text(
                  'Choose your username',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'Lexend',
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: context.textPrimaryColor,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 8),

                // Subtitle
                Text(
                  'Your unique handle for friends to find and message you on Chatty.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'Lexend',
                    fontSize: 14,
                    color: context.textSecondaryColor,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 32),

                // Username Input Container
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  decoration: BoxDecoration(
                    color: context.surfaceColor,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: _isAvailable == true
                          ? AppTheme.success
                          : (_isAvailable == false && !_isChecking)
                              ? AppTheme.danger
                              : context.borderColor,
                      width: 1.2,
                    ),
                    boxShadow: context.softShadow,
                  ),
                  child: Row(
                    children: [
                      Text(
                        '@',
                        style: TextStyle(
                          fontFamily: 'Lexend',
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: context.textPrimaryColor,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _controller,
                          autofocus: true,
                          textInputAction: TextInputAction.done,
                          keyboardType: TextInputType.text,
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                                RegExp(r'[a-zA-Z0-9_]')),
                            LengthLimitingTextInputFormatter(20),
                          ],
                          onChanged: _onChanged,
                          onSubmitted: (_) {
                            if (canSubmit) _submitChosen();
                          },
                          style: TextStyle(
                            fontFamily: 'Lexend',
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: context.textPrimaryColor,
                          ),
                          decoration: InputDecoration(
                            border: InputBorder.none,
                            hintText: 'username',
                            hintStyle: TextStyle(
                              fontFamily: 'Lexend',
                              fontSize: 16,
                              color: context.textMutedColor,
                            ),
                          ),
                        ),
                      ),
                      if (_isChecking)
                        const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      else if (_isAvailable == true)
                        const Icon(Icons.check_circle_rounded,
                            color: AppTheme.success, size: 20)
                      else if (_isAvailable == false)
                        const Icon(Icons.error_outline_rounded,
                            color: AppTheme.danger, size: 20),
                    ],
                  ),
                ),

                // Helper / Status message
                Padding(
                  padding: const EdgeInsets.only(left: 6, top: 8),
                  child: Text(
                    _statusMessage.isNotEmpty
                        ? _statusMessage
                        : '3-20 characters: lowercase letters, numbers, underscores.',
                    style: TextStyle(
                      fontFamily: 'Lexend',
                      fontSize: 12.5,
                      fontWeight: FontWeight.w500,
                      color: _isAvailable == true
                          ? AppTheme.success
                          : (_isAvailable == false && !_isChecking)
                              ? AppTheme.danger
                              : context.textMutedColor,
                    ),
                  ),
                ),

                const Spacer(flex: 2),

                // Continue Button
                ElevatedButton(
                  onPressed: canSubmit ? _submitChosen : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        context.isDark ? Colors.white : Colors.black,
                    foregroundColor:
                        context.isDark ? Colors.black : Colors.white,
                    disabledBackgroundColor: (context.isDark
                            ? Colors.white
                            : Colors.black)
                        .withValues(alpha: 0.35),
                    disabledForegroundColor: (context.isDark
                            ? Colors.black
                            : Colors.white)
                        .withValues(alpha: 0.5),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                  child: _isSubmitting
                      ? SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              context.isDark ? Colors.black : Colors.white,
                            ),
                          ),
                        )
                      : const Text(
                          'Continue',
                          style: TextStyle(
                            fontFamily: 'Lexend',
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                ),
                const SizedBox(height: 12),

                // Random unique username button
                TextButton(
                  onPressed: _isSubmitting ? null : _skipWithRandom,
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: Text(
                    'Generate Random Username',
                    style: TextStyle(
                      fontFamily: 'Lexend',
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: context.textSecondaryColor,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    );
  },
),
),
      ),
    );
  }
}
