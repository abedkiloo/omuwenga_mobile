import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../design_system/design_system.dart';
import '../../auth/application/auth_controller.dart';
import '../../auth/domain/persona.dart';
import '../../pos/application/pos_controllers.dart';
import '../application/customer_list_paging.dart';
import '../application/customers_controllers.dart';
import '../domain/customer.dart';
import '../domain/customer_intelligence.dart';
import '../domain/wallet_debt.dart';
import '../../../core/format/money.dart';
import 'classification_badges.dart';

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
  bool _chromeCollapsed = false;

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

  bool _onListScroll(ScrollNotification notification) {
    handleChromeScrollCollapse(
      notification: notification,
      collapsed: _chromeCollapsed,
      setCollapsed: (value) {
        if (_chromeCollapsed == value) return;
        setState(() => _chromeCollapsed = value);
      },
    );
    final metrics = notification.metrics;
    final list = ref.read(customersListProvider);
    if (shouldFetchMoreCustomers(
      hasMore: list.hasMore,
      loading: list.loading,
      loadingMore: list.loadingMore,
      extentAfter: metrics.extentAfter,
      maxScrollExtent: metrics.maxScrollExtent,
    )) {
      ref.read(customersListProvider.notifier).loadMore();
    }
    return false;
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
        list.sort(
          (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
        );
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(customersListProvider);
    final auth = ref.watch(authControllerProvider);
    final session = auth.session;
    final settings = ref
        .watch(customersSettingsProvider)
        .maybeWhen(
          data: (s) => s,
          orElse: () => const CustomersModuleSettings(),
        );
    final canCreate =
        (session?.permissions.canCreateCustomers ?? false) &&
        settings.enableCustomerCreate;
    final canPos = session?.permissions.canAccessPos ?? false;
    final canVisit = session?.permissions.canPlaceVisitOrders ?? false;
    final userName = session?.user.displayName ?? 'Cashier';
    final roleLabel =
        session?.profile.roleDisplay ?? session?.profile.role ?? 'Cashier';
    final fieldSalesOnly = session != null &&
        isFieldSalesProfile(session.profile);

    final visible = _visible(state.items);
    final debtorCount = state.items
        .where((c) => c.standing == CustomerStanding.debt)
        .length;
    final creditCount = state.items
        .where((c) => c.standing == CustomerStanding.credit)
        .length;
    final goodCount = state.items
        .where((c) => c.standing == CustomerStanding.good)
        .length;
    final totalOutstanding = state.items.fold<double>(
      0,
      (sum, c) => sum + c.debtAmount,
    );
    final maxDebt = state.items.fold<double>(
      0,
      (max, c) => c.debtAmount > max ? c.debtAmount : max,
    );

    return Scaffold(
      backgroundColor: AppColors.background,
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        top: false,
        bottom: false,
        child: CbChromeListColumn(
          chrome: CbCollapsibleChrome(
            collapsed: _chromeCollapsed,
            onToggle: () =>
                setState(() => _chromeCollapsed = !_chromeCollapsed),
            collapsedLabel: 'Customer directory summary',
            collapsedSummary: state.items.isEmpty
                ? null
                : '${state.count > 0 ? state.count : state.items.length} customers · ${formatKes(totalOutstanding)} outstanding',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                  child: Text(
                    fieldSalesOnly
                        ? 'My customers'
                        : 'Customer Directory',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (fieldSalesOnly)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
                    child: Text(
                      'Only dukas you registered show here.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.mutedForeground,
                      ),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                  child: _DirectoryHeaderCard(
                    userName: userName,
                    roleLabel: roleLabel,
                  ),
                ),
                if (state.items.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                    child: _DirectorySummaryCard(
                      totalOutstanding: totalOutstanding,
                      debtorCount: debtorCount,
                      shopCount: state.items.length,
                    ),
                  ),
              ],
            ),
          ),
          stickyBelow: Padding(
            padding: const EdgeInsets.fromLTRB(12, 6, 12, 0),
            child: CbSearchField(
              fieldKey: const Key('customers_search'),
              controller: _search,
              hintText: 'Search name, contact or tags…',
              onSubmitted: (q) =>
                  ref.read(customersListProvider.notifier).load(search: q),
            ),
          ),
          filters: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: SizedBox(
                        height: 36,
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          children: [
                            for (final tier in EngagementTier.values) ...[
                              if (tier != EngagementTier.values.first)
                                const SizedBox(width: 8),
                              _FilterChip(
                                label: tier.label,
                                selected: state.engagementTier == tier,
                                tooltip: tier.tip,
                                onTap: () => ref
                                    .read(customersListProvider.notifier)
                                    .setEngagementTier(tier),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    if (state.engagementTier != EngagementTier.prospect)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: SizedBox(
                          height: 36,
                          child: ListView(
                            scrollDirection: Axis.horizontal,
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            children: [
                              for (final seg in BuyerSegment.values) ...[
                                if (seg != BuyerSegment.values.first)
                                  const SizedBox(width: 8),
                                _FilterChip(
                                  label: seg.label,
                                  selected: state.buyerSegment == seg,
                                  tooltip: seg.tip,
                                  onTap: () => ref
                                      .read(customersListProvider.notifier)
                                      .setBuyerSegment(seg),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: SizedBox(
                        height: 36,
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          children: [
                            for (final loc in CustomerLocationStatus.values) ...[
                              if (loc != CustomerLocationStatus.values.first)
                                const SizedBox(width: 8),
                              _FilterChip(
                                label: loc.label,
                                selected: state.locationStatus == loc,
                                tooltip: loc == CustomerLocationStatus.valid
                                    ? 'County, sub-county, and ward match our list'
                                    : loc == CustomerLocationStatus.invalid
                                        ? 'Blank or mismatched Kenya admin location'
                                        : 'All location qualities',
                                onTap: () => ref
                                    .read(customersListProvider.notifier)
                                    .setLocationStatus(loc),
                              ),
                            ],
                            if (state.hasLocationFilter) ...[
                              const SizedBox(width: 8),
                              _FilterChip(
                                label: 'Clear location',
                                selected: false,
                                onTap: () => ref
                                    .read(customersListProvider.notifier)
                                    .clearLocationFilters(),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                      child: _LocationLevelFilters(state: state),
                    ),
                    if (state.items.isNotEmpty) ...[
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: SizedBox(
                          height: 36,
                          child: ListView(
                            scrollDirection: Axis.horizontal,
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            children: [
                              _FilterChip(
                                label:
                                    'Standing · All (${state.count > 0 ? state.count : state.items.length})',
                                selected: _filter == _CustomerFilter.all,
                                onTap: () => setState(
                                  () => _filter = _CustomerFilter.all,
                                ),
                              ),
                              const SizedBox(width: 8),
                              _FilterChip(
                                label: 'Debtors ($debtorCount)',
                                selected: _filter == _CustomerFilter.debtors,
                                onTap: () => setState(
                                  () => _filter = _CustomerFilter.debtors,
                                ),
                              ),
                              const SizedBox(width: 8),
                              _FilterChip(
                                label: 'Credit ($creditCount)',
                                selected: _filter == _CustomerFilter.credit,
                                onTap: () => setState(
                                  () => _filter = _CustomerFilter.credit,
                                ),
                              ),
                              const SizedBox(width: 8),
                              _FilterChip(
                                label: 'Good ($goodCount)',
                                selected: _filter == _CustomerFilter.good,
                                onTap: () => setState(
                                  () => _filter = _CustomerFilter.good,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(12, 6, 12, 0),
                        child: Row(
                          children: [
                            Text(
                              'Sort by: ',
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(color: AppColors.mutedForeground),
                            ),
                            Expanded(
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<_CustomerSort>(
                                  value: _sort,
                                  isDense: true,
                                  isExpanded: true,
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(
                                        color: AppColors.primary,
                                        fontWeight: FontWeight.w600,
                                      ),
                                  items: const [
                                    DropdownMenuItem(
                                      value: _CustomerSort.highestDebt,
                                      child: Text(
                                        'Balance / Highest Debt',
                                        overflow: TextOverflow.ellipsis,
                                      ),
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
                            ),
                          ],
                        ),
                      ),
                    ],
                    if (state.loading)
                      const LinearProgressIndicator(minHeight: 2),
                  ],
                ),
          body: NotificationListener<ScrollNotification>(
            onNotification: _onListScroll,
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
        ),
      ),
      bottomNavigationBar: canCreate
          ? CbStickyActionBar(
              safeArea: false,
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
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.person_add_alt_1, size: 20),
                      const SizedBox(width: 8),
                      const Flexible(
                        child: Text(
                          'Register New Customer',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                      const SizedBox(width: 10),
                      const _FastAddBadge(),
                    ],
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
      final tier = state.engagementTier;
      final segment = state.buyerSegment;
      final fieldSalesOnly = auth.session != null &&
          isFieldSalesProfile(auth.session!.profile);
      String title = 'No customers';
      String message = state.query.isEmpty
          ? (fieldSalesOnly
              ? 'Register a duka to start your list — only customers you onboard appear here.'
              : 'Add a customer or search by name or phone.')
          : 'No matches for “${state.query}”.';
      if (state.query.isEmpty && tier == EngagementTier.buyer) {
        if (segment != BuyerSegment.any) {
          title = 'No customers in “${segment.label}”';
          message =
              'Buyers move into this segment based on how recently and how often they purchase.';
        } else {
          title = 'No buyers yet';
          message =
              'Customers who complete a sale from Omuwenga show up here as buyers.';
        }
      } else if (state.query.isEmpty && tier == EngagementTier.prospect) {
        title = 'No registered-only customers';
        message =
            'Everyone here has already bought — switch to All or Bought from Omuwenga.';
      } else if (state.query.isEmpty && state.hasLocationFilter) {
        if (state.locationStatus == CustomerLocationStatus.invalid) {
          title = 'No customers need a location fix';
          message =
              'Everyone${state.county.isNotEmpty ? ' in ${state.county}' : ''} already has a county, sub-county, and ward from our list.';
        } else if (state.locationStatus == CustomerLocationStatus.valid) {
          title =
              'No customers with a fixed location${state.county.isNotEmpty ? ' in ${state.county}' : ''}';
          message =
              'Try another county, sub-county, or ward — or clear Location OK.';
        } else {
          title = state.county.isNotEmpty
              ? 'No customers in ${state.county}'
              : 'No customers for this location';
          message = 'Clear or change the location filters to see more.';
        }
      }
      return EmptyState(
        key: const Key('customers_empty'),
        title: title,
        message: message,
        primaryLabel: state.hasLocationFilter
            ? 'Clear location'
            : tier != EngagementTier.all
                ? 'Show all'
                : 'Refresh',
        onPrimary: () {
          if (state.hasLocationFilter) {
            ref.read(customersListProvider.notifier).clearLocationFilters();
          } else if (tier != EngagementTier.all) {
            ref
                .read(customersListProvider.notifier)
                .setEngagementTier(EngagementTier.all);
          } else {
            ref.read(customersListProvider.notifier).load();
          }
        },
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
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 12),
      itemCount: visible.length + (state.hasMore ? 1 : 0),
      itemBuilder: (context, i) {
        if (i >= visible.length) {
          if (!state.loadingMore && state.hasMore && state.error == null) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) return;
              ref.read(customersListProvider.notifier).loadMore();
            });
          }
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Center(
              child: state.loadingMore
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const SizedBox(height: 20),
            ),
          );
        }
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
                context.push(AppRoutes.customerDetail(c.id, tab: 'ledger')),
            onSettle: () => context.push(AppRoutes.customerSettle(c.id)),
            onStartPos: () {
              ref
                  .read(cartControllerProvider.notifier)
                  .attachCustomer(id: c.id, name: c.name);
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
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(SnackBar(content: Text('Copied $phone')));
            },
          ),
        );
      },
    );
  }
}

class _LocationLevelFilters extends ConsumerWidget {
  const _LocationLevelFilters({required this.state});

  final CustomersListState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unitsAsync = ref.watch(kenyaAdminUnitsProvider);
    return unitsAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
      data: (units) {
        final counties = units.sortedCounties();
        final subs = state.county.isEmpty
            ? const <String>[]
            : units.subCountiesFor(state.county);
        final wards = state.county.isEmpty || state.subCounty.isEmpty
            ? const <String>[]
            : units.wardsFor(state.county, state.subCounty);
        return Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    key: const Key('customers_filter_county'),
                    isDense: true,
                    value: state.county.isEmpty ? '' : state.county,
                    decoration: const InputDecoration(
                      labelText: 'County',
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                    ),
                    items: [
                      const DropdownMenuItem(value: '', child: Text('All')),
                      for (final name in counties)
                        DropdownMenuItem(value: name, child: Text(name)),
                    ],
                    onChanged: (v) => ref
                        .read(customersListProvider.notifier)
                        .setCounty(v ?? ''),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    key: const Key('customers_filter_sub_county'),
                    isDense: true,
                    value: state.subCounty.isEmpty ? '' : state.subCounty,
                    decoration: const InputDecoration(
                      labelText: 'Sub-county',
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                    ),
                    items: [
                      const DropdownMenuItem(value: '', child: Text('All')),
                      for (final name in subs)
                        DropdownMenuItem(value: name, child: Text(name)),
                    ],
                    onChanged: state.county.isEmpty
                        ? null
                        : (v) => ref
                            .read(customersListProvider.notifier)
                            .setSubCounty(v ?? ''),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              key: const Key('customers_filter_ward'),
              isDense: true,
              value: state.ward.isEmpty ? '' : state.ward,
              decoration: const InputDecoration(
                labelText: 'Ward',
                isDense: true,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
              ),
              items: [
                const DropdownMenuItem(value: '', child: Text('All')),
                for (final name in wards)
                  DropdownMenuItem(value: name, child: Text(name)),
              ],
              onChanged: state.county.isEmpty || state.subCounty.isEmpty
                  ? null
                  : (v) =>
                      ref.read(customersListProvider.notifier).setWard(v ?? ''),
            ),
          ],
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
  const _DirectoryHeaderCard({required this.userName, required this.roleLabel});

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
            label: 'Online',
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
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (debtorCount > 0) ...[
                const SizedBox(width: 8),
                Flexible(
                  child: CbStatusPill(
                    label: '$debtorCount Overdue Accounts',
                    variant: CbStatusPillVariant.info,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _SummaryMetric(
                  label: 'Total Outstanding',
                  value: formatKes(totalOutstanding),
                  subtitle: 'Across $shopCount customers',
                ),
              ),
              Expanded(
                child: _SummaryMetric(
                  label: 'Debtors',
                  value: '$debtorCount',
                  subtitle: debtorCount == 1
                      ? '1 customer owes'
                      : '$debtorCount customers owe',
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
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.labelSmall?.copyWith(
            color: AppColors.mutedForeground,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w800,
            color: valueColor,
          ),
        ),
        Text(
          subtitle,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
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
    this.tooltip,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    return CbFilterChip(
      label: label,
      selected: selected,
      compact: true,
      tooltip: tooltip,
      onTap: onTap,
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
      return parts.first
          .substring(0, parts.first.length.clamp(0, 2))
          .toUpperCase();
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
                          Flexible(
                            child: Align(
                              alignment: Alignment.centerRight,
                              child: _StandingBadge(customer: customer),
                            ),
                          ),
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
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      ClassificationBadges(
                        engagementTier: customer.engagementTier,
                        buyerSegment: customer.buyerSegment,
                        purchaseCount: customer.purchaseCount,
                        showPurchaseCount: true,
                      ),
                      if (customer.locationLine.isNotEmpty ||
                          customer.needsLocationFix) ...[
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            const Icon(
                              Icons.location_on_outlined,
                              size: 14,
                              color: AppColors.mutedForeground,
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                customer.locationLine.isNotEmpty
                                    ? customer.locationLine
                                    : '—',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: AppColors.mutedForeground,
                                ),
                              ),
                            ),
                            if (customer.locationIssueLabel.isNotEmpty) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFFF7ED),
                                  borderRadius: BorderRadius.circular(999),
                                  border: Border.all(
                                    color: const Color(0xFFFDBA74),
                                  ),
                                ),
                                child: Text(
                                  customer.locationIssueLabel,
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: const Color(0xFFC2410C),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                IconButton(
                  key: Key('customer_open_${customer.id}'),
                  tooltip: 'View ledger',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 36,
                    minHeight: 36,
                  ),
                  onPressed: onOpenLedger,
                  icon: const Icon(
                    Icons.chevron_right,
                    color: AppColors.primary,
                  ),
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
                        ? formatKes(debt)
                        : credit > 0
                        ? 'Credit ${formatKes(credit)}'
                        : formatKes(0),
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: debt > 0
                          ? AppColors.destructive
                          : AppColors.foreground,
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
                _IconAction(icon: Icons.phone_outlined, onPressed: onCall),
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
                      key: Key('customer_list_settle_${customer.id}'),
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
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
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
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: fg,
            fontWeight: FontWeight.w700,
          ),
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
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
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
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
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
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
        ),
      ),
    );
  }
}
