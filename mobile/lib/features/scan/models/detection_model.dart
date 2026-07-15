import 'dart:convert';
import 'dart:typed_data';


String _humanizeModelLabel(String label) {
  final cleaned = label.replaceAll(RegExp(r'^.*?_{2,}'), '');
  return cleaned.replaceAll('_', ' ').trim();
}



class ConfidenceScore {
  final String name;
  final double confidence;

  const ConfidenceScore({required this.name, required this.confidence});

  factory ConfidenceScore.fromJson(Map<String, dynamic> json) =>
      ConfidenceScore(
        name:       json['name']       as String? ?? '',
        confidence: (json['confidence'] as num?)?.toDouble() ?? 0.0,
      );
}



class DetectionResult {
  final int id;


  final String plantName;
  final double plantConfidence;
  final String plantConfidencePct;
  final List<ConfidenceScore> plantScores;
  final String? plantGradcamImageUrl;


  final String? diseaseName;
  final String? diseaseCause;
  final String? diseaseDescription;
  final String? diseaseRemedy;
  final String? diseasePrevention;
  final double confidence;
  final String confidencePct;
  final List<ConfidenceScore> diseaseScores;
  final String? gradcamImageUrl;
  final String? advice;


  final String? uploadedImageUrl;
  final String status;
  final bool isHealthy;

  const DetectionResult({
    required this.id,
    required this.plantName,
    required this.plantConfidence,
    required this.plantConfidencePct,
    required this.plantScores,
    this.plantGradcamImageUrl,
    this.diseaseName,
    this.diseaseCause,
    this.diseaseDescription,
    this.diseaseRemedy,
    this.diseasePrevention,
    required this.confidence,
    required this.confidencePct,
    required this.diseaseScores,
    this.gradcamImageUrl,
    this.advice,
    this.uploadedImageUrl,
    required this.status,
    required this.isHealthy,
  });

  factory DetectionResult.fromJson(Map<String, dynamic> json, {String? fallbackDiseaseName}) {
    final detail = json['disease_detail'] as Map<String, dynamic>?;

    String? diseaseName;
    if (detail != null && detail['name'] != null) {
      diseaseName = _humanizeModelLabel(detail['name'] as String);
    } else if (fallbackDiseaseName != null && fallbackDiseaseName.isNotEmpty) {
      diseaseName = fallbackDiseaseName;
    }


    final rawPlantScores = json['plant_scores'];
    final List<ConfidenceScore> plantScores = rawPlantScores is List
        ? rawPlantScores
            .whereType<Map<String, dynamic>>()
            .map(ConfidenceScore.fromJson)
            .toList()
        : [];


    final rawDiseaseScores = json['disease_scores'];
    final List<ConfidenceScore> diseaseScores = rawDiseaseScores is List
        ? rawDiseaseScores
            .whereType<Map<String, dynamic>>()
            .map(ConfidenceScore.fromJson)
            .toList()
        : [];

    return DetectionResult(
      id:                  (json['id'] as num?)?.toInt() ?? 0,
      plantName:           json['plant_name']           as String? ?? '',
      plantConfidence:     (json['plant_confidence']    as num?)?.toDouble() ?? 0.0,
      plantConfidencePct:  json['plant_confidence_pct'] as String? ?? '0.0%',
      plantScores:         plantScores,
      plantGradcamImageUrl: json['plant_gradcam_image'] as String?,
      diseaseName:         diseaseName,
      diseaseCause:        detail?['cause']       as String?,
      diseaseDescription:  detail?['description'] as String?,
      diseaseRemedy:       detail?['remedy']      as String?,
      diseasePrevention:   detail?['prevention']  as String?,
      confidence:          (json['confidence']    as num?)?.toDouble() ?? 0.0,
      confidencePct:       json['confidence_pct'] as String? ?? '0.0%',
      diseaseScores:       diseaseScores,
      gradcamImageUrl:     json['gradcam_image']  as String?,
      advice:              json['advice']         as String?,
      uploadedImageUrl:    json['uploaded_image'] as String?,
      status:              json['status']         as String? ?? '',
      isHealthy:           json['is_healthy']     as bool? ?? false,
    );
  }
}



class DetectionApiResponse {
  final String status;
  final String? message;
  final DetectionResult? data;
  final bool isHealthy;
  final String? rawDiseaseName;

  const DetectionApiResponse({
    required this.status,
    this.message,
    this.data,
    this.isHealthy = false,
    this.rawDiseaseName,
  });

  factory DetectionApiResponse.fromJson(Map<String, dynamic> json) {
    final rawData = json['data'];
    final topLevelDiseaseName = json['disease_name'] as String?;
    return DetectionApiResponse(
      status:         json['status']       as String? ?? 'failed',
      message:        json['message']      as String?,
      isHealthy:      json['is_healthy']   as bool?   ?? false,
      rawDiseaseName: topLevelDiseaseName,
      data:    rawData is Map<String, dynamic>
                  ? DetectionResult.fromJson(rawData, fallbackDiseaseName: topLevelDiseaseName)
                  : null,
    );
  }

  bool get effectivelyHealthy =>
      isHealthy ||
      status == 'healthy' ||
      rawDiseaseName?.toLowerCase() == 'healthy' ||
      (data?.diseaseName?.toLowerCase() == 'healthy') ||
      (data?.isHealthy ?? false);
}



class DetectionHistoryEntry {
  final DateTime createdAt;


  final String plantName;
  final double plantConfidence;
  final List<Map<String, dynamic>> plantScores;
  final String? plantGradcamBase64;


  final String? diseaseName;
  final String? diseaseCause;
  final String? diseaseDescription;
  final String? diseaseRemedy;
  final String? diseasePrevention;
  final double confidence;
  final List<Map<String, dynamic>> diseaseScores;
  final String? advice;


  final bool isHealthy;
  final String? message;
  final String? imageBase64;
  final String? gradcamBase64;



  const DetectionHistoryEntry({
    required this.createdAt,
    required this.plantName,
    required this.plantConfidence,
    required this.plantScores,
    this.plantGradcamBase64,
    this.diseaseName,
    this.diseaseCause,
    this.diseaseDescription,
    this.diseaseRemedy,
    this.diseasePrevention,
    required this.confidence,
    required this.diseaseScores,
    this.advice,
    required this.isHealthy,
    this.message,
    this.imageBase64,
    this.gradcamBase64,
  });



  Uint8List? get imageBytes {
    if (imageBase64 == null || imageBase64!.isEmpty) return null;
    try {
      return base64Decode(imageBase64!);
    } catch (_) {
      return null;
    }
  }

  Uint8List? get gradcamBytes {
    if (gradcamBase64 == null || gradcamBase64!.isEmpty) return null;
    try {
      return base64Decode(gradcamBase64!);
    } catch (_) {
      return null;
    }
  }

  Uint8List? get plantGradcamBytes {
    if (plantGradcamBase64 == null || plantGradcamBase64!.isEmpty) return null;
    try {
      return base64Decode(plantGradcamBase64!);
    } catch (_) {
      return null;
    }
  }



  factory DetectionHistoryEntry.fromDetection(
    DetectionResult result,
    String? message, {
    Uint8List? imageBytes,
    Uint8List? gradcamBytes,
    Uint8List? plantGradcamBytes,
  }) {
    return DetectionHistoryEntry(
      createdAt:         DateTime.now(),
      plantName:         result.plantName,
      plantConfidence:   result.plantConfidence,
      plantScores:       result.plantScores
          .map((s) => {'name': s.name, 'confidence': s.confidence})
          .toList(),
      plantGradcamBase64: plantGradcamBytes != null
          ? base64Encode(plantGradcamBytes)
          : null,
      diseaseName:       result.diseaseName,
      diseaseCause:      result.diseaseCause,
      diseaseDescription: result.diseaseDescription,
      diseaseRemedy:     result.diseaseRemedy,
      diseasePrevention: result.diseasePrevention,
      confidence:        result.confidence,
      diseaseScores:     result.diseaseScores
          .map((s) => {'name': s.name, 'confidence': s.confidence})
          .toList(),
      advice:            result.advice,
      isHealthy:         result.isHealthy,
      message:           message,
      imageBase64:       imageBytes != null ? base64Encode(imageBytes) : null,
      gradcamBase64:     gradcamBytes != null ? base64Encode(gradcamBytes) : null,
    );
  }



  Map<String, dynamic> toJson() => {
        'createdAt':          createdAt.toIso8601String(),
        'plantName':          plantName,
        'plantConfidence':    plantConfidence,
        'plantScores':        plantScores,
        'plantGradcamBase64': plantGradcamBase64,
        'diseaseName':        diseaseName,
        'diseaseCause':       diseaseCause,
        'diseaseDescription': diseaseDescription,
        'diseaseRemedy':      diseaseRemedy,
        'diseasePrevention':  diseasePrevention,
        'confidence':         confidence,
        'diseaseScores':      diseaseScores,
        'advice':             advice,
        'isHealthy':          isHealthy,
        'message':            message,
        'imageBase64':        imageBase64,
        'gradcamBase64':      gradcamBase64,
      };

  factory DetectionHistoryEntry.fromJson(Map<String, dynamic> json) {
    List<Map<String, dynamic>> parseScores(dynamic raw) {
      if (raw is! List) return [];
      return raw.whereType<Map<String, dynamic>>().toList();
    }

    return DetectionHistoryEntry(
      createdAt: DateTime.parse(json['createdAt'] as String),
      plantName: json['plantName'] as String? ?? '',
      plantConfidence:
          (json['plantConfidence'] as num?)?.toDouble() ?? 0.0,
      plantScores:     parseScores(json['plantScores']),
      plantGradcamBase64: json['plantGradcamBase64'] as String?,
      diseaseName:     json['diseaseName']       as String?,
      diseaseCause:    json['diseaseCause']      as String?,
      diseaseDescription: json['diseaseDescription'] as String?,
      diseaseRemedy:   json['diseaseRemedy']     as String?,
      diseasePrevention: json['diseasePrevention'] as String?,
      confidence:      (json['confidence'] as num?)?.toDouble() ?? 0.0,
      diseaseScores:   parseScores(json['diseaseScores']),
      advice:          json['advice']    as String?,
      isHealthy:       json['isHealthy'] as bool? ?? false,
      message:         json['message']   as String?,
      imageBase64:     json['imageBase64']     as String?,
      gradcamBase64:   json['gradcamBase64']   as String?,
    );
  }
}
