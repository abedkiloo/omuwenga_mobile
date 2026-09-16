import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/result/result.dart';
import '../../../sync/application/connectivity_monitor.dart';
import '../../../sync/data/outbox_store.dart';
import '../../../sync/domain/client_uuid.dart';
import '../../../sync/domain/outbox_entry.dart';
import '../../../sync/providers.dart';
import '../data/delivery_api.dart';
import '../domain/delivery_stop.dart';

final deliveryApiProvider = Provider<DeliveryApi>((ref) {
  return DeliveryApi(ref.watch(apiClientProvider));
});

class DeliveryRouteState {
  const DeliveryRouteState({
    this.route,
    this.config = const DeliveryConfig(),
    this.loading = false,
    this.error,
    this.acting = false,
    this.pod = const PodDraft(),
    this.queuedPodOffline = false,
  });

  final DeliveryRoute? route;
  final DeliveryConfig config;
  final bool loading;
  final String? error;
  final bool acting;
  final PodDraft pod;
  final bool queuedPodOffline;

  DeliveryStop? get nextStop =>
      route == null ? null : selectNextStop(route!.stops);

  DeliveryRouteState copyWith({
    DeliveryRoute? route,
    DeliveryConfig? config,
    bool? loading,
    String? error,
    bool? acting,
    PodDraft? pod,
    bool? queuedPodOffline,
    bool clearError = false,
  }) {
    return DeliveryRouteState(
      route: route ?? this.route,
      config: config ?? this.config,
      loading: loading ?? this.loading,
      error: clearError ? null : (error ?? this.error),
      acting: acting ?? this.acting,
      pod: pod ?? this.pod,
      queuedPodOffline: queuedPodOffline ?? this.queuedPodOffline,
    );
  }
}

class DeliveryRouteController extends StateNotifier<DeliveryRouteState> {
  DeliveryRouteController(
    this._api,
    this._connectivity,
    this._outbox, {
    ClientUuid? ids,
  }) : _ids = ids ?? ClientUuid(),
       super(const DeliveryRouteState());

  final DeliveryApi _api;
  final ConnectivityMonitor _connectivity;
  final OutboxStore _outbox;
  final ClientUuid _ids;

  Future<void> load() async {
    state = state.copyWith(loading: true, clearError: true);
    final cfg = await _api.config();
    final config = cfg.getOrNull() ?? const DeliveryConfig();
    final result = await _api.todayRoute(
      requirePod: config.requirePodToComplete,
    );
    result.when(
      success: (route) =>
          state = state.copyWith(route: route, config: config, loading: false),
      failure: (e, _) =>
          state = state.copyWith(loading: false, error: e.toString()),
    );
  }

  DeliveryStop? stopById(int id) {
    final stops = state.route?.stops ?? const <DeliveryStop>[];
    for (final s in stops) {
      if (s.id == id) return s;
    }
    return null;
  }

  void setPodDraft(PodDraft draft) {
    state = state.copyWith(pod: draft, clearError: true);
  }

  Future<bool> arrive(int stopId) => _act(() => _api.arrive(stopId));
  Future<bool> start(int stopId) => _act(() => _api.start(stopId));

  Future<bool> saveLines(int stopId, List<DeliveryLine> lines) =>
      _act(() => _api.updateLines(stopId, lines));

  Future<bool> collectCash(int stopId, {double? amount}) =>
      _act(() => _api.collect(stopId, method: 'cash', amount: amount));

  Future<bool> collectDebt(int stopId) =>
      _act(() => _api.collect(stopId, method: 'debt'));

  Future<bool> collectMpesa(
    int stopId, {
    required double amount,
    String receipt = '',
  }) => _act(
    () => _api.collect(
      stopId,
      method: 'defer_stk',
      amount: amount,
      notes: receipt,
    ),
  );

  Future<bool> submitPod(int stopId) async {
    final draft = state.pod;
    if (!draft.isComplete) {
      state = state.copyWith(error: 'Capture signature, photo, and pin');
      return false;
    }
    final online = await _connectivity.isOnline;
    if (!online) {
      if (!state.config.allowOfflinePodQueue) {
        state = state.copyWith(error: 'Offline — POD queue not allowed');
        return false;
      }
      await _outbox.enqueue(
        EnqueueMutation(
          method: 'POST',
          path: 'delivery/stops/$stopId/pod/',
          bodyJson: jsonEncode({
            'latitude': draft.latitude,
            'longitude': draft.longitude,
            'notes': draft.notes,
            'signature_b64': 'offline',
            'photo_b64': 'offline',
          }),
          idempotencyKey: _ids.next(),
          clientResourceId: _ids.next(),
        ),
      );
      state = state.copyWith(queuedPodOffline: true, clearError: true);
      return true;
    }
    return _act(() => _api.submitPod(stopId, draft: draft));
  }

  Future<bool> complete(int stopId) async {
    final stop = stopById(stopId);
    if (stop != null && !stop.canComplete && !state.queuedPodOffline) {
      state = state.copyWith(error: 'POD required before complete');
      return false;
    }
    final ok = await _act(() => _api.complete(stopId));
    if (ok) {
      state = state.copyWith(pod: const PodDraft(), queuedPodOffline: false);
    }
    return ok;
  }

  Future<bool> _act(Future<Result<DeliveryStop>> Function() call) async {
    state = state.copyWith(acting: true, clearError: true);
    final result = await call();
    if (result.isFailure) {
      final f = result as Failure;
      state = state.copyWith(acting: false, error: f.error.toString());
      return false;
    }
    final updated = result.getOrThrow();
    final route = state.route;
    if (route != null) {
      final stops = [
        for (final s in route.stops)
          if (s.id == updated.id) updated else s,
      ];
      state = state.copyWith(
        acting: false,
        route: DeliveryRoute(
          id: route.id,
          routeDate: route.routeDate,
          stops: stops,
          nextStopId: selectNextStop(stops)?.id,
        ),
      );
    } else {
      state = state.copyWith(acting: false);
    }
    return true;
  }
}

final deliveryRouteProvider =
    StateNotifierProvider<DeliveryRouteController, DeliveryRouteState>(
      (ref) => DeliveryRouteController(
        ref.watch(deliveryApiProvider),
        ref.watch(connectivityMonitorProvider),
        ref.watch(outboxStoreProvider),
      ),
    );
