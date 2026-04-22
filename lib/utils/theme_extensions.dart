import 'package:flutter/material.dart';

/// Convenience extension for checking dark mode.
extension ThemeContext on BuildContext {
  bool get isDark => Theme.of(this).brightness == Brightness.dark;
}
