import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/theme/app_theme.dart';
import 'features/home/screens/home_screen.dart';

/// Global notifier that drives the app-wide theme mode.
/// HomeScreen reads and writes this to provide the AppBar toggle.
final themeModeNotifier = ValueNotifier<ThemeMode>(ThemeMode.light);

void main() {
  runApp(const ProviderScope(child: MidoriApp()));
}

class MidoriApp extends StatefulWidget {
  const MidoriApp({super.key});

  @override
  State<MidoriApp> createState() => _MidoriAppState();
}

class _MidoriAppState extends State<MidoriApp> {
  @override
  void initState() {
    super.initState();
    themeModeNotifier.addListener(_onThemeModeChanged);
  }

  @override
  void dispose() {
    themeModeNotifier.removeListener(_onThemeModeChanged);
    super.dispose();
  }

  void _onThemeModeChanged() => setState(() {});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Midori',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeModeNotifier.value,
      home: const HomeScreen(),
    );
  }
}
