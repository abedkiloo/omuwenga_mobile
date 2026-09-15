import '../data/pos_api.dart';
import '../domain/cart.dart';

/// Loads the product catalog in pages (backend `page` / `page_size`).
class ProductCatalogPaging {
  ProductCatalogPaging({this.pageSize = 10});

  final int pageSize;

  List<CatalogProduct> items = const [];
  String query = '';
  int? categoryId;
  int _page = 0;
  bool hasMore = true;
  bool loading = false;
  bool loadingMore = false;
  String? error;

  bool get isEmpty => items.isEmpty && !loading;

  Future<void> refresh(
    PosApi api, {
    String? search,
    void Function()? onUpdate,
  }) async {
    if (search != null) query = search.trim();
    loading = true;
    loadingMore = false;
    error = null;
    hasMore = true;
    _page = 0;
    onUpdate?.call();

    final result = await api.listProducts(
      search: query,
      page: 1,
      pageSize: pageSize,
      categoryId: categoryId,
    );
    result.when(
      success: (page) {
        items = page.results;
        _page = page.page;
        hasMore = page.hasNext;
        loading = false;
        error = null;
      },
      failure: (e, _) {
        items = const [];
        _page = 0;
        hasMore = false;
        loading = false;
        error = e.toString();
      },
    );
    onUpdate?.call();
  }

  Future<void> setCategory(
    PosApi api, {
    required int? categoryId,
    void Function()? onUpdate,
  }) async {
    this.categoryId = categoryId;
    await refresh(api, onUpdate: onUpdate);
  }

  Future<void> loadMore(PosApi api, {void Function()? onUpdate}) async {
    if (loading || loadingMore || !hasMore) return;
    loadingMore = true;
    error = null;
    onUpdate?.call();

    final nextPage = _page + 1;
    final result = await api.listProducts(
      search: query,
      page: nextPage,
      pageSize: pageSize,
      categoryId: categoryId,
    );
    result.when(
      success: (page) {
        items = [...items, ...page.results];
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
