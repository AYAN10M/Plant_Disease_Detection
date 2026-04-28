import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../features/home/models/detection_record.dart';

class MidoriApiException implements Exception {
  MidoriApiException(this.message);

  final String message;

  @override
  String toString() => message;
}

class MidoriApiClient {
  MidoriApiClient({http.Client? client, String? baseUrl})
    : _client = client ?? http.Client(),
      _baseUrl = (baseUrl ?? _defaultBaseUrl()).replaceAll(RegExp(r'/$'), '');

  final http.Client _client;
  final String _baseUrl;

  static String _defaultBaseUrl() {
    const override = String.fromEnvironment('MIDORI_API_BASE_URL');
    if (override.isNotEmpty) {
      return override;
    }

    if (kIsWeb) {
      return 'http://localhost:8000';
    }

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return 'http://10.0.2.2:8000';
      case TargetPlatform.iOS:
        return 'http://localhost:8000';
      case TargetPlatform.macOS:
      case TargetPlatform.linux:
      case TargetPlatform.windows:
        return 'http://127.0.0.1:8000';
      case TargetPlatform.fuchsia:
        return 'http://127.0.0.1:8000';
    }
  }

  Uri _resolveUri(String path) {
    final uri = Uri.parse(path);
    // If the backend already returned an absolute URL (which it does now via
    // request.build_absolute_uri), use it directly.
    if (uri.hasScheme) {
      return uri;
    }

    // Fallback for legacy relative paths — prepend base URL.
    return Uri.parse('$_baseUrl${path.startsWith('/') ? '' : '/'}$path');
  }

  /// Resolve a media URL returned by the backend.
  ///
  /// The backend now returns **absolute** URLs, so this mostly passes through.
  /// Falls back to constructing an absolute URL for any legacy relative path.
  Uri? resolveMediaUri(String? path) {
    if (path == null || path.isEmpty) {
      return null;
    }
    return _resolveUri(path);
  }

  Uri get detectionsUri => Uri.parse('$_baseUrl/api/detections/');

  Future<DetectionApiResponse> detectImage({
    required Uint8List imageBytes,
    required String filename,
  }) async {
    final request = http.MultipartRequest('POST', detectionsUri)
      ..files.add(
        http.MultipartFile.fromBytes(
          'uploaded_image',
          imageBytes,
          filename: filename,
        ),
      );

    final streamedResponse = await request.send();
    final responseBody = await streamedResponse.stream.bytesToString();

    if (streamedResponse.statusCode < 200 ||
        streamedResponse.statusCode >= 300) {
      throw MidoriApiException(
        _extractErrorMessage(responseBody, streamedResponse.statusCode),
      );
    }

    final decoded = jsonDecode(responseBody);
    if (decoded is! Map<String, dynamic>) {
      throw MidoriApiException('Unexpected response from the detection API.');
    }

    return DetectionApiResponse.fromJson(decoded);
  }

  /// Fetch raw bytes from an absolute URL returned by the backend.
  ///
  /// Returns null when [path] is empty, null, or the request fails.
  Future<Uint8List?> fetchBytes(String? path) async {
    if (path == null || path.isEmpty) {
      return null;
    }

    try {
      final response = await _client.get(_resolveUri(path));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return null;
      }
      return response.bodyBytes;
    } catch (_) {
      return null;
    }
  }

  String _extractErrorMessage(String responseBody, int statusCode) {
    try {
      final decoded = jsonDecode(responseBody);
      if (decoded is Map<String, dynamic>) {
        final message =
            decoded['detail'] ?? decoded['message'] ?? decoded['error'];
        if (message is String && message.isNotEmpty) {
          return message;
        }
      }
    } catch (_) {
      // Fall through to the generic error.
    }

    return 'Detection request failed with status $statusCode.';
  }

  void close() {
    _client.close();
  }
}
