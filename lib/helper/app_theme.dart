import 'package:flutter/material.dart';

/// Central Design System & Theme for Chatty (Light & Dark Mode)
class AppTheme {
  // Brand Colors
  static const Color primary = Color(0xFF4F46E5); // Modern Indigo
  static const Color primaryDark = Color(0xFF3730A3);
  static const Color primaryLight = Color(0xFF818CF8);
  static const Color primarySoft = Color(0xFFEEF2FF);

  static const Color secondary = Color(0xFF0EA5E9); // Sky Blue
  static const Color accent = Color(0xFFF59E0B); // Amber
  static const Color success = Color(0xFF10B981); // Emerald Green (online)
  static const Color danger = Color(0xFFEF4444); // Red (logout/error)

  // Light Mode Colors
  static const Color background = Color(0xFFF8FAFC); // Slate 50
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceMuted = Color(0xFFF1F5F9); // Slate 100
  static const Color border = Color(0xFFE2E8F0); // Slate 200
  static const Color borderLight = Color(0xFFF1F5F9);

  static const Color textPrimary = Color(0xFF0F172A); // Slate 900
  static const Color textSecondary = Color(0xFF64748B); // Slate 500
  static const Color textMuted = Color(0xFF94A3B8); // Slate 400
  static const Color textWhite = Color(0xFFFFFFFF);

  // Dark Mode Colors (Pure Black & White Monochrome - Zero Blue)
  static const Color darkBackground = Color(0xFF000000); // Pure OLED Black
  static const Color darkSurface = Color(0xFF121212); // Pure Neutral Dark Charcoal
  static const Color darkSurfaceMuted = Color(0xFF1E1E1E); // Pure Neutral Muted Charcoal
  static const Color darkBorder = Color(0xFF2C2C2C); // Pure Neutral Dark Border
  static const Color darkBorderLight = Color(0xFF1C1C1C);

  static const Color darkTextPrimary = Color(0xFFFFFFFF); // Crisp Pure White
  static const Color darkTextSecondary = Color(0xFFA3A3A3); // Crisp Neutral Grey
  static const Color darkTextMuted = Color(0xFF737373); // Muted Neutral Grey
  static const Color darkPrimarySoft = Color(0xFF262626); // Neutral Charcoal Accent
  static const Color darkPrimary = Color(0xFFFFFFFF); // Crisp Pure White Accent
  static const Color darkOnPrimary = Color(0xFF000000); // Pure Black on White

  // Shadows
  static List<BoxShadow> get softShadow => [
        BoxShadow(
          color: const Color(0xFF0F172A).withValues(alpha: 0.04),
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
          color: primary.withValues(alpha: 0.3),
          blurRadius: 12,
          offset: const Offset(0, 4),
        ),
      ];

  // Light Theme
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      splashFactory: InkRipple.splashFactory,
      brightness: Brightness.light,
      fontFamily: 'Lexend',
      colorScheme: ColorScheme.fromSeed(
        seedColor: primary,
        brightness: Brightness.light,
        primary: primary,
        secondary: secondary,
        surface: surface,
      ),
      scaffoldBackgroundColor: background,
      appBarTheme: const AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        backgroundColor: surface,
        foregroundColor: textPrimary,
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
  List<BoxShadow> get softShadow =>
      isDark ? AppTheme.darkSoftShadow : AppTheme.softShadow;
}
