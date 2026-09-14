import 'package:completebyte_pos_mobile/sync/domain/client_uuid.dart';
import 'package:completebyte_pos_mobile/sync/domain/human_error.dart';
import 'package:completebyte_pos_mobile/sync/domain/outbox_entry.dart';
import 'package:completebyte_pos_mobile/sync/domain/sync_backoff.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ClientUuid', () {
    test('generates unique well-formed ids', () {
      final gen = ClientUuid();
      final a = gen.next();
      final b = gen.next();
      expect(a, isNot(b));
      expect(ClientUuid.isWellFormed(a), isTrue);
      expect(ClientUuid.isWellFormed('not-a-uuid'), isFalse);
    });
  });

  group('SyncBackoff', () {
    test('grows exponentially and caps', () {
      const backoff = SyncBackoff();
      expect(backoff.delayForAttempt(0), Duration.zero);
      expect(backoff.delayForAttempt(1), const Duration(seconds: 1));
      expect(backoff.delayForAttempt(2), const Duration(seconds: 2));
      expect(backoff.delayForAttempt(3), const Duration(seconds: 4));
      expect(backoff.delayForAttempt(10), const Duration(seconds: 60));
    });
  });

  group('humanizeSyncError', () {
    test('maps common failures', () {
      expect(humanizeSyncError(statusCode: 401, error: 'x'), contains('Sign in'));
      expect(humanizeSyncError(statusCode: 409, error: 'x'), contains('conflict'));
      expect(humanizeSyncError(statusCode: 500, error: 'x'), contains('unavailable'));
      expect(
        humanizeSyncError(statusCode: null, error: Exception('SocketException')),
        contains('No connection'),
      );
      expect(isPermanentHttpFailure(400), isTrue);
      expect(isPermanentHttpFailure(429), isFalse);
      expect(isPermanentHttpFailure(500), isFalse);
    });
  });

  group('OutboxEntry', () {
    test('copyWith and flags', () {
      final entry = OutboxEntry(
        id: '1',
        clientResourceId: 'c',
        idempotencyKey: 'k',
        method: 'POST',
        path: 'sales/',
        bodyJson: '{}',
        status: OutboxStatus.pending,
        attemptCount: 0,
        createdAt: DateTime.utc(2026, 1, 1),
      );
      expect(entry.isPendingWork, isTrue);
      final failed = entry.copyWith(
        status: OutboxStatus.failed,
        humanError: 'Nope',
        lastError: '400',
      );
      expect(failed.isFailed, isTrue);
      expect(failed.humanError, 'Nope');
      expect(failed.copyWith(clearError: true).humanError, isNull);
    });
  });
}
