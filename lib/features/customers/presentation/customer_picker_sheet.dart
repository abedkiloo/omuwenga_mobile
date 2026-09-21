import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../design_system/states/async_states.dart';
import '../../auth/application/auth_controller.dart';
import '../../pos/application/pos_controllers.dart';
import '../application/customer_list_paging.dart';
import '../application/customers_controllers.dart';
import '../domain/customer.dart';

/// POS deep-link: pick or quick-add a customer onto the cart.
Future<void> showCustomerPickerSheet(BuildContext context, WidgetRef ref) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
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
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    final items = _paging.items;

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, 16 + bottom),
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.65,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Select customer',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            TextField(
              key: const Key('pos_customer_search'),
              controller: _search,
              decoration: const InputDecoration(
                labelText: 'Search name, phone, or code',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: _onSearchChanged,
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
            Expanded(
              child: items.isEmpty && !_paging.loading
                  ? Center(
                      child: Text(
                        'No customers found',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.mutedForeground,
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
                        return ListTile(
                          key: Key('pos_pick_customer_${c.id}'),
                          leading: const Icon(Icons.storefront_outlined),
                          title: Text(c.name),
                          subtitle: c.phone == null || c.phone!.isEmpty
                              ? null
                              : Text(c.phone!),
                          onTap: () => _select(c),
                        );
                      },
                    ),
            ),
            if (canCreate)
              CbPrimaryButton(
                key: const Key('pos_customer_create'),
                label: _search.text.trim().isEmpty
                    ? 'Register new customer'
                    : 'Register “${_search.text.trim()}”',
                onPressed: _paging.loading ? null : _quickCreate,
              ),
          ],
        ),
      ),
    );
  }
}
