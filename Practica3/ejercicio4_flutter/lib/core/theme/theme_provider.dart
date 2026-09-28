import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/app_colors.dart';

enum InstitutionalTheme { guindaIPN, azulESCOM }

class ThemeProvider extends ChangeNotifier {
  static const String _prefThemeKey = 'selected_institutional_theme';
  static const String _prefModeKey = 'selected_theme_mode';

  InstitutionalTheme _institutionalTheme = InstitutionalTheme.guindaIPN;
  ThemeMode _themeMode = ThemeMode.system;

  InstitutionalTheme get institutionalTheme => _institutionalTheme;
  ThemeMode get themeMode => _themeMode;

  ThemeProvider() {
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    final themeString = prefs.getString(_prefThemeKey);
    final modeString = prefs.getString(_prefModeKey);

    if (themeString == 'azulESCOM') {
      _institutionalTheme = InstitutionalTheme.azulESCOM;
    } else {
      _institutionalTheme = InstitutionalTheme.guindaIPN;
    }

    if (modeString == 'light') {
      _themeMode = ThemeMode.light;
    } else if (modeString == 'dark') {
      _themeMode = ThemeMode.dark;
    } else {
      _themeMode = ThemeMode.system;
    }

    notifyListeners();
  }

  Future<void> setInstitutionalTheme(InstitutionalTheme theme) async {
    _institutionalTheme = theme;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _prefThemeKey,
      theme == InstitutionalTheme.azulESCOM ? 'azulESCOM' : 'guindaIPN',
    );
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    String modeString = 'system';
    if (mode == ThemeMode.light) modeString = 'light';
    if (mode == ThemeMode.dark) modeString = 'dark';
    await prefs.setString(_prefModeKey, modeString);
  }

  Color get primaryColor {
    return _institutionalTheme == InstitutionalTheme.guindaIPN
        ? AppColors.ipnGuinda
        : AppColors.escomAzul;
  }

  ThemeData get lightTheme {
    final isGuinda = _institutionalTheme == InstitutionalTheme.guindaIPN;
    final primary = isGuinda ? AppColors.ipnGuinda : AppColors.escomAzul;
    final secondary = isGuinda ? AppColors.ipnOro : AppColors.escomCeleste;

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primary,
        primary: primary,
        secondary: secondary,
        brightness: Brightness.light,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: primary,
        foregroundColor: Colors.white,
        elevation: 2,
        centerTitle: false,
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: primary,
        foregroundColor: Colors.white,
      ),
      cardTheme: CardThemeData(
        elevation: 1,
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  ThemeData get darkTheme {
    final isGuinda = _institutionalTheme == InstitutionalTheme.guindaIPN;
    final primary = isGuinda ? AppColors.ipnGuindaLight : AppColors.escomAzulLight;
    final secondary = isGuinda ? AppColors.ipnOro : AppColors.escomCeleste;

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primary,
        primary: primary,
        secondary: secondary,
        brightness: Brightness.dark,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF1E1E1E),
        foregroundColor: Colors.white,
        elevation: 2,
        centerTitle: false,
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: primary,
        foregroundColor: Colors.white,
      ),
      cardTheme: CardThemeData(
        elevation: 1,
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
