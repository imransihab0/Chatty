import 'dart:developer';
import 'dart:io';

import 'package:chatty/api/apis.dart';
import 'package:chatty/helper/app_haptics.dart';
import 'package:chatty/helper/app_theme.dart';
import 'package:chatty/helper/dialogs.dart';
import 'package:chatty/main.dart';
import 'package:chatty/screens/auth/username_setup_screen.dart';
import 'package:chatty/screens/home_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  Future<void> _handleGoogleBtnClick() async {
    AppHaptics.medium();
    Dialogs.showProgressbar(context);
    UserCredential? user;
    try {
      user = await _signInWithGoogle();
    } finally {
      if (mounted) Navigator.pop(context);
    }

    if (user != null) {
      log('\nUser: ${user.user}');
      log('\nUserAdditionalInfo: ${user.additionalUserInfo}');

      if (await APIs.userExists()) {
        await APIs.getMyInfo();
        if (!mounted) return;
        Navigator.pushReplacement(
            context, MaterialPageRoute(builder: (_) => const HomeScreen()));
      } else {
        // Brand new user signing up with Google - ask to select username
        if (!mounted) return;
        Navigator.pushReplacement(
            context, MaterialPageRoute(builder: (_) => const UsernameSetupScreen()));
      }
    }
  }

  Future<UserCredential?> _signInWithGoogle() async {
    try {
      try {
        await InternetAddress.lookup('google.com')
            .timeout(const Duration(seconds: 4));
      } catch (_) {
        // Continue to GoogleSignIn even if DNS lookup was slow
      }

      // Trigger the authentication flow with explicit client IDs for Android & iOS
      final GoogleSignIn googleSignIn = GoogleSignIn(
        serverClientId: Platform.isAndroid
            ? '449504252227-9a3orqchqhkq03pgu9ksmnotgr8asbg3.apps.googleusercontent.com'
            : null,
        clientId: Platform.isIOS
            ? '449504252227-dc3g146m0u9mr3ljfkierrknn3geur36.apps.googleusercontent.com'
            : null,
      );

      // Clear any cached stale session to force fresh account selection
      try {
        await googleSignIn.signOut();
      } catch (_) {}

      final GoogleSignInAccount? googleUser = await googleSignIn.signIn();
      if (googleUser == null) return null;

      // Obtain the auth details from the request
      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      log('\nGoogle Auth idToken: ${googleAuth.idToken != null ? "Present" : "NULL"}');
      log('Google Auth accessToken: ${googleAuth.accessToken != null ? "Present" : "NULL"}');

      // Create a new credential
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Once signed in, return the UserCredential
      return await APIs.auth.signInWithCredential(credential);
    } catch (e, stack) {
      log('\n_signInWithGoogle error: $e');
      log('StackTrace: $stack');
      debugPrint('\n==================== [DETAILED GOOGLE SIGN IN ERROR] ====================');
      debugPrint('ERROR: $e');
      debugPrint('ERROR TYPE: ${e.runtimeType}');
      debugPrint('STACK TRACE:\n$stack');
      debugPrint('=========================================================================\n');
      if (mounted) {
        final errorMsg = e.toString();
        if (errorMsg.contains('10') || errorMsg.contains('sign_in_failed')) {
          Dialogs.showSnackbar(context,
              'Sign in failed: SHA-1 certificate must be added in Firebase Console');
        } else {
          Dialogs.showSnackbar(
              context, 'Sign in error: ${errorMsg.split(']').last.trim()}');
        }
      }
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    mq = size;
    final double logoSize = (size.width * 0.35).clamp(100.0, 136.0);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: context.systemOverlayStyle,
      child: Scaffold(
        backgroundColor: context.backgroundColor,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              physics: const ClampingScrollPhysics(),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: size.width * 0.08),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const SizedBox(height: 20),
                      // Hero Brand Info
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: logoSize,
                            height: logoSize,
                            decoration: BoxDecoration(
                              color: context.surfaceColor,
                              borderRadius: BorderRadius.circular(32),
                              boxShadow: context.softShadow,
                            ),
                            padding: const EdgeInsets.all(20),
                            child: Image.asset('images/icon.png',
                                fit: BoxFit.contain),
                          ),
                          const SizedBox(height: 28),
                          Text(
                            'Welcome to Chatty',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontFamily: 'Lexend',
                              fontSize: 28,
                              fontWeight: FontWeight.w800,
                              color: context.textPrimaryColor,
                              letterSpacing: -0.5,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'The fast, modern, and secure way to message your favorite people.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontFamily: 'Lexend',
                              fontSize: 15,
                              fontWeight: FontWeight.w400,
                              color: context.textSecondaryColor,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),

                      // Bottom Actions
                      Padding(
                        padding: const EdgeInsets.only(top: 24, bottom: 28),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Google Sign-In Button with working InkWell ripple
                            Material(
                              color: context.surfaceColor,
                              borderRadius: BorderRadius.circular(16),
                              elevation: 0,
                              child: InkWell(
                                onTap: _handleGoogleBtnClick,
                                borderRadius: BorderRadius.circular(16),
                                child: Container(
                                  width: double.infinity,
                                  height: 56,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                        color: context.borderColor,
                                        width: 1.5),
                                    boxShadow: context.softShadow,
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Image.asset('images/google.png',
                                          height: 26),
                                      const SizedBox(width: 12),
                                      Text(
                                        'Continue with Google',
                                        style: TextStyle(
                                          fontFamily: 'Lexend',
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                          color: context.textPrimaryColor,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 20),
                            Text(
                              'By continuing, you agree to Chatty\'s Terms & Privacy Policy',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontFamily: 'Lexend',
                                fontSize: 11,
                                color: context.textSecondaryColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
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