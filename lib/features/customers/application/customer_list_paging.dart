import '../data/customers_api.dart';
import '../domain/customer.dart';

/// Loads the customer directory in pages (backend `page` / `page_size`).
class CustomerListPaging {
  CustomerListPaging({this.pageSize = 25});

  final int pageSize;

  List<CustomerSummary> items = const [];
  String query = '';
  int count = 0;
  int _page = 0;
  int _generation = 0;
  bool hasMore = true;
  bool loading = false;
  bool loadingMore = false;
  String? error;

  bool get isEmpty => items.isEmpty && !loading;

  Future<void> refresh(
    CustomersApi api, {
    String? search,
    void Function()? onUpdate,
  }) async {
    if (search != null) query = search.trim();
    final gen = ++_generation;
    loading = true;
    loadingMore = false;
    error = null;
    hasMore = true;
    _page = 0;
    onUpdate?.call();

    final result = await api.list(search: query, page: 1, pageSize: pageSize);
    if (gen != _generation) return;
    result.when(
      success: (page) {
        items = page.results;
        count = page.count;
        _page = page.page;
        hasMore = page.hasNext;
        loading = false;
        error = null;
      },
      failure: (e, _) {
        items = const [];
        count = 0;
        _page = 0;
        hasMore = false;
        loading = false;
        error = e.toString();
      },
    );
    onUpdate?.call();
  }

  Future<void> loadMore(CustomersApi api, {void Function()? onUpdate}) async {
    if (loading || loadingMore || !hasMore) return;
    final gen = _generation;
    loadingMore = true;
    error = null;
    onUpdate?.call();

    final nextPage = _page + 1;
    final result = await api.list(
      search: query,
      page: nextPage,
      pageSize: pageSize,
    );
    if (gen != _generation) return;
    result.when(
      success: (page) {
        final seen = {for (final c in items) c.id};
        items = [
          ...items,
          ...page.results.where((c) => !seen.contains(c.id)),
        ];
        count = page.count;
        _page = page.page;
        hasMore = page.hasNext;
        loadingMore = false;
      },
      failure: (e, _) {
        loadingMore = false;
        error = e.toString();
      },
    );
    onUpdate?.call();
  }
}

bool shouldFetchMoreCustomers({
  required bool hasMore,
  required bool loading,
  required bool loadingMore,
  required double extentAfter,
  required double maxScrollExtent,
}) {
  if (loading || loadingMore || !hasMore) return false;
  return maxScrollExtent <= 0 || extentAfter < 240;
}
