import 'package:completebyte_pos_mobile/core/result/result.dart';
import 'package:completebyte_pos_mobile/sync/application/sync_engine.dart';
import 'package:completebyte_pos_mobile/sync/data/memory_outbox_store.dart';
import 'package:completebyte_pos_mobile/sync/domain/outbox_entry.dart';
import 'package:completebyte_pos_mobile/sync/domain/sync_backoff.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

void main() {
  late MemoryOutboxStore store;
  late DateTime now;

  setUp(() {
    now = DateTime.utc(2026, 9, 14, 12);
    store = MemoryOutboxStore(clock: () => now);
  });

  tearDown(() async {
    await store.dispose();
  });

  test('enqueue / dequeue / retry / permanent fail', () async {
    final keys = <String>[];
    final engine = SyncEngine(
      store: store,
      backoff: const SyncBackoff(
        base: Duration(seconds: 1),
        cap: Duration(seconds: 60),
      ),
      maxAttempts: 3,
      clock: () => now,
      sender: (entry) async {
        keys.add(entry.idempotencyKey);
        return Failure(Exception('SocketException: offline'));
      },
    );

    final first = await store.enqueue(
      const EnqueueMutation(
        method: 'POST',
        path: 'sales/',
        bodyJson: '{"total":1}',
        idempotencyKey: 'stable-key-1',
        clientResourceId: 'client-sale-1',
      ),
    );
    expect(first.idempotencyKey, 'stable-key-1');

    expect(await engine.drainOnce(), 0);
    expect(keys, ['stable-key-1']);
    var pending = await store.listPending(
      readyBefore: now.add(const Duration(hours: 1)),
    );
    expect(pending.single.attemptCount, 1);
    expect(pending.single.idempotencyKey, 'stable-key-1');

    now = now.add(const Duration(seconds: 2));
    await engine.drainOnce();
    expect(keys, ['stable-key-1', 'stable-key-1']);

    now = now.add(const Duration(seconds: 4));
    await engine.drainOnce();
    expect(keys.length, 3);
    expect(keys.toSet(), {'stable-key-1'});

    final failed = await store.listFailed();
    expect(failed, hasLength(1));
    expect(failed.single.humanError, contains('No connection'));
  });

  test('successful drain marks synced and airplane reconnect demo', () async {
    var online = false;
    final engine = SyncEngine(
      store: store,
      clock: () => now,
      sender: (entry) async {
        if (!online) {
          return Failure(Exception('Network is unreachable'));
        }
        expect(entry.idempotencyKey, 'idem-42');
        return Success(http.Response('{"ok":true}', 201));
      },
    );

    await store.enqueue(
      const EnqueueMutation(
        method: 'POST',
        path: 'sales/customers/',
        bodyJson: '{"name":"Ada"}',
        idempotencyKey: 'idem-42',
      ),
    );

    // Airplane mode: enqueue stays pending.
    expect(await engine.drainOnce(), 0);
    expect(await store.pendingCount(), 1);

    // Reconnect drains queue.
    online = true;
    now = now.add(const Duration(seconds: 2));
    expect(await engine.drainOnce(), 1);
    expect(await store.pendingCount(), 0);
    expect(await store.listFailed(), isEmpty);
  });

  test('permanent 400 fails without silent loss', () async {
    final engine = SyncEngine(
      store: store,
      clock: () => now,
      sender: (_) async => Success(http.Response('{"error":"bad"}', 400)),
    );
    await store.enqueue(
      const EnqueueMutation(method: 'POST', path: 'x/', bodyJson: '{}'),
    );
    await engine.drainOnce();
    final failed = await store.listFailed();
    expect(failed, hasLength(1));
    expect(failed.single.humanError, contains('rejected'));
    await store.requeue(failed.single.id);
    expect(await store.pendingCount(), 1);
    await store.discard((await store.listPending()).single.id);
    expect(await store.pendingCount(), 0);
  });
}
