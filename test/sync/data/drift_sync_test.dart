import 'package:completebyte_pos_mobile/sync/data/app_database.dart';
import 'package:completebyte_pos_mobile/sync/data/drift_outbox_store.dart';
import 'package:completebyte_pos_mobile/sync/data/pii_cipher.dart';
import 'package:completebyte_pos_mobile/sync/data/product_cache_repository.dart';
import 'package:completebyte_pos_mobile/sync/domain/outbox_entry.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.memory();
  });

  tearDown(() async {
    await db.close();
  });

  test('Drift outbox persists enqueue and status transitions', () async {
    final store = DriftOutboxStore(db);
    final entry = await store.enqueue(
      const EnqueueMutation(
        method: 'post',
        path: 'sales/',
        bodyJson: '{}',
        idempotencyKey: 'k1',
      ),
    );
    expect(entry.method, 'POST');
    await store.markInFlight(entry.id);
    expect((await store.findById(entry.id))!.status, OutboxStatus.inFlight);
    await store.markSynced(entry.id);
    expect(await store.pendingCount(), 0);

    final again = await store.enqueue(
      const EnqueueMutation(method: 'POST', path: 'x/', bodyJson: '{}'),
    );
    await store.markFailed(id: again.id, lastError: 'e', humanError: 'Human');
    expect((await store.listFailed()).single.humanError, 'Human');
    await store.requeue(again.id);
    expect(await store.pendingCount(), 1);
    await store.discard(again.id);
    expect(await store.watchActive().first, isEmpty);
  });

  test('product cache encrypts sensitive payload', () async {
    final cipher = AesPiiCipher(MemoryPiiKeyStore());
    final repo = ProductCacheRepository(db, cipher: cipher);
    await repo.upsert(
      ProductCacheEntry(
        id: 'p1',
        name: 'Cement 50kg',
        price: 850,
        updatedAt: DateTime.utc(2026, 9, 14),
        sensitiveNote: 'supplier phone 07xx',
      ),
    );
    final found = await repo.findById('p1');
    expect(found!.name, 'Cement 50kg');
    expect(found.sensitiveNote, 'supplier phone 07xx');
    final row = await db.select(db.cachedProducts).getSingle();
    expect(row.encryptedPayload, isNot(contains('07xx')));
    expect(await repo.listAll(), hasLength(1));
  });

  test('AesPiiCipher round-trip and bad blob', () async {
    final cipher = AesPiiCipher(MemoryPiiKeyStore());
    final blob = await cipher.encryptUtf8('secret');
    expect(await cipher.decryptUtf8(blob), 'secret');
    expect(() => cipher.decryptUtf8('bad'), throwsFormatException);
  });
}
