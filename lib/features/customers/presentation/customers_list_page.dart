import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../design_system/design_system.dart';
import '../../auth/application/auth_controller.dart';
import '../../pos/application/pos_controllers.dart';
import '../application/customers_controllers.dart';
import '../domain/customer.dart';
import '../domain/wallet_debt.dart';

String _kes(num value) => 'KES ${value.toStringAsFixed(2)}';

enum _CustomerFilter { all, debtors, credit, good }

enum _CustomerSort { highestDebt, name }

class CustomersListPage extends ConsumerStatefulWidget {
  const CustomersListPage({super.key});

  @override
  ConsumerState<CustomersListPage> createState() => _CustomersListPageState();
}

class _CustomersListPageState extends ConsumerState<CustomersListPage> {
  final _search = TextEditingController();
  int? _expandedId;
  _CustomerFilter _filter = _CustomerFilter.all;
  _CustomerSort _sort = _CustomerSort.highestDebt;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(customersListProvider.notifier).load();
    });
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<CustomerSummary> _visible(List<CustomerSummary> items) {
    Iterable<CustomerSummary> filtered = items;
    switch (_filter) {
      case _CustomerFilter.all:
        break;
      case _CustomerFilter.debtors:
        filtered = items.where((c) => c.standing == CustomerStanding.debt);
      case _CustomerFilter.credit:
        filtered = items.where((c) => c.standing == CustomerStanding.credit);
      case _CustomerFilter.good:
        filtered = items.where((c) => c.standing == CustomerStanding.good);
    }
    final list = filtered.toList();
    switch (_sort) {
      case _CustomerSort.highestDebt:
        list.sort((a, b) {
          final byDebt = b.debtAmount.compareTo(a.debtAmount);
          if (byDebt != 0) return byDebt;
          return a.name.toLowerCase().compareTo(b.name.toLowerCase());
        });
      case _CustomerSort.name:
        list.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(customersListProvider);
    final auth = ref.watch(authControllerProvider);
    final session = auth.session;
    final settings = ref.watch(customersSettingsProvider).maybeWhen(
          data: (s) => s,
          orElse: () => const CustomersModuleSettings(),
        );
    final canCreate = (session?.permissions.canCreateCustomers ?? false) &&
        settings.enableCustomerCreate;
    final canPos = session?.permissions.canAccessPos ?? false;
    final canVisit = session?.permissions.canPlaceVisitOrders ?? false;
    final userName = session?.user.displayName ?? 'Cashier';
    final roleLabel =
        session?.profile.roleDisplay ?? session?.profile.role ?? 'Cashier';

    final visible = _visible(state.items);
    final debtorCount =
        state.items.where((c) => c.standing == CustomerStanding.debt).length;
    final creditCount =
        state.items.where((c) => c.standing == CustomerStanding.credit).length;
    final goodCount =
        state.items.where((c) => c.standing == CustomerStanding.good).length;
    final totalOutstanding =
        state.items.fold<double>(0, (sum, c) => sum + c.debtAmount);
    final maxDebt = state.items.fold<double>(
      0,
      (max, c) => c.debtAmount > max ? c.debtAmount : max,
    );

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Text(
                'Customer Directory',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: _DirectoryHeaderCard(
                userName: userName,
                roleLabel: roleLabel,
              ),
            ),
            if (state.items.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: _DirectorySummaryCard(
                  totalOutstanding: totalOutstanding,
                  debtorCount: debtorCount,
                  shopCount: state.items.length,
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: CbSearchField(
                fieldKey: const Key('customers_search'),
                controller: _search,
                hintText: 'Search name, contact or tags…',
                onSubmitted: (q) =>
                    ref.read(customersListProvider.notifier).load(search: q),
              ),
            ),
            if (state.items.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: SizedBox(
                  height: 36,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    children: [
                      _FilterChip(
                        label: 'All (${state.items.length})',
                        selected: _filter == _CustomerFilter.all,
                        onTap: () =>
                            setState(() => _filter = _CustomerFilter.all),
                      ),
                      const SizedBox(width: 8),
                      _FilterChip(
                        label: 'All Debtors ($debtorCount)',
                        selected: _filter == _CustomerFilter.debtors,
                        onTap: () =>
                            setState(() => _filter = _CustomerFilter.debtors),
                      ),
                      const SizedBox(width: 8),
                      _FilterChip(
                        label: 'Credit ($creditCount)',
                        selected: _filter == _CustomerFilter.credit,
                        onTap: () =>
                            setState(() => _filter = _CustomerFilter.credit),
                      ),
                      const SizedBox(width: 8),
                      _FilterChip(
                        label: 'Good ($goodCount)',
                        selected: _filter == _CustomerFilter.good,
                        onTap: () =>
                            setState(() => _filter = _CustomerFilter.good),
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                child: Row(
                  children: [
                    Text(
                      'Sort by: ',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.mutedForeground,
                          ),
                    ),
                    DropdownButtonHideUnderline(
                      child: DropdownButton<_CustomerSort>(
                        value: _sort,
                        isDense: true,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w600,
                            ),
                        items: const [
                          DropdownMenuItem(
                            value: _CustomerSort.highestDebt,
                            child: Text('Balance / Highest Debt'),
                          ),
                          DropdownMenuItem(
                            value: _CustomerSort.name,
                            child: Text('Name A–Z'),
                          ),
                        ],
                        onChanged: (v) {
                          if (v != null) setState(() => _sort = v);
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (state.loading) const LinearProgressIndicator(minHeight: 2),
            Expanded(
              child: _buildBody(
                context,
                state: state,
                visible: visible,
                maxDebt: maxDebt,
                canPos: canPos,
                canVisit: canVisit,
                settings: settings,
                auth: auth,
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: canCreate
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: SizedBox(
                  height: 52,
                  child: FilledButton(
                    key: const Key('customers_add'),
                    onPressed: () => context.push(AppRoutes.customerNew),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: AppColors.primaryForeground,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.person_add_alt_1, size: 20),
                        SizedBox(width: 8),
                        Text(
                          'Register New Customer',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                        SizedBox(width: 10),
                        _FastAddBadge(),
                      ],
                    ),
                  ),
                ),
              ),
            )
          : null,
    );
  }

  Widget _buildBody(
    BuildContext context, {
    required CustomersListState state,
    required List<CustomerSummary> visible,
    required double maxDebt,
    required bool canPos,
    required bool canVisit,
    required CustomersModuleSettings settings,
    required AuthState auth,
  }) {
    if (state.loading && state.items.isEmpty) {
      return const LoadingState(label: 'Loading customers…');
    }
    if (state.error != null && state.items.isEmpty) {
      return ErrorState(
        message: state.error!,
        onRetry: () => ref.read(customersListProvider.notifier).load(),
      );
    }
    if (state.items.isEmpty) {
      return EmptyState(
        key: const Key('customers_empty'),
        title: 'No customers',
        message: state.query.isEmpty
            ? 'Add a customer or search by name or phone.'
            : 'No matches for “${state.query}”.',
        primaryLabel: 'Refresh',
        onPrimary: () => ref.read(customersListProvider.notifier).load(),
      );
    }
    if (visible.isEmpty) {
      return EmptyState(
        title: 'No matches',
        message: 'No customers in this filter.',
        primaryLabel: 'Show all',
        onPrimary: () => setState(() => _filter = _CustomerFilter.all),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      itemCount: visible.length,
      itemBuilder: (context, i) {
        final c = visible[i];
        final expanded = _expandedId == c.id;
        final canSettle = canSettleCustomerDebt(
          auth: auth,
          settings: settings,
          debtAmount: c.debtAmount,
        );
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: _CustomerExpandableCard(
            key: Key('customer_row_${c.id}'),
            customer: c,
            expanded: expanded,
            maxDebt: maxDebt,
            canPos: canPos,
            canVisit: canVisit,
            canSettle: canSettle,
            onToggle: () {
              setState(() {
                _expandedId = expanded ? null : c.id;
              });
            },
            onOpenLedger: () =>
                context.push(AppRoutes.customerDetail(c.id)),
            onSettle: () => context.push(AppRoutes.customerSettle(c.id)),
            onStartPos: () {
              ref.read(cartControllerProvider.notifier).attachCustomer(
                    id: c.id,
                    name: c.name,
                  );
              context.go(AppRoutes.pos);
            },
            onVisit: () => context.go(AppRoutes.siteVisit),
            onCall: () async {
              final phone = c.phone?.trim() ?? '';
              if (phone.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('No phone on file')),
                );
                return;
              }
              await Clipboard.setData(ClipboardData(text: phone));
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Copied $phone')),
              );
            },
          ),
        );
      },
    );
  }
}

class _FastAddBadge extends StatelessWidget {
  const _FastAddBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(6),
      ),
      child: const Text(
        'FAST ADD',
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}

class _DirectoryHeaderCard extends StatelessWidget {
  const _DirectoryHeaderCard({
    required this.userName,
    required this.roleLabel,
  });

  final String userName;
  final String roleLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return CbSurfaceCard(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: AppColors.accentSoft,
            child: Text(
              userName.isNotEmpty ? userName[0].toUpperCase() : 'C',
              style: theme.textTheme.titleMedium?.copyWith(
                color: AppColors.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  userName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  roleLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.mutedForeground,
                  ),
                ),
              ],
            ),
          ),
          const CbStatusPill(
            label: 'Online · Synced',
            variant: CbStatusPillVariant.online,
            showOnlineDot: true,
          ),
        ],
      ),
    );
  }
}

class _DirectorySummaryCard extends StatelessWidget {
  const _DirectorySummaryCard({
    required this.totalOutstanding,
    required this.debtorCount,
    required this.shopCount,
  });

  final double totalOutstanding;
  final int debtorCount;
  final int shopCount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return CbSurfaceCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Directory overview',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (debtorCount > 0)
                CbStatusPill(
                  label: '$debtorCount Overdue Accounts',
                  variant: CbStatusPillVariant.info,
                ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _SummaryMetric(
                  label: 'Total Outstanding',
                  value: _kes(totalOutstanding),
                  subtitle: 'Across $shopCount shops',
                ),
              ),
              Expanded(
                child: _SummaryMetric(
                  label: 'Debtors',
                  value: '$debtorCount',
                  subtitle: debtorCount == 1 ? '1 shop owes' : '$debtorCount shops owe',
                  valueColor: debtorCount > 0 ? AppColors.destructive : null,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SummaryMetric extends StatelessWidget {
  const _SummaryMetric({
    required this.label,
    required this.value,
    required this.subtitle,
    this.valueColor,
  });

  final String label;
  final String value;
  final String subtitle;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: AppColors.mutedForeground,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w800,
            color: valueColor,
          ),
        ),
        Text(
          subtitle,
          style: theme.textTheme.bodySmall?.copyWith(
            color: AppColors.mutedForeground,
          ),
        ),
      ],
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.primary : AppColors.surface,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: selected ? AppColors.primary : AppColors.border,
            ),
          ),
          child: Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: selected
                      ? AppColors.primaryForeground
                      : AppColors.foreground,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ),
      ),
    );
  }
}

class _CustomerExpandableCard extends StatelessWidget {
  const _CustomerExpandableCard({
    super.key,
    required this.customer,
    required this.expanded,
    required this.maxDebt,
    required this.canPos,
    required this.canVisit,
    required this.canSettle,
    required this.onToggle,
    required this.onOpenLedger,
    required this.onSettle,
    required this.onStartPos,
    required this.onVisit,
    required this.onCall,
  });

  final CustomerSummary customer;
  final bool expanded;
  final double maxDebt;
  final bool canPos;
  final bool canVisit;
  final bool canSettle;
  final VoidCallback onToggle;
  final VoidCallback onOpenLedger;
  final VoidCallback onSettle;
  final VoidCallback onStartPos;
  final VoidCallback onVisit;
  final VoidCallback onCall;

  Color get _avatarColor {
    const palette = [
      Color(0xFFDC2626),
      Color(0xFF16A34A),
      Color(0xFF2563EB),
      Color(0xFFD97706),
      Color(0xFF7C3AED),
    ];
    return palette[customer.id.abs() % palette.length];
  }

  String get _initials {
    final parts = customer.name
        .trim()
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) {
      return parts.first.substring(0, parts.first.length.clamp(0, 2)).toUpperCase();
    }
    return (parts[0][0] + parts[1][0]).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final debt = customer.debtAmount;
    final credit = customer.walletBalance != null && customer.walletBalance! > 0
        ? customer.walletBalance!
        : 0.0;
    final progress = maxDebt <= 0 ? 0.0 : (debt / maxDebt).clamp(0.0, 1.0);

    return CbSurfaceCard(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: onToggle,
            borderRadius: BorderRadius.circular(8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: _avatarColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    _initials,
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: _avatarColor,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              customer.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          _StandingBadge(customer: customer),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text.rich(
                        TextSpan(
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: AppColors.mutedForeground,
                          ),
                          children: [
                            if (customer.customerCode != null &&
                                customer.customerCode!.isNotEmpty)
                              TextSpan(text: '${customer.customerCode} · '),
                            if (customer.phone != null &&
                                customer.phone!.isNotEmpty)
                              TextSpan(
                                text: customer.phone,
                                style: const TextStyle(
                                  color: Color(0xFF2563EB),
                                  fontWeight: FontWeight.w600,
                                ),
                              )
                            else
                              const TextSpan(text: 'No phone'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  key: Key('customer_open_${customer.id}'),
                  tooltip: 'View ledger',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                  onPressed: onOpenLedger,
                  icon: const Icon(Icons.chevron_right, color: AppColors.primary),
                ),
                Icon(
                  expanded ? Icons.expand_less : Icons.expand_more,
                  color: AppColors.mutedForeground,
                ),
              ],
            ),
          ),
          if (expanded) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    debt > 0 ? 'Outstanding Debt' : 'Account Balance',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: AppColors.mutedForeground,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    debt > 0
                        ? _kes(debt)
                        : credit > 0
                            ? 'Credit ${_kes(credit)}'
                            : _kes(0),
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: debt > 0 ? AppColors.destructive : AppColors.foreground,
                    ),
                  ),
                  if (debt > 0) ...[
                    const SizedBox(height: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 8,
                        backgroundColor: const Color(0xFFE2E8F0),
                        color: progress > 0.75
                            ? AppColors.destructive
                            : AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Relative to highest debt in this directory',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.mutedForeground,
                      ),
                    ),
                  ] else if (credit > 0) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Wallet credit available for future sales',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.mutedForeground,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _IconAction(
                  icon: Icons.phone_outlined,
                  onPressed: onCall,
                ),
                const SizedBox(width: 8),
                if (canVisit)
                  Expanded(
                    child: _OutlineAction(
                      label: 'Field Visit',
                      onPressed: onVisit,
                    ),
                  )
                else if (canPos)
                  Expanded(
                    child: _OutlineAction(
                      label: 'Start POS',
                      onPressed: onStartPos,
                    ),
                  )
                else
                  const Spacer(),
                const SizedBox(width: 8),
                if (canSettle)
                  Expanded(
                    child: _FilledAction(
                      label: 'Settle Debt',
                      color: AppColors.brandGreen,
                      onPressed: onSettle,
                    ),
                  )
                else if (canPos && canVisit)
                  Expanded(
                    child: _FilledAction(
                      label: 'Start POS',
                      color: AppColors.primary,
                      onPressed: onStartPos,
                    ),
                  )
                else
                  Expanded(
                    child: _FilledAction(
                      label: 'View ledger',
                      color: AppColors.primary,
                      onPressed: onOpenLedger,
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _StandingBadge extends StatelessWidget {
  const _StandingBadge({required this.customer});

  final CustomerSummary customer;

  @override
  Widget build(BuildContext context) {
    final label = standingLabel(
      customer.standing,
      debtAmount: customer.debtAmount,
      credit: customer.walletBalance != null && customer.walletBalance! > 0
          ? customer.walletBalance!
          : 0,
    );
    final (bg, fg, border) = switch (customer.standing) {
      CustomerStanding.debt => (
          const Color(0xFFFEE2E2),
          AppColors.destructive,
          AppColors.destructive,
        ),
      CustomerStanding.credit => (
          const Color(0xFFDCFCE7),
          AppColors.success,
          AppColors.success,
        ),
      CustomerStanding.good => (
          AppColors.secondary,
          AppColors.mutedForeground,
          AppColors.border,
        ),
    };
    return Container(
      key: Key('customer_standing_${customer.id}'),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: border.withValues(alpha: 0.45)),
      ),
      child: Text(
        !customer.isActive
            ? 'Inactive'
            : customer.standing == CustomerStanding.good &&
                    customer.debtAmount <= 0
                ? 'Zero Balance'
                : label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: fg,
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}

class _IconAction extends StatelessWidget {
  const _IconAction({required this.icon, required this.onPressed});

  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 44,
      height: 40,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          padding: EdgeInsets.zero,
          foregroundColor: AppColors.primary,
          side: const BorderSide(color: AppColors.primary),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
        child: Icon(icon, size: 18),
      ),
    );
  }
}

class _OutlineAction extends StatelessWidget {
  const _OutlineAction({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          side: const BorderSide(color: AppColors.primary),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
        child: Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
        ),
      ),
    );
  }
}

class _FilledAction extends StatelessWidget {
  const _FilledAction({
    super.key,
    required this.label,
    required this.color,
    required this.onPressed,
  });

  final String label;
  final Color color;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
        child: Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
        ),
      ),
    );
  }
}
