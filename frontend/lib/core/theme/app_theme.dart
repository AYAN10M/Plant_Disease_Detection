import 'package:flutter/material.dart';

class AppColors {
  static const spotifyGreen = Color(0xFF1DB954);
  static const spotifyGreenDark = Color(0xFF1AA34A);
  static const error = Color(0xFFD32F2F);

  // Backward-compatible aliases used by existing screens.
  static const primary = spotifyGreen;
  static const primaryLight = Color(0xFF58D68D);
  static const accent = Color(0xFF6C6C6C);
  static const background = Color(0xFFF6F6F6);
  static const surface = Color(0xFFFFFFFF);
  static const textPrimary = Color(0xFF121212);
  static const textSecondary = Color(0xFF7A7A7A);
}

class AppTheme {
  static ThemeData get light => ThemeData(
    useMaterial3: true,
    colorScheme: const ColorScheme(
      brightness: Brightness.light,
      primary: AppColors.spotifyGreen,
      onPrimary: Colors.black,
      secondary: Color(0xFF2D2D2D),
      onSecondary: Colors.white,
      error: AppColors.error,
      onError: Colors.white,
      surface: Color(0xFFFFFFFF),
      onSurface: Color(0xFF121212),
    ),
    scaffoldBackgroundColor: const Color(0xFFF6F6F6),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.white,
      foregroundColor: Color(0xFF121212),
      elevation: 0,
      centerTitle: true,
    ),
    cardTheme: const CardThemeData(
      color: Colors.white,
      surfaceTintColor: Colors.transparent,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(18)),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.spotifyGreen,
        foregroundColor: Colors.black,
        minimumSize: const Size(double.infinity, 52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: AppColors.spotifyGreen,
      foregroundColor: Colors.black,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(16)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: const Color(0xFF121212),
        side: const BorderSide(color: Color(0xFFC8CEC9)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        minimumSize: const Size(double.infinity, 52),
      ),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return Colors.black;
        }
        return Colors.white;
      }),
      trackColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return AppColors.spotifyGreen;
        }
        return const Color(0xFFD2D8D3);
      }),
    ),
    navigationBarTheme: const NavigationBarThemeData(
      indicatorColor: Color(0x2B1DB954),
      labelTextStyle: WidgetStatePropertyAll(
        TextStyle(fontWeight: FontWeight.w600),
      ),
    ),
    chipTheme: const ChipThemeData(
      backgroundColor: Color(0xFFE8F7EE),
      selectedColor: AppColors.spotifyGreen,
      labelStyle: TextStyle(color: Color(0xFF121212)),
      padding: EdgeInsets.symmetric(horizontal: 8),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: const Color(0xFFFDFDFD),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFD3D3D3)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFD3D3D3)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.spotifyGreen, width: 2),
      ),
    ),
  );

  static ThemeData get dark => ThemeData(
    useMaterial3: true,
    colorScheme: const ColorScheme(
      brightness: Brightness.dark,
      primary: AppColors.spotifyGreen,
      onPrimary: Colors.black,
      secondary: Color(0xFFB3B3B3),
      onSecondary: Color(0xFF121212),
      error: AppColors.error,
      onError: Colors.white,
      surface: Color(0xFF1A1A1A),
      onSurface: Color(0xFFF3F3F3),
    ),
    scaffoldBackgroundColor: const Color(0xFF121212),
    appBarTheme: const AppBarTheme(
      backgroundColor: Color(0xFF121212),
      foregroundColor: Colors.white,
      elevation: 0,
      centerTitle: true,
    ),
    cardTheme: const CardThemeData(
      color: Color(0xFF1D1D1D),
      surfaceTintColor: Colors.transparent,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(18)),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.spotifyGreen,
        foregroundColor: Colors.black,
        minimumSize: const Size(double.infinity, 52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: AppColors.spotifyGreen,
      foregroundColor: Colors.black,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(16)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: const Color(0xFFEDEDED),
        side: const BorderSide(color: Color(0xFF2F3B33)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        minimumSize: const Size(double.infinity, 52),
      ),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return Colors.black;
        }
        return const Color(0xFFE9E9E9);
      }),
      trackColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return AppColors.spotifyGreen;
        }
        return const Color(0xFF353535);
      }),
    ),
    navigationBarTheme: const NavigationBarThemeData(
      indicatorColor: Color(0x3F1DB954),
      labelTextStyle: WidgetStatePropertyAll(
        TextStyle(fontWeight: FontWeight.w600),
      ),
    ),
    chipTheme: const ChipThemeData(
      backgroundColor: Color(0xFF2A2A2A),
      selectedColor: AppColors.spotifyGreen,
      labelStyle: TextStyle(color: Colors.white),
      padding: EdgeInsets.symmetric(horizontal: 8),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: const Color(0xFF212121),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF3D3D3D)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF3D3D3D)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.spotifyGreen, width: 2),
      ),
    ),
  );

  static ThemeData get gray => ThemeData(
    useMaterial3: true,
    colorScheme: const ColorScheme(
      brightness: Brightness.light,
      primary: AppColors.spotifyGreenDark,
      onPrimary: Colors.white,
      secondary: Color(0xFF515151),
      onSecondary: Colors.white,
      error: AppColors.error,
      onError: Colors.white,
      surface: Color(0xFFF0F0F0),
      onSurface: Color(0xFF212121),
    ),
    scaffoldBackgroundColor: const Color(0xFFE5E5E5),
    appBarTheme: const AppBarTheme(
      backgroundColor: Color(0xFF565656),
      foregroundColor: Colors.white,
      elevation: 0,
      centerTitle: true,
    ),
    cardTheme: const CardThemeData(
      color: Color(0xFFF2F2F2),
      surfaceTintColor: Colors.transparent,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.spotifyGreenDark,
        foregroundColor: Colors.white,
        minimumSize: const Size(double.infinity, 52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: AppColors.spotifyGreenDark,
      foregroundColor: Colors.white,
    ),
    chipTheme: const ChipThemeData(
      backgroundColor: Color(0xFFE1E1E1),
      selectedColor: AppColors.spotifyGreenDark,
      labelStyle: TextStyle(color: Color(0xFF212121)),
      padding: EdgeInsets.symmetric(horizontal: 8),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: const Color(0xFFF8F8F8),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFBBBBBB)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFBBBBBB)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(
          color: AppColors.spotifyGreenDark,
          width: 2,
        ),
      ),
    ),
  );
}
