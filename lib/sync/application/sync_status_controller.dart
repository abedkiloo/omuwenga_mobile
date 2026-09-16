import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/outbox_store.dart';
import '../domain/outbox_entry.dart';
import 'connectivity_monitor.dart';
import 'sync_engine.dart';

enum SyncChipTone { online, offline, pending, error }

class SyncStatus {
  const SyncStatus({
    required this.isOnline,
    required this.pendingCount,
    required this.failedCount,
    this.lastHumanError,
  });

  final bool isOnline;
  final int pendingCount;
  final int failedCount;
  final String? lastHumanError;

  SyncChipTone get tone {
    if (failedCount > 0) return SyncChipTone.error;
    if (!isOnline) return SyncChipTone.offline;
    if (pendingCount > 0) return SyncChipTone.pending;
    return SyncChipTone.online;
  }

  String get label {
    switch (tone) {
      case SyncChipTone.error:
        return failedCount == 1 ? '1 sync failed' : '$failedCount syncs failed';
      case SyncChipTone.offline:
        return pendingCount > 0 ? 'Offline · $pendingCount waiting' : 'Offline';
      case SyncChipTone.pending:
        return '$pendingCount waiting to sync';
      case SyncChipTone.online:
        return 'Online';
    }
  }
}

class SyncStatusController extends StateNotifier<SyncStatus> {
  SyncStatusController({
    required OutboxStore store,
    required ConnectivityMonitor connectivity,
    required SyncEngine engine,
  }) : _store = store,
       _connectivity = connectivity,
       _engine = engine,
       super(
         const SyncStatus(isOnline: true, pendingCount: 0, failedCount: 0),
       ) {
    _init();
  }

  final OutboxStore _store;
  final ConnectivityMonitor _connectivity;
  final SyncEngine _engine;
  final _subs = <StreamSubscription<dynamic>>[];

  Future<void> _init() async {
    final online = await _connectivity.isOnline;
    await _refresh(isOnline: online);
    _subs.add(
      _connectivity.online.listen((online) async {
        await _refresh(isOnline: online);
        if (online) {
          await _engine.drainOnce();
          await _refresh(isOnline: true);
        }
      }),
    );
    _subs.add(
      _store.watchActive().listen((_) async {
        await _refresh();
      }),
    );
  }

  Future<void> _refresh({bool? isOnline}) async {
    final online = isOnline ?? state.isOnline;
    final pending = await _store.pendingCount();
    final failed = await _store.listFailed();
    state = SyncStatus(
      isOnline: online,
      pendingCount: pending,
      failedCount: failed.length,
      lastHumanError: failed.isEmpty ? null : failed.first.humanError,
    );
  }

  Future<void> retryFailed(String id) async {
    await _store.requeue(id);
    if (await _connectivity.isOnline) {
      await _engine.drainOnce();
    }
    await _refresh();
  }

  Future<void> discardFailed(String id) async {
    await _store.discard(id);
    await _refresh();
  }

  Future<List<OutboxEntry>> failedItems() => _store.listFailed();

  @override
  void dispose() {
    for (final s in _subs) {
      s.cancel();
    }
    super.dispose();
  }
}
