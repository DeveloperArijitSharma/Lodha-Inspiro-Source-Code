import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

/// Shared visual language for Lodha Inspiro.
/// On Apple platforms Flutter resolves .SF Pro Text to the system SF Pro family.
/// Android falls back safely to the platform sans-serif font.
class InspiroUi {
  static const String systemFont = '.SF Pro Text';
  static const Color accent = Color(0xFF4B8DFF);

  static ThemeData lightTheme() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      fontFamily: systemFont,
      scaffoldBackgroundColor: const Color(0xFFF2F5F9),
      splashFactory: NoSplash.splashFactory,
      visualDensity: VisualDensity.standard,
      colorScheme: ColorScheme.fromSeed(
        seedColor: accent,
        brightness: Brightness.light,
        surface: const Color(0xFFF8FAFC),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(24))),
      ),
    );
  }

  static ThemeData darkTheme() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      fontFamily: systemFont,
      scaffoldBackgroundColor: const Color(0xFF080B12),
      splashFactory: NoSplash.splashFactory,
      visualDensity: VisualDensity.standard,
      colorScheme: ColorScheme.fromSeed(
        seedColor: accent,
        brightness: Brightness.dark,
        surface: const Color(0xFF111722),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(24))),
      ),
    );
  }

  static CupertinoThemeData cupertinoTheme(Brightness brightness) {
    return CupertinoThemeData(
      brightness: brightness,
      primaryColor: accent,
      scaffoldBackgroundColor: brightness == Brightness.dark
          ? const Color(0xFF080B12)
          : const Color(0xFFF2F5F9),
      textTheme: const CupertinoTextThemeData(
        textStyle: TextStyle(fontFamily: systemFont),
      ),
    );
  }
}
