import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

/// Shared visual language for Lodha Inspiro.
/// Google Sans Flex is the app font; CupertinoIcons provide the cross-platform
/// SF Symbols-style icon language used throughout the student UI.
class InspiroUi {
  static const String systemFont = 'Google Sans Flex';
  static const Color accent = Color(0xFF4B8DFF);
  static const Color lightBackground = Color(0xFFF2F5F9);
  static const Color darkBackground = Color(0xFF080B12);
  static const Color lightSurface = Color(0xFFF8FAFC);
  static const Color darkSurface = Color(0xFF111722);

  static ThemeData lightTheme() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      fontFamily: systemFont,
      scaffoldBackgroundColor: lightBackground,
      splashFactory: NoSplash.splashFactory,
      visualDensity: VisualDensity.standard,
      colorScheme: ColorScheme.fromSeed(
        seedColor: accent,
        brightness: Brightness.light,
        surface: lightSurface,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
      ),
      cardTheme: const CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(24)),
        ),
      ),
    );
  }

  static ThemeData darkTheme() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      fontFamily: systemFont,
      scaffoldBackgroundColor: darkBackground,
      splashFactory: NoSplash.splashFactory,
      visualDensity: VisualDensity.standard,
      colorScheme: ColorScheme.fromSeed(
        seedColor: accent,
        brightness: Brightness.dark,
        surface: darkSurface,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
      ),
      cardTheme: const CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(24)),
        ),
      ),
    );
  }

  static CupertinoThemeData cupertinoTheme(Brightness brightness) {
    return CupertinoThemeData(
      brightness: brightness,
      primaryColor: accent,
      scaffoldBackgroundColor:
          brightness == Brightness.dark ? darkBackground : lightBackground,
      textTheme: const CupertinoTextThemeData(
        textStyle: TextStyle(fontFamily: systemFont),
      ),
    );
  }
}
