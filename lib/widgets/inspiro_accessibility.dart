import 'package:flutter/material.dart';

/// Small accessibility helpers shared by interactive Inspiro components.
class InspiroAccessibility {
  InspiroAccessibility._();

  static Widget labeledButton({
    required String label,
    required VoidCallback? onPressed,
    required Widget child,
    bool excludeSemantics = false,
  }) {
    return Semantics(
      button: true,
      enabled: onPressed != null,
      label: label,
      excludeSemantics: excludeSemantics,
      child: child,
    );
  }

  static Widget section({
    required String label,
    required Widget child,
  }) {
    return Semantics(
      container: true,
      label: label,
      child: child,
    );
  }
}
