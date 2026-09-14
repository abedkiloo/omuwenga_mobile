import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:encrypt/encrypt.dart' as enc;

/// Narrow key vault for PII AES material (not JWT tokens).
abstract class PiiKeyStore {
  Future<String?> read();
  Future<void> write(String base64Key);
  Future<void> clear();
}

class MemoryPiiKeyStore implements PiiKeyStore {
  String? _value;

  @override
  Future<String?> read() async => _value;

  @override
  Future<void> write(String base64Key) async => _value = base64Key;

  @override
  Future<void> clear() async => _value = null;
}

/// Field-level AES for PII cache columns. Key material stays in [PiiKeyStore].
class AesPiiCipher {
  AesPiiCipher(this._keys);

  final PiiKeyStore _keys;
  enc.Key? _cached;

  Future<enc.Key> ensureKey() async {
    if (_cached != null) return _cached!;
    final existing = await _keys.read();
    if (existing != null && existing.isNotEmpty) {
      _cached = enc.Key.fromBase64(existing);
      return _cached!;
    }
    final bytes = Uint8List(32);
    final random = Random.secure();
    for (var i = 0; i < bytes.length; i++) {
      bytes[i] = random.nextInt(256);
    }
    final key = enc.Key(bytes);
    await _keys.write(base64Encode(bytes));
    _cached = key;
    return key;
  }

  Future<String> encryptUtf8(String plaintext) async {
    final key = await ensureKey();
    final iv = enc.IV.fromSecureRandom(16);
    final encrypter = enc.Encrypter(enc.AES(key));
    final encrypted = encrypter.encrypt(plaintext, iv: iv);
    return '${iv.base64}:${encrypted.base64}';
  }

  Future<String> decryptUtf8(String blob) async {
    final key = await ensureKey();
    final parts = blob.split(':');
    if (parts.length != 2) {
      throw const FormatException('Invalid cipher blob');
    }
    final iv = enc.IV.fromBase64(parts[0]);
    final encrypter = enc.Encrypter(enc.AES(key));
    return encrypter.decrypt64(parts[1], iv: iv);
  }
}
