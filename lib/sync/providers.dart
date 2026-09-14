import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/providers.dart';
import 'application/connectivity_monitor.dart';
import 'application/sync_engine.dart';
import 'application/sync_status_controller.dart';
import 'data/app_database.dart';
import 'data/drift_outbox_store.dart';
import 'data/memory_outbox_store.dart';
import 'data/outbox_store.dart';
import 'data/pii_cipher.dart';
import 'data/product_cache_repository.dart';

final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase.memory();
  ref.onDispose(db.close);
  return db;
});

/// Override in production bootstrap with [AppDatabase.file].
final outboxStoreProvider = Provider<OutboxStore>((ref) {
  return DriftOutboxStore(ref.watch(appDatabaseProvider));
});

final piiKeyStoreProvider = Provider<PiiKeyStore>((ref) {
  return MemoryPiiKeyStore();
});

final piiCipherProvider = Provider<AesPiiCipher>((ref) {
  return AesPiiCipher(ref.watch(piiKeyStoreProvider));
});

final productCacheProvider = Provider<ProductCacheRepository>((ref) {
  return ProductCacheRepository(
    ref.watch(appDatabaseProvider),
    cipher: ref.watch(piiCipherProvider),
  );
});

/// Default is fake (test-friendly). Production overrides with ConnectivityPlusMonitor.
final connectivityMonitorProvider = Provider<ConnectivityMonitor>((ref) {
  final monitor = FakeConnectivityMonitor(online: true);
  ref.onDispose(monitor.dispose);
  return monitor;
});

final syncEngineProvider = Provider<SyncEngine>((ref) {
  return SyncEngine(
    store: ref.watch(outboxStoreProvider),
    sender: apiOutboxSender(ref.watch(apiClientProvider)),
  );
});

final syncStatusProvider =
    StateNotifierProvider<SyncStatusController, SyncStatus>((ref) {
  return SyncStatusController(
    store: ref.watch(outboxStoreProvider),
    connectivity: ref.watch(connectivityMonitorProvider),
    engine: ref.watch(syncEngineProvider),
  );
});

/// Test helper: memory outbox without Drift.
OutboxStore memoryOutboxForTests() => MemoryOutboxStore();
