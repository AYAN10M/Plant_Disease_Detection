library;

class AppConstants {
  AppConstants._();

  static const String serverBaseUrl = String.fromEnvironment(
    'MIDORI_BASE_URL',
    defaultValue: '',
  );

  static const String lanIp = String.fromEnvironment(
    'MIDORI_SERVER_IP',
    defaultValue: '172.25.0.38',
  );

  static const int maxImageBytes = 10 * 1024 * 1024;
  static const int maxImageDimension = 1920;

  static const Duration healthCheckTimeout = Duration(seconds: 15);
  static const Duration detectionTimeout = Duration(seconds: 90);
  static const Duration mediaFetchTimeout = Duration(seconds: 30);

  static const int maxHistoryEntries = 50;
  static const String historyPrefsKey = 'detection_history';

  static const List<String> plantOverrideOptions = [
    'Apple',
    'Grape',
    'Potato',
    'Pepper',
  ];

  static const List<String> identifiedOnlyPlants = [
    'Corn',
    'Strawberry',
  ];

  static const String stage1ModelName = 'EfficientNetV2-S';
  static const String stage2ModelName = 'MobileNetV2';

  static const double highConfidence = 0.80;
  static const double mediumConfidence = 0.55;

  static const String statusSuccess = 'success';
  static const String statusHealthy = 'healthy';
  static const String statusLowConfidence = 'low_confidence';
  static const String statusNotRecognized = 'not_recognized';
  static const String statusNoModel = 'no_model';
  static const String statusNotAPlant = 'not_a_plant';
  static const String statusFailed = 'failed';
  static const String statusProcessing = 'processing';
}
