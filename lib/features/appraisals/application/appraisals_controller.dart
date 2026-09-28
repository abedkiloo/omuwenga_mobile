import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/result/result.dart';
import '../../daily_notes/application/daily_notes_controllers.dart';
import '../data/appraisals_api.dart';
import '../domain/appraisal.dart';

final appraisalsApiProvider = Provider<AppraisalsApi>((ref) {
  return AppraisalsApi(ref.watch(apiClientProvider));
});

class AppraisalsState {
  const AppraisalsState({
    this.snapshot,
    this.loading = false,
    this.dismissedDate,
    this.error,
  });

  final AppraisalSnapshot? snapshot;
  final bool loading;
  final String? dismissedDate;
  final String? error;

  bool get shouldGreet {
    final snap = snapshot;
    if (snap == null || loading) return false;
    if (!snap.greetWhenNoStickyNotes) return false;
    if (dismissedDate != null && dismissedDate == snap.todayDate) return false;
    return true;
  }

  AppraisalsState copyWith({
    AppraisalSnapshot? snapshot,
    bool? loading,
    String? dismissedDate,
    String? error,
    bool clearError = false,
  }) {
    return AppraisalsState(
      snapshot: snapshot ?? this.snapshot,
      loading: loading ?? this.loading,
      dismissedDate: dismissedDate ?? this.dismissedDate,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class AppraisalsController extends StateNotifier<AppraisalsState> {
  AppraisalsController(this._api) : super(const AppraisalsState());

  final AppraisalsApi _api;

  Future<void> load() async {
    state = state.copyWith(loading: true, clearError: true);
    final result = await _api.me();
    if (result.isFailure) {
      state = state.copyWith(
        loading: false,
        snapshot: null,
        error: (result as Failure).error.toString(),
      );
      return;
    }
    state = state.copyWith(
      loading: false,
      snapshot: result.getOrThrow(),
      clearError: true,
    );
  }

  void dismissGreeting() {
    state = state.copyWith(dismissedDate: state.snapshot?.todayDate ?? '');
  }

  void reset() {
    state = const AppraisalsState();
  }
}

final appraisalsProvider =
    StateNotifierProvider<AppraisalsController, AppraisalsState>(
      (ref) => AppraisalsController(ref.watch(appraisalsApiProvider)),
    );

bool appraisalGreetingVisible(AppraisalsState appraisals, StickyNotesGateState notes) {
  if (notes.loading || notes.shouldShow) return false;
  return appraisals.shouldGreet;
}
