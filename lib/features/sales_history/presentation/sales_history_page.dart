import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../design_system/states/async_states.dart';
import '../application/sales_history_controllers.dart';
import '../domain/payment_status.dart';

class SalesHistoryPage extends ConsumerStatefulWidget {
  const SalesHistoryPage({super.key});

  @override
  ConsumerState<SalesHistoryPage> createState() => _SalesHistoryPageState();
}

class _SalesHistoryPageState extends ConsumerState<SalesHistoryPage> {
  final _search = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(salesHistoryProvider.notifier).load();
    });
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _pickDate({required bool from}) async {
    final filters = ref.read(salesHistoryProvider).filters;
    final initial = parseApiDate(from ? filters.dateFrom : filters.dateTo) ??
        DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (picked == null) return;
    final ymd = formatApiDate(picked);
    final next = from
        ? filters.copyWith(dateFrom: ymd)
        : filters.copyWith(dateTo: ymd);
    await ref.read(salesHistoryProvider.notifier).load(filters: next);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(salesHistoryProvider);
    final filters = state.filters;

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Text(
                'Sales history',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                key: const Key('sales_search'),
                controller: _search,
                textInputAction: TextInputAction.search,
                decoration: const InputDecoration(
                  labelText: 'Search sale or customer',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.search),
                ),
                onSubmitted: (q) => ref.read(salesHistoryProvider.notifier).load(
                      filters: filters.copyWith(search: q),
                    ),
              ),
            ),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  ActionChip(
                    key: const Key('sales_filter_from'),
                    label: Text(filters.dateFrom == null
                        ? 'From date'
                        : 'From ${filters.dateFrom}'),
                    onPressed: () => _pickDate(from: true),
                  ),
                  const SizedBox(width: 8),
                  ActionChip(
                    key: const Key('sales_filter_to'),
                    label: Text(filters.dateTo == null
                        ? 'To date'
                        : 'To ${filters.dateTo}'),
                    onPressed: () => _pickDate(from: false),
                  ),
                  const SizedBox(width: 8),
                  for (final method in const ['', 'cash', 'mpesa', 'card'])
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        key: Key('sales_method_${method.isEmpty ? 'all' : method}'),
                        label: Text(method.isEmpty ? 'All methods' : method),
                        selected: filters.paymentMethod == method,
                        onSelected: (_) => ref
                            .read(salesHistoryProvider.notifier)
                            .load(
                              filters: filters.copyWith(paymentMethod: method),
                            ),
                      ),
                    ),
                ],
              ),
            ),
            if (state.loading) const LinearProgressIndicator(minHeight: 2),
            Expanded(child: _body(state)),
          ],
        ),
      ),
    );
  }

  Widget _body(SalesHistoryState state) {
    if (state.loading && state.items.isEmpty) {
      return const LoadingState(label: 'Loading sales…');
    }
    if (state.error != null && state.items.isEmpty) {
      return ErrorState(
        message: state.error!,
        onRetry: () => ref.read(salesHistoryProvider.notifier).load(),
      );
    }
    if (state.items.isEmpty) {
      return EmptyState(
        key: const Key('sales_empty'),
        title: 'No sales',
        message: 'Try a different day or search.',
        primaryLabel: 'Refresh',
        onPrimary: () => ref.read(salesHistoryProvider.notifier).load(),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      itemCount: state.items.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, i) {
        final sale = state.items[i];
        return ListTile(
          key: Key('sale_row_${sale.id}'),
          contentPadding: EdgeInsets.zero,
          title: Text(sale.saleNumber),
          subtitle: Text(
            [
              if (sale.customerName != null && sale.customerName!.isNotEmpty)
                sale.customerName,
              if (sale.occurredAt != null) sale.occurredAt,
              paymentStatusLabel(sale.paymentStatus),
            ].whereType<String>().join(' · '),
          ),
          trailing: Text(
            sale.total.toStringAsFixed(2),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          onTap: () => context.push(AppRoutes.saleDetail(sale.id)),
        );
      },
    );
  }
}
