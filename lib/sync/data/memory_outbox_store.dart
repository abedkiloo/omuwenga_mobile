import 'dart:async';

import '../domain/client_uuid.dart';
import '../domain/outbox_entry.dart';
import 'outbox_store.dart';

/// In-memory outbox for unit tests and sync engine proofs.
class MemoryOutboxStore implements OutboxStore {
  MemoryOutboxStore({ClientUuid? ids, DateTime Function()? clock})
    : _ids = ids ?? ClientUuid(),
      _clock = clock ?? DateTime.now;

  final ClientUuid _ids;
  final DateTime Function() _clock;
  final Map<String, OutboxEntry> _items = {};
  final _controller = StreamController<List<OutboxEntry>>.broadcast();

  void _emit() {
    _controller.add(_activeSnapshot());
  }

  List<OutboxEntry> _activeSnapshot() {
    return _items.values.where((e) => e.status != OutboxStatus.synced).toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
  }

  @override
  Future<OutboxEntry> enqueue(EnqueueMutation mutation) async {
    final id = _ids.next();
    final resourceId = mutation.clientResourceId ?? _ids.next();
    final key = mutation.idempotencyKey ?? _ids.next();
    final entry = OutboxEntry(
      id: id,
      clientResourceId: resourceId,
      idempotencyKey: key,
      method: mutation.method.toUpperCase(),
      path: mutation.path,
      bodyJson: mutation.bodyJson,
      status: OutboxStatus.pending,
      attemptCount: 0,
      createdAt: _clock().toUtc(),
      nextAttemptAt: _clock().toUtc(),
    );
    _items[id] = entry;
    _emit();
    return entry;
  }

  @override
  Future<List<OutboxEntry>> listPending({DateTime? readyBefore}) async {
    final now = readyBefore ?? _clock().toUtc();
    return _items.values
        .where(
          (e) =>
              e.status == OutboxStatus.pending &&
              (e.nextAttemptAt == null || !e.nextAttemptAt!.isAfter(now)),
        )
        .toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
  }

  @override
  Future<List<OutboxEntry>> listFailed() async {
    return _items.values.where((e) => e.status == OutboxStatus.failed).toList();
  }

  @override
  Future<int> pendingCount() async {
    return _items.values.where((e) => e.isPendingWork).length;
  }

  @override
  Future<OutboxEntry?> findById(String id) async => _items[id];

  @override
  Future<void> markInFlight(String id) async {
    final e = _items[id];
    if (e == null) return;
    _items[id] = e.copyWith(status: OutboxStatus.inFlight);
    _emit();
  }

  @override
  Future<void> markSynced(String id) async {
    final e = _items[id];
    if (e == null) return;
    _items[id] = e.copyWith(status: OutboxStatus.synced, clearError: true);
    _emit();
  }

  @override
  Future<void> markRetry({
    required String id,
    required int attemptCount,
    required DateTime nextAttemptAt,
    required String lastError,
    required String humanError,
  }) async {
    final e = _items[id];
    if (e == null) return;
    _items[id] = e.copyWith(
      status: OutboxStatus.pending,
      attemptCount: attemptCount,
      nextAttemptAt: nextAttemptAt,
      lastError: lastError,
      humanError: humanError,
    );
    _emit();
  }

  @override
  Future<void> markFailed({
    required String id,
    required String lastError,
    required String humanError,
  }) async {
    final e = _items[id];
    if (e == null) return;
    _items[id] = e.copyWith(
      status: OutboxStatus.failed,
      lastError: lastError,
      humanError: humanError,
    );
    _emit();
  }

  @override
  Future<void> discard(String id) async {
    _items.remove(id);
    _emit();
  }

  @override
  Future<void> requeue(String id) async {
    final e = _items[id];
    if (e == null) return;
    _items[id] = e.copyWith(
      status: OutboxStatus.pending,
      attemptCount: 0,
      nextAttemptAt: _clock().toUtc(),
      clearError: true,
    );
    _emit();
  }

  @override
  Stream<List<OutboxEntry>> watchActive() async* {
    yield _activeSnapshot();
    yield* _controller.stream;
  }

  Future<void> dispose() async {
    await _controller.close();
  }
}
