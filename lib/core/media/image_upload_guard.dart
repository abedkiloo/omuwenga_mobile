import 'dart:typed_data';

import 'package:flutter_image_compress/flutter_image_compress.dart';

/// Client-side receipt / note photo checks before multipart upload.
///
/// Mirrors backend backfill/expense image rules: real bitmap only, size cap,
/// server-friendly filename + content-type. Does not replace server validation.
///
/// Prefer [prepareForUpload] from UI code — it recompresses so the request
/// stays under typical reverse-proxy limits (nginx default 1 MiB → HTTP 413).
abstract final class ImageUploadGuard {
  /// Max size accepted from the gallery before we try to recompress.
  static const maxBytes = 5 * 1024 * 1024;

  /// Target upload size after compression (leaves room for multipart headers).
  static const targetUploadBytes = 900 * 1024;

  static const _allowed = <String>{'image/jpeg', 'image/png', 'image/webp', 'image/gif'};

  /// Validate [bytes] and derive a safe name + MIME type (no recompress).
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

  /// Validate then JPEG-compress so uploads fit under proxy body limits.
  ///
  /// Throws [ImageUploadException] when the source is invalid or still too
  /// large after compression.
  static Future<PreparedImageUpload> prepareForUpload(
    List<int> bytes, {
    String? preferredName,
  }) async {
    final checked = prepare(bytes, preferredName: preferredName);
    final base = _sanitizeBaseName(preferredName) ?? 'photo';
    if (checked.bytes.length <= targetUploadBytes &&
        checked.contentType == 'image/jpeg') {
      return PreparedImageUpload(
        bytes: checked.bytes,
        fileName: '$base.jpg',
        contentType: 'image/jpeg',
      );
    }

    Uint8List? best;
    for (final quality in const [72, 60, 48, 36]) {
      Uint8List compressed;
      try {
        compressed = await FlutterImageCompress.compressWithList(
          Uint8List.fromList(checked.bytes),
          minWidth: 1280,
          minHeight: 1280,
          quality: quality,
          format: CompressFormat.jpeg,
        );
      } on Object {
        // Unit tests / missing native codec — fall through with original bytes.
        break;
      }
      if (compressed.isEmpty) continue;
      best = compressed;
      if (compressed.length <= targetUploadBytes) {
        return PreparedImageUpload(
          bytes: compressed,
          fileName: '$base.jpg',
          contentType: 'image/jpeg',
        );
      }
    }

    if (best != null && best.length <= maxBytes) {
      // Still over the proxy-friendly target but under backend max — send it;
      // server nginx must allow ≥ this (see fe/nginx.conf client_max_body_size).
      return PreparedImageUpload(
        bytes: best,
        fileName: '$base.jpg',
        contentType: 'image/jpeg',
      );
    }

    if (checked.bytes.length <= targetUploadBytes) {
      return checked;
    }

    throw ImageUploadException(
      'Receipt photo is still too large after compressing. '
      'Crop the screenshot or pick a smaller picture.',
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
