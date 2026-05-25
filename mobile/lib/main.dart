import 'package:flutter/material.dart';

import 'core/theme/app_theme.dart';
import 'features/scan/screens/scan_screen.dart';

final themeModeNotifier = ValueNotifier<ThemeMode>(ThemeMode.light);

void main() {
  runApp(const MidoriApp());
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
    themeModeNotifier.addListener(_onThemeChanged);
  }

  @override
  void dispose() {
    themeModeNotifier.removeListener(_onThemeChanged);
    super.dispose();
  }

  void _onThemeChanged() => setState(() {});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Midori',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeModeNotifier.value,
      home: const ScanScreen(),
    );
  }
}
