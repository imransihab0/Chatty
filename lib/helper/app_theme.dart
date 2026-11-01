import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// ---------------------------------------------------------------------------
/// 4-POINT SPACING SYSTEM (AppSpacing)
/// Consistent 4-point spacing scale across the entire application.
/// ---------------------------------------------------------------------------
class AppSpacing {
  AppSpacing._();

  static const double xxs = 2.0;
  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 12.0;
  static const double lg = 16.0;
  static const double xl = 20.0;
  static const double xxl = 24.0;
  static const double xxxl = 32.0;
  static const double huge = 40.0;
  static const double massive = 48.0;

  // Reusable Edge Insets
  static const EdgeInsets zero = EdgeInsets.zero;
  static const EdgeInsets screenPadding = EdgeInsets.symmetric(horizontal: lg, vertical: md);
  static const EdgeInsets screenHorizontal = EdgeInsets.symmetric(horizontal: lg);
  static const EdgeInsets cardPadding = EdgeInsets.all(lg);
  static const EdgeInsets cardPaddingDense = EdgeInsets.symmetric(horizontal: 14.0, vertical: 10.0);
  static const EdgeInsets listItemPadding = EdgeInsets.symmetric(horizontal: lg, vertical: 10.0);
  static const EdgeInsets buttonPadding = EdgeInsets.symmetric(horizontal: xl, vertical: md);
  static const EdgeInsets pillPadding = EdgeInsets.symmetric(horizontal: 14.0, vertical: 6.0);
  static const EdgeInsets bubblePaddingText = EdgeInsets.fromLTRB(13.0, 8.0, 13.0, 7.0);
  static const EdgeInsets bubblePaddingMedia = EdgeInsets.all(4.0);

  // Reusable Spacers (Width Gaps)
  static const SizedBox gapW2 = SizedBox(width: xxs);
  static const SizedBox gapW4 = SizedBox(width: xs);
  static const SizedBox gapW6 = SizedBox(width: 6.0);
  static const SizedBox gapW8 = SizedBox(width: sm);
  static const SizedBox gapW10 = SizedBox(width: 10.0);
  static const SizedBox gapW12 = SizedBox(width: md);
  static const SizedBox gapW14 = SizedBox(width: 14.0);
  static const SizedBox gapW16 = SizedBox(width: lg);
  static const SizedBox gapW20 = SizedBox(width: xl);
  static const SizedBox gapW24 = SizedBox(width: xxl);

  // Reusable Spacers (Height Gaps)
  static const SizedBox gapH2 = SizedBox(height: xxs);
  static const SizedBox gapH4 = SizedBox(height: xs);
  static const SizedBox gapH6 = SizedBox(height: 6.0);
  static const SizedBox gapH8 = SizedBox(height: sm);
  static const SizedBox gapH10 = SizedBox(height: 10.0);
  static const SizedBox gapH12 = SizedBox(height: md);
  static const SizedBox gapH14 = SizedBox(height: 14.0);
  static const SizedBox gapH16 = SizedBox(height: lg);
  static const SizedBox gapH20 = SizedBox(height: xl);
  static const SizedBox gapH24 = SizedBox(height: xxl);
  static const SizedBox gapH32 = SizedBox(height: xxxl);
  static const SizedBox gapH40 = SizedBox(height: huge);
  static const SizedBox gapH48 = SizedBox(height: massive);
}

/// ---------------------------------------------------------------------------
/// RADIUS TOKENS (AppRadius)
/// Standardized curvature radii across cards, pills, sheets, and bubbles.
/// ---------------------------------------------------------------------------
class AppRadius {
  AppRadius._();

  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 12.0;
  static const double lg = 16.0;
  static const double xl = 20.0;
  static const double pill = 22.0;
  static const double sheet = 24.0;
  static const double circular = 999.0;

  static const BorderRadius radiusXs = BorderRadius.all(Radius.circular(xs));
  static const BorderRadius radiusSm = BorderRadius.all(Radius.circular(sm));
  static const BorderRadius radiusMd = BorderRadius.all(Radius.circular(md));
  static const BorderRadius radiusLg = BorderRadius.all(Radius.circular(lg));
  static const BorderRadius radiusXl = BorderRadius.all(Radius.circular(xl));
  static const BorderRadius radiusPill = BorderRadius.all(Radius.circular(pill));
  static const BorderRadius radiusSheet = BorderRadius.vertical(top: Radius.circular(sheet));
  static const BorderRadius radiusCircular = BorderRadius.all(Radius.circular(circular));
}

/// ---------------------------------------------------------------------------
/// TYPOGRAPHY SCALE (AppTypography)
/// Complete Lexend typography scale with balanced line-heights and tracking.
/// ---------------------------------------------------------------------------
class AppTypography {
  AppTypography._();

  static const String fontFamily = 'Lexend';

  static const TextStyle display = TextStyle(
    fontFamily: fontFamily,
    fontSize: 28,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.5,
    height: 1.2,
  );

  static const TextStyle headline = TextStyle(
    fontFamily: fontFamily,
    fontSize: 22,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.4,
    height: 1.25,
  );

  static const TextStyle title = TextStyle(
    fontFamily: fontFamily,
    fontSize: 18,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.2,
    height: 1.3,
  );

  static const TextStyle subtitle = TextStyle(
    fontFamily: fontFamily,
    fontSize: 15,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.1,
    height: 1.35,
  );

  static const TextStyle body = TextStyle(
    fontFamily: fontFamily,
    fontSize: 14,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.0,
    height: 1.4,
  );

  static const TextStyle bodyMedium = TextStyle(
    fontFamily: fontFamily,
    fontSize: 14,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.0,
    height: 1.4,
  );

  static const TextStyle caption = TextStyle(
    fontFamily: fontFamily,
    fontSize: 12,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.1,
    height: 1.3,
  );

  static const TextStyle metadata = TextStyle(
    fontFamily: fontFamily,
    fontSize: 10,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.2,
    height: 1.2,
  );

  static const TextStyle badge = TextStyle(
    fontFamily: fontFamily,
    fontSize: 11,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.2,
  );
}

/// ---------------------------------------------------------------------------
/// CENTRAL DESIGN SYSTEM & THEME TOKENS
/// Pure Monochrome (0% Blue/Purple Tint) - Telegram/iOS/Linear Precision
/// ---------------------------------------------------------------------------
class AppTheme {
  // Brand Colors (Pure Monochrome - Zero Blue)
  static const Color primary = Color(0xFF000000); // Crisp Pure Black in Light Mode
  static const Color primaryDark = Color(0xFF000000);
  static const Color primaryLight = Color(0xFF262626);
  static const Color primarySoft = Color(0xFFF4F4F5); // Neutral Grey Accent (0% Blue)

  static const Color secondary = Color(0xFF27272A); // Neutral Dark Charcoal
  static const Color accent = Color(0xFF71717A); // Neutral Mid Grey
  static const Color success = Color(0xFF22C55E); // Green 500 (standard online dot)
  static const Color danger = Color(0xFFEF4444); // Red (logout/error)
  static const Color warning = Color(0xFFF59E0B); // Amber 500
  static const Color charcoal = Color(0xFF18181B); // Zinc-900 Neutral Charcoal
  static const Color charcoalMuted = Color(0xFF27272A); // Zinc-800 Neutral Charcoal

  // Light Mode Colors (Pure White & Black Monochrome - Zero Blue/Slate)
  static const Color background = Color(0xFFF7F7F8); // Neutral Light Background (0% blue)
  static const Color surface = Color(0xFFFFFFFF); // Crisp Pure White
  static const Color surfaceElevated = Color(0xFFFFFFFF); // Elevated Crisp White
  static const Color surfaceMuted = Color(0xFFF0F0F2); // Pure Neutral Light Grey
  static const Color border = Color(0xFFE4E4E7); // Pure Neutral Border
  static const Color borderLight = Color(0xFFF4F4F5);
  static const Color divider = Color(0xFFE4E4E7);

  static const Color textPrimary = Color(0xFF09090B); // Pure Crisp Black
  static const Color textSecondary = Color(0xFF27272A); // Zinc-800: Maximum-contrast sharp charcoal
  static const Color textMuted = Color(0xFF52525B); // Zinc-600: High-contrast legible grey
  static const Color textWhite = Color(0xFFFFFFFF);

  // Message Bubbles (Light Mode)
  static const Color incomingBubbleLight = Color(0xFFE9E9EB); // Telegram iOS neutral grey
  static const Color incomingBubbleTextLight = Color(0xFF09090B);
  static const Color outgoingBubbleLight = Color(0xFF18181B); // Deep charcoal black
  static const Color outgoingBubbleTextLight = Color(0xFFFFFFFF);

  // Dark Mode Colors (Pure Black & White Monochrome - Zero Blue)
  static const Color darkBackground = Color(0xFF000000); // Pure OLED Black
  static const Color darkSurface = Color(0xFF141416); // Pure Neutral Dark Charcoal
  static const Color darkSurfaceElevated = Color(0xFF1C1C1E); // Elevated Dark Charcoal
  static const Color darkSurfaceMuted = Color(0xFF1E1E20); // Pure Neutral Muted Charcoal
  static const Color darkBorder = Color(0xFF2C2C2E); // Pure Neutral Dark Border
  static const Color darkBorderLight = Color(0xFF1C1C1E);
  static const Color darkDivider = Color(0xFF27272A);

  static const Color darkTextPrimary = Color(0xFFFFFFFF); // Crisp Pure White
  static const Color darkTextSecondary = Color(0xFFE4E4E7); // Zinc-200: Maximum-contrast silver-white
  static const Color darkTextMuted = Color(0xFFD4D4D8); // Zinc-300: High-contrast legible grey
  static const Color darkPrimarySoft = Color(0xFF262628); // Neutral Charcoal Accent
  static const Color darkPrimary = Color(0xFFFFFFFF); // Crisp Pure White Accent
  static const Color darkOnPrimary = Color(0xFF000000); // Pure Black on White

  // Message Bubbles (Dark Mode)
  static const Color incomingBubbleDark = Color(0xFF1E1E22);
  static const Color incomingBubbleTextDark = Color(0xFFF4F4F5);
  static const Color incomingBubbleBorderDark = Color(0xFF2E2E32);
  static const Color outgoingBubbleDark = Color(0xFF2E2E32);
  static const Color outgoingBubbleTextDark = Color(0xFFFFFFFF);
  static const Color outgoingBubbleBorderDark = Color(0xFF3F3F46);

  // Shadows
  static List<BoxShadow> get softShadow => [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.04),
          blurRadius: 12,
          offset: const Offset(0, 4),
        ),
      ];

  static List<BoxShadow> get darkSoftShadow => [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.25),
          blurRadius: 12,
          offset: const Offset(0, 4),
        ),
      ];

  static List<BoxShadow> get buttonShadow => [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.15),
          blurRadius: 10,
          offset: const Offset(0, 4),
        ),
      ];

  // Light Theme (Pure Black & White Monochrome - Zero Blue)
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      splashFactory: InkRipple.splashFactory,
      brightness: Brightness.light,
      fontFamily: AppTypography.fontFamily,
      colorScheme: const ColorScheme(
        brightness: Brightness.light,
        primary: primary,
        onPrimary: Colors.white,
        secondary: secondary,
        onSecondary: Colors.white,
        error: danger,
        onError: Colors.white,
        surface: surface,
        onSurface: textPrimary,
      ),
      scaffoldBackgroundColor: background,
      appBarTheme: const AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        backgroundColor: surface,
        foregroundColor: textPrimary,
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark,
          statusBarBrightness: Brightness.light,
          systemNavigationBarColor: Colors.transparent,
          systemNavigationBarIconBrightness: Brightness.dark,
        ),
        titleTextStyle: TextStyle(
          fontFamily: AppTypography.fontFamily,
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: textPrimary,
        ),
        iconTheme: IconThemeData(color: textPrimary),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: border, width: 1),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: primary,
        foregroundColor: textWhite,
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        titleTextStyle: const TextStyle(
          fontFamily: AppTypography.fontFamily,
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: textPrimary,
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith<Color>((states) {
          return states.contains(WidgetState.selected)
              ? Colors.white
              : const Color(0xFF71717A);
        }),
        trackColor: WidgetStateProperty.resolveWith<Color>((states) {
          return states.contains(WidgetState.selected)
              ? Colors.black
              : const Color(0xFFE4E4E7);
        }),
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.android: ZoomPageTransitionsBuilder(),
        },
      ),
    );
  }

  // Dark Theme (Pure Black & White Monochrome - Zero Blue)
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      splashFactory: InkRipple.splashFactory,
      brightness: Brightness.dark,
      fontFamily: AppTypography.fontFamily,
      colorScheme: const ColorScheme(
        brightness: Brightness.dark,
        primary: darkPrimary,
        onPrimary: darkOnPrimary,
        secondary: Color(0xFFE5E5E5),
        onSecondary: Color(0xFF000000),
        error: danger,
        onError: Colors.white,
        surface: darkSurface,
        onSurface: darkTextPrimary,
      ),
      scaffoldBackgroundColor: darkBackground,
      appBarTheme: const AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        backgroundColor: darkBackground,
        foregroundColor: darkTextPrimary,
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
          statusBarBrightness: Brightness.dark,
          systemNavigationBarColor: Colors.transparent,
          systemNavigationBarIconBrightness: Brightness.light,
        ),
        titleTextStyle: TextStyle(
          fontFamily: AppTypography.fontFamily,
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: darkTextPrimary,
        ),
        iconTheme: IconThemeData(color: darkTextPrimary),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: darkSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: darkBorder, width: 1),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: darkPrimary,
        foregroundColor: darkOnPrimary,
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: darkSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        titleTextStyle: const TextStyle(
          fontFamily: AppTypography.fontFamily,
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: darkTextPrimary,
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith<Color>((states) {
          return states.contains(WidgetState.selected)
              ? Colors.black
              : const Color(0xFFA1A1AA);
        }),
        trackColor: WidgetStateProperty.resolveWith<Color>((states) {
          return states.contains(WidgetState.selected)
              ? Colors.white
              : const Color(0xFF27272A);
        }),
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.android: ZoomPageTransitionsBuilder(),
        },
      ),
    );
  }
}

/// ---------------------------------------------------------------------------
/// BuildContext Theme Extension
/// Provides immediate, null-safe, dynamic theme values for all widgets.
/// ---------------------------------------------------------------------------
extension AppThemeContext on BuildContext {
  bool get isDark => Theme.of(this).brightness == Brightness.dark;

  // Background & Surfaces
  Color get backgroundColor =>
      isDark ? AppTheme.darkBackground : AppTheme.background;
  Color get surfaceColor => isDark ? AppTheme.darkSurface : AppTheme.surface;
  Color get surfaceElevatedColor =>
      isDark ? AppTheme.darkSurfaceElevated : AppTheme.surfaceElevated;
  Color get surfaceMutedColor =>
      isDark ? AppTheme.darkSurfaceMuted : AppTheme.surfaceMuted;
  Color get borderColor => isDark ? AppTheme.darkBorder : AppTheme.border;
  Color get dividerColor => isDark ? AppTheme.darkDivider : AppTheme.divider;

  // Text Tokens
  Color get textPrimaryColor =>
      isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary;
  Color get textSecondaryColor =>
      isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary;
  Color get textMutedColor =>
      isDark ? AppTheme.darkTextMuted : AppTheme.textMuted;

  // Primary & Actions
  Color get primarySoftColor =>
      isDark ? AppTheme.darkPrimarySoft : AppTheme.primarySoft;
  Color get primaryColor =>
      isDark ? AppTheme.darkPrimary : AppTheme.primary;
  Color get onPrimaryColor =>
      isDark ? AppTheme.darkOnPrimary : Colors.white;

  // Status & Feedback
  Color get onlineColor => AppTheme.success;
  Color get dangerColor => AppTheme.danger;
  Color get dangerSoftColor => AppTheme.danger.withValues(alpha: 0.12);
  Color get warningColor => AppTheme.warning;

  // Message Bubbles
  Color get incomingBubbleColor =>
      isDark ? AppTheme.incomingBubbleDark : AppTheme.incomingBubbleLight;
  Color get incomingBubbleTextColor =>
      isDark ? AppTheme.incomingBubbleTextDark : AppTheme.incomingBubbleTextLight;
  Color? get incomingBubbleBorderColor =>
      isDark ? AppTheme.incomingBubbleBorderDark : null;

  Color get outgoingBubbleColor =>
      isDark ? AppTheme.outgoingBubbleDark : AppTheme.outgoingBubbleLight;
  Color get outgoingBubbleTextColor =>
      isDark ? AppTheme.outgoingBubbleTextDark : AppTheme.outgoingBubbleTextLight;
  Color? get outgoingBubbleBorderColor =>
      isDark ? AppTheme.outgoingBubbleBorderDark : null;

  // Badges & Accents
  Color get badgeBackgroundColor =>
      isDark ? const Color(0xFF27272A) : const Color(0xFFF4F4F5);
  Color get badgeIconColor =>
      isDark ? Colors.white : const Color(0xFF18181B);
  Color get chevronColor =>
      isDark ? const Color(0xFF71717A) : const Color(0xFFA1A1AA);

  // Shadows
  List<BoxShadow> get softShadow =>
      isDark ? AppTheme.darkSoftShadow : AppTheme.softShadow;

  // System UI Overlay
  SystemUiOverlayStyle get systemOverlayStyle => isDark
      ? const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
          statusBarBrightness: Brightness.dark,
          systemNavigationBarColor: Colors.transparent,
          systemNavigationBarIconBrightness: Brightness.light,
        )
      : const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark,
          statusBarBrightness: Brightness.light,
          systemNavigationBarColor: Colors.transparent,
          systemNavigationBarIconBrightness: Brightness.dark,
        );
}
