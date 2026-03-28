import 'package:flutter/material.dart';
import 'package:plant_disease_detection/screens/auth_screen.dart';
import 'package:plant_disease_detection/screens/history_screen.dart';
import 'package:plant_disease_detection/screens/home_screen.dart';
import 'package:plant_disease_detection/screens/result_screen.dart';
import 'package:plant_disease_detection/theme/app_theme.dart';


// ─────────────────────────────────────────
//  main.dart
//  Entry point of the app.
//  Sets up theme and named routes.
//
//  PUBSPEC DEPENDENCIES to add:
//  dependencies:
//    flutter:
//      sdk: flutter
//    image_picker: ^1.0.7
//    dio: ^5.4.0          # for API calls
//    google_fonts: ^6.1.0 # optional for Nunito font
//
//  FONT: Add Nunito via google_fonts package, or
//  download and add to pubspec.yaml under fonts:
// ─────────────────────────────────────────

void main() {
  runApp(const PlantDiseaseApp());
}

class PlantDiseaseApp extends StatelessWidget {
  const PlantDiseaseApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'LeafScan',
      debugShowCheckedModeBanner: false,

      // Apply our custom theme from app_theme.dart
      theme: AppTheme.theme,

      // Start on auth screen
      // Change to '/home' if you want to skip login during development
      initialRoute: '/auth',

      // Named routes — easy to navigate between screens
      routes: {
        '/auth': (ctx) => const AuthScreen(),
        '/home': (ctx) => const HomeScreen(),
        '/result': (ctx) => const ResultScreen(),
        '/history': (ctx) => const HistoryScreen(),
      },
    );
  }
}
