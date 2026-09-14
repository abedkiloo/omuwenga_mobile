import 'package:completebyte_pos_mobile/app/providers.dart';
import 'package:completebyte_pos_mobile/core/env/app_env.dart';
import 'package:completebyte_pos_mobile/core/network/api_client.dart';
import 'package:completebyte_pos_mobile/core/result/result.dart';
import 'package:completebyte_pos_mobile/core/secure/token_store.dart';
import 'package:completebyte_pos_mobile/sync/application/sync_engine.dart';
import 'package:completebyte_pos_mobile/sync/data/app_database.dart';
import 'package:completebyte_pos_mobile/sync/data/drift_outbox_store.dart';
import 'package:completebyte_pos_mobile/sync/data/memory_outbox_store.dart';
import 'package:completebyte_pos_mobile/sync/data/pii_cipher.dart';
import 'package:completebyte_pos_mobile/sync/domain/human_error.dart';
import 'package:completebyte_pos_mobile/sync/domain/outbox_entry.dart';
import 'package:completebyte_pos_mobile/sync/providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('humanize remaining branches', () {
    expect(humanizeSyncError(statusCode: 404, error: 'x'), contains('no longer'));
    expect(humanizeSyncError(statusCode: 422, error: 'x'), contains('rejected'));
    expect(
      humanizeSyncError(statusCode: null, error: Exception('TimeoutException')),
      contains('timed out'),
    );
    expect(humanizeSyncError(statusCode: null, error: 'other'), contains('Could not sync'));
  });

  test('apiOutboxSender methods and unsupported', () async {
    final tokens = InMemoryTokenStore();
    await tokens.writeTokens(access: 'a', refresh: 'r');
    final methods = <String>[];
    final client = ApiClient(
      env: const AppEnv(flavor: AppFlavor.dev, apiBaseUrl: 'http://example.com/api'),
      tokenStore: tokens,
      httpClient: MockClient((request) async {
        methods.add(request.method);
        expect(request.headers['Idempotency-Key'], 'ik');
        return http.Response('{}', 200);
      }),
    );
    final sender = apiOutboxSender(client);
    OutboxEntry entry(String method, {String body = '{}'}) => OutboxEntry(
          id: '1',
          clientResourceId: 'c',
          idempotencyKey: 'ik',
          method: method,
          path: 'sales/',
          bodyJson: body,
          status: OutboxStatus.pending,
          attemptCount: 0,
          createdAt: DateTime.utc(2026),
        );

    expect((await sender(entry('POST'))).isSuccess, isTrue);
    expect((await sender(entry('PUT'))).isSuccess, isTrue);
    expect((await sender(entry('PATCH', body: ''))).isSuccess, isTrue);
    expect((await sender(entry('DELETE'))).isFailure, isTrue);
    expect((await sender(entry('POST', body: '[1]'))).isSuccess, isTrue);
    expect(methods, ['POST', 'PUT', 'PATCH', 'POST']);
    client.close();
  });

  test('sync engine 5xx retries then permanent fail', () async {
    final store = MemoryOutboxStore();
    final engine = SyncEngine(
      store: store,
      maxAttempts: 2,
      clock: () => DateTime.utc(2026, 1, 1),
      sender: (_) async => Success(http.Response('nope', 503)),
    );
    final queued = await store.enqueue(
      const EnqueueMutation(method: 'POST', path: 'x/', bodyJson: '{}'),
    );
    expect(await engine.drainOnce(), 0);
    await store.markRetry(
      id: queued.id,
      attemptCount: 1,
      nextAttemptAt: DateTime.utc(2026, 1, 1),
      lastError: 'HTTP 503',
      humanError: 'Server is temporarily unavailable. Will retry.',
    );
    expect(await engine.drainOnce(), 0);
    expect(await store.listFailed(), hasLength(1));
    await store.dispose();
  });

  test('providers wire memory stack', () async {
    final container = ProviderContainer(
      overrides: [
        tokenStoreProvider.overrideWithValue(InMemoryTokenStore()),
        appEnvProvider.overrideWithValue(
          const AppEnv(flavor: AppFlavor.dev, apiBaseUrl: 'http://example.com/api'),
        ),
        httpClientProvider.overrideWithValue(
          MockClient((_) async => http.Response('{}', 200)),
        ),
        outboxStoreProvider.overrideWithValue(MemoryOutboxStore()),
      ],
    );
    expect(container.read(outboxStoreProvider), isA<MemoryOutboxStore>());
    expect(container.read(productCacheProvider), isNotNull);
    expect(container.read(piiCipherProvider), isA<AesPiiCipher>());
    expect(container.read(syncEngineProvider), isA<SyncEngine>());
    expect(container.read(syncStatusProvider).isOnline, isTrue);
    expect(memoryOutboxForTests(), isA<MemoryOutboxStore>());
    await Future<void>.delayed(const Duration(milliseconds: 20));
    container.dispose();
  });

  test('providers default drift outbox', () async {
    final container = ProviderContainer(
      overrides: [
        tokenStoreProvider.overrideWithValue(InMemoryTokenStore()),
        appEnvProvider.overrideWithValue(
          const AppEnv(flavor: AppFlavor.dev, apiBaseUrl: 'http://example.com/api'),
        ),
        httpClientProvider.overrideWithValue(
          MockClient((_) async => http.Response('{}', 200)),
        ),
      ],
    );
    expect(container.read(outboxStoreProvider), isA<DriftOutboxStore>());
    expect(container.read(appDatabaseProvider), isA<AppDatabase>());
    await Future<void>.delayed(const Duration(milliseconds: 30));
    container.dispose();
  });

  test('drift markRetry respects nextAttemptAt', () async {
    final db = AppDatabase.memory();
    addTearDown(db.close);
    final store = DriftOutboxStore(db, clock: () => DateTime.utc(2026, 1, 1, 12));
    final e = await store.enqueue(
      const EnqueueMutation(method: 'POST', path: 'x/', bodyJson: '{"a":1}'),
    );
    await store.markRetry(
      id: e.id,
      attemptCount: 2,
      nextAttemptAt: DateTime.utc(2026, 1, 1, 13),
      lastError: 'x',
      humanError: 'Will retry',
    );
    expect(await store.listPending(readyBefore: DateTime.utc(2026, 1, 1, 12)), isEmpty);
    expect(await store.listPending(readyBefore: DateTime.utc(2026, 1, 1, 14)), hasLength(1));
  });

  test('pii key reuse and clear', () async {
    final keys = MemoryPiiKeyStore();
    final c1 = AesPiiCipher(keys);
    final blob = await c1.encryptUtf8('a');
    expect(await c1.encryptUtf8('b'), isNot(blob));
    final c2 = AesPiiCipher(keys);
    expect(await c2.decryptUtf8(blob), 'a');
    await keys.clear();
    expect(await keys.read(), isNull);
  });

  test('outbox inFlight is pending work', () {
    final e = OutboxEntry(
      id: '1',
      clientResourceId: 'c',
      idempotencyKey: 'k',
      method: 'POST',
      path: 'x/',
      bodyJson: '{}',
      status: OutboxStatus.inFlight,
      attemptCount: 1,
      createdAt: DateTime.utc(2026),
    );
    expect(e.isPendingWork, isTrue);
  });
}
