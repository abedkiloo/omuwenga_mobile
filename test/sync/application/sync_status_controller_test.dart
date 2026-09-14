import 'package:completebyte_pos_mobile/core/result/result.dart';
import 'package:completebyte_pos_mobile/sync/application/connectivity_monitor.dart';
import 'package:completebyte_pos_mobile/sync/application/sync_engine.dart';
import 'package:completebyte_pos_mobile/sync/application/sync_status_controller.dart';
import 'package:completebyte_pos_mobile/sync/data/memory_outbox_store.dart';
import 'package:completebyte_pos_mobile/sync/domain/outbox_entry.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

void main() {
  test('controller reflects offline pending and drains on reconnect', () async {
    final store = MemoryOutboxStore();
    final connectivity = FakeConnectivityMonitor(online: false);
    final engine = SyncEngine(
      store: store,
      sender: (_) async => Success(http.Response('{}', 200)),
    );
    final controller = SyncStatusController(
      store: store,
      connectivity: connectivity,
      engine: engine,
    );
    await Future<void>.delayed(Duration.zero);

    await store.enqueue(
      const EnqueueMutation(method: 'POST', path: 'x/', bodyJson: '{}'),
    );
    await Future<void>.delayed(const Duration(milliseconds: 30));
    expect(controller.state.isOnline, isFalse);
    expect(controller.state.pendingCount, greaterThan(0));
    expect(controller.state.label, contains('Offline'));

    connectivity.setOnline(true);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(controller.state.isOnline, isTrue);
    expect(controller.state.pendingCount, 0);

    final failed = await store.enqueue(
      const EnqueueMutation(method: 'POST', path: 'fail/', bodyJson: '{}'),
    );
    await store.markFailed(
      id: failed.id,
      lastError: 'e',
      humanError: 'Human fail',
    );
    await Future<void>.delayed(const Duration(milliseconds: 30));
    expect(controller.state.failedCount, greaterThan(0));

    final items = await controller.failedItems();
    await controller.retryFailed(items.first.id);
    await Future<void>.delayed(const Duration(milliseconds: 30));
    expect(controller.state.failedCount, 0);

    final discard = await store.enqueue(
      const EnqueueMutation(method: 'POST', path: 'discard/', bodyJson: '{}'),
    );
    await store.markFailed(id: discard.id, lastError: 'e', humanError: 'Bye');
    await Future<void>.delayed(const Duration(milliseconds: 30));
    await controller.discardFailed(discard.id);
    await Future<void>.delayed(const Duration(milliseconds: 30));
    expect(await store.findById(discard.id), isNull);

    controller.dispose();
    await store.dispose();
    connectivity.dispose();
  });
}
