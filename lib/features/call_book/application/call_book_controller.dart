import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../data/call_book_api.dart';
import '../domain/call_book.dart';

final callBookApiProvider = Provider<CallBookApi>((ref) {
  return CallBookApi(ref.watch(apiClientProvider));
});

/// Screen state for one day page of the call centre.
class CallBookView {
  const CallBookView({
    this.book,
    this.weekday = 0,
    this.page = 1,
    this.loading = false,
    this.error = '',
    this.booted = false,
  });

  final CallBookPageData? book;
  final int weekday;
  final int page;
  final bool loading;
  final String error;
  final bool booted;

  List<CallBookRow> get rows => visibleCallRows(book?.results ?? const []);

  int get total => book?.count ?? rows.length;

  int get pageCount {
    final pages = (total / kCallBookPageSize).ceil();
    return pages < 1 ? 1 : pages;
  }

  CallBookView copyWith({
    CallBookPageData? book,
    int? weekday,
    int? page,
    bool? loading,
    String? error,
    bool? booted,
  }) {
    return CallBookView(
      book: book ?? this.book,
      weekday: weekday ?? this.weekday,
      page: page ?? this.page,
      loading: loading ?? this.loading,
      error: error ?? this.error,
      booted: booted ?? this.booted,
    );
  }
}

/// Loads the paged day list and moves between days and pages.
class CallBookController extends Notifier<CallBookView> {
  @override
  CallBookView build() => const CallBookView();

  /// Reload the current day and page.
  ///
  /// The first successful load follows today's weekday from the summary.
  /// An empty page after page 1 steps back one page and loads that page.
  ///
  /// Returns when the request finishes. No local writes.
  Future<void> load() async {
    final requestedPage = state.page;
    final requestedDay = state.weekday;
    state = state.copyWith(loading: true, error: '');
    final result = await ref.read(callBookApiProvider).fetch(
          weekday: requestedDay,
          page: requestedPage,
        );
    await result.when(
      success: (book) async {
        var day = requestedDay;
        var booted = state.booted;
        if (!booted) {
          booted = true;
          day = book.summary.isCallDay ? book.summary.weekday.clamp(0, 4) : 0;
        }
        if (book.results.isEmpty && requestedPage > 1) {
          state = state.copyWith(
            book: book,
            loading: false,
            booted: booted,
            weekday: day,
            page: requestedPage - 1,
          );
          await load();
          return;
        }
        state = state.copyWith(
          book: book,
          loading: false,
          error: '',
          booted: booted,
          weekday: day,
          page: requestedPage,
        );
        if (booted && day != requestedDay) {
          state = state.copyWith(weekday: day, page: 1);
          await load();
        }
      },
      failure: (error, _) async {
        state = state.copyWith(loading: false, error: '$error');
      },
    );
  }

  /// Show another weekday from page 1.
  ///
  /// [weekday] is clamped to 0–4.
  ///
  /// Returns when that page has loaded.
  Future<void> setWeekday(int weekday) async {
    state = state.copyWith(weekday: weekday.clamp(0, 4), page: 1, booted: true);
    await load();
  }

  /// Show another page of the same day.
  ///
  /// [page] below 1 becomes 1.
  ///
  /// Returns when that page has loaded.
  Future<void> setPage(int page) async {
    state = state.copyWith(page: page < 1 ? 1 : page, booted: true);
    await load();
  }
}

final callBookControllerProvider =
    NotifierProvider<CallBookController, CallBookView>(CallBookController.new);
