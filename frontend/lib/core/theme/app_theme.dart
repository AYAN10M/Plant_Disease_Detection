import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  static const black = Color(0xFF111111);
  static const white = Color(0xFFFFFFFF);
  static const gray900 = Color(0xFF1F1F1F);
  static const gray800 = Color(0xFF2E2E2E);
  static const gray700 = Color(0xFF4A4A4A);
  static const gray600 = Color(0xFF666666);
  static const gray500 = Color(0xFF8A8A8A);
  static const gray300 = Color(0xFFD1D1D1);
  static const gray200 = Color(0xFFE5E5E5);
  static const gray100 = Color(0xFFF2F2F2);
  static const gray50 = Color(0xFFF8F8F8);
  static const error = Color(0xFF444444);

  // Backward-compatible aliases used by existing screens.
  static const primary = black;
  static const primaryLight = gray700;
  static const accent = gray600;
  static const background = gray50;
  static const surface = white;
  static const textPrimary = black;
  static const textSecondary = gray600;
}

class AppTheme {
  static TextTheme _textTheme(Brightness brightness) {
    final base = brightness == Brightness.dark
        ? ThemeData.dark().textTheme
        : ThemeData.light().textTheme;
    return GoogleFonts.manropeTextTheme(base).copyWith(
      titleLarge: GoogleFonts.manrope(
        fontWeight: FontWeight.w700,
        letterSpacing: -0.2,
      ),
      titleMedium: GoogleFonts.manrope(
        fontWeight: FontWeight.w700,
        letterSpacing: -0.1,
      ),
      bodyLarge: GoogleFonts.manrope(fontWeight: FontWeight.w500, height: 1.4),
      bodyMedium: GoogleFonts.manrope(
        fontWeight: FontWeight.w500,
        height: 1.35,
      ),
      labelLarge: GoogleFonts.manrope(fontWeight: FontWeight.w700),
    );
  }

  static ThemeData get light => ThemeData(
    useMaterial3: true,
    textTheme: _textTheme(Brightness.light),
    colorScheme: const ColorScheme(
      brightness: Brightness.light,
      primary: AppColors.black,
      onPrimary: AppColors.white,
      secondary: AppColors.gray700,
      onSecondary: AppColors.white,
      error: AppColors.error,
      onError: AppColors.white,
      surface: AppColors.white,
      onSurface: AppColors.black,
    ),
    scaffoldBackgroundColor: AppColors.gray50,
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.white,
      foregroundColor: AppColors.black,
      elevation: 0,
      centerTitle: true,
    ),
    cardTheme: const CardThemeData(
      color: AppColors.white,
      surfaceTintColor: Colors.transparent,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(18)),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.black,
        foregroundColor: AppColors.white,
        minimumSize: const Size(double.infinity, 52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: AppColors.black,
      foregroundColor: AppColors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(16)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.black,
        side: const BorderSide(color: AppColors.gray300),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        minimumSize: const Size(double.infinity, 52),
      ),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return AppColors.white;
        }
        return AppColors.gray100;
      }),
      trackColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return AppColors.black;
        }
        return AppColors.gray300;
      }),
    ),
    navigationBarTheme: const NavigationBarThemeData(
      indicatorColor: AppColors.gray200,
      labelTextStyle: WidgetStatePropertyAll(
        TextStyle(fontWeight: FontWeight.w600),
      ),
    ),
    chipTheme: const ChipThemeData(
      backgroundColor: AppColors.gray100,
      selectedColor: AppColors.gray300,
      labelStyle: TextStyle(color: AppColors.black),
      padding: EdgeInsets.symmetric(horizontal: 8),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.gray300),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.gray300),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.black, width: 2),
      ),
    ),
  );

  static ThemeData get dark => ThemeData(
    useMaterial3: true,
    textTheme: _textTheme(Brightness.dark),
    colorScheme: const ColorScheme(
      brightness: Brightness.dark,
      primary: AppColors.white,
      onPrimary: AppColors.black,
      secondary: AppColors.gray300,
      onSecondary: AppColors.black,
      error: AppColors.error,
      onError: AppColors.white,
      surface: AppColors.gray900,
      onSurface: AppColors.white,
    ),
    scaffoldBackgroundColor: AppColors.black,
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.black,
      foregroundColor: AppColors.white,
      elevation: 0,
      centerTitle: true,
    ),
    cardTheme: const CardThemeData(
      color: AppColors.gray900,
      surfaceTintColor: Colors.transparent,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(18)),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.white,
        foregroundColor: Colors.black,
        minimumSize: const Size(double.infinity, 52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: AppColors.white,
      foregroundColor: Colors.black,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(16)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.white,
        side: const BorderSide(color: AppColors.gray700),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        minimumSize: const Size(double.infinity, 52),
      ),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return AppColors.black;
        }
        return AppColors.gray200;
      }),
      trackColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return AppColors.white;
        }
        return AppColors.gray700;
      }),
    ),
    navigationBarTheme: const NavigationBarThemeData(
      indicatorColor: AppColors.gray700,
      labelTextStyle: WidgetStatePropertyAll(
        TextStyle(fontWeight: FontWeight.w600),
      ),
    ),
    chipTheme: const ChipThemeData(
      backgroundColor: AppColors.gray800,
      selectedColor: AppColors.gray600,
      labelStyle: TextStyle(color: AppColors.white),
      padding: EdgeInsets.symmetric(horizontal: 8),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.gray900,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.gray700),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.gray700),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.white, width: 2),
      ),
    ),
  );

  static ThemeData get gray => ThemeData(
    useMaterial3: true,
    textTheme: _textTheme(Brightness.light),
    colorScheme: const ColorScheme(
      brightness: Brightness.light,
      primary: AppColors.gray800,
      onPrimary: Colors.white,
      secondary: AppColors.gray600,
      onSecondary: Colors.white,
      error: AppColors.error,
      onError: Colors.white,
      surface: AppColors.gray100,
      onSurface: AppColors.gray900,
    ),
    scaffoldBackgroundColor: AppColors.gray200,
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.gray700,
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
        backgroundColor: AppColors.gray800,
        foregroundColor: Colors.white,
        minimumSize: const Size(double.infinity, 52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: AppColors.gray800,
      foregroundColor: Colors.white,
    ),
    chipTheme: const ChipThemeData(
      backgroundColor: Color(0xFFE1E1E1),
      selectedColor: AppColors.gray600,
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
        borderSide: const BorderSide(color: AppColors.gray800, width: 2),
      ),
    ),
  );
}
