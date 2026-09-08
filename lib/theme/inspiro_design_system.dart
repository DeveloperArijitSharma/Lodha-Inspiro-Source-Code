import 'package:flutter/material.dart';

/// Shared visual tokens for the friendly Lodha Inspiro design language.
/// Keep feature screens lightweight by consuming these values instead of
/// introducing one-off spacing, radii, and typography constants.
class InspiroDesignSystem {
  InspiroDesignSystem._();

  static const Color accent = Color(0xFF32C5FF);
  static const Color lightBackground = Color(0xFFEBF0F5);
  static const Color darkBackground = Color(0xFF121212);

  static const double radiusSmall = 14;
  static const double radiusMedium = 18;
  static const double radiusLarge = 24;

  static const EdgeInsets screenPadding = EdgeInsets.fromLTRB(16, 16, 16, 24);
  static const EdgeInsets cardPadding = EdgeInsets.all(18);

  static const Duration quick = Duration(milliseconds: 180);
  static const Duration standard = Duration(milliseconds: 280);

  static TextStyle title(BuildContext context) =>
      Theme.of(context).textTheme.titleLarge!.copyWith(
            fontFamily: 'Google Sans Flex',
            fontWeight: FontWeight.w700,
          );

  static TextStyle section(BuildContext context) =>
      Theme.of(context).textTheme.titleMedium!.copyWith(
            fontFamily: 'Google Sans Flex',
            fontWeight: FontWeight.w700,
          );

  static TextStyle body(BuildContext context) =>
      Theme.of(context).textTheme.bodyMedium!.copyWith(
            fontFamily: 'Google Sans Flex',
            height: 1.4,
          );
}
