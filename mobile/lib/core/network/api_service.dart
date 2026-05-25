import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../constants/app_constants.dart';
import '../../features/scan/models/detection_model.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Exception
// ─────────────────────────────────────────────────────────────────────────────

class MidoriApiException implements Exception {
  final String message;
  const MidoriApiException(this.message);

  @override
  String toString() => 'MidoriApiException: $message';
}

// ─────────────────────────────────────────────────────────────────────────────
// Client
// ─────────────────────────────────────────────────────────────────────────────

class MidoriApiClient {
  final http.Client _http;
  final String baseUrl;

  MidoriApiClient({http.Client? client, String? baseUrl})
      : _http   = client ?? http.Client(),
        baseUrl = baseUrl ?? _resolveBaseUrl();

  /// Priority: --dart-define=MIDORI_BASE_URL → platform default.
  static String _resolveBaseUrl() {
    if (AppConstants.serverBaseUrl.isNotEmpty) return AppConstants.serverBaseUrl;

    if (kIsWeb) return 'http://localhost:8000';

    if (Platform.isAndroid) {
      // Emulator loopback in debug; LAN IP in release.
      return kDebugMode
          ? 'http://10.0.2.2:8000'
          : 'http://${AppConstants.lanIp}:8000';
    }
    // iOS, macOS, Windows, Linux
    return 'http://localhost:8000';
  }

  // ── Health check ──────────────────────────────────────────────────────────

  Future<bool> checkServerHealth() async {
    try {
      final uri  = Uri.parse('$baseUrl/api/detections/health/');
      final resp = await _http
          .get(uri)
          .timeout(AppConstants.healthCheckTimeout);
      return resp.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  // ── Detect ────────────────────────────────────────────────────────────────

  /// POST /api/detections/ — upload [imageBytes] and run the two-stage pipeline.
  ///
  /// [plantOverride]       : if non-null, skips Stage-1 plant ID
  /// [confidenceThreshold] : Stage-1 min confidence % (0–100, default 40)
  Future<DetectionApiResponse> detectImage({
    required Uint8List imageBytes,
    required String filename,
    String? plantOverride,
    double confidenceThreshold = 40.0,
  }) async {
    if (imageBytes.lengthInBytes > AppConstants.maxImageBytes) {
      throw const MidoriApiException(
        'Image is too large (max 10 MB). Please select a smaller photo.',
      );
    }

    final uri     = Uri.parse('$baseUrl/api/detections/');
    final request = http.MultipartRequest('POST', uri);

    request.files.add(
      http.MultipartFile.fromBytes(
        'uploaded_image',
        imageBytes,
        filename: filename.isNotEmpty ? filename : 'leaf.jpg',
      ),
    );

    if (plantOverride != null && plantOverride.isNotEmpty) {
      request.fields['plant_override'] = plantOverride;
    }

    // Always send threshold so backend uses the user's chosen value
    request.fields['confidence_threshold'] =
        confidenceThreshold.toStringAsFixed(1);

    try {
      final streamed = await request
          .send()
          .timeout(AppConstants.detectionTimeout);
      final body = await streamed.stream.bytesToString();

      if (streamed.statusCode == 200) {
        final json = jsonDecode(body) as Map<String, dynamic>;
        return DetectionApiResponse.fromJson(json);
      }

      final errMsg = _extractError(body, streamed.statusCode);
      throw MidoriApiException(errMsg);
    } on MidoriApiException {
      rethrow;
    } on SocketException {
      throw const MidoriApiException(
        'Cannot connect to the server. '
        'Make sure the backend is running and reachable on your network.',
      );
    } on http.ClientException catch (e) {
      throw MidoriApiException('Network error: ${e.message}');
    } catch (e) {
      if (e.toString().contains('TimeoutException')) {
        throw const MidoriApiException(
          'Request timed out. The server is taking too long — please try again.',
        );
      }
      throw MidoriApiException('Unexpected error: $e');
    }
  }

  // ── Fetch raw bytes (for Grad-CAM images) ────────────────────────────────

  Future<Uint8List?> fetchBytes(String? urlOrPath) async {
    if (urlOrPath == null || urlOrPath.isEmpty) return null;

    final uri = urlOrPath.startsWith('http')
        ? Uri.parse(urlOrPath)
        : Uri.parse('$baseUrl/media/$urlOrPath');

    try {
      final resp = await _http
          .get(uri)
          .timeout(AppConstants.mediaFetchTimeout);
      if (resp.statusCode == 200) return resp.bodyBytes;
      return null;
    } catch (_) {
      return null;
    }
  }

  // ── Error parsing ─────────────────────────────────────────────────────────

  String _extractError(String body, int statusCode) {
    try {
      final json = jsonDecode(body) as Map<String, dynamic>;
      final msg  = json['detail'] ?? json['message'] ?? json['error'];
      if (msg != null) return msg.toString();
    } catch (_) {}
    return 'Server returned HTTP $statusCode.';
  }

  void close() => _http.close();
}
