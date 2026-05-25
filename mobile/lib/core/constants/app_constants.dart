/// Midori — App-wide constants
///
/// Import with:
///   import 'package:midori/core/constants/app_constants.dart';
library;

class AppConstants {
  AppConstants._();

  // ── Server ─────────────────────────────────────────────────────────────────
  /// Override at build time:
  ///   flutter run --dart-define=MIDORI_BASE_URL=http://192.168.x.x:8000
  static const String serverBaseUrl = String.fromEnvironment(
    'MIDORI_BASE_URL',
    defaultValue: '',  // resolved at runtime in api_service.dart
  );

  /// LAN IP for release builds on a real Android device.
  static const String lanIp = String.fromEnvironment(
    'MIDORI_SERVER_IP',
    defaultValue: '192.168.29.92',
  );

  // ── Image limits ───────────────────────────────────────────────────────────
  static const int maxImageBytes = 10 * 1024 * 1024;   // 10 MB
  static const int maxImageDimension = 1920;            // px

  // ── Timeouts ───────────────────────────────────────────────────────────────
  static const Duration healthCheckTimeout = Duration(seconds: 15);
  static const Duration detectionTimeout   = Duration(seconds: 90);
  static const Duration mediaFetchTimeout  = Duration(seconds: 30);

  // ── History ────────────────────────────────────────────────────────────────
  static const int maxHistoryEntries = 50;
  static const String historyPrefsKey = 'detection_history';

  // ── Plant override options (must match server PLANT_CLASSES) ───────────────
  static const List<String> plantOverrideOptions = [
    'Apple', 'Corn', 'Grape', 'Potato', 'Tomato', 'Pepper',
  ];

  // ── Confidence thresholds (mirror server thresholds) ──────────────────────
  static const double highConfidence   = 0.80;
  static const double mediumConfidence = 0.55;
  // Below mediumConfidence → low/warn colour

  // ── Status codes (must match server STATUS_CHOICES) ────────────────────────
  static const String statusSuccess       = 'success';
  static const String statusHealthy       = 'healthy';
  static const String statusLowConfidence = 'low_confidence';
  static const String statusNotRecognized = 'not_recognized';
  static const String statusNoModel       = 'no_model';
  static const String statusNotAPlant     = 'not_a_plant';
  static const String statusFailed        = 'failed';
  static const String statusProcessing    = 'processing';
}
