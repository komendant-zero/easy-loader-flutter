import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AppThemePreset {
  darkBlue,
  midnightPurple,
  hackerGreen,
  vhsTheme
}

class AppThemeData {
  final Color backgroundColor;
  final Color cardColor;
  final Color primaryColor;
  final Color primaryButtonTextColor;
  final Color textColor;
  final Color secondaryTextColor;

  const AppThemeData({
    required this.backgroundColor,
    required this.cardColor,
    required this.primaryColor,
    required this.primaryButtonTextColor,
    required this.textColor,
    required this.secondaryTextColor,
  });

  factory AppThemeData.fromPreset(AppThemePreset preset) {
    switch (preset) {
      case AppThemePreset.darkBlue:
        return const AppThemeData(
          backgroundColor: Color(0xFF0D0D14),
          cardColor: Color(0xFF14141E),
          primaryColor: Color(0xFF3B82F6),
          primaryButtonTextColor: Colors.white,
          textColor: Colors.white,
          secondaryTextColor: Color(0xFF8A8A9E),
        );
      case AppThemePreset.midnightPurple:
        return const AppThemeData(
          backgroundColor: Color(0xFF130B1C),
          cardColor: Color(0xFF1C1326),
          primaryColor: Color(0xFFA855F7),
          primaryButtonTextColor: Colors.white,
          textColor: Colors.white,
          secondaryTextColor: Color(0xFF9E8AAB),
        );
      case AppThemePreset.hackerGreen:
        return const AppThemeData(
          backgroundColor: Color(0xFF000000),
          cardColor: Color(0xFF0A0A0A),
          primaryColor: Color(0xFF10B981),
          primaryButtonTextColor: Colors.white,
          textColor: Color(0xFF10B981),
          secondaryTextColor: Color(0xFF047857),
        );
      case AppThemePreset.vhsTheme:
        return const AppThemeData(
          backgroundColor: Color(0xFF18181A),
          cardColor: Color(0xFF222226),
          primaryColor: Color(0xFF00A2FF), // Pale Cyan
          primaryButtonTextColor: Colors.white,
          textColor: Color(0xFFEEEEEE),
          secondaryTextColor: Color(0xFF999999),
        );
    }
  }
}

class ThemeNotifier extends StateNotifier<AppThemePreset> {
  ThemeNotifier() : super(AppThemePreset.darkBlue) {
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final index = prefs.getInt('theme_preset') ?? 0;
    if (index >= 0 && index < AppThemePreset.values.length) {
      state = AppThemePreset.values[index];
    }
  }

  Future<void> setTheme(AppThemePreset preset) async {
    state = preset;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('theme_preset', preset.index);
  }
}

final themeProvider = StateNotifierProvider<ThemeNotifier, AppThemePreset>((ref) {
  return ThemeNotifier();
});
