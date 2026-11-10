import 'dart:typed_data';

import 'package:completebyte_pos_mobile/core/media/image_upload_guard.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ImageUploadGuard', () {
    test('accepts JPEG magic bytes and sets safe name', () {
      final bytes = Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xE0, 1, 2, 3, 4]);
      final prepared = ImageUploadGuard.prepare(
        bytes,
        preferredName: 'Receipt.HTML',
      );
      expect(prepared.contentType, 'image/jpeg');
      expect(prepared.fileName, 'Receipt.jpg');
    });

    test('rejects empty and non-image payloads', () {
      expect(
        () => ImageUploadGuard.prepare(const []),
        throwsA(isA<ImageUploadException>()),
      );
      expect(
        () => ImageUploadGuard.prepare(
          Uint8List.fromList('<svg xmlns="x"></svg>'.codeUnits),
        ),
        throwsA(isA<ImageUploadException>()),
      );
    });

    test('rejects oversized payloads', () {
      final bytes = Uint8List(ImageUploadGuard.maxBytes + 1);
      bytes[0] = 0xFF;
      bytes[1] = 0xD8;
      bytes[2] = 0xFF;
      expect(
        () => ImageUploadGuard.prepare(bytes),
        throwsA(isA<ImageUploadException>()),
      );
    });
  });
}
