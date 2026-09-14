import 'package:uuid/uuid.dart';

/// Client-generated UUIDs for offline-capable creates.
class ClientUuid {
  ClientUuid([Uuid? uuid]) : _uuid = uuid ?? const Uuid();

  final Uuid _uuid;

  String next() => _uuid.v4();

  /// True when [value] is a canonical UUID string (any version).
  static bool isWellFormed(String value) {
    return Uuid.isValidUUID(fromString: value);
  }
}
