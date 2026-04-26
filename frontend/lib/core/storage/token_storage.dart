import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class TokenStorage {
  static const _storage = FlutterSecureStorage();

  static const _accessKey = 'access_token';
  static const _refreshKey = 'refresh_token';

  // Save both tokens after login
  static Future<void> saveTokens({
    required String access,
    required String refresh,
  }) async {
    await _storage.write(key: _accessKey, value: access);
    await _storage.write(key: _refreshKey, value: refresh);
  }

  // Read access token — used by interceptor
  static Future<String?> getAccessToken() async {
    return _storage.read(key: _accessKey);
  }

  // Read refresh token — used when access token expires
  static Future<String?> getRefreshToken() async {
    return _storage.read(key: _refreshKey);
  }

  // Save only the new access token after refresh
  static Future<void> updateAccessToken(String access) async {
    await _storage.write(key: _accessKey, value: access);
  }

  // Clear everything on logout
  static Future<void> clearTokens() async {
    await _storage.deleteAll();
  }

  // Check if user is already logged in (app startup)
  static Future<bool> hasToken() async {
    final token = await getAccessToken();
    return token != null;
  }
}
