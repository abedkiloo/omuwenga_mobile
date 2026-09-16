import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../design_system/states/async_states.dart';
import '../../auth/application/auth_controller.dart';
import '../../pos/application/pos_controllers.dart';
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
  List<CustomerSummary> _items = const [];
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load([String? q]) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final result = await ref
        .read(customersApiProvider)
        .list(search: q ?? _search.text);
    if (!mounted) return;
    result.when(
      success: (items) => setState(() {
        _items = items;
        _loading = false;
      }),
      failure: (e, _) => setState(() {
        _loading = false;
        _error = e.toString();
        _items = const [];
      }),
    );
  }

  void _select(CustomerSummary c) {
    ref
        .read(cartControllerProvider.notifier)
        .attachCustomer(id: c.id, name: c.name);
    Navigator.pop(context);
  }

  Future<void> _quickCreate() async {
    final name = _search.text.trim();
    if (name.isEmpty) {
      Navigator.pop(context);
      context.push('${AppRoutes.customerNew}?returnTo=pos');
      return;
    }
    setState(() => _loading = true);
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
          _loading = false;
          _error = e.toString();
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

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, 16 + bottom),
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.65,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Add customer',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            TextField(
              key: const Key('pos_customer_search'),
              controller: _search,
              decoration: const InputDecoration(
                labelText: 'Search or type a name',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.search),
              ),
              onSubmitted: _load,
            ),
            if (_loading) const LinearProgressIndicator(minHeight: 2),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  _error!,
                  style: const TextStyle(color: AppColors.destructive),
                ),
              ),
            Expanded(
              child: _items.isEmpty && !_loading
                  ? Center(
                      child: Text(
                        'No customers found',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.mutedForeground,
                        ),
                      ),
                    )
                  : ListView.builder(
                      itemCount: _items.length,
                      itemBuilder: (context, i) {
                        final c = _items[i];
                        return ListTile(
                          key: Key('pos_pick_customer_${c.id}'),
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
                    ? 'Create customer'
                    : 'Create “${_search.text.trim()}”',
                onPressed: _loading ? null : _quickCreate,
              ),
          ],
        ),
      ),
    );
  }
}
