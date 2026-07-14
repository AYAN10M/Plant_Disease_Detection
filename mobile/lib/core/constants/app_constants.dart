/// Midori — Application-wide constants.
library;

class AppConstants {
  AppConstants._();

  // Server
  static const String serverBaseUrl = String.fromEnvironment(
    'MIDORI_BASE_URL',
    defaultValue: '',
  );

  static const String lanIp = String.fromEnvironment(
    'MIDORI_SERVER_IP',
    defaultValue: '10.0.2.2',  // Android emulator -> host localhost
  );

  // Image limits
  static const int maxImageBytes = 10 * 1024 * 1024; // 10 MB
  static const int maxImageDimension = 1920;

  // Timeouts
  static const Duration healthCheckTimeout = Duration(seconds: 15);
  static const Duration detectionTimeout = Duration(seconds: 90);
  static const Duration mediaFetchTimeout = Duration(seconds: 30);

  // History
  static const int maxHistoryEntries = 50;
  static const String historyPrefsKey = 'detection_history';

  // Supported plants (those with trained disease models)
  static const List<String> plantOverrideOptions = [
    'Apple',
    'Grape',
    'Potato',
    'Pepper',
  ];

  // Plants identified by Stage 1 but without disease models yet
  static const List<String> identifiedOnlyPlants = [
    'Corn',
    'Strawberry',
  ];

  // Model architecture
  static const String stage1ModelName = 'EfficientNetV2-S';
  static const String stage2ModelName = 'MobileNetV2';

  // Confidence thresholds
  static const double highConfidence = 0.80;
  static const double mediumConfidence = 0.55;

  // Status codes (must match server STATUS_CHOICES)
  static const String statusSuccess = 'success';
  static const String statusHealthy = 'healthy';
  static const String statusLowConfidence = 'low_confidence';
  static const String statusNotRecognized = 'not_recognized';
  static const String statusNoModel = 'no_model';
  static const String statusNotAPlant = 'not_a_plant';
  static const String statusFailed = 'failed';
  static const String statusProcessing = 'processing';
}
