import 'package:chatty/api/apis.dart';
import 'package:chatty/helper/app_theme.dart';
import 'package:chatty/main.dart';
import 'package:chatty/screens/auth/login_screen.dart';
import 'package:chatty/screens/home_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// ---------------------------------------------------------------------------
/// MODERN PROFESSIONAL SPLASH SCREEN
/// Features:
/// - Apple-grade spring scale & staggered fade-in entrance
/// - Ambient obsidian / pearl depth backdrop
/// - Titanium 3D app icon presentation with soft ambient glow
/// - Clean privacy & encryption footer
/// ---------------------------------------------------------------------------
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animController;
  late final Animation<double> _iconScale;
  late final Animation<double> _iconFade;
  late final Animation<double> _textFade;
  late final Animation<double> _footerFade;

  @override
  void initState() {
    super.initState();

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    );

    _iconScale = Tween<double>(begin: 0.88, end: 1.0).animate(
      CurvedAnimation(
        parent: _animController,
        curve: Curves.easeOutBack,
      ),
    );

    _iconFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animController,
        curve: const Interval(0.0, 0.60, curve: Curves.easeOut),
      ),
    );

    _textFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animController,
        curve: const Interval(0.25, 0.85, curve: Curves.easeOut),
      ),
    );

    _footerFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animController,
        curve: const Interval(0.50, 1.0, curve: Curves.easeOut),
      ),
    );

    _animController.forward();

    Future.delayed(const Duration(milliseconds: 1900), () {
      if (!mounted) return;
      final targetScreen = APIs.auth.currentUser != null
          ? const HomeScreen()
          : const LoginScreen();

      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          pageBuilder: (_, __, ___) => targetScreen,
          transitionsBuilder: (_, animation, __, child) =>
              FadeTransition(opacity: animation, child: child),
          transitionDuration: const Duration(milliseconds: 380),
        ),
      );
    });
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    mq = MediaQuery.sizeOf(context);
    final logoSize = (mq.width * 0.36).clamp(112.0, 150.0);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: context.systemOverlayStyle,
      child: Scaffold(
        backgroundColor: context.backgroundColor,
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: context.isDark
                  ? const [
                      Color(0xFF000000),
                      Color(0xFF090A0D),
                      Color(0xFF040406),
                    ]
                  : const [
                      Color(0xFFFFFFFF),
                      Color(0xFFF7F7FA),
                      Color(0xFFF0F0F4),
                    ],
            ),
          ),
          child: SafeArea(
            child: SizedBox.expand(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(height: 40),

                  // Center Brand Presentation
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      FadeTransition(
                        opacity: _iconFade,
                        child: ScaleTransition(
                          scale: _iconScale,
                          child: Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: (context.isDark
                                          ? Colors.white
                                          : Colors.black)
                                      .withValues(
                                          alpha: context.isDark ? 0.08 : 0.05),
                                  blurRadius: 40,
                                  spreadRadius: 8,
                                ),
                              ],
                            ),
                            child: SizedBox(
                              width: logoSize,
                              height: logoSize,
                              child: Image.asset(
                                'images/icon.png',
                                fit: BoxFit.contain,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 26),

                      // App Name & Tagline
                      FadeTransition(
                        opacity: _textFade,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Chatty',
                              style: TextStyle(
                                fontFamily: AppTypography.fontFamily,
                                fontSize: 34,
                                fontWeight: FontWeight.w800,
                                color: context.textPrimaryColor,
                                letterSpacing: -0.6,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Real-time messaging, redefined',
                              style: TextStyle(
                                fontFamily: AppTypography.fontFamily,
                                fontSize: 14.5,
                                fontWeight: FontWeight.w400,
                                color: context.textSecondaryColor,
                                letterSpacing: 0.2,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  // Professional Security Footer
                  FadeTransition(
                    opacity: _footerFade,
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 28.0),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.lock_outline_rounded,
                            size: 13.5,
                            color: context.textMutedColor,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'End-to-End Encrypted',
                            style: TextStyle(
                              fontFamily: AppTypography.fontFamily,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              letterSpacing: 0.5,
                              color: context.textMutedColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
