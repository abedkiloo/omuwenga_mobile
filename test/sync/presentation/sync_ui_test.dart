import 'package:completebyte_pos_mobile/sync/application/sync_status_controller.dart';
import 'package:completebyte_pos_mobile/sync/presentation/sync_failures_sheet.dart';
import 'package:completebyte_pos_mobile/sync/presentation/sync_status_chip.dart';
import 'package:completebyte_pos_mobile/sync/domain/outbox_entry.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('status chip states', (tester) async {
    Future<void> pumpStatus(SyncStatus status) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: SyncStatusChip(status: status)),
        ),
      );
      await tester.pump();
    }

    await pumpStatus(
      const SyncStatus(isOnline: true, pendingCount: 0, failedCount: 0),
    );
    expect(find.text('Online'), findsOneWidget);

    await pumpStatus(
      const SyncStatus(isOnline: false, pendingCount: 0, failedCount: 0),
    );
    expect(find.text('Offline'), findsOneWidget);

    await pumpStatus(
      const SyncStatus(isOnline: false, pendingCount: 2, failedCount: 0),
    );
    expect(find.text('Offline · 2 waiting'), findsOneWidget);

    await pumpStatus(
      const SyncStatus(isOnline: true, pendingCount: 3, failedCount: 0),
    );
    expect(find.text('3 waiting to sync'), findsOneWidget);

    await pumpStatus(
      const SyncStatus(isOnline: true, pendingCount: 0, failedCount: 1),
    );
    expect(find.text('1 sync failed'), findsOneWidget);
  });

  testWidgets('failures sheet retry', (tester) async {
    final retried = <String>[];
    final item = OutboxEntry(
      id: 'f1',
      clientResourceId: 'c',
      idempotencyKey: 'k',
      method: 'POST',
      path: 'sales/',
      bodyJson: '{}',
      status: OutboxStatus.failed,
      attemptCount: 5,
      createdAt: DateTime.utc(2026, 1, 1),
      humanError: 'Server rejected this change. Review and try again.',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SyncFailuresSheet(
            items: [item],
            onRetry: retried.add,
            onDiscard: (_) {},
          ),
        ),
      ),
    );
    expect(find.textContaining('rejected'), findsOneWidget);
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(retried, ['f1']);
  });

  testWidgets('failures sheet discard and empty', (tester) async {
    final discarded = <String>[];
    final item = OutboxEntry(
      id: 'f1',
      clientResourceId: 'c',
      idempotencyKey: 'k',
      method: 'POST',
      path: 'sales/',
      bodyJson: '{}',
      status: OutboxStatus.failed,
      attemptCount: 5,
      createdAt: DateTime.utc(2026, 1, 1),
      humanError: 'Could not sync.',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SyncFailuresSheet(
            items: [item],
            onRetry: (_) {},
            onDiscard: discarded.add,
          ),
        ),
      ),
    );
    await tester.tap(find.text('Discard'));
    await tester.pumpAndSettle();
    expect(discarded, ['f1']);

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => SyncFailuresSheet.show(
                context,
                items: const [],
                onRetry: (_) {},
                onDiscard: (_) {},
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('No failed syncs.'), findsOneWidget);
  });

  test('SyncStatus labels for plural failures', () {
    const status = SyncStatus(isOnline: true, pendingCount: 0, failedCount: 2);
    expect(status.label, '2 syncs failed');
    expect(status.tone, SyncChipTone.error);
  });
}
