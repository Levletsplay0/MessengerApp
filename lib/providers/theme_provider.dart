import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeProvider extends ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.system;

  ThemeProvider() {
    _loadThemeFromPreferences();
  }

  ThemeMode get themeMode => _themeMode;

  Future<void> _loadThemeFromPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    final themeString = prefs.getString('theme_mode');

    if (themeString == 'light') {
      _themeMode = ThemeMode.light;
    } else if (themeString == 'dark') {
      _themeMode = ThemeMode.dark;
    } else {
      _themeMode = ThemeMode.system;
    }
    notifyListeners();
  }

  Future<void> toggleTheme(bool isLight) async {
    final prefs = await SharedPreferences.getInstance();

    if (isLight) {
      _themeMode = ThemeMode.light;
      await prefs.setString('theme_mode', 'light');
    } else {
      _themeMode = ThemeMode.dark;
      await prefs.setString('theme_mode', 'dark');
    }

    notifyListeners();
  }

  bool get isLightMode => _themeMode == ThemeMode.light;
  bool get isDarkMode => _themeMode == ThemeMode.dark;
}
