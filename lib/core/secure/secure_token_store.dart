import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'token_store.dart';

/// Production store — tokens live in platform secure storage only.
class SecureTokenStore implements TokenStore {
  SecureTokenStore({FlutterSecureStorage? storage})
    : _storage =
          storage ??
          const FlutterSecureStorage(
            aOptions: AndroidOptions(encryptedSharedPreferences: true),
          );

  static const _accessKey = 'cb_access_token';
  static const _refreshKey = 'cb_refresh_token';

  final FlutterSecureStorage _storage;

  @override
  Future<String?> readAccess() => _storage.read(key: _accessKey);

  @override
  Future<String?> readRefresh() => _storage.read(key: _refreshKey);

  @override
  Future<void> writeTokens({
    required String access,
    required String refresh,
  }) async {
    await _storage.write(key: _accessKey, value: access);
    await _storage.write(key: _refreshKey, value: refresh);
  }

  @override
  Future<void> writeAccess(String access) =>
      _storage.write(key: _accessKey, value: access);

  @override
  Future<void> clear() async {
    await _storage.delete(key: _accessKey);
    await _storage.delete(key: _refreshKey);
  }
}
