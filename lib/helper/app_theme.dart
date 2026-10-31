import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Central Design System & Theme for Chatty (Light & Dark Mode)
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
  static const Color charcoal = Color(0xFF18181B); // Zinc-900 Neutral Charcoal
  static const Color charcoalMuted = Color(0xFF27272A); // Zinc-800 Neutral Charcoal

  // Light Mode Colors (Pure White & Black Monochrome - Zero Blue/Slate)
  static const Color background = Color(0xFFF7F7F8); // Neutral Light Background (0% blue)
  static const Color surface = Color(0xFFFFFFFF); // Crisp Pure White
  static const Color surfaceMuted = Color(0xFFF0F0F2); // Pure Neutral Light Grey
  static const Color border = Color(0xFFE4E4E7); // Pure Neutral Border
  static const Color borderLight = Color(0xFFF4F4F5);

  static const Color textPrimary = Color(0xFF09090B); // Pure Crisp Black
  static const Color textSecondary = Color(0xFF52525B); // Neutral Mid Grey
  static const Color textMuted = Color(0xFF71717A); // Neutral Mid Grey (4.74:1 on Surface - PASS WCAG AA)
  static const Color textWhite = Color(0xFFFFFFFF);

  // Dark Mode Colors (Pure Black & White Monochrome - Zero Blue)
  static const Color darkBackground = Color(0xFF000000); // Pure OLED Black
  static const Color darkSurface = Color(0xFF121212); // Pure Neutral Dark Charcoal
  static const Color darkSurfaceMuted = Color(0xFF1E1E1E); // Pure Neutral Muted Charcoal
  static const Color darkBorder = Color(0xFF2C2C2C); // Pure Neutral Dark Border
  static const Color darkBorderLight = Color(0xFF1C1C1C);

  static const Color darkTextPrimary = Color(0xFFFFFFFF); // Crisp Pure White
  static const Color darkTextSecondary = Color(0xFFA3A3A3); // Crisp Neutral Grey
  static const Color darkTextMuted = Color(0xFF8E8E93); // Crisp Neutral Grey (5.21:1 on Dark Surface - PASS WCAG AA)
  static const Color darkPrimarySoft = Color(0xFF262626); // Neutral Charcoal Accent
  static const Color darkPrimary = Color(0xFFFFFFFF); // Crisp Pure White Accent
  static const Color darkOnPrimary = Color(0xFF000000); // Pure Black on White

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
      fontFamily: 'Lexend',
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
          fontFamily: 'Lexend',
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
          fontFamily: 'Lexend',
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
    );
  }

  // Dark Theme (Pure Black & White Monochrome - Zero Blue)
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      splashFactory: InkRipple.splashFactory,
      brightness: Brightness.dark,
      fontFamily: 'Lexend',
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
          fontFamily: 'Lexend',
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
          fontFamily: 'Lexend',
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
    );
  }
}

/// Handy BuildContext extensions for dynamic theme values
extension AppThemeContext on BuildContext {
  bool get isDark => Theme.of(this).brightness == Brightness.dark;
  Color get backgroundColor =>
      isDark ? AppTheme.darkBackground : AppTheme.background;
  Color get surfaceColor => isDark ? AppTheme.darkSurface : AppTheme.surface;
  Color get surfaceMutedColor =>
      isDark ? AppTheme.darkSurfaceMuted : AppTheme.surfaceMuted;
  Color get borderColor => isDark ? AppTheme.darkBorder : AppTheme.border;
  Color get textPrimaryColor =>
      isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary;
  Color get textSecondaryColor =>
      isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary;
  Color get textMutedColor =>
      isDark ? AppTheme.darkTextMuted : AppTheme.textMuted;
  Color get primarySoftColor =>
      isDark ? AppTheme.darkPrimarySoft : AppTheme.primarySoft;
  Color get primaryColor =>
      isDark ? AppTheme.darkPrimary : AppTheme.primary;
  Color get onPrimaryColor =>
      isDark ? AppTheme.darkOnPrimary : Colors.white;
  Color get dangerColor => AppTheme.danger;
  Color get dangerSoftColor => AppTheme.danger.withValues(alpha: 0.12);
  Color get badgeBackgroundColor =>
      isDark ? const Color(0xFF27272A) : const Color(0xFFF4F4F5);
  Color get badgeIconColor =>
      isDark ? Colors.white : const Color(0xFF18181B);
  Color get chevronColor =>
      isDark ? const Color(0xFF71717A) : const Color(0xFFA1A1AA);
  List<BoxShadow> get softShadow =>
      isDark ? AppTheme.darkSoftShadow : AppTheme.softShadow;
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
