import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../design_system/chrome/cb_bounded_sheet.dart';
import '../../../design_system/chrome/cb_sticky_action_bar.dart';
import '../../../design_system/chrome/cb_surface_card.dart';
import '../../auth/application/auth_controller.dart';
import '../../pos/application/pos_controllers.dart';
import '../application/customer_list_paging.dart';
import '../application/customers_controllers.dart';
import '../domain/customer.dart';

/// POS deep-link: pick or quick-add a customer onto the cart.
Future<void> showCustomerPickerSheet(BuildContext context, WidgetRef ref) {
  return showCbBoundedSheet<void>(
    context: context,
    heightFactor: 0.92,
    builder: (context) => const CustomerPickerSheet(),
  );
}

class CustomerPickerSheet extends ConsumerStatefulWidget {
  const CustomerPickerSheet({super.key});

  @override
  ConsumerState<CustomerPickerSheet> createState() =>
      _CustomerPickerSheetState();
}

class _CustomerPickerSheetState extends ConsumerState<CustomerPickerSheet> {
  final _search = TextEditingController();
  final _scroll = ScrollController();
  final _paging = CustomerListPaging();
  Timer? _searchDebounce;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _reload();
    });
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _scroll.dispose();
    _search.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scroll.hasClients) return;
    if (shouldFetchMoreCustomers(
      hasMore: _paging.hasMore,
      loading: _paging.loading,
      loadingMore: _paging.loadingMore,
      extentAfter: _scroll.position.extentAfter,
      maxScrollExtent: _scroll.position.maxScrollExtent,
    )) {
      _loadMore();
    }
  }

  void _fillIfNeeded() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scroll.hasClients) return;
      if (shouldFetchMoreCustomers(
        hasMore: _paging.hasMore,
        loading: _paging.loading,
        loadingMore: _paging.loadingMore,
        extentAfter: _scroll.position.extentAfter,
        maxScrollExtent: _scroll.position.maxScrollExtent,
      )) {
        _loadMore();
      }
    });
  }

  Future<void> _reload([String? q]) async {
    await _paging.refresh(
      ref.read(customersApiProvider),
      search: q ?? _search.text,
      onUpdate: () {
        if (mounted) setState(() {});
      },
    );
    _fillIfNeeded();
  }

  Future<void> _loadMore() async {
    await _paging.loadMore(
      ref.read(customersApiProvider),
      onUpdate: () {
        if (mounted) setState(() {});
      },
    );
    _fillIfNeeded();
  }

  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 350), () {
      _reload(value);
    });
  }

  void _select(CustomerSummary c) {
    _searchDebounce?.cancel();
    ref
        .read(cartControllerProvider.notifier)
        .attachCustomer(id: c.id, name: c.name);
    Navigator.pop(context);
  }

  Future<void> _quickCreate() async {
    _searchDebounce?.cancel();
    final name = _search.text.trim();
    if (name.isEmpty) {
      Navigator.pop(context);
      context.push('${AppRoutes.customerNew}?returnTo=pos');
      return;
    }
    setState(() => _paging.loading = true);
    final result = await ref
        .read(customersApiProvider)
        .create(CustomerDraft(name: name));
    if (!mounted) return;
    result.when(
      success: (c) {
        ref
            .read(cartControllerProvider.notifier)
            .attachCustomer(id: c.id, name: c.name);
        Navigator.pop(context);
      },
      failure: (e, _) {
        setState(() {
          _paging.loading = false;
          _paging.error = e.toString();
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final auth = ref.watch(authControllerProvider);
    final settings = ref
        .watch(customersSettingsProvider)
        .maybeWhen(
          data: (s) => s,
          orElse: () => const CustomersModuleSettings(),
        );
    final canCreate =
        (auth.session?.permissions.canCreateCustomers ?? false) &&
        settings.enableCustomerCreate &&
        settings.allowQuickAddAtPos;
    final items = _paging.items;
    final query = _search.text.trim();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Select duka', style: theme.textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(
            'Search existing dukas or register a new one.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppColors.mutedForeground,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            key: const Key('pos_customer_search'),
            controller: _search,
            textInputAction: TextInputAction.search,
            decoration: const InputDecoration(
              labelText: 'Search name, phone, or code',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.search),
              isDense: true,
            ),
            onChanged: (v) {
              setState(() {});
              _onSearchChanged(v);
            },
            onSubmitted: _reload,
          ),
          if (_paging.loading) const LinearProgressIndicator(minHeight: 2),
          if (_paging.error != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                _paging.error!,
                style: const TextStyle(color: AppColors.destructive),
              ),
            ),
          const SizedBox(height: 8),
          Expanded(
            child: items.isEmpty && !_paging.loading
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.storefront_outlined,
                            size: 36,
                            color: AppColors.mutedForeground.withValues(
                              alpha: 0.7,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            query.isEmpty
                                ? 'No dukas yet'
                                : 'No match for “$query”',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.titleSmall,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            canCreate
                                ? 'Register a duka below to attach to this sale.'
                                : 'Try a different name or phone.',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: AppColors.mutedForeground,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.builder(
                    controller: _scroll,
                    itemCount: items.length + (_paging.hasMore ? 1 : 0),
                    itemBuilder: (context, i) {
                      if (i >= items.length) {
                        if (!_paging.loadingMore &&
                            _paging.hasMore &&
                            _paging.error == null) {
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            if (mounted) _loadMore();
                          });
                        }
                        return const Padding(
                          padding: EdgeInsets.symmetric(vertical: 16),
                          child: Center(
                            child: SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          ),
                        );
                      }
                      final c = items[i];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: CbSurfaceCard(
                          padding: EdgeInsets.zero,
                          onTap: () => _select(c),
                          child: ListTile(
                            key: Key('pos_pick_customer_${c.id}'),
                            leading: const Icon(
                              Icons.storefront_outlined,
                              color: AppColors.primary,
                            ),
                            title: Text(
                              c.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: c.phone == null || c.phone!.isEmpty
                                ? null
                                : Text(c.phone!),
                            trailing: const Icon(
                              Icons.chevron_right,
                              color: AppColors.mutedForeground,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
          if (canCreate)
            CbStickyActionBar(
              safeArea: false,
              primaryKey: const Key('pos_customer_create'),
              primaryLabel: query.isEmpty
                  ? 'Register duka'
                  : (query.length > 22
                        ? 'Register “${query.substring(0, 20)}…”'
                        : 'Register “$query”'),
              onPrimary: _paging.loading ? null : _quickCreate,
            ),
        ],
      ),
    );
  }
}
