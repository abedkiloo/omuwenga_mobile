import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/result/result.dart';
import '../data/payroll_api.dart';
import '../domain/payroll.dart';
import 'payroll_controller.dart';

String agentCommissionTodayLocal() {
  final now = DateTime.now();
  final y = now.year.toString().padLeft(4, '0');
  final m = now.month.toString().padLeft(2, '0');
  final d = now.day.toString().padLeft(2, '0');
  return '$y-$m-$d';
}

String agentCommissionShiftDate(String iso, int deltaDays) {
  final parsed = DateTime.tryParse(iso) ?? DateTime.now();
  final next = parsed.add(Duration(days: deltaDays));
  final y = next.year.toString().padLeft(4, '0');
  final m = next.month.toString().padLeft(2, '0');
  final d = next.day.toString().padLeft(2, '0');
  return '$y-$m-$d';
}

class AgentCommissionState {
  const AgentCommissionState({
    this.date = '',
    this.day,
    this.loading = false,
    this.error,
  });

  final String date;
  final AgentCommissionDay? day;
  final bool loading;
  final String? error;

  AgentCommissionState copyWith({
    String? date,
    AgentCommissionDay? day,
    bool? loading,
    String? error,
    bool clearError = false,
    bool clearDay = false,
  }) {
    return AgentCommissionState(
      date: date ?? this.date,
      day: clearDay ? null : (day ?? this.day),
      loading: loading ?? this.loading,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class AgentCommissionController extends StateNotifier<AgentCommissionState> {
  AgentCommissionController(this._api)
      : super(AgentCommissionState(date: agentCommissionTodayLocal()));

  final PayrollApi _api;

  Future<void> load([String? date]) async {
    final target = (date ?? state.date).trim().isEmpty
        ? agentCommissionTodayLocal()
        : (date ?? state.date).trim();
    state = state.copyWith(loading: true, clearError: true, date: target);
    final today = agentCommissionTodayLocal();
    final result = await _api.commissionDay(
      date: target == today ? null : target,
    );
    if (result.isFailure) {
      final f = result as Failure;
      state = state.copyWith(
        loading: false,
        error: f.error.toString(),
        clearDay: true,
      );
      return;
    }
    state = state.copyWith(
      loading: false,
      day: result.getOrThrow(),
      clearError: true,
    );
  }

  Future<void> shiftDay(int delta) async {
    final today = agentCommissionTodayLocal();
    var next = agentCommissionShiftDate(state.date, delta);
    if (next.compareTo(today) > 0) next = today;
    await load(next);
  }
}

final agentCommissionProvider =
    StateNotifierProvider.autoDispose<AgentCommissionController, AgentCommissionState>(
  (ref) => AgentCommissionController(ref.watch(payrollApiProvider)),
);
