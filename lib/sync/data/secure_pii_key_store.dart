import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'pii_cipher.dart';

/// Production PII key vault — excluded from coverage (platform secure storage).
class SecurePiiKeyStore implements PiiKeyStore {
  SecurePiiKeyStore({
    FlutterSecureStorage? storage,
    this.storageKey = 'cbpos_pii_aes_key',
  }) : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;
  final String storageKey;

  @override
  Future<String?> read() => _storage.read(key: storageKey);

  @override
  Future<void> write(String base64Key) =>
      _storage.write(key: storageKey, value: base64Key);

  @override
  Future<void> clear() => _storage.delete(key: storageKey);
}
