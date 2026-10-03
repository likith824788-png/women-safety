import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureStorageService {
  final FlutterSecureStorage _storage;

  SecureStorageService({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  static const String _keyAuthToken = 'auth_token';
  static const String _keyUserId = 'user_id';
  static const String _keySmsFallbackEnabled = 'sms_fallback_enabled';

  Future<void> saveAuthToken(String token) async {
    await _storage.write(key: _keyAuthToken, value: token);
  }

  Future<String?> getAuthToken() async {
    return await _storage.read(key: _keyAuthToken);
  }

  Future<void> saveUserId(String userId) async {
    await _storage.write(key: _keyUserId, value: userId);
  }

  Future<String?> getUserId() async {
    return await _storage.read(key: _keyUserId);
  }

  Future<void> setSmsFallbackEnabled(bool enabled) async {
    await _storage.write(key: _keySmsFallbackEnabled, value: enabled.toString());
  }

  Future<bool> isSmsFallbackEnabled() async {
    final value = await _storage.read(key: _keySmsFallbackEnabled);
    return value == 'true';
  }

  Future<void> writeKey(String key, String value) async {
    await _storage.write(key: key, value: value);
  }

  Future<String?> readKey(String key) async {
    return await _storage.read(key: key);
  }

  Future<void> clearAll() async {
    await _storage.deleteAll();
  }
}
