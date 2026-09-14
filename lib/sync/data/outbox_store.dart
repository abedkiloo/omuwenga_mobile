import '../domain/outbox_entry.dart';

/// Persistence for the mutation outbox.
abstract class OutboxStore {
  Future<OutboxEntry> enqueue(EnqueueMutation mutation);

  Future<List<OutboxEntry>> listPending({DateTime? readyBefore});

  Future<List<OutboxEntry>> listFailed();

  Future<int> pendingCount();

  Future<OutboxEntry?> findById(String id);

  Future<void> markInFlight(String id);

  Future<void> markSynced(String id);

  Future<void> markRetry({
    required String id,
    required int attemptCount,
    required DateTime nextAttemptAt,
    required String lastError,
    required String humanError,
  });

  Future<void> markFailed({
    required String id,
    required String lastError,
    required String humanError,
  });

  Future<void> discard(String id);

  Future<void> requeue(String id);

  Stream<List<OutboxEntry>> watchActive();
}
