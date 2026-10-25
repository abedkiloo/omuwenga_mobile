import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/result/result.dart';
import '../data/payroll_api.dart';
import '../domain/payroll.dart';

final payrollApiProvider = Provider<PayrollApi>((ref) {
  return PayrollApi(ref.watch(apiClientProvider));
});

class PayrollState {
  const PayrollState({
    this.pay,
    this.payslips = const [],
    this.loading = false,
    this.downloadingId,
    this.error,
  });

  final MyCurrentPay? pay;
  final List<MyPayslipSummary> payslips;
  final bool loading;
  final int? downloadingId;
  final String? error;

  PayrollState copyWith({
    MyCurrentPay? pay,
    List<MyPayslipSummary>? payslips,
    bool? loading,
    int? downloadingId,
    String? error,
    bool clearError = false,
    bool clearDownloading = false,
  }) {
    return PayrollState(
      pay: pay ?? this.pay,
      payslips: payslips ?? this.payslips,
      loading: loading ?? this.loading,
      downloadingId:
          clearDownloading ? null : (downloadingId ?? this.downloadingId),
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class PayrollController extends StateNotifier<PayrollState> {
  PayrollController(this._api) : super(const PayrollState());

  final PayrollApi _api;

  Future<void> load() async {
    state = state.copyWith(loading: true, clearError: true);
    final payResult = await _api.myPay();
    final slipsResult = await _api.myPayslips();

    if (payResult.isFailure && slipsResult.isFailure) {
      state = state.copyWith(
        loading: false,
        error: (payResult as Failure).error.toString(),
      );
      return;
    }

    state = state.copyWith(
      loading: false,
      pay: payResult.isSuccess ? payResult.getOrThrow() : state.pay,
      payslips: slipsResult.isSuccess ? slipsResult.getOrThrow() : state.payslips,
      error: payResult.isFailure
          ? (payResult as Failure).error.toString()
          : slipsResult.isFailure
              ? (slipsResult as Failure).error.toString()
              : null,
      clearError: payResult.isSuccess && slipsResult.isSuccess,
    );
  }

  Future<Result<Uint8List>> downloadPayslipPdf(int id) async {
    state = state.copyWith(downloadingId: id, clearError: true);
    final result = await _api.myPayslipPdf(id);
    state = state.copyWith(clearDownloading: true);
    if (result.isFailure) {
      state = state.copyWith(
        error: (result as Failure).error.toString(),
      );
    }
    return result;
  }

  void reset() {
    state = const PayrollState();
  }
}

final payrollProvider =
    StateNotifierProvider<PayrollController, PayrollState>(
      (ref) => PayrollController(ref.watch(payrollApiProvider)),
    );
