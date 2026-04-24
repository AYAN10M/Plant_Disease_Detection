import 'package:flutter/material.dart';
import 'package:plant_disease_detection/screens/auth_screen.dart';
import 'package:plant_disease_detection/screens/result_screen.dart';
import 'package:plant_disease_detection/theme/app_theme.dart';
import 'package:plant_disease_detection/widgets/main_shell.dart';

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
      theme: AppTheme.theme,

      // During development change to '/home' to skip login
      initialRoute: '/auth',

      routes: {
        '/auth': (ctx) => const AuthScreen(),
        '/home': (ctx) => const MainShell(), // <-- shell with bottom nav
        '/result': (ctx) => const ResultScreen(),
        // History and Scan are now tabs inside MainShell, not named routes
      },
    );
  }
}
