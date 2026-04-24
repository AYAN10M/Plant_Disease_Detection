import 'dart:io';
import 'dart:math';

import 'package:plant_disease_detection/models/disease_info.dart';
import 'package:plant_disease_detection/models/scan_result.dart';

class ApiService {
  static final Random _random = Random();

  static const List<Map<String, dynamic>> _mockDiseases = [
    {
      'disease': 'Early Blight',
      'plant': 'Tomato',
      'isHealthy': false,
      'info': {
        'diseaseName': 'Early Blight',
        'summary':
            'A fungal disease that causes target-like brown lesions on leaves.',
        'cause':
            'Often develops in warm, humid conditions with poor airflow and wet foliage.',
        'symptoms': [
          'Dark concentric spots on older leaves',
          'Yellowing around lesions',
          'Leaf drop over time',
        ],
        'treatmentSteps': [
          'Remove infected foliage',
          'Improve spacing and airflow',
          'Apply a labeled fungicide',
        ],
      },
    },
    {
      'disease': 'Powdery Mildew',
      'plant': 'Cucumber',
      'isHealthy': false,
      'info': {
        'diseaseName': 'Powdery Mildew',
        'summary':
            'A common fungal infection that appears as white powdery patches.',
        'cause': 'Triggered by crowded plants and humid, stagnant air.',
        'symptoms': [
          'White powdery patches on leaves',
          'Curling leaves',
          'Reduced plant vigor',
        ],
        'treatmentSteps': [
          'Prune dense growth',
          'Avoid overhead irrigation',
          'Apply sulfur or potassium bicarbonate products',
        ],
      },
    },
    {
      'disease': 'Healthy',
      'plant': 'Tomato',
      'isHealthy': true,
      'info': {
        'diseaseName': 'Healthy Leaf',
        'summary': 'No visible disease characteristics were detected.',
        'cause': 'Leaf pattern appears normal in the sampled image.',
        'symptoms': ['Uniform color', 'No visible lesions'],
        'treatmentSteps': [
          'Continue regular care',
          'Monitor plants weekly for changes',
        ],
      },
    },
  ];

  static Future<ScanResult> predict(File imageFile) async {
    if (!imageFile.existsSync()) {
      throw const FileSystemException('Selected image file does not exist.');
    }

    await Future.delayed(const Duration(milliseconds: 1200));

    final selected = _mockDiseases[_random.nextInt(_mockDiseases.length)];
    final confidence = (0.62 + _random.nextDouble() * 0.36).clamp(0.0, 1.0);

    final infoMap = selected['info'];
    final info = infoMap is Map<String, dynamic>
        ? DiseaseInfo.fromJson(infoMap)
        : null;

    return ScanResult(
      imagePath: imageFile.path,
      disease: selected['disease'] as String? ?? 'Unknown',
      confidence: confidence,
      plant: selected['plant'] as String? ?? 'Unknown plant',
      isHealthy: selected['isHealthy'] as bool? ?? false,
      diseaseInfo: info,
    );
  }

  static Future<void> saveHistory(ScanResult result) async {
    if (result.disease.trim().isEmpty) {
      throw ArgumentError('Result disease cannot be empty.');
    }

    await Future.delayed(const Duration(milliseconds: 350));
  }
}
