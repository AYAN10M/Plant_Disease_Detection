import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/theme/app_theme.dart';
import 'features/home/screens/demo_home_screen.dart';

void main() {
  runApp(
    // ProviderScope is required for Riverpod to work throughout the app.
    const ProviderScope(child: MidoriApp()),
  );
}

class MidoriApp extends StatefulWidget {
  const MidoriApp({super.key});

  @override
  State<MidoriApp> createState() => _MidoriAppState();
}

class _MidoriAppState extends State<MidoriApp> {
  bool _isDarkMode = false;

  void _setDarkMode(bool value) {
    setState(() => _isDarkMode = value);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Midori',
      debugShowCheckedModeBanner: false,
      theme:     AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: _isDarkMode ? ThemeMode.dark : ThemeMode.light,
      home: DemoHomeScreen(
        isDarkMode: _isDarkMode,
        onThemeChanged: _setDarkMode,
      ),
    );
  }
}
