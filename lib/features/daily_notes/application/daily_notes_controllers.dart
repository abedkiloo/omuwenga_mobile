import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/result/result.dart';
import '../data/daily_notes_api.dart';
import '../domain/daily_note.dart';

final dailyNotesApiProvider = Provider<DailyNotesApi>((ref) {
  return DailyNotesApi(ref.watch(apiClientProvider));
});

class DailyNotesState {
  const DailyNotesState({
    this.date = '',
    this.notes = const [],
    this.tasks = const [],
    this.staff = const [],
    this.loading = false,
    this.acting = false,
    this.error,
  });

  final String date;
  final List<DailyNote> notes;
  final List<DailyTaskItem> tasks;
  final List<DailyStaffOption> staff;
  final bool loading;
  final bool acting;
  final String? error;

  DailyNotesState copyWith({
    String? date,
    List<DailyNote>? notes,
    List<DailyTaskItem>? tasks,
    List<DailyStaffOption>? staff,
    bool? loading,
    bool? acting,
    String? error,
    bool clearError = false,
  }) {
    return DailyNotesState(
      date: date ?? this.date,
      notes: notes ?? this.notes,
      tasks: tasks ?? this.tasks,
      staff: staff ?? this.staff,
      loading: loading ?? this.loading,
      acting: acting ?? this.acting,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class DailyNotesController extends StateNotifier<DailyNotesState> {
  DailyNotesController(this._api) : super(DailyNotesState(date: todayIsoDate()));

  final DailyNotesApi _api;

  Future<void> load({String? date, bool loadStaff = false}) async {
    final day = date ?? state.date;
    state = state.copyWith(loading: true, date: day, clearError: true);
    final notes = await _api.listNotes(noteDate: day);
    final tasks = await _api.listTasks(taskDate: day);
    if (notes.isFailure) {
      state = state.copyWith(
        loading: false,
        error: (notes as Failure).error.toString(),
      );
      return;
    }
    var staff = state.staff;
    if (loadStaff) {
      final staffResult = await _api.staff();
      if (staffResult.isSuccess) staff = staffResult.getOrThrow();
    }
    state = state.copyWith(
      notes: notes.getOrThrow(),
      tasks: tasks.isSuccess ? tasks.getOrThrow() : const [],
      staff: staff,
      loading: false,
      error: tasks.isFailure ? (tasks as Failure).error.toString() : null,
      clearError: tasks.isSuccess,
    );
  }

  Future<bool> createNote({
    required String content,
    String title = '',
    bool isSticky = false,
    int? assignedTo,
  }) async {
    if (content.trim().isEmpty) {
      state = state.copyWith(error: 'Write the note before saving');
      return false;
    }
    state = state.copyWith(acting: true, clearError: true);
    final result = await _api.createNote(
      createNotePayload(
        noteDate: state.date,
        content: content,
        title: title,
        isSticky: isSticky,
        assignedTo: assignedTo,
      ),
    );
    if (result.isFailure) {
      state = state.copyWith(
        acting: false,
        error: (result as Failure).error.toString(),
      );
      return false;
    }
    state = state.copyWith(acting: false);
    await load();
    return true;
  }

  Future<bool> toggleNote(int id) async {
    state = state.copyWith(acting: true, clearError: true);
    final result = await _api.toggleNote(id);
    if (result.isFailure) {
      state = state.copyWith(
        acting: false,
        error: (result as Failure).error.toString(),
      );
      return false;
    }
    final updated = result.getOrThrow();
    state = state.copyWith(
      acting: false,
      notes: [
        for (final n in state.notes)
          if (n.id == id) updated else n,
      ],
    );
    return true;
  }

  Future<bool> toggleTask(int id) async {
    state = state.copyWith(acting: true, clearError: true);
    final result = await _api.toggleTask(id);
    if (result.isFailure) {
      state = state.copyWith(
        acting: false,
        error: (result as Failure).error.toString(),
      );
      return false;
    }
    final updated = result.getOrThrow();
    state = state.copyWith(
      acting: false,
      tasks: [
        for (final t in state.tasks)
          if (t.id == id) updated else t,
      ],
    );
    return true;
  }
}

final dailyNotesProvider =
    StateNotifierProvider.autoDispose<DailyNotesController, DailyNotesState>(
      (ref) => DailyNotesController(ref.watch(dailyNotesApiProvider)),
    );

class StickyNotesGateState {
  const StickyNotesGateState({
    this.notes = const [],
    this.loading = false,
    this.acting = false,
    this.error,
  });

  final List<DailyNote> notes;
  final bool loading;
  final bool acting;
  final String? error;

  bool get isBlocking => hasBlockingStickyNotes(notes);

  StickyNotesGateState copyWith({
    List<DailyNote>? notes,
    bool? loading,
    bool? acting,
    String? error,
    bool clearError = false,
  }) {
    return StickyNotesGateState(
      notes: notes ?? this.notes,
      loading: loading ?? this.loading,
      acting: acting ?? this.acting,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class StickyNotesGateController extends StateNotifier<StickyNotesGateState> {
  StickyNotesGateController(this._api) : super(const StickyNotesGateState());

  final DailyNotesApi _api;

  Future<void> load() async {
    state = state.copyWith(loading: true, clearError: true);
    final result = await _api.blocking();
    if (result.isFailure) {
      state = state.copyWith(
        loading: false,
        notes: const [],
        error: (result as Failure).error.toString(),
      );
      return;
    }
    state = state.copyWith(
      loading: false,
      notes: result.getOrThrow(),
      clearError: true,
    );
  }

  Future<bool> tick(int id) async {
    state = state.copyWith(acting: true, clearError: true);
    final result = await _api.toggleNote(id);
    if (result.isFailure) {
      state = state.copyWith(
        acting: false,
        error: (result as Failure).error.toString(),
      );
      return false;
    }
    final updated = result.getOrThrow();
    state = state.copyWith(
      acting: false,
      notes: [
        for (final n in state.notes)
          if (n.id == id) updated else n,
      ].where((n) => n.isSticky && !n.isDone).toList(),
    );
    return true;
  }
}

final stickyNotesGateProvider =
    StateNotifierProvider<StickyNotesGateController, StickyNotesGateState>(
      (ref) => StickyNotesGateController(ref.watch(dailyNotesApiProvider)),
    );
