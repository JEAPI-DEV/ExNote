import 'package:flutter/material.dart';

class AppTheme {
  static final ThemeData lightTheme = ThemeData(
    brightness: Brightness.light,
    primaryColor: Colors.black,
    scaffoldBackgroundColor: const Color(0xFFF5F5F5), // Off-white
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.white,
      foregroundColor: Colors.black,
      elevation: 0,
      iconTheme: IconThemeData(color: Colors.black87),
    ),
    iconTheme: const IconThemeData(color: Colors.black87),
    sliderTheme: SliderThemeData(
      activeTrackColor: Colors.black,
      inactiveTrackColor: Colors.grey.shade300,
      thumbColor: Colors.black,
      overlayColor: Colors.black.withOpacity(0.1),
    ),
    colorScheme: const ColorScheme.light(
      primary: Colors.black,
      secondary: Colors.blueAccent,
      surface: Colors.white,
      background: Color(0xFFF5F5F5),
    ),
  );

  static final ThemeData darkTheme = ThemeData(
    brightness: Brightness.dark,
    primaryColor: Colors.white,
    scaffoldBackgroundColor: const Color(0xFF1E1E1E), // Dark Gray
    appBarTheme: const AppBarTheme(
      backgroundColor: Color(0xFF2D2D2D), // Slightly lighter gray
      foregroundColor: Colors.white,
      elevation: 0,
      iconTheme: IconThemeData(color: Colors.white70),
    ),
    iconTheme: const IconThemeData(color: Colors.white70),
    sliderTheme: SliderThemeData(
      activeTrackColor: Colors.white,
      inactiveTrackColor: Colors.grey.shade700,
      thumbColor: Colors.white,
      overlayColor: Colors.white.withOpacity(0.1),
    ),
    colorScheme: const ColorScheme.dark(
      primary: Colors.white,
      secondary: Colors.blueAccent,
      surface: Color(0xFF2D2D2D),
      background: Color(0xFF1E1E1E),
    ),
  );
}
