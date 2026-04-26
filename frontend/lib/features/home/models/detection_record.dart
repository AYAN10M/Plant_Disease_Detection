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
  final String? diseaseDescription;
  final String? diseaseRemedy;
  final String? uploadedImageUrl;
  final String? gradcamImageUrl;
  final double confidence;
  final String confidencePct;
  final String status;
  final DateTime? createdAt;

  const DetectionResult({
    required this.id,
    required this.plantName,
    required this.diseaseName,
    required this.diseaseDescription,
    required this.diseaseRemedy,
    required this.uploadedImageUrl,
    required this.gradcamImageUrl,
    required this.confidence,
    required this.confidencePct,
    required this.status,
    required this.createdAt,
  });

  factory DetectionResult.fromJson(Map<String, dynamic> json) {
    final diseaseDetail = json['disease_detail'] as Map<String, dynamic>?;
    return DetectionResult(
      id: json['id'] as int,
      plantName: json['plant_name'] as String? ?? '',
      diseaseName: diseaseDetail?['name'] as String?,
      diseaseDescription: diseaseDetail?['description'] as String?,
      diseaseRemedy: diseaseDetail?['remedy'] as String?,
      uploadedImageUrl: json['uploaded_image'] as String?,
      gradcamImageUrl: json['gradcam_image'] as String?,
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0.0,
      confidencePct: json['confidence_pct'] as String? ?? '0%',
      status: json['status'] as String? ?? 'success',
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? ''),
    );
  }
}

class DetectionHistoryEntry {
  final String plantName;
  final String? diseaseName;
  final String? message;
  final String? imageUrl;
  final String? gradcamUrl;
  final double confidence;
  final String status;
  final DateTime createdAt;

  const DetectionHistoryEntry({
    required this.plantName,
    required this.diseaseName,
    required this.message,
    required this.imageUrl,
    required this.gradcamUrl,
    required this.confidence,
    required this.status,
    required this.createdAt,
  });

  factory DetectionHistoryEntry.fromDetection({
    required DetectionResult result,
    required String? message,
  }) {
    return DetectionHistoryEntry(
      plantName: result.plantName,
      diseaseName: result.diseaseName,
      message: message,
      imageUrl: result.uploadedImageUrl,
      gradcamUrl: result.gradcamImageUrl,
      confidence: result.confidence,
      status: result.status,
      createdAt: result.createdAt ?? DateTime.now(),
    );
  }

  factory DetectionHistoryEntry.fromJson(Map<String, dynamic> json) {
    return DetectionHistoryEntry(
      plantName: json['plantName'] as String? ?? '',
      diseaseName: json['diseaseName'] as String?,
      message: json['message'] as String?,
      imageUrl: json['imageUrl'] as String?,
      gradcamUrl: json['gradcamUrl'] as String?,
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0.0,
      status: json['status'] as String? ?? 'success',
      createdAt:
          DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'plantName': plantName,
      'diseaseName': diseaseName,
      'message': message,
      'imageUrl': imageUrl,
      'gradcamUrl': gradcamUrl,
      'confidence': confidence,
      'status': status,
      'createdAt': createdAt.toIso8601String(),
    };
  }
}
