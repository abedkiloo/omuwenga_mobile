import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../design_system/design_system.dart';
import '../application/sales_history_controllers.dart';
import '../domain/payment_status.dart';
import '../domain/sale.dart';

class SalesHistoryPage extends ConsumerStatefulWidget {
  const SalesHistoryPage({super.key});

  @override
  ConsumerState<SalesHistoryPage> createState() => _SalesHistoryPageState();
}

class _SalesHistoryPageState extends ConsumerState<SalesHistoryPage> {
  final _search = TextEditingController();
  bool _chromeCollapsed = false;

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

  bool _onListScroll(ScrollNotification notification) {
    return handleChromeScrollCollapse(
      notification: notification,
      collapsed: _chromeCollapsed,
      setCollapsed: (value) {
        if (_chromeCollapsed == value) return;
        setState(() => _chromeCollapsed = value);
      },
    );
  }

  Future<void> _pickDate({required bool from}) async {
    final filters = ref.read(salesHistoryProvider).filters;
    final initial =
        parseApiDate(from ? filters.dateFrom : filters.dateTo) ??
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

  Future<void> _setRange(int daysBack) async {
    final today = DateTime.now();
    final from = today.subtract(Duration(days: daysBack));
    final filters = ref
        .read(salesHistoryProvider)
        .filters
        .copyWith(dateFrom: formatApiDate(from), dateTo: formatApiDate(today));
    await ref.read(salesHistoryProvider.notifier).load(filters: filters);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(salesHistoryProvider);
    final filters = state.filters;

    final gross = state.items.fold<double>(0, (sum, sale) => sum + sale.total);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        top: false,
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            CbCollapsibleChrome(
              collapsed: _chromeCollapsed,
              onToggle: () =>
                  setState(() => _chromeCollapsed = !_chromeCollapsed),
              collapsedLabel: 'Sales filters & summary',
              collapsedSummary: state.items.isEmpty
                  ? null
                  : '${state.items.length} sales · ${_money(gross)}',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Padding(
                    padding: EdgeInsets.fromLTRB(12, 6, 12, 0),
                    child: _HistoryHeader(),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                    child: _RangeSelector(
                      filters: filters,
                      onToday: () => _setRange(0),
                      onYesterday: () => _setRange(1),
                      onWeek: () => _setRange(7),
                      onFrom: () => _pickDate(from: true),
                      onTo: () => _pickDate(from: false),
                    ),
                  ),
                  if (state.items.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                      child: _ShiftSummary(items: state.items),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 6, 12, 0),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      key: const Key('sales_search'),
                      controller: _search,
                      textInputAction: TextInputAction.search,
                      decoration: const InputDecoration(
                        hintText: 'Search receipt #, customer, till…',
                        isDense: true,
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.search),
                      ),
                      onSubmitted: (q) => ref
                          .read(salesHistoryProvider.notifier)
                          .load(filters: filters.copyWith(search: q)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filledTonal(
                    key: const Key('sales_scan'),
                    tooltip: 'Scan receipt',
                    onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Receipt scanner is not available yet.'),
                      ),
                    ),
                    icon: const Icon(Icons.qr_code_scanner),
                  ),
                ],
              ),
            ),
            SizedBox(
              height: 44,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(12, 6, 12, 0),
                children: [
                  for (final method in const ['', 'mpesa', 'cash'])
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: CbFilterChip(
                        key: Key(
                          'sales_method_${method.isEmpty ? 'all' : method}',
                        ),
                        label: method.isEmpty
                            ? 'All (${state.items.length})'
                            : method == 'mpesa'
                            ? 'M-Pesa'
                            : 'Cash',
                        selected: filters.paymentMethod == method,
                        compact: true,
                        onTap: () => ref
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
            Expanded(
              child: NotificationListener<ScrollNotification>(
                onNotification: _onListScroll,
                child: _body(state),
              ),
            ),
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
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      itemCount: state.items.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, i) {
        final sale = state.items[i];
        return _SaleHistoryCard(
          key: Key('sale_row_${sale.id}'),
          sale: sale,
          onTap: () => context.push(AppRoutes.saleDetail(sale.id)),
        );
      },
    );
  }
}

class _HistoryHeader extends StatelessWidget {
  const _HistoryHeader();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(Icons.receipt_long_outlined, color: AppColors.primary),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Sales History & Search',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
              Text(
                'Receipts, payments and audit trail',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.mutedForeground,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _RangeSelector extends StatelessWidget {
  const _RangeSelector({
    required this.filters,
    required this.onToday,
    required this.onYesterday,
    required this.onWeek,
    required this.onFrom,
    required this.onTo,
  });

  final SalesHistoryFilters filters;
  final VoidCallback onToday;
  final VoidCallback onYesterday;
  final VoidCallback onWeek;
  final VoidCallback onFrom;
  final VoidCallback onTo;

  _DatePreset get _preset {
    final today = formatApiDate(DateTime.now());
    final yesterday = formatApiDate(
      DateTime.now().subtract(const Duration(days: 1)),
    );
    final weekFrom = formatApiDate(
      DateTime.now().subtract(const Duration(days: 7)),
    );
    final from = filters.dateFrom;
    final to = filters.dateTo;
    if (from == today && to == today) return _DatePreset.today;
    if (from == yesterday && to == today) return _DatePreset.yesterday;
    if (from == weekFrom && to == today) return _DatePreset.week;
    return _DatePreset.custom;
  }

  String _friendlyDate(String? raw, String empty) {
    final d = parseApiDate(raw);
    if (d == null) return empty;
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${d.day} ${months[d.month - 1]}';
  }

  @override
  Widget build(BuildContext context) {
    final preset = _preset;
    final theme = Theme.of(context);

    return CbSurfaceCard(
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Period',
            style: theme.textTheme.labelSmall?.copyWith(
              color: AppColors.mutedForeground,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: CbFilterChip(
                  key: const Key('sales_range_today'),
                  label: 'Today',
                  selected: preset == _DatePreset.today,
                  expand: true,
                  onTap: onToday,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: CbFilterChip(
                  key: const Key('sales_range_yesterday'),
                  label: 'Yesterday',
                  selected: preset == _DatePreset.yesterday,
                  expand: true,
                  onTap: onYesterday,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: CbFilterChip(
                  key: const Key('sales_range_week'),
                  label: '7 days',
                  selected: preset == _DatePreset.week,
                  expand: true,
                  onTap: onWeek,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Custom range',
            style: theme.textTheme.labelSmall?.copyWith(
              color: AppColors.mutedForeground,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: CbFilterChip(
                  key: const Key('sales_filter_from'),
                  label: _friendlyDate(filters.dateFrom, 'From'),
                  selected: preset == _DatePreset.custom &&
                      (filters.dateFrom?.isNotEmpty ?? false),
                  leading: const Icon(Icons.calendar_today_outlined),
                  expand: true,
                  onTap: onFrom,
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Text(
                  '→',
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: AppColors.mutedForeground,
                  ),
                ),
              ),
              Expanded(
                child: CbFilterChip(
                  key: const Key('sales_filter_to'),
                  label: _friendlyDate(filters.dateTo, 'To'),
                  selected: preset == _DatePreset.custom &&
                      (filters.dateTo?.isNotEmpty ?? false),
                  leading: const Icon(Icons.event_outlined),
                  expand: true,
                  onTap: onTo,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

enum _DatePreset { today, yesterday, week, custom }


class _ShiftSummary extends StatelessWidget {
  const _ShiftSummary({required this.items});
  final List<SaleSummary> items;

  @override
  Widget build(BuildContext context) {
    final gross = items.fold<double>(0, (sum, sale) => sum + sale.total);
    double tender(String method) => items
        .where((sale) => sale.paymentMethod?.toLowerCase() == method)
        .fold<double>(0, (sum, sale) => sum + sale.amountPaid);

    return CbSurfaceCard(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Total Shift Sales (Gross)',
                  style: TextStyle(color: AppColors.mutedForeground),
                ),
              ),
              CbStatusPill(
                label: '${items.length} TXNS',
                variant: CbStatusPillVariant.info,
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            _money(gross),
            key: const Key('sales_shift_total'),
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _TenderTotal(label: 'M-PESA', value: tender('mpesa')),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _TenderTotal(label: 'Cash', value: tender('cash')),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TenderTotal extends StatelessWidget {
  const _TenderTotal({required this.label, required this.value});
  final String label;
  final double value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.labelSmall),
          Text(
            _money(value),
            maxLines: 1,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _SaleHistoryCard extends StatelessWidget {
  const _SaleHistoryCard({super.key, required this.sale, required this.onTap});

  final SaleSummary sale;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final voided =
        sale.status == 'cancelled' ||
        sale.status == 'voided' ||
        (sale.refundStatus != null && sale.refundStatus != 'none');
    final method = (sale.paymentMethod ?? 'credit').toUpperCase();

    return CbSurfaceCard(
      padding: EdgeInsets.zero,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    voided
                        ? 'Cancelled/Void'
                        : (sale.customerName?.trim().isNotEmpty == true
                              ? sale.customerName!
                              : 'Walk-in Retail'),
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: voided ? AppColors.destructive : null,
                    ),
                  ),
                ),
                Text(
                  _money(sale.total),
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: voided ? AppColors.destructive : AppColors.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Row(
              children: [
                Expanded(
                  child: Text(
                    '#${sale.saleNumber}',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: AppColors.mutedForeground,
                    ),
                  ),
                ),
                Text(
                  _time(sale.occurredAt),
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: AppColors.mutedForeground,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: CbStatusPill(
                    label: voided
                        ? 'VOIDED · ${sale.refundStatus ?? 'Cancelled'}'
                        : '$method · ${paymentStatusLabel(sale.paymentStatus)}',
                    variant: voided
                        ? CbStatusPillVariant.warning
                        : sale.paymentStatus == PaymentStatusDisplay.paid
                        ? CbStatusPillVariant.success
                        : CbStatusPillVariant.warning,
                  ),
                ),
                if (sale.cashierName != null)
                  Text(
                    'Cashier: ${sale.cashierName}',
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                const SizedBox(width: 4),
                const Icon(Icons.chevron_right, size: 18),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

String _money(double value) => 'KES ${value.toStringAsFixed(2)}';

String _time(String? raw) {
  final parsed = DateTime.tryParse(raw ?? '')?.toLocal();
  if (parsed == null) return raw ?? '';
  final hour = parsed.hour % 12 == 0 ? 12 : parsed.hour % 12;
  final minute = parsed.minute.toString().padLeft(2, '0');
  return '$hour:$minute ${parsed.hour >= 12 ? 'PM' : 'AM'}';
}
