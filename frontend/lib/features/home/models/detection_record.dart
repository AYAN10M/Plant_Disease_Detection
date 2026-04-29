import 'dart:convert';
import 'dart:typed_data';

String humanizeModelLabel(String? label) {
  if (label == null || label.trim().isEmpty) {
    return 'Unknown';
  }

  var value = label.trim();
  if (value.contains('___')) {
    value = value.split('___').last;
  } else if (value.contains('__')) {
    value = value.split('__').last;
  }

  value = value.replaceAll('_', ' ');
  value = value.replaceAll(RegExp(r'\s+'), ' ').trim();
  return value;
}

// ─────────────────────────────────────────────────────────────────────────────
// API response wrappers (used when talking to the real Django backend)
// ─────────────────────────────────────────────────────────────────────────────

class DetectionApiResponse {
  final String status;
  final String? message;
  final DetectionResult? data;

  const DetectionApiResponse({required this.status, this.message, this.data});

  factory DetectionApiResponse.fromJson(Map<String, dynamic> json) {
    return DetectionApiResponse(
      status: json['status'] as String? ?? 'success',
      message: json['message'] as String?,
      data: json['data'] is Map<String, dynamic>
          ? DetectionResult.fromJson(json['data'] as Map<String, dynamic>)
          : null,
    );
  }
}

class DetectionResult {
  final int id;
  final String plantName;
  final String? diseaseName;
  final String? diseaseCause;
  final String? diseaseDescription;
  final String? diseaseRemedy;
  final String? diseasePrevention;
  final String? uploadedImageUrl;
  final String? gradcamImageUrl;
  final double confidence;
  final String confidencePct;
  final String status;
  final bool isHealthy;
  final DateTime? createdAt;

  const DetectionResult({
    required this.id,
    required this.plantName,
    required this.diseaseName,
    required this.diseaseCause,
    required this.diseaseDescription,
    required this.diseaseRemedy,
    required this.diseasePrevention,
    required this.uploadedImageUrl,
    required this.gradcamImageUrl,
    required this.confidence,
    required this.confidencePct,
    required this.status,
    required this.isHealthy,
    required this.createdAt,
  });

  factory DetectionResult.fromJson(Map<String, dynamic> json) {
    final diseaseDetail = json['disease_detail'] as Map<String, dynamic>?;
    final statusStr = json['status'] as String? ?? 'success';
    return DetectionResult(
      id: json['id'] as int,
      plantName: json['plant_name'] as String? ?? '',
      diseaseName: humanizeModelLabel(diseaseDetail?['name'] as String?),
      diseaseCause: diseaseDetail?['cause'] as String?,
      diseaseDescription: diseaseDetail?['description'] as String?,
      diseaseRemedy: diseaseDetail?['remedy'] as String?,
      diseasePrevention: diseaseDetail?['prevention'] as String?,
      uploadedImageUrl: json['uploaded_image'] as String?,
      gradcamImageUrl: json['gradcam_image'] as String?,
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0.0,
      confidencePct: json['confidence_pct'] as String? ?? '0%',
      status: statusStr,
      isHealthy: (json['is_healthy'] as bool?) ?? (statusStr == 'healthy'),
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? ''),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Local-storage history entry
// ─────────────────────────────────────────────────────────────────────────────

class DetectionHistoryEntry {
  final String plantName;
  final String? diseaseName;
  final String? diseaseCause;
  final String? diseaseDescription;
  final String? diseaseRemedy;
  final String? diseasePrevention;
  final String? message;
  final String? imageUrl;
  final String? gradcamUrl;

  /// Raw bytes of the uploaded image encoded as base-64 so they can be stored
  /// in SharedPreferences and displayed without needing a network URL.
  final String? imageBase64;

  /// Raw bytes of the Grad-CAM overlay encoded as base-64.
  final String? gradcamBase64;

  final double confidence;
  final String status;
  final bool isHealthy;
  final DateTime createdAt;

  const DetectionHistoryEntry({
    required this.plantName,
    required this.diseaseName,
    this.diseaseCause,
    this.diseaseDescription,
    this.diseaseRemedy,
    this.diseasePrevention,
    required this.message,
    required this.imageUrl,
    required this.gradcamUrl,
    this.imageBase64,
    this.gradcamBase64,
    required this.confidence,
    required this.status,
    required this.isHealthy,
    required this.createdAt,
  });

  // ── Helpers ────────────────────────────────────────────────────────────────

  /// Returns the decoded image bytes, or null if the stored data is corrupt.
  Uint8List? get imageBytes {
    if (imageBase64 == null) return null;
    try {
      return base64Decode(imageBase64!);
    } catch (_) {
      return null;
    }
  }

  /// Returns the decoded Grad-CAM bytes, or null if the stored data is corrupt.
  Uint8List? get gradcamBytes {
    if (gradcamBase64 == null) return null;
    try {
      return base64Decode(gradcamBase64!);
    } catch (_) {
      return null;
    }
  }

  // ── Factory constructors ───────────────────────────────────────────────────

  factory DetectionHistoryEntry.fromDetection({
    required DetectionResult result,
    required String? message,
    Uint8List? imageBytes,
    Uint8List? gradcamBytes,
  }) {
    // result.diseaseName is already humanized in DetectionResult.fromJson —
    // do NOT call humanizeModelLabel again or names get processed twice.
    return DetectionHistoryEntry(
      plantName: result.plantName.isNotEmpty ? result.plantName : 'Unknown plant',
      diseaseName: result.diseaseName,
      diseaseCause: result.diseaseCause,
      diseaseDescription: result.diseaseDescription,
      diseaseRemedy: result.diseaseRemedy,
      diseasePrevention: result.diseasePrevention,
      message: message,
      imageUrl: result.uploadedImageUrl,
      gradcamUrl: result.gradcamImageUrl,
      imageBase64: imageBytes != null ? base64Encode(imageBytes) : null,
      gradcamBase64: gradcamBytes != null ? base64Encode(gradcamBytes) : null,
      confidence: result.confidence,
      status: result.status,
      isHealthy: result.isHealthy,
      createdAt: result.createdAt ?? DateTime.now(),
    );
  }

  factory DetectionHistoryEntry.fromJson(Map<String, dynamic> json) {
    final statusStr = json['status'] as String? ?? 'success';
    return DetectionHistoryEntry(
      plantName: json['plantName'] as String? ?? '',
      diseaseName: json['diseaseName'] as String?,
      diseaseCause: json['diseaseCause'] as String?,
      diseaseDescription: json['diseaseDescription'] as String?,
      diseaseRemedy: json['diseaseRemedy'] as String?,
      diseasePrevention: json['diseasePrevention'] as String?,
      message: json['message'] as String?,
      imageUrl: json['imageUrl'] as String?,
      gradcamUrl: json['gradcamUrl'] as String?,
      imageBase64: json['imageBase64'] as String?,
      gradcamBase64: json['gradcamBase64'] as String?,
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0.0,
      status: statusStr,
      isHealthy: (json['isHealthy'] as bool?) ?? (statusStr == 'healthy'),
      createdAt:
          DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'plantName': plantName,
      'diseaseName': diseaseName,
      'diseaseCause': diseaseCause,
      'diseaseDescription': diseaseDescription,
      'diseaseRemedy': diseaseRemedy,
      'diseasePrevention': diseasePrevention,
      'message': message,
      'imageUrl': imageUrl,
      'gradcamUrl': gradcamUrl,
      'imageBase64': imageBase64,
      'gradcamBase64': gradcamBase64,
      'confidence': confidence,
      'status': status,
      'isHealthy': isHealthy,
      'createdAt': createdAt.toIso8601String(),
    };
  }
}
