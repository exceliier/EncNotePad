import 'package:flutter/material.dart';
import 'font_stack.dart';

class AppTheme {
  static const Color primaryDark = Color(0xFF1E1E2E);
  static const Color surfaceDark = Color(0xFF252538);
  static const Color cardDark = Color(0xFF2E2E44);
  static const Color accentBlue = Color(0xFF4C78DD);
  static const Color accentGreen = Color(0xFF4EBA6F);
  static const Color textPrimary = Color(0xFFEEEEEE);
  static const Color textMuted = Color(0xFFAAAAAA);
  static const Color borderSubtle = Color(0xFF3E3E58);

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: primaryDark,
      fontFamilyFallback: FontStack.fontFamilies,
      colorScheme: const ColorScheme.dark(
        primary: accentBlue,
        surface: surfaceDark,
        onSurface: textPrimary,
      ),
      cardTheme: const CardThemeData(
        color: cardDark,
        elevation: 2,
        margin: EdgeInsets.symmetric(vertical: 6, horizontal: 12),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceDark,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: borderSubtle),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: borderSubtle),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: accentBlue, width: 1.5),
        ),
      ),
    );
  }
}
