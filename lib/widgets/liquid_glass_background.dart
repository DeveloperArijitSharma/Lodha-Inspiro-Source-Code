import 'dart:ui';

import 'package:flutter/material.dart';

import '../theme/inspiro_design_system.dart';

/// A subtle glass-friendly backdrop for Studio and other content-heavy pages.
/// It does not replace the page content or navigation, so existing features
/// remain unchanged while surfaces gain depth.
class LiquidGlassBackground extends StatelessWidget {
  final Widget child;

  const LiquidGlassBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Stack(
      fit: StackFit.expand,
      children: [
        ColoredBox(
          color: isDark
              ? InspiroDesignSystem.darkBackground
              : InspiroDesignSystem.lightBackground,
        ),
        Positioned(
          top: -90,
          right: -60,
          child: _orb(180, InspiroDesignSystem.accent.withOpacity(.16)),
        ),
        Positioned(
          bottom: -110,
          left: -80,
          child: _orb(220, Colors.white.withOpacity(isDark ? .04 : .48)),
        ),
        BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 28, sigmaY: 28),
          child: ColoredBox(color: Colors.transparent, child: child),
        ),
      ],
    );
  }

  Widget _orb(double size, Color color) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(shape: BoxShape.circle, color: color),
      ),
    );
  }
}
