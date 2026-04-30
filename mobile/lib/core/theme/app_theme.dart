import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// A clean, nature-inspired palette. Green is the accent in both modes.
class AppColors {
  // ── Greens ──────────────────────────────────────────────────────────────
  static const green600  = Color(0xFF2E7D32); // primary action (dark on white)
  static const green500  = Color(0xFF388E3C);
  static const green400  = Color(0xFF43A047);
  static const green100  = Color(0xFFC8E6C9);
  static const green50   = Color(0xFFE8F5E9);

  // ── Neutrals ─────────────────────────────────────────────────────────────
  static const black     = Color(0xFF0D0D0D);
  static const gray950   = Color(0xFF121212);
  static const gray900   = Color(0xFF1C1C1C);
  static const gray800   = Color(0xFF2A2A2A);
  static const gray700   = Color(0xFF3D3D3D);
  static const gray600   = Color(0xFF555555);
  static const gray400   = Color(0xFF909090);
  static const gray300   = Color(0xFFBBBBBB);
  static const gray200   = Color(0xFFDDDDDD);
  static const gray100   = Color(0xFFF0F0F0);
  static const gray50    = Color(0xFFF7F7F7);
  static const white     = Color(0xFFFFFFFF);

  // ── Semantic ─────────────────────────────────────────────────────────────
  static const error     = Color(0xFFD32F2F);
  static const warning   = Color(0xFFF57F17);
  static const success   = Color(0xFF2E7D32);
}

class AppTheme {
  static TextTheme _textTheme(Brightness brightness) {
    final base = brightness == Brightness.dark
        ? ThemeData.dark().textTheme
        : ThemeData.light().textTheme;
    return GoogleFonts.plusJakartaSansTextTheme(base).copyWith(
      titleLarge:  GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, letterSpacing: -0.3),
      titleMedium: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, letterSpacing: -0.1),
      bodyLarge:   GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w500, height: 1.45),
      bodyMedium:  GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w400, height: 1.4),
      labelLarge:  GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600, letterSpacing: 0.1),
    );
  }

  // ── Shared splash/highlight removal ─────────────────────────────────────
  static const _noSplash = NoSplash.splashFactory;

  static ThemeData get light => ThemeData(
    useMaterial3: true,
    splashFactory: _noSplash,
    highlightColor: Colors.transparent,
    splashColor: Colors.transparent,
    textTheme: _textTheme(Brightness.light),
    colorScheme: const ColorScheme(
      brightness:   Brightness.light,
      primary:      AppColors.green600,
      onPrimary:    AppColors.white,
      secondary:    AppColors.green500,
      onSecondary:  AppColors.white,
      error:        AppColors.error,
      onError:      AppColors.white,
      surface:      AppColors.white,
      onSurface:    AppColors.black,
    ),
    scaffoldBackgroundColor: AppColors.gray50,
    appBarTheme: AppBarTheme(
      backgroundColor: AppColors.white,
      foregroundColor: AppColors.black,
      elevation: 0,
      centerTitle: false,
      surfaceTintColor: Colors.transparent,
      shadowColor: Colors.transparent,
      titleTextStyle: GoogleFonts.plusJakartaSans(
        color: AppColors.black,
        fontWeight: FontWeight.w800,
        fontSize: 20,
        letterSpacing: -0.3,
      ),
    ),
    cardTheme: const CardThemeData(
      color: AppColors.white,
      surfaceTintColor: Colors.transparent,
      margin: EdgeInsets.zero,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(16)),
        side: BorderSide(color: AppColors.gray200),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.green600,
        foregroundColor: AppColors.white,
        minimumSize: const Size(double.infinity, 50),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 0,
        splashFactory: _noSplash,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.green600,
        side: const BorderSide(color: AppColors.green600, width: 1.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        minimumSize: const Size(double.infinity, 50),
        splashFactory: _noSplash,
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: AppColors.white,
      surfaceTintColor: Colors.transparent,
      indicatorColor: AppColors.green50,
      iconTheme: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return const IconThemeData(color: AppColors.green600);
        }
        return const IconThemeData(color: AppColors.gray400);
      }),
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 12,
            color: AppColors.green600,
          );
        }
        return const TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 12,
          color: AppColors.gray400,
        );
      }),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.gray200),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.gray200),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.green600, width: 2),
      ),
    ),
    dividerTheme: const DividerThemeData(color: AppColors.gray100, thickness: 1),
    iconTheme: const IconThemeData(color: AppColors.gray600),
  );

  static ThemeData get dark => ThemeData(
    useMaterial3: true,
    splashFactory: _noSplash,
    highlightColor: Colors.transparent,
    splashColor: Colors.transparent,
    textTheme: _textTheme(Brightness.dark),
    colorScheme: const ColorScheme(
      brightness:   Brightness.dark,
      primary:      AppColors.green400,
      onPrimary:    AppColors.black,
      secondary:    AppColors.green400,
      onSecondary:  AppColors.black,
      error:        Color(0xFFEF5350),
      onError:      AppColors.white,
      surface:      AppColors.gray900,
      onSurface:    AppColors.white,
    ),
    scaffoldBackgroundColor: AppColors.gray950,
    appBarTheme: AppBarTheme(
      backgroundColor: AppColors.gray950,
      foregroundColor: AppColors.white,
      elevation: 0,
      centerTitle: false,
      surfaceTintColor: Colors.transparent,
      shadowColor: Colors.transparent,
      titleTextStyle: GoogleFonts.plusJakartaSans(
        color: AppColors.white,
        fontWeight: FontWeight.w800,
        fontSize: 20,
        letterSpacing: -0.3,
      ),
    ),
    cardTheme: const CardThemeData(
      color: AppColors.gray900,
      surfaceTintColor: Colors.transparent,
      margin: EdgeInsets.zero,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(16)),
        side: BorderSide(color: AppColors.gray800),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.green400,
        foregroundColor: AppColors.black,
        minimumSize: const Size(double.infinity, 50),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 0,
        splashFactory: _noSplash,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.green400,
        side: const BorderSide(color: AppColors.green400, width: 1.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        minimumSize: const Size(double.infinity, 50),
        splashFactory: _noSplash,
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: AppColors.gray900,
      surfaceTintColor: Colors.transparent,
      indicatorColor: const Color(0xFF1B3A1B),
      iconTheme: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return const IconThemeData(color: AppColors.green400);
        }
        return const IconThemeData(color: AppColors.gray400);
      }),
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 12,
            color: AppColors.green400,
          );
        }
        return const TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 12,
          color: AppColors.gray400,
        );
      }),
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
        borderSide: const BorderSide(color: AppColors.green400, width: 2),
      ),
    ),
    dividerTheme: const DividerThemeData(color: AppColors.gray800, thickness: 1),
    iconTheme: const IconThemeData(color: AppColors.gray400),
  );
}
