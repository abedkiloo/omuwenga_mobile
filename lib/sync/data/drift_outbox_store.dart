import 'package:drift/drift.dart';

import '../domain/client_uuid.dart';
import '../domain/outbox_entry.dart';
import 'app_database.dart';
import 'outbox_store.dart';

class DriftOutboxStore implements OutboxStore {
  DriftOutboxStore(this._db, {ClientUuid? ids, DateTime Function()? clock})
    : _ids = ids ?? ClientUuid(),
      _clock = clock ?? DateTime.now;

  final AppDatabase _db;
  final ClientUuid _ids;
  final DateTime Function() _clock;

  OutboxEntry _map(OutboxItem row) {
    return OutboxEntry(
      id: row.id,
      clientResourceId: row.clientResourceId,
      idempotencyKey: row.idempotencyKey,
      method: row.method,
      path: row.path,
      bodyJson: row.bodyJson,
      status: OutboxStatus.values.byName(row.status),
      attemptCount: row.attemptCount,
      createdAt: row.createdAt,
      nextAttemptAt: row.nextAttemptAt,
      lastError: row.lastError,
      humanError: row.humanError,
    );
  }

  @override
  Future<OutboxEntry> enqueue(EnqueueMutation mutation) async {
    final id = _ids.next();
    final resourceId = mutation.clientResourceId ?? _ids.next();
    final key = mutation.idempotencyKey ?? _ids.next();
    final now = _clock().toUtc();
    final companion = OutboxItemsCompanion.insert(
      id: id,
      clientResourceId: resourceId,
      idempotencyKey: key,
      method: mutation.method.toUpperCase(),
      path: mutation.path,
      bodyJson: mutation.bodyJson,
      status: OutboxStatus.pending.name,
      createdAt: now,
      nextAttemptAt: Value(now),
    );
    await _db.into(_db.outboxItems).insert(companion);
    return (await findById(id))!;
  }

  @override
  Future<List<OutboxEntry>> listPending({DateTime? readyBefore}) async {
    final now = readyBefore ?? _clock().toUtc();
    final rows =
        await (_db.select(_db.outboxItems)
              ..where((t) => t.status.equals(OutboxStatus.pending.name))
              ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
            .get();
    return rows
        .map(_map)
        .where((e) => e.nextAttemptAt == null || !e.nextAttemptAt!.isAfter(now))
        .toList();
  }

  @override
  Future<List<OutboxEntry>> listFailed() async {
    final rows = await (_db.select(
      _db.outboxItems,
    )..where((t) => t.status.equals(OutboxStatus.failed.name))).get();
    return rows.map(_map).toList();
  }

  @override
  Future<int> pendingCount() async {
    final rows =
        await (_db.select(_db.outboxItems)..where(
              (t) =>
                  t.status.equals(OutboxStatus.pending.name) |
                  t.status.equals(OutboxStatus.inFlight.name),
            ))
            .get();
    return rows.length;
  }

  @override
  Future<OutboxEntry?> findById(String id) async {
    final row = await (_db.select(
      _db.outboxItems,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    return row == null ? null : _map(row);
  }

  Future<void> _update(String id, OutboxItemsCompanion companion) async {
    await (_db.update(
      _db.outboxItems,
    )..where((t) => t.id.equals(id))).write(companion);
  }

  @override
  Future<void> markInFlight(String id) => _update(
    id,
    OutboxItemsCompanion(status: Value(OutboxStatus.inFlight.name)),
  );

  @override
  Future<void> markSynced(String id) => _update(
    id,
    OutboxItemsCompanion(
      status: Value(OutboxStatus.synced.name),
      lastError: const Value(null),
      humanError: const Value(null),
    ),
  );

  @override
  Future<void> markRetry({
    required String id,
    required int attemptCount,
    required DateTime nextAttemptAt,
    required String lastError,
    required String humanError,
  }) => _update(
    id,
    OutboxItemsCompanion(
      status: Value(OutboxStatus.pending.name),
      attemptCount: Value(attemptCount),
      nextAttemptAt: Value(nextAttemptAt),
      lastError: Value(lastError),
      humanError: Value(humanError),
    ),
  );

  @override
  Future<void> markFailed({
    required String id,
    required String lastError,
    required String humanError,
  }) => _update(
    id,
    OutboxItemsCompanion(
      status: Value(OutboxStatus.failed.name),
      lastError: Value(lastError),
      humanError: Value(humanError),
    ),
  );

  @override
  Future<void> discard(String id) async {
    await (_db.delete(_db.outboxItems)..where((t) => t.id.equals(id))).go();
  }

  @override
  Future<void> requeue(String id) => _update(
    id,
    OutboxItemsCompanion(
      status: Value(OutboxStatus.pending.name),
      attemptCount: const Value(0),
      nextAttemptAt: Value(_clock().toUtc()),
      lastError: const Value(null),
      humanError: const Value(null),
    ),
  );

  @override
  Stream<List<OutboxEntry>> watchActive() {
    return (_db.select(_db.outboxItems)
          ..where((t) => t.status.equals(OutboxStatus.synced.name).not())
          ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
        .watch()
        .map((rows) => rows.map(_map).toList());
  }
}
