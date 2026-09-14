import 'package:completebyte_pos_mobile/core/result/result.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Result', () {
    test('Success when/map/getOrThrow/getOrNull', () {
      const result = Success<int>(4);
      expect(result.isSuccess, isTrue);
      expect(result.isFailure, isFalse);
      expect(result.getOrThrow(), 4);
      expect(result.getOrNull(), 4);
      expect(result.map((v) => v * 2).getOrThrow(), 8);
      expect(
        result.when(success: (v) => 'ok-$v', failure: (_, _) => 'fail'),
        'ok-4',
      );
    });

    test('Failure when/map/getOrNull and getOrThrow', () {
      final result = Failure<int>(StateError('boom'), StackTrace.current);
      expect(result.isFailure, isTrue);
      expect(result.getOrNull(), isNull);
      expect(result.map((v) => v).isFailure, isTrue);
      expect(
        result.when(success: (_) => 'ok', failure: (e, _) => e.toString()),
        contains('boom'),
      );
      expect(() => result.getOrThrow(), throwsA(isA<StateError>()));
    });

    test('Failure without stackTrace still throws', () {
      const result = Failure<int>('nope');
      expect(() => result.getOrThrow(), throwsA('nope'));
    });
  });
}
