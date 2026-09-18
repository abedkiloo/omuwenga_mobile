import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../design_system/design_system.dart';
import '../../auth/application/auth_controller.dart';
import '../application/customers_controllers.dart';
import '../application/debt_management_controller.dart';
import '../domain/customer.dart';
import '../domain/debt_management.dart';

String _kes(num value) => 'KES ${value.toStringAsFixed(2)}';

const _agingBuckets = <(String key, String label)>[
  ('0_7', '0–7 days'),
  ('8_30', '8–30 days'),
  ('31_60', '31–60 days'),
  ('60_plus', '60+ days'),
];

class DebtManagementPage extends ConsumerStatefulWidget {
  const DebtManagementPage({super.key});

  @override
  ConsumerState<DebtManagementPage> createState() => _DebtManagementPageState();
}

class _DebtManagementPageState extends ConsumerState<DebtManagementPage> {
  final _search = TextEditingController();
  bool _chromeCollapsed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(debtManagementControllerProvider.notifier).load();
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

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(debtManagementControllerProvider);
    final auth = ref.watch(authControllerProvider);
    final settings = ref
        .watch(customersSettingsProvider)
        .maybeWhen(
          data: (s) => s,
          orElse: () => const CustomersModuleSettings(),
        );
    final canCollect =
        (auth.session?.permissions.canUpdateDebtManagement ?? false) &&
        settings.canSettleDebt(hasUpdatePermission: true);

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
              collapsedLabel: 'Debtors',
              collapsedSummary: state.summary == null
                  ? null
                  : '${state.summary!.customersWithDebt} · ${_kes(state.summary!.totalDebt)}',
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 6, 12, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Debtors',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Collect payments from customers who owe money.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.mutedForeground,
                      ),
                    ),
                    const SizedBox(height: 10),
                    if (state.summary != null)
                      _SummaryStrip(summary: state.summary!),
                    if (state.summary != null) ...[
                      const SizedBox(height: 8),
                      _AgingChips(
                        summary: state.summary!,
                        selected: state.agingBucket,
                        onSelect: (key) {
                          final next = state.agingBucket == key ? '' : key;
                          ref
                              .read(debtManagementControllerProvider.notifier)
                              .setAgingBucket(next);
                        },
                      ),
                    ],
                    const SizedBox(height: 8),
                    CbSearchField(
                      controller: _search,
                      hintText: 'Name, phone, or code…',
                      fieldKey: const Key('debt_search'),
                      searchButtonKey: const Key('debt_search_go'),
                      onSubmitted: (q) => ref
                          .read(debtManagementControllerProvider.notifier)
                          .setSearch(q),
                      onSearchTap: () => ref
                          .read(debtManagementControllerProvider.notifier)
                          .setSearch(_search.text),
                    ),
                    const SizedBox(height: 6),
                  ],
                ),
              ),
            ),
            Expanded(
              child: NotificationListener<ScrollNotification>(
                onNotification: _onListScroll,
                child: RefreshIndicator(
                  onRefresh: () =>
                      ref.read(debtManagementControllerProvider.notifier).load(),
                  child: _body(state: state, canCollect: canCollect),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _body({
    required DebtManagementState state,
    required bool canCollect,
  }) {
    if (state.loading && state.debtors.isEmpty && state.summary == null) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: const [
          SizedBox(height: 80),
          LoadingState(label: 'Loading debtors…'),
        ],
      );
    }
    if (state.error != null && state.debtors.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(
            height: 280,
            child: ErrorState(
              message: state.error!,
              onRetry: () =>
                  ref.read(debtManagementControllerProvider.notifier).load(),
            ),
          ),
        ],
      );
    }
    if (state.debtors.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(
            height: 280,
            child: EmptyState(
              title: 'No customers with debt',
              message: state.search.isNotEmpty || state.agingBucket.isNotEmpty
                  ? 'Try clearing search or age filters.'
                  : 'When sales are put on account, debtors will appear here.',
              primaryLabel: 'Refresh',
              onPrimary: () =>
                  ref.read(debtManagementControllerProvider.notifier).load(),
            ),
          ),
        ],
      );
    }

    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 12),
      itemCount: state.debtors.length,
      itemBuilder: (context, i) {
        final row = state.debtors[i];
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: _DebtorCard(
            key: Key('debtor_row_${row.id}'),
            row: row,
            canCollect: canCollect,
            onCollect: () => context.push(AppRoutes.customerSettle(row.id)),
            onOpen: () => context.push(AppRoutes.customerDetail(row.id)),
          ),
        );
      },
    );
  }
}

class _SummaryStrip extends StatelessWidget {
  const _SummaryStrip({required this.summary});

  final DebtSummary summary;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _StatTile(
            key: const Key('debt_stat_count'),
            label: 'Debtors',
            value: '${summary.customersWithDebt}',
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _StatTile(
            key: const Key('debt_stat_total'),
            label: 'Outstanding',
            value: _kes(summary.totalDebt),
            valueColor: summary.totalDebt > 0 ? AppColors.destructive : null,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _StatTile(
            key: const Key('debt_stat_collected'),
            label: 'Collected today',
            value: _kes(summary.collectedToday),
            valueColor: summary.collectedToday > 0 ? AppColors.success : null,
          ),
        ),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    super.key,
    required this.label,
    required this.value,
    this.valueColor,
  });

  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return CbSurfaceCard(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: AppColors.mutedForeground,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: valueColor,
            ),
          ),
        ],
      ),
    );
  }
}

class _AgingChips extends StatelessWidget {
  const _AgingChips({
    required this.summary,
    required this.selected,
    required this.onSelect,
  });

  final DebtSummary summary;
  final String selected;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Debt age',
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: AppColors.mutedForeground,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.3,
          ),
        ),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final (key, label) in _agingBuckets) ...[
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: CbFilterChip(
                    key: Key('debt_aging_$key'),
                    label: '$label · ${summary.aging[key]?.count ?? 0}',
                    selected: selected == key,
                    compact: true,
                    onTap: () => onSelect(key),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _DebtorCard extends StatelessWidget {
  const _DebtorCard({
    super.key,
    required this.row,
    required this.canCollect,
    required this.onCollect,
    required this.onOpen,
  });

  final DebtorRow row;
  final bool canCollect;
  final VoidCallback onCollect;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final subtitle = [
      if (row.phone.isNotEmpty) row.phone,
      if (row.customerCode.isNotEmpty) row.customerCode,
    ].join(' · ');

    return CbSurfaceCard(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      row.name,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (subtitle.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.mutedForeground,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Text(
                key: Key('debtor_amount_${row.id}'),
                _kes(row.debtAmount),
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: AppColors.destructive,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              CbStatusPill(
                label: '${row.debtAgeDays}d · ${row.agingLabel}',
                variant: CbStatusPillVariant.warning,
              ),
              const Spacer(),
              TextButton(
                key: Key('debtor_history_${row.id}'),
                onPressed: onOpen,
                child: const Text('History'),
              ),
              if (canCollect) ...[
                const SizedBox(width: 4),
                SizedBox(
                  height: 36,
                  child: FilledButton(
                    key: Key('debtor_collect_${row.id}'),
                    onPressed: onCollect,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.brandGreen,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text(
                      'Collect',
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
