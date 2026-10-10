import 'package:completebyte_pos_mobile/core/network/api_error_message.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('apiErrorMessage', () {
    test('reads top-level error and detail', () {
      expect(
        apiErrorMessage('{"error":"Stock too low"}'),
        'Stock too low',
      );
      expect(
        apiErrorMessage('{"detail":"Not allowed."}'),
        'Not allowed.',
      );
    });

    test('formats DRF field errors for the user', () {
      expect(
        apiErrorMessage(
          '{"phone":["This phone is already used by Wambua Hardware. '
          'Open that duka instead of registering again."]}',
        ),
        'Phone: This phone is already used by Wambua Hardware. '
        'Open that duka instead of registering again.',
      );
    });

    test('joins multiple field errors', () {
      expect(
        apiErrorMessage(
          '{"county":["Select a valid Kenyan county."],'
          '"ward":["Select a ward in this sub-county."]}',
        ),
        'County: Select a valid Kenyan county.\n'
        'Ward: Select a ward in this sub-county.',
      );
    });

    test('handles non_field_errors list', () {
      expect(
        apiErrorMessage('{"non_field_errors":["Fix the form."]}'),
        'Fix the form.',
      );
    });

    test('falls back when body is empty or opaque', () {
      expect(
        apiErrorMessage(''),
        'Something went wrong. Please try again.',
      );
      expect(
        apiErrorMessage('<html>traceback</html>'),
        'Something went wrong. Please try again.',
      );
    });
  });
}
