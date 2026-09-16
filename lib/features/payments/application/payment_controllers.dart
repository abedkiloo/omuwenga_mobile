import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/result/result.dart';
import '../../../sync/application/connectivity_monitor.dart';
import '../../../sync/providers.dart';
import '../data/payments_api.dart';
import '../domain/payment_intent.dart';

final paymentsApiProvider = Provider<PaymentsApi>((ref) {
  return PaymentsApi(ref.watch(apiClientProvider));
});

class StkWaitState {
  const StkWaitState({
    this.intent,
    this.polling = false,
    this.error,
    this.offlineBlocked = false,
  });

  final PaymentIntent? intent;
  final bool polling;
  final String? error;
  final bool offlineBlocked;

  bool get isPaid => intent?.status == PaymentIntentStatus.paid;
  bool get isFailed =>
      intent?.status == PaymentIntentStatus.failed ||
      intent?.status == PaymentIntentStatus.cancelled ||
      intent?.status == PaymentIntentStatus.expired;
  bool get showSmsSent => intent?.smsSent == true;

  StkWaitState copyWith({
    PaymentIntent? intent,
    bool? polling,
    String? error,
    bool? offlineBlocked,
    bool clearError = false,
  }) {
    return StkWaitState(
      intent: intent ?? this.intent,
      polling: polling ?? this.polling,
      error: clearError ? null : (error ?? this.error),
      offlineBlocked: offlineBlocked ?? this.offlineBlocked,
    );
  }
}

class StkWaitController extends StateNotifier<StkWaitState> {
  StkWaitController(this._api, this._connectivity)
    : super(const StkWaitState());

  final PaymentsApi _api;
  final ConnectivityMonitor _connectivity;
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<bool> start({
    required double amount,
    required String phone,
    required String purpose,
    int? customerId,
    String customerName = '',
  }) async {
    final online = await _connectivity.isOnline;
    if (!online) {
      state = state.copyWith(
        offlineBlocked: true,
        error: 'M-Pesa STK requires a connection',
      );
      return false;
    }
    state = state.copyWith(
      polling: true,
      clearError: true,
      offlineBlocked: false,
    );
    final created = await _api.create(
      amount: amount,
      phone: phone,
      purpose: purpose,
      customerId: customerId,
      customerName: customerName,
    );
    if (created.isFailure) {
      final f = created as Failure;
      state = state.copyWith(polling: false, error: f.error.toString());
      return false;
    }
    var intent = created.getOrThrow();
    final prompted = await _api.sendStk(intent.id);
    if (prompted.isFailure) {
      final f = prompted as Failure;
      state = state.copyWith(
        intent: intent,
        polling: false,
        error: f.error.toString(),
      );
      return false;
    }
    intent = prompted.getOrThrow();
    state = state.copyWith(intent: intent, polling: true, clearError: true);
    _startPolling(intent.id);
    return true;
  }

  void _startPolling(int id) {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 2), (_) async {
      await refresh(id);
    });
  }

  Future<void> refresh(int id) async {
    final result = await _api.get(id);
    if (result.isFailure) return;
    final intent = result.getOrThrow();
    state = state.copyWith(intent: intent);
    if (intent.status.isTerminal) {
      _timer?.cancel();
      state = state.copyWith(polling: false);
    }
  }

  Future<void> queryNow() async {
    final id = state.intent?.id;
    if (id == null) return;
    state = state.copyWith(polling: true, clearError: true);
    final result = await _api.query(id);
    if (result.isFailure) {
      final f = result as Failure;
      state = state.copyWith(polling: false, error: f.error.toString());
      return;
    }
    final intent = result.getOrThrow();
    state = state.copyWith(intent: intent, polling: !intent.status.isTerminal);
    if (intent.status.isTerminal) {
      _timer?.cancel();
    }
  }

  void reset() {
    _timer?.cancel();
    state = const StkWaitState();
  }
}

final stkWaitProvider =
    StateNotifierProvider.autoDispose<StkWaitController, StkWaitState>(
      (ref) => StkWaitController(
        ref.watch(paymentsApiProvider),
        ref.watch(connectivityMonitorProvider),
      ),
    );
