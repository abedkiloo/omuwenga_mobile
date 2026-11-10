import 'dart:typed_data';

/// Client-side receipt / note photo checks before multipart upload.
///
/// Mirrors backend backfill/expense image rules: real bitmap only, size cap,
/// server-friendly filename + content-type. Does not replace server validation.
abstract final class ImageUploadGuard {
  /// Max upload size (5 MiB) — same ballpark as backend receipt photos.
  static const maxBytes = 5 * 1024 * 1024;

  static const _allowed = <String>{'image/jpeg', 'image/png', 'image/webp', 'image/gif'};

  /// Validate [bytes] and derive a safe name + MIME type.
  ///
  /// Returns a prepared [PreparedImageUpload], or throws [ImageUploadException]
  /// with a short staff-facing message when the file is empty, too large,
  /// or not a JPEG/PNG/WebP/GIF bitmap.
  static PreparedImageUpload prepare(
    List<int> bytes, {
    String? preferredName,
  }) {
    if (bytes.isEmpty) {
      throw ImageUploadException('Photo is empty. Take or pick another image.');
    }
    if (bytes.length > maxBytes) {
      throw ImageUploadException(
        'Photo must be 5 MB or smaller. Choose a clearer, smaller picture.',
      );
    }
    final mime = detectMime(bytes);
    if (mime == null || !_allowed.contains(mime)) {
      throw ImageUploadException(
        'Use a JPEG, PNG, WebP, or GIF photo — not a document or webpage.',
      );
    }
    final ext = switch (mime) {
      'image/png' => 'png',
      'image/webp' => 'webp',
      'image/gif' => 'gif',
      _ => 'jpg',
    };
    final base = _sanitizeBaseName(preferredName) ?? 'photo';
    return PreparedImageUpload(
      bytes: Uint8List.fromList(bytes),
      fileName: '$base.$ext',
      contentType: mime,
    );
  }

  /// Sniff common image magic bytes. Returns null when unrecognized.
  static String? detectMime(List<int> bytes) {
    if (bytes.length >= 3 &&
        bytes[0] == 0xFF &&
        bytes[1] == 0xD8 &&
        bytes[2] == 0xFF) {
      return 'image/jpeg';
    }
    if (bytes.length >= 4 &&
        bytes[0] == 0x89 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x4E &&
        bytes[3] == 0x47) {
      return 'image/png';
    }
    if (bytes.length >= 3 &&
        bytes[0] == 0x47 &&
        bytes[1] == 0x49 &&
        bytes[2] == 0x46) {
      return 'image/gif';
    }
    // WebP: RIFF....WEBP
    if (bytes.length >= 12 &&
        bytes[0] == 0x52 &&
        bytes[1] == 0x49 &&
        bytes[2] == 0x46 &&
        bytes[3] == 0x46 &&
        bytes[8] == 0x57 &&
        bytes[9] == 0x45 &&
        bytes[10] == 0x42 &&
        bytes[11] == 0x50) {
      return 'image/webp';
    }
    return null;
  }

  static String? _sanitizeBaseName(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    var name = raw.trim();
    final dot = name.lastIndexOf('.');
    if (dot > 0) name = name.substring(0, dot);
    name = name.replaceAll(RegExp(r'[^A-Za-z0-9_-]+'), '_');
    if (name.isEmpty) return null;
    if (name.length > 40) name = name.substring(0, 40);
    return name;
  }
}

class PreparedImageUpload {
  const PreparedImageUpload({
    required this.bytes,
    required this.fileName,
    required this.contentType,
  });

  final Uint8List bytes;
  final String fileName;
  final String contentType;
}

class ImageUploadException implements Exception {
  ImageUploadException(this.message);

  final String message;

  @override
  String toString() => message;
}
