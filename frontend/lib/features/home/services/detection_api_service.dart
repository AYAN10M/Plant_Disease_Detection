import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../../../core/api/endpoints.dart';
import '../models/detection_record.dart';
import '../models/plant_model.dart';

class DetectionApiService {
  DetectionApiService()
    : _dio = Dio(
        BaseOptions(
          connectTimeout: const Duration(seconds: 15),
          receiveTimeout: const Duration(seconds: 20),
        ),
      );

  final Dio _dio;

  Future<List<PlantModel>> fetchPlants() async {
    final response = await _dio.get(Endpoints.plants);
    final plants = response.data as List<dynamic>;
    return plants
        .cast<Map<String, dynamic>>()
        .map(PlantModel.fromJson)
        .toList();
  }

  Future<DetectionApiResponse> detect({
    required int plantId,
    required Uint8List imageBytes,
    required String fileName,
  }) async {
    final formData = FormData.fromMap({
      'plant': plantId,
      'uploaded_image': MultipartFile.fromBytes(imageBytes, filename: fileName),
    });

    final response = await _dio.post(
      Endpoints.detect,
      data: formData,
      options: Options(contentType: 'multipart/form-data'),
    );

    return DetectionApiResponse.fromJson(
      Map<String, dynamic>.from(response.data as Map),
    );
  }
}
