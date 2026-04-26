// Midori — App Router
//
// No authentication required. All routes are publicly accessible.
// The app opens directly to the scan/home screen.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/home/screens/demo_home_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => DemoHomeScreen(
          isDarkMode: false,
          onThemeChanged: (_) {},
        ),
      ),
    ],
  );
});
