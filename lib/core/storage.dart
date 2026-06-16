import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'constants.dart';

/// Thin wrapper around flutter_secure_storage so the rest of the app never
/// touches platform-specific KeyStore / Keychain calls directly.
class StorageService {
  StorageService(this._storage);
  final FlutterSecureStorage _storage;

  Future<String?> readToken() => _storage.read(key: AppConfig.tokenKey);
  Future<void> writeToken(String token) => _storage.write(key: AppConfig.tokenKey, value: token);
  Future<void> clearToken() => _storage.delete(key: AppConfig.tokenKey);

  Future<String?> readRefreshToken() => _storage.read(key: AppConfig.refreshTokenKey);
  Future<void> writeRefreshToken(String token) =>
      _storage.write(key: AppConfig.refreshTokenKey, value: token);
  Future<void> clearRefreshToken() => _storage.delete(key: AppConfig.refreshTokenKey);

  Future<String?> readUser() => _storage.read(key: AppConfig.userKey);
  Future<void> writeUser(String userJson) => _storage.write(key: AppConfig.userKey, value: userJson);
  Future<void> clearUser() => _storage.delete(key: AppConfig.userKey);

  Future<void> clearAll() => _storage.deleteAll();
}

final storageProvider = Provider<StorageService>((ref) {
  return StorageService(
    const FlutterSecureStorage(
      aOptions: AndroidOptions(encryptedSharedPreferences: true),
      iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
    ),
  );
});
