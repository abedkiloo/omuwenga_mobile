import 'dart:typed_data';

import 'site_visit.dart';

/// Ensures compressed bytes stay within [SiteVisitConfig.maxImageBytes].
class ImageCompressionBounds {
  const ImageCompressionBounds(this.config);

  final SiteVisitConfig config;

  bool isWithinLimit(int byteLength) => byteLength <= config.maxImageBytes;

  /// Returns null when [bytes] already fit; otherwise signals need to recompress.
  Uint8List? acceptOrNull(Uint8List bytes) {
    if (isWithinLimit(bytes.length)) return bytes;
    return null;
  }

  /// Clamp quality hint for iterative compression attempts.
  int nextQuality(int currentQuality) {
    if (currentQuality <= 40) return 40;
    return currentQuality - 15;
  }
}

/// Pure helper used by production compressor + unit tests.
class SitePhotoCompressor {
  SitePhotoCompressor({
    SiteVisitConfig config = SiteVisitConfig.defaults,
    Future<Uint8List?> Function(Uint8List bytes, {required int quality})?
        compressFn,
  })  : _config = config,
        _bounds = ImageCompressionBounds(config),
        _compressFn = compressFn;

  final SiteVisitConfig _config;
  final ImageCompressionBounds _bounds;
  final Future<Uint8List?> Function(Uint8List bytes, {required int quality})?
      _compressFn;

  Future<Uint8List> compressToLimit(Uint8List input) async {
    if (_bounds.isWithinLimit(input.length)) return input;
    final compress = _compressFn;
    if (compress == null) {
      throw StateError(
        'Image exceeds ${_config.maxImageBytes} bytes and no compressor is configured.',
      );
    }
    var quality = _config.compressQuality;
    Uint8List? current = input;
    for (var i = 0; i < 5; i++) {
      current = await compress(current!, quality: quality);
      if (current == null) break;
      if (_bounds.isWithinLimit(current.length)) return current;
      quality = _bounds.nextQuality(quality);
    }
    throw StateError('Unable to compress image under ${_config.maxImageBytes} bytes.');
  }
}
