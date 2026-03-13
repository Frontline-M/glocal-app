import 'package:flutter/material.dart';

class AppTheme {
  static ThemeData get lightTheme => ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF0E6BA8)),
        fontFamily: 'Inter',
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF7FAFC),
      );

  static ThemeData get darkTheme => ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF0E6BA8),
          brightness: Brightness.dark,
        ),
        fontFamily: 'Inter',
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFF0B1220),
      );
}
