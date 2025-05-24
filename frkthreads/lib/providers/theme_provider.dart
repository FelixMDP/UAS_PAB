import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeProvider with ChangeNotifier {
  static const String _themeKey = 'theme_mode';
  late SharedPreferences _prefs;
  bool _isDarkMode = false;

  ThemeProvider() {
    _loadTheme();
  }

  bool get isDarkMode => _isDarkMode;
  // Light Theme Colors
  static const Color _lightBackground = Color(0xFFF5F0E5);
  static const Color _lightSurface = Color(0xFFFFFFFF);
  static const Color _lightPrimary = Color(0xFFB88C66);
  static const Color _lightSecondary = Color(0xFF8B4513);
  static const Color _lightAccent = Color(0xFF2D3B3A);
  static const Color _lightText = Color(0xFF293133);
  static const Color _lightDivider = Color(0xFFE0D5C1);
  static const Color _lightError = Color(0xFFB00020);

  // Dark Theme Colors
  static const Color _darkBackground = Color(0xFF1A2327);
  static const Color _darkSurface = Color(0xFF37474F);
  static const Color _darkPrimary = Color(0xFFB88C66);
  static const Color _darkSecondary = Color(0xFF90A4AE);
  static const Color _darkAccent = Color(0xFF64B5F6);
  static const Color _darkText = Color(0xFFF1E9D2);
  static const Color _darkDivider = Color(0xFF546E7A);
  static const Color _darkError = Color(0xFFCF6679);
  ThemeData get lightTheme => ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    primaryColor: _lightPrimary,
    colorScheme: ColorScheme.light(
      primary: _lightPrimary,
      secondary: _lightSecondary,
      surface: _lightSurface,
      background: _lightBackground,
      error: _lightError,
    ),
    scaffoldBackgroundColor: _lightBackground,
    appBarTheme: AppBarTheme(
      backgroundColor: _lightPrimary,
      foregroundColor: _lightSurface,
      elevation: 2,
      shadowColor: _lightPrimary.withOpacity(0.5),
      centerTitle: true,
      iconTheme: IconThemeData(color: _lightSurface),
      titleTextStyle: TextStyle(
        color: _lightSurface,
        fontSize: 20,
        fontWeight: FontWeight.bold,
        letterSpacing: 0.5,
      ),
    ),
    cardTheme: CardTheme(
      color: _lightSurface,
      elevation: 2,
      shadowColor: _lightPrimary.withOpacity(0.3),
      margin: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: _lightDivider, width: 0.5),
      ),
    ),
    textTheme: TextTheme(
      bodyLarge: TextStyle(color: _lightText),
      bodyMedium: TextStyle(color: _lightText.withOpacity(0.9)),
      titleLarge: TextStyle(color: _lightText, fontWeight: FontWeight.bold),
      titleMedium: TextStyle(
        color: _lightText.withOpacity(0.9),
        letterSpacing: 0.25,
      ),
    ),
    iconTheme: IconThemeData(color: _lightAccent, size: 24),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: _lightPrimary,
        foregroundColor: _lightSurface,
        elevation: 3,
        shadowColor: _lightPrimary.withOpacity(0.5),
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ).copyWith(
        overlayColor: MaterialStateProperty.resolveWith<Color?>((
          Set<MaterialState> states,
        ) {
          if (states.contains(MaterialState.hovered))
            return _lightPrimary.withOpacity(0.8);
          if (states.contains(MaterialState.pressed)) return _lightSecondary;
          return null;
        }),
      ),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: _lightAccent,
      foregroundColor: _lightSurface,
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: _lightPrimary.withOpacity(0.1),
      labelStyle: TextStyle(color: _lightPrimary),
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      side: BorderSide(color: _lightPrimary.withOpacity(0.2)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),
    dividerTheme: DividerThemeData(
      color: _lightDivider,
      thickness: 1,
      space: 16,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: _lightSurface,
      hintStyle: TextStyle(color: _lightText.withOpacity(0.5)),
      errorStyle: TextStyle(color: _lightError),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: _lightPrimary.withOpacity(0.2)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: _lightPrimary.withOpacity(0.2)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: _lightPrimary, width: 2),
      ),
    ),
  );
  ThemeData get darkTheme => ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    primaryColor: _darkPrimary,
    colorScheme: ColorScheme.dark(
      primary: _darkPrimary,
      secondary: _darkSecondary,
      surface: _darkSurface,
      background: _darkBackground,
      error: _darkError,
    ),
    scaffoldBackgroundColor: _darkBackground,
    appBarTheme: AppBarTheme(
      backgroundColor: _darkSurface,
      foregroundColor: _darkText,
      elevation: 3,
      shadowColor: Colors.black26,
      centerTitle: true,
      iconTheme: IconThemeData(color: _darkText),
      titleTextStyle: TextStyle(
        color: _darkText,
        fontSize: 20,
        fontWeight: FontWeight.bold,
        letterSpacing: 0.5,
      ),
    ),
    cardTheme: CardTheme(
      color: _darkSurface,
      elevation: 4,
      shadowColor: Colors.black45,
      margin: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: _darkDivider.withOpacity(0.2), width: 0.5),
      ),
    ),
    textTheme: TextTheme(
      bodyLarge: TextStyle(color: _darkText),
      bodyMedium: TextStyle(color: _darkText.withOpacity(0.9)),
      titleLarge: TextStyle(color: _darkText, fontWeight: FontWeight.bold),
      titleMedium: TextStyle(
        color: _darkText.withOpacity(0.9),
        letterSpacing: 0.25,
      ),
    ),
    iconTheme: IconThemeData(color: _darkAccent, size: 24),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: _darkPrimary,
        foregroundColor: _darkText,
        elevation: 4,
        shadowColor: Colors.black38,
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ).copyWith(
        overlayColor: MaterialStateProperty.resolveWith<Color?>((
          Set<MaterialState> states,
        ) {
          if (states.contains(MaterialState.hovered))
            return _darkPrimary.withOpacity(0.8);
          if (states.contains(MaterialState.pressed)) return _darkSecondary;
          return null;
        }),
      ),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: _darkAccent,
      foregroundColor: _darkText,
      elevation: 6,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: _darkPrimary.withOpacity(0.15),
      labelStyle: TextStyle(color: _darkPrimary),
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      side: BorderSide(color: _darkPrimary.withOpacity(0.3)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),
    dividerTheme: DividerThemeData(
      color: _darkDivider,
      thickness: 1,
      space: 16,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: _darkSurface,
      hintStyle: TextStyle(color: _darkText.withOpacity(0.5)),
      errorStyle: TextStyle(color: _darkError),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: _darkPrimary.withOpacity(0.2)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: _darkPrimary.withOpacity(0.2)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: _darkPrimary, width: 2),
      ),
    ),
    bottomNavigationBarTheme: BottomNavigationBarThemeData(
      backgroundColor: _darkSurface,
      selectedItemColor: _darkAccent,
      unselectedItemColor: _darkText.withOpacity(0.7),
      showUnselectedLabels: true,
      type: BottomNavigationBarType.fixed,
    ),
  );

  Future<void> _loadTheme() async {
    _prefs = await SharedPreferences.getInstance();
    _isDarkMode = _prefs.getBool(_themeKey) ?? false;
    notifyListeners();
  }

  Future<void> toggleTheme() async {
    _isDarkMode = !_isDarkMode;
    await _prefs.setBool(_themeKey, _isDarkMode);
    notifyListeners();
  }
}
