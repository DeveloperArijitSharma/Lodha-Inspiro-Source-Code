import 'dart:ui';

import 'package:flutter/material.dart';

/// Reusable translucent glass surfaces for the student-friendly Inspiro UI.
class LiquidGlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;
  final BorderRadius borderRadius;
  final VoidCallback? onTap;
  final double blur;
  final double opacity;

  const LiquidGlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.margin = EdgeInsets.zero,
    this.borderRadius = const BorderRadius.all(Radius.circular(24)),
    this.onTap,
    this.blur = 22,
    this.opacity = .72,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surface = isDark
        ? Colors.white.withOpacity(.08)
        : Colors.white.withOpacity(opacity);
    final border = isDark
        ? Colors.white.withOpacity(.14)
        : Colors.white.withOpacity(.82);

    final content = ClipRRect(
      borderRadius: borderRadius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: surface,
            borderRadius: borderRadius,
            border: Border.all(color: border),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(isDark ? .16 : .06),
                blurRadius: 22,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );

    return Padding(
      padding: margin,
      child: onTap == null
          ? content
          : Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: borderRadius,
                onTap: onTap,
                child: content,
              ),
            ),
    );
  }
}

class LiquidGlassButton extends StatelessWidget {
  final Widget child;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool filled;

  const LiquidGlassButton({
    super.key,
    required this.child,
    required this.onPressed,
    this.icon,
    this.filled = false,
  });

  @override
  Widget build(BuildContext context) {
    final buttonChild = icon == null
        ? child
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18),
              const SizedBox(width: 8),
              child,
            ],
          );

    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Material(
          color: filled
              ? const Color(0xFF32C5FF).withOpacity(.9)
              : Colors.white.withOpacity(.18),
          child: InkWell(
            onTap: onPressed,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: filled ? Colors.white.withOpacity(.24) : Colors.white.withOpacity(.55),
                ),
              ),
              child: DefaultTextStyle.merge(
                style: TextStyle(
                  fontFamily: 'Google Sans Flex',
                  fontWeight: FontWeight.w700,
                  color: filled ? Colors.white : null,
                ),
                child: buttonChild,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
