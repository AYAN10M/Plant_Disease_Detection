import 'package:plant_disease_detection/models/disease_info.dart';

class ScanResult {
  final String imagePath;
  final String disease;
  final double confidence;
  final String plant;
  final bool isHealthy;
  final String? annotatedImageUrl;
  final DiseaseInfo? diseaseInfo;

  const ScanResult({
    required this.imagePath,
    required this.disease,
    required this.confidence,
    required this.plant,
    required this.isHealthy,
    this.annotatedImageUrl,
    this.diseaseInfo,
  });

  factory ScanResult.fromJson(Map<String, dynamic> json) {
    final confidence = _asDouble(json['confidence']) ?? 0.0;

    return ScanResult(
      imagePath: _asString(json['imagePath']) ?? '',
      disease: _asString(json['disease']) ?? 'Unknown',
      confidence: confidence.clamp(0.0, 1.0),
      plant: _asString(json['plant']) ?? 'Unknown plant',
      isHealthy: _asBool(json['isHealthy']) ?? false,
      annotatedImageUrl: _asString(json['annotatedImageUrl']),
      diseaseInfo: _asDiseaseInfo(json['diseaseInfo']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'imagePath': imagePath,
      'disease': disease,
      'confidence': confidence,
      'plant': plant,
      'isHealthy': isHealthy,
      'annotatedImageUrl': annotatedImageUrl,
      'diseaseInfo': diseaseInfo?.toJson(),
    };
  }

  Map<String, dynamic> toRouteArguments() {
    return {
      'imagePath': imagePath,
      'disease': disease,
      'confidence': confidence,
      'plant': plant,
      'isHealthy': isHealthy,
      'diseaseInfo': diseaseInfo?.toJson(),
    };
  }

  static String? _asString(dynamic value) {
    if (value is String) {
      final trimmed = value.trim();
      return trimmed.isEmpty ? null : trimmed;
    }
    return null;
  }

  static double? _asDouble(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  static bool? _asBool(dynamic value) {
    if (value is bool) return value;
    if (value is String) {
      final normalized = value.trim().toLowerCase();
      if (normalized == 'true') return true;
      if (normalized == 'false') return false;
    }
    return null;
  }

  static DiseaseInfo? _asDiseaseInfo(dynamic value) {
    if (value is Map<String, dynamic>) {
      return DiseaseInfo.fromJson(value);
    }
    return null;
  }
}
