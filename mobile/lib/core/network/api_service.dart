import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../features/scan/models/detection_model.dart';

/// Detection timeout — generous for first cold-start (model load ≈ 10-30 s).
const Duration _kDetectionTimeout = Duration(seconds: 90);

/// Timeout for lightweight calls (health, media fetch).
const Duration _kDefaultTimeout = Duration(seconds: 15);

/// ── How to set the backend URL ────────────────────────────────────────────
/// Option A — compile-time dart-define (recommended for physical device):
///   flutter run --dart-define=MIDORI_API_BASE_URL=http://192.168.29.92:8000
///
/// Option B — for emulator only:
///   No flag needed — 10.0.2.2 is the emulator loopback to host.
///
/// The backend MUST be started with:
///   python manage.py runserver 0.0.0.0:8000
/// ─────────────────────────────────────────────────────────────────────────
const String _kConfiguredBaseUrl =
    String.fromEnvironment('MIDORI_API_BASE_URL');

/// Your PC's LAN IP — change this if your IP changes or pass via dart-define.
const String _kLanIp = '192.168.29.92';

class MidoriApiException implements Exception {
  const MidoriApiException(this.message);
  final String message;
  @override
  String toString() => message;
}

class MidoriApiClient {
  MidoriApiClient({http.Client? client, String? baseUrl})
      : _client = client ?? http.Client(),
        _baseUrl = (baseUrl ?? _resolveBaseUrl()).replaceAll(RegExp(r'/$'), '');

  final http.Client _client;
  final String _baseUrl;

  static String _resolveBaseUrl() {
    // 1. Explicit dart-define always wins
    if (_kConfiguredBaseUrl.isNotEmpty) return _kConfiguredBaseUrl;

    if (kIsWeb) return 'http://localhost:8000';

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        // 10.0.2.2 = emulator loopback; physical device needs LAN IP
        return kReleaseMode
            ? 'http://$_kLanIp:8000'   // release build → always LAN
            : 'http://10.0.2.2:8000';  // debug → assume emulator;
                                        // override with --dart-define for physical
      case TargetPlatform.iOS:
        return 'http://localhost:8000';
      default:
        return 'http://127.0.0.1:8000';
    }
  }

  Uri _resolve(String path) {
    final uri = Uri.parse(path);
    if (uri.hasScheme) return uri;
    return Uri.parse('$_baseUrl${path.startsWith('/') ? '' : '/'}$path');
  }

  Uri? resolveMediaUri(String? path) {
    if (path == null || path.isEmpty) return null;
    return _resolve(path);
  }

  Uri get _detectUri => Uri.parse('$_baseUrl/api/detections/');
  Uri get _healthUri  => Uri.parse('$_baseUrl/api/detections/health/');

  /// Returns true when the server + model are ready.
  Future<bool> checkServerHealth() async {
    try {
      final resp = await _client.get(_healthUri).timeout(_kDefaultTimeout);
      return resp.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// Upload [imageBytes] and return the detection result.
  Future<DetectionApiResponse> detectImage({
    required Uint8List imageBytes,
    required String filename,
  }) async {
    final request = http.MultipartRequest('POST', _detectUri)
      ..files.add(http.MultipartFile.fromBytes(
        'uploaded_image',
        imageBytes,
        filename: filename,
      ));

    late http.StreamedResponse streamed;
    try {
      streamed = await request.send().timeout(
        _kDetectionTimeout,
        onTimeout: () => throw const MidoriApiException(
          'The model is taking too long to respond.\n'
          'This usually happens on the first scan after the server starts.\n'
          'Wait a few seconds and try again.',
        ),
      );
    } on MidoriApiException {
      rethrow;
    } catch (_) {
      throw MidoriApiException(
        'Cannot connect to the backend server.\n'
        'Make sure Django is running:\n'
        '  cd server  →  python manage.py runserver 0.0.0.0:8000\n\n'
        'Backend URL in use: $_baseUrl\n'
        'If using a physical device, pass:\n'
        '  --dart-define=MIDORI_API_BASE_URL=http://$_kLanIp:8000',
      );
    }

    final body = await streamed.stream.bytesToString().timeout(
      _kDetectionTimeout,
      onTimeout: () => throw const MidoriApiException(
        'Server response timed out while streaming. Please try again.',
      ),
    );

    if (streamed.statusCode < 200 || streamed.statusCode >= 300) {
      throw MidoriApiException(_extractError(body, streamed.statusCode));
    }

    final decoded = jsonDecode(body);
    if (decoded is! Map<String, dynamic>) {
      throw const MidoriApiException('Unexpected response format from server.');
    }
    return DetectionApiResponse.fromJson(decoded);
  }

  /// Fetch raw bytes from an absolute or relative URL. Returns null on failure.
  Future<Uint8List?> fetchBytes(String? path) async {
    if (path == null || path.isEmpty) return null;
    try {
      final resp = await _client.get(_resolve(path)).timeout(_kDefaultTimeout);
      if (resp.statusCode < 200 || resp.statusCode >= 300) return null;
      return resp.bodyBytes;
    } catch (_) {
      return null;
    }
  }

  String _extractError(String body, int code) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) {
        final msg = decoded['detail'] ?? decoded['message'] ?? decoded['error'];
        if (msg is String && msg.isNotEmpty) return msg;
      }
    } catch (_) {}
    return 'Detection failed (HTTP $code). Check the backend logs.';
  }

  void close() => _client.close();
}
