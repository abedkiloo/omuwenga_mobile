import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../design_system/chrome/cb_flow_header.dart';
import '../../../design_system/chrome/cb_search_field.dart';
import '../../../design_system/chrome/cb_section_label.dart';
import '../../../design_system/chrome/cb_status_pill.dart';
import '../../../design_system/chrome/cb_step_progress.dart';
import '../../../design_system/chrome/cb_sticky_action_bar.dart';
import '../../../design_system/chrome/cb_surface_card.dart';
import '../../../design_system/states/async_states.dart';
import '../../customers/application/customers_controllers.dart';
import '../../customers/domain/customer.dart';
import '../../customers/domain/wallet_debt.dart';
import '../../customers/presentation/customer_form_page.dart';
import '../../pos/application/pos_controllers.dart';
import '../../pos/application/product_catalog_paging.dart';
import '../../pos/domain/cart.dart';
import '../../pos/presentation/variant_picker_sheet.dart';
import '../application/visit_order_controller.dart';
import '../domain/site_pin.dart';
import 'map_pin_picker.dart';

String _kes(num value) => 'KES ${value.toStringAsFixed(2)}';

String _shortName(String name) {
  final parts = name.trim().split(RegExp(r'\s+'));
  if (parts.length <= 2) return name.trim();
  return parts.take(2).join(' ');
}

/// Sales visit: customer → products → map location → place order for the office.
class VisitOrderPage extends ConsumerStatefulWidget {
  VisitOrderPage({super.key, MapPinPickerBuilder? mapBuilder})
    : mapBuilder = mapBuilder ?? defaultMapPinPickerBuilder;

  final MapPinPickerBuilder mapBuilder;

  @override
  ConsumerState<VisitOrderPage> createState() => _VisitOrderPageState();
}

class _VisitOrderPageState extends ConsumerState<VisitOrderPage> {
  final _landmark = TextEditingController();
  final _notes = TextEditingController();
  bool _locating = false;

  @override
  void dispose() {
    _landmark.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _selectProduct(CatalogProduct product) async {
    if (product.hasVariants) {
      final pick = await showVariantPickerSheet(
        context: context,
        product: product,
        loadVariants: () async {
          final result = await ref
              .read(posApiProvider)
              .fetchVariants(product.id);
          return result.when(
            success: (list) => list,
            failure: (e, _) => throw e,
          );
        },
      );
      if (!mounted || pick == null) return;
      ref
          .read(visitOrderProvider.notifier)
          .addProduct(pick.product, variant: pick.variant, qty: pick.quantity);
    } else {
      ref.read(visitOrderProvider.notifier).addProduct(product);
    }
  }

  Future<void> _useCurrentLocation() async {
    setState(() => _locating = true);
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Location permission is required.')),
        );
        return;
      }
      final pos = await Geolocator.getCurrentPosition();
      if (!mounted) return;
      ref
          .read(visitOrderProvider.notifier)
          .setPin(
            SitePin(
              latitude: pos.latitude,
              longitude: pos.longitude,
              accuracy: pos.accuracy,
              label: 'Current location',
            ),
          );
    } on Object catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not get location: $e')));
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  void _exitVisit() {
    ref.read(visitOrderProvider.notifier).reset();
    final router = GoRouter.maybeOf(context);
    if (router != null) {
      context.go(AppRoutes.home);
    } else {
      Navigator.of(context).maybePop();
    }
  }

  /// App-bar / system back: previous wizard step, or leave from step 1.
  void _handleBack() {
    final state = ref.read(visitOrderProvider);
    if (state.submitting) return;
    if (ref.read(visitOrderProvider.notifier).goBack()) return;
    _exitVisit();
  }

  String _stepHeadline(VisitOrderStep step) {
    return switch (step) {
      VisitOrderStep.customer => 'Step 1 of 4: Select Customer & Verify Debt',
      VisitOrderStep.products => 'Step 2 of 4: Order Items & Packs',
      VisitOrderStep.location => 'Step 3 of 4: Pin Delivery Drop & Landmark',
      VisitOrderStep.review => 'Step 4 of 4: Final Review & Handoff',
    };
  }

  String _stepCaption(VisitOrderStep step) {
    return switch (step) {
      VisitOrderStep.customer =>
        'Verify customer standing before placing the booking.',
      VisitOrderStep.products => 'Search the catalog and set pack quantities.',
      VisitOrderStep.location =>
          'Snap GPS first, then adjust the pin if needed.',
      VisitOrderStep.review => 'Ready to submit — sent to the packing queue.',
    };
  }

  Future<void> _place() async {
    final ok = await ref.read(visitOrderProvider.notifier).placeOrder();
    if (!mounted) return;
    if (ok) {
      final id = ref.read(visitOrderProvider).placedOrderId;
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          key: const Key('visit_order_success'),
          title: const Text('Order placed'),
          content: Text(
            'Order #$id was sent to the office to pack and mark ready for pickup.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      if (!mounted) return;
      ref.read(visitOrderProvider.notifier).reset();
      final router = GoRouter.maybeOf(context);
      if (router != null) {
        context.go(AppRoutes.home);
      } else {
        Navigator.of(context).maybePop();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(visitOrderProvider);
    ref.listen(visitOrderProvider, (prev, next) {
      if (next.landmark != _landmark.text) {
        _landmark.text = next.landmark;
      }
      if (next.notes != _notes.text) {
        _notes.text = next.notes;
      }
    });

    const stepLabels = ['Customer', 'Products', 'Pin Drop', 'Review'];
    final stepIndex = VisitOrderStep.values.indexOf(state.step);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _handleBack();
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: CbFlowHeader(
          title: 'Field Visit Order',
          leadingIcon: Icons.assignment_outlined,
          subtitle: 'Sales visit',
          onBack: _handleBack,
        ),
        body: Column(
          children: [
            CbStepProgress(labels: stepLabels, currentIndex: stepIndex),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _stepHeadline(state.step),
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _stepCaption(state.step),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.mutedForeground,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(child: _buildStep(state)),
          ],
        ),
        bottomNavigationBar: _bottomBar(state),
      ),
    );
  }

  Widget _buildStep(VisitOrderState state) {
    switch (state.step) {
      case VisitOrderStep.customer:
        return _CustomerStep(
          selected: state.customer,
          onSelected: (c) =>
              ref.read(visitOrderProvider.notifier).selectCustomer(c),
        );
      case VisitOrderStep.products:
        return _ProductsStep(
          customer: state.customer,
          lines: state.lines,
          onSelectProduct: _selectProduct,
          onSetQuantity: (key, qty) =>
              ref.read(visitOrderProvider.notifier).setQuantity(key, qty),
          onRemove: (key) =>
              ref.read(visitOrderProvider.notifier).removeLine(key),
        );
      case VisitOrderStep.location:
        return _LocationStep(
          mapBuilder: widget.mapBuilder,
          customer: state.customer,
          lines: state.lines,
          subtotal: state.subtotal,
          pin: state.pin,
          landmarkController: _landmark,
          locating: _locating,
          onPin: (pin) => ref.read(visitOrderProvider.notifier).setPin(pin),
          onLandmark: (v) =>
              ref.read(visitOrderProvider.notifier).setLandmark(v),
          onUseCurrent: _useCurrentLocation,
        );
      case VisitOrderStep.review:
        return _ReviewStep(
          state: state,
          notesController: _notes,
          onNotes: (v) => ref.read(visitOrderProvider.notifier).setNotes(v),
        );
    }
  }

  Widget _bottomBar(VisitOrderState state) {
    Widget? back;
    late String label;
    Key? primaryKey;
    VoidCallback? onPrimary;
    String? summary;
    String? summaryTrailing;

    switch (state.step) {
      case VisitOrderStep.customer:
        final name = state.customer == null
            ? null
            : _shortName(state.customer!.name);
        label = name == null
            ? 'Select a customer'
            : 'Confirm $name & Add Products';
        primaryKey = const Key('visit_next_customer');
        onPrimary = state.hasCustomer
            ? () => ref
                  .read(visitOrderProvider.notifier)
                  .goTo(VisitOrderStep.products)
            : null;
        if (state.customer != null) {
          summary = _customerLedgerSummary(state.customer!);
        }
      case VisitOrderStep.products:
        label = 'Proceed to Delivery Pin';
        primaryKey = const Key('visit_next_products');
        onPrimary = state.hasProducts
            ? () => ref
                  .read(visitOrderProvider.notifier)
                  .goTo(VisitOrderStep.location)
            : null;
        summary =
            '${state.lines.length} SKU · ${state.lines.fold<double>(0, (s, l) => s + l.quantity).round()} packs';
        summaryTrailing = _kes(state.subtotal);
        back = TextButton(
          key: const Key('visit_back'),
          onPressed: () => ref.read(visitOrderProvider.notifier).goBack(),
          child: const Text('Back'),
        );
      case VisitOrderStep.location:
        label = 'Save Location & Review Order';
        primaryKey = const Key('visit_next_location');
        onPrimary = state.hasPin
            ? () => ref
                  .read(visitOrderProvider.notifier)
                  .goTo(VisitOrderStep.review)
            : null;
        back = TextButton(
          key: const Key('visit_back'),
          onPressed: () => ref.read(visitOrderProvider.notifier).goBack(),
          child: const Text('Back'),
        );
      case VisitOrderStep.review:
        label = state.submitting ? 'Placing…' : 'Submit Order to Pack Queue';
        primaryKey = const Key('visit_place_order');
        onPrimary = state.canPlace ? _place : null;
        summary = '${state.lines.length} items';
        summaryTrailing = _kes(state.subtotal);
        back = TextButton(
          key: const Key('visit_back'),
          onPressed: state.submitting
              ? null
              : () => ref.read(visitOrderProvider.notifier).goBack(),
          child: const Text('Back'),
        );
    }

    return CbStickyActionBar(
      summary: summary,
      summaryTrailing: summaryTrailing,
      primaryLabel: label,
      primaryKey: primaryKey,
      onPrimary: onPrimary,
      secondary: back == null
          ? null
          : Align(alignment: Alignment.centerLeft, child: back),
    );
  }
}

String _customerLedgerSummary(CustomerSummary c) {
  switch (c.standing) {
    case CustomerStanding.debt:
      return '${_shortName(c.name)} · Outstanding ${_kes(c.debtAmount)}';
    case CustomerStanding.credit:
      return '${_shortName(c.name)} · Credit ${_kes(c.walletBalance ?? 0)}';
    case CustomerStanding.good:
      return '${_shortName(c.name)} · Good standing';
  }
}

class _CustomerStep extends ConsumerStatefulWidget {
  const _CustomerStep({required this.selected, required this.onSelected});

  final CustomerSummary? selected;
  final ValueChanged<CustomerSummary> onSelected;

  @override
  ConsumerState<_CustomerStep> createState() => _CustomerStepState();
}

class _CustomerStepState extends ConsumerState<_CustomerStep> {
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

  Future<void> _addCustomer() async {
    final created = await Navigator.of(context).push<CustomerSummary>(
      MaterialPageRoute(
        builder: (_) => const CustomerFormPage(returnCustomer: true),
      ),
    );
    if (created != null) {
      widget.onSelected(created);
    }
  }

  @override
  Widget build(BuildContext context) {
    final selected = widget.selected;
    final alternates = selected == null
        ? _items
        : _items.where((c) => c.id != selected.id).toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      children: [
        CbSearchField(
          fieldKey: const Key('visit_customer_search'),
          controller: _search,
          hintText: 'Search name, phone, or code',
          onSubmitted: _load,
          onSearchTap: () => _load(),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          key: const Key('visit_add_customer'),
          onPressed: _addCustomer,
          icon: const Icon(Icons.person_add_outlined),
          label: const Text('Add new customer'),
        ),
        if (_loading) const LinearProgressIndicator(minHeight: 2),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(
              _error!,
              style: const TextStyle(color: AppColors.destructive),
            ),
          ),
        if (selected != null) ...[
          const SizedBox(height: 16),
          _ActiveStoreCard(customer: selected),
        ],
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: CbSectionLabel(
                label: selected == null ? 'Customers' : 'Other customers',
                icon: Icons.storefront_outlined,
              ),
            ),
            Text(
              '${_items.length} customers',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: AppColors.mutedForeground,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        for (final c in (selected == null ? _items : alternates))
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _CustomerListCard(
              customer: c,
              onTap: () => widget.onSelected(c),
            ),
          ),
      ],
    );
  }
}

class _ActiveStoreCard extends StatelessWidget {
  const _ActiveStoreCard({required this.customer});

  final CustomerSummary customer;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final standing = customer.standing;
    final debt = customer.debtAmount;
    final credit = customer.walletBalance != null && customer.walletBalance! > 0
        ? customer.walletBalance!
        : 0.0;

    return CbSurfaceCard(
      key: const Key('visit_selected_customer'),
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            decoration: const BoxDecoration(
              color: AppColors.accentSoft,
              borderRadius: BorderRadius.vertical(
                top: Radius.circular(AppColors.radius),
              ),
            ),
            child: Row(
              children: [
                Text(
                  'ACTIVE STORE SELECTED',
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.4,
                    color: AppColors.primary,
                  ),
                ),
                const Spacer(),
                const Icon(
                  Icons.check_circle,
                  color: AppColors.success,
                  size: 18,
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  customer.name,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (customer.phone != null && customer.phone!.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(
                        Icons.person_outline,
                        size: 16,
                        color: AppColors.mutedForeground,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        customer.phone!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppColors.mutedForeground,
                        ),
                      ),
                    ],
                  ),
                ],
                if (customer.customerCode != null &&
                    customer.customerCode!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  CbStatusPill(
                    label: customer.customerCode!,
                    variant: CbStatusPillVariant.info,
                  ),
                ],
                const SizedBox(height: 16),
                Text(
                  'ACCOUNT LEDGER',
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.4,
                    color: AppColors.mutedForeground,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _LedgerStat(
                        label: 'Outstanding debt',
                        value: _kes(debt),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _LedgerStat(
                        label: 'Wallet credit',
                        value: _kes(credit),
                      ),
                    ),
                  ],
                ),
                if (customer.totalOutstanding != null) ...[
                  const SizedBox(height: 8),
                  _LedgerStat(
                    label: 'Total outstanding',
                    value: _kes(customer.totalOutstanding!),
                  ),
                ],
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.accentSoft,
                    borderRadius: BorderRadius.circular(AppColors.radius - 2),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        standing == CustomerStanding.debt
                            ? 'OUTSTANDING BALANCE'
                            : standing == CustomerStanding.credit
                            ? 'AVAILABLE WALLET CREDIT'
                            : 'ACCOUNT STANDING',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: AppColors.mutedForeground,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        standing == CustomerStanding.debt
                            ? _kes(debt)
                            : standing == CustomerStanding.credit
                            ? _kes(credit)
                            : 'Cleared for booking',
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        standingLabel(
                          standing,
                          debtAmount: debt,
                          credit: credit,
                        ),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppColors.mutedForeground,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LedgerStat extends StatelessWidget {
  const _LedgerStat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(AppColors.radius - 4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: AppColors.mutedForeground,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _CustomerListCard extends StatelessWidget {
  const _CustomerListCard({required this.customer, required this.onTap});

  final CustomerSummary customer;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final standing = customer.standing;
    final pill = switch (standing) {
      CustomerStanding.debt => CbStatusPill(
        label: 'Owes ${_kes(customer.debtAmount)}',
        variant: CbStatusPillVariant.warning,
      ),
      CustomerStanding.credit => CbStatusPill(
        label: 'Credit ${_kes(customer.walletBalance ?? 0)}',
        variant: CbStatusPillVariant.success,
      ),
      CustomerStanding.good => const CbStatusPill(
        label: 'Clean ledger',
        variant: CbStatusPillVariant.info,
      ),
    };

    return CbSurfaceCard(
      key: Key('visit_customer_${customer.id}'),
      padding: const EdgeInsets.all(12),
      onTap: onTap,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  customer.name,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  [
                    if (customer.phone != null && customer.phone!.isNotEmpty)
                      customer.phone,
                    if (customer.customerCode != null &&
                        customer.customerCode!.isNotEmpty)
                      customer.customerCode,
                  ].whereType<String>().join(' · '),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.mutedForeground,
                  ),
                ),
                const SizedBox(height: 8),
                pill,
              ],
            ),
          ),
          const Icon(Icons.chevron_right, color: AppColors.mutedForeground),
        ],
      ),
    );
  }
}

class _ProductsStep extends ConsumerStatefulWidget {
  const _ProductsStep({
    required this.customer,
    required this.lines,
    required this.onSelectProduct,
    required this.onSetQuantity,
    required this.onRemove,
  });

  final CustomerSummary? customer;
  final List<CartLine> lines;
  final ValueChanged<CatalogProduct> onSelectProduct;
  final void Function(String lineKey, double qty) onSetQuantity;
  final ValueChanged<String> onRemove;

  @override
  ConsumerState<_ProductsStep> createState() => _ProductsStepState();
}

class _ProductsStepState extends ConsumerState<_ProductsStep> {
  final _search = TextEditingController();
  final _catalog = ProductCatalogPaging();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadCatalog());
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _loadCatalog([String? raw]) async {
    await _catalog.refresh(
      ref.read(posApiProvider),
      search: raw ?? _search.text,
      onUpdate: () {
        if (mounted) setState(() {});
      },
    );
  }

  Future<void> _loadMore() async {
    await _catalog.loadMore(
      ref.read(posApiProvider),
      onUpdate: () {
        if (mounted) setState(() {});
      },
    );
  }

  bool _onScroll(ScrollNotification notification) {
    if (notification.metrics.extentAfter < 240) {
      _loadMore();
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final customer = widget.customer;
    final lines = widget.lines;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (customer != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.accentSoft,
                borderRadius: BorderRadius.circular(AppColors.radius),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.storefront_outlined,
                    color: AppColors.primary,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      customer.name,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  CbStatusPill(
                    label: standingLabel(
                      customer.standing,
                      debtAmount: customer.debtAmount,
                      credit:
                          customer.walletBalance != null &&
                              customer.walletBalance! > 0
                          ? customer.walletBalance!
                          : 0,
                    ),
                    variant: customer.standing == CustomerStanding.debt
                        ? CbStatusPillVariant.warning
                        : CbStatusPillVariant.success,
                  ),
                ],
              ),
            ),
          ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: CbSearchField(
            fieldKey: const Key('visit_product_search'),
            controller: _search,
            hintText: 'Search SKU, brand, or barcode…',
            onSubmitted: _loadCatalog,
            onSearchTap: _catalog.loading ? null : () => _loadCatalog(),
          ),
        ),
        if (_catalog.loading && _catalog.items.isEmpty)
          const LinearProgressIndicator(minHeight: 2),
        if (_catalog.error != null)
          Padding(
            padding: const EdgeInsets.all(12),
            child: Text(
              _catalog.error!,
              style: const TextStyle(color: AppColors.destructive),
            ),
          ),
        Expanded(
          child: _catalog.isEmpty && !_catalog.loading
              ? const EmptyState(
                  key: Key('visit_empty_products'),
                  title: 'No products yet',
                  message: 'Browse the catalog or search by SKU.',
                  primaryLabel: 'OK',
                  onPrimary: _noop,
                )
              : NotificationListener<ScrollNotification>(
                  onNotification: _onScroll,
                  child: ListView(
                    key: const Key('visit_product_results'),
                    padding: const EdgeInsets.fromLTRB(12, 6, 12, 10),
                    children: [
                      if (lines.isNotEmpty) ...[
                        for (final line in lines) ...[
                          _ProductLineCard(
                            line: line,
                            onSetQuantity: widget.onSetQuantity,
                            onRemove: widget.onRemove,
                          ),
                          const SizedBox(height: 8),
                        ],
                      ],
                      CbSectionLabel(
                        label: _catalog.query.isEmpty
                            ? 'Products'
                            : 'Search results',
                        icon: Icons.inventory_2_outlined,
                      ),
                      const SizedBox(height: 8),
                      for (final p in _catalog.items) ...[
                        CbSurfaceCard(
                          key: Key('visit_product_${p.id}'),
                          padding: const EdgeInsets.all(12),
                          onTap: () => widget.onSelectProduct(p),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      p.name,
                                      style: theme.textTheme.titleSmall
                                          ?.copyWith(
                                            fontWeight: FontWeight.w600,
                                          ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      [
                                        if (p.hasVariants) 'Has variants',
                                        if (p.sku != null && p.sku!.isNotEmpty)
                                          p.sku!,
                                        if (p.stockQuantity != null)
                                          'Stock ${p.stockQuantity!.round()}',
                                      ].join(' · '),
                                      style: theme.textTheme.bodySmall
                                          ?.copyWith(
                                            color: AppColors.mutedForeground,
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                              Text(
                                _kes(p.price),
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Icon(
                                p.hasVariants
                                    ? Icons.layers_outlined
                                    : Icons.add_circle_outline,
                                color: AppColors.primary,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                      ],
                      if (_catalog.loadingMore)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 12),
                          child: Center(
                            child: SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
        ),
      ],
    );
  }
}

class _ProductLineCard extends StatelessWidget {
  const _ProductLineCard({
    required this.line,
    required this.onSetQuantity,
    required this.onRemove,
  });

  final CartLine line;
  final void Function(String lineKey, double qty) onSetQuantity;
  final ValueChanged<String> onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return CbSurfaceCard(
      key: Key('visit_line_${line.lineKey}'),
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
                      line.displayName,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (line.sku != null && line.sku!.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        line.sku!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppColors.mutedForeground,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const CbStatusPill(
                label: 'ADDED',
                variant: CbStatusPillVariant.info,
              ),
            ],
          ),
          if (line.stockQuantity != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.secondary,
                borderRadius: BorderRadius.circular(AppColors.radius - 4),
              ),
              child: Text(
                'In stock: ${line.stockQuantity!.round()}',
                style: theme.textTheme.bodySmall,
              ),
            ),
          ],
          const SizedBox(height: 10),
          Row(
            children: [
              Text(
                '${_kes(line.unitPrice)} / unit',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppColors.mutedForeground,
                ),
              ),
              const Spacer(),
              IconButton(
                onPressed: () => onSetQuantity(line.lineKey, line.quantity - 1),
                icon: const Icon(Icons.remove_circle_outline),
              ),
              Text(
                '${line.quantity.round()}',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              IconButton(
                onPressed: () => onSetQuantity(line.lineKey, line.quantity + 1),
                icon: const Icon(Icons.add_circle_outline),
              ),
              IconButton(
                onPressed: () => onRemove(line.lineKey),
                icon: const Icon(
                  Icons.delete_outline,
                  color: AppColors.destructive,
                ),
              ),
            ],
          ),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              'Pack total ${_kes(line.lineTotal)}',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: AppColors.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

void _noop() {}

class _LocationStep extends StatelessWidget {
  const _LocationStep({
    required this.mapBuilder,
    required this.customer,
    required this.lines,
    required this.subtotal,
    required this.pin,
    required this.landmarkController,
    required this.locating,
    required this.onPin,
    required this.onLandmark,
    required this.onUseCurrent,
  });

  final MapPinPickerBuilder mapBuilder;
  final CustomerSummary? customer;
  final List<CartLine> lines;
  final double subtotal;
  final SitePin? pin;
  final TextEditingController landmarkController;
  final bool locating;
  final ValueChanged<SitePin> onPin;
  final ValueChanged<String> onLandmark;
  final VoidCallback onUseCurrent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final packCount = lines.fold<double>(0, (s, l) => s + l.quantity).round();

    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      children: [
        CbSurfaceCard(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  customer?.name ?? 'Customer',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              CbStatusPill(
                label: '$packCount packs',
                variant: CbStatusPillVariant.info,
              ),
              const SizedBox(width: 8),
              Text(
                _kes(subtotal),
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        CbPrimaryButton(
          key: const Key('visit_use_current_location'),
          label: locating
              ? 'Getting location…'
              : 'Snap to Current GPS Location',
          onPressed: locating ? null : onUseCurrent,
        ),
        if (pin != null) ...[
          const SizedBox(height: 10),
          Container(
            key: const Key('visit_pin_coords'),
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(AppColors.radius - 2),
            ),
            child: Text(
              '${pin!.latitude.toStringAsFixed(6)}, ${pin!.longitude.toStringAsFixed(6)}'
              '${pin!.label.isNotEmpty ? ' · ${pin!.label}' : ''}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.primaryForeground,
              ),
            ),
          ),
        ],
        const SizedBox(height: 12),
        SizedBox(
          height: 240,
          child: CbSurfaceCard(
            padding: EdgeInsets.zero,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppColors.radius),
              child: Stack(
                children: [
                  Positioned.fill(
                    child: mapBuilder(context, selected: pin, onChanged: onPin),
                  ),
                  Positioned(
                    top: 12,
                    left: 12,
                    child: CbStatusPill(
                      label: pin == null ? 'Drop pin on map' : 'Pin placed',
                      variant: pin == null
                          ? CbStatusPillVariant.warning
                          : CbStatusPillVariant.success,
                      showOnlineDot: pin != null,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        CbSurfaceCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const CbSectionLabel(
                label: 'Physical Landmark & Access Details',
                icon: Icons.place_outlined,
              ),
              const SizedBox(height: 4),
              Text(
                'Helps riders and dispatch find the outlet.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppColors.mutedForeground,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                key: const Key('visit_landmark'),
                controller: landmarkController,
                maxLines: 3,
                decoration: const InputDecoration(
                  hintText: 'e.g. Behind TotalEnergies, blue gates next to ATM',
                  border: OutlineInputBorder(),
                ),
                onChanged: onLandmark,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ReviewStep extends StatelessWidget {
  const _ReviewStep({
    required this.state,
    required this.notesController,
    required this.onNotes,
  });

  final VisitOrderState state;
  final TextEditingController notesController;
  final ValueChanged<String> onNotes;

  @override
  Widget build(BuildContext context) {
    final pin = state.pin;
    final theme = Theme.of(context);
    final packCount = state.lines
        .fold<double>(0, (s, l) => s + l.quantity)
        .round();

    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      children: [
        if (state.error != null) ...[
          Text(
            state.error!,
            key: const Key('visit_place_error'),
            maxLines: 6,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: AppColors.destructive),
          ),
          const SizedBox(height: 12),
        ],
        CbSurfaceCard(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.accentSoft,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.storefront_outlined,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'VERIFIED OUTLET',
                      style: theme.textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.4,
                        color: AppColors.mutedForeground,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      state.customer?.name ?? '—',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (state.customer?.phone != null &&
                        state.customer!.phone!.isNotEmpty)
                      Text(
                        state.customer!.phone!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppColors.mutedForeground,
                        ),
                      ),
                    if (state.customer?.customerCode != null &&
                        state.customer!.customerCode!.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      CbStatusPill(
                        label: state.customer!.customerCode!,
                        variant: CbStatusPillVariant.info,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        CbSurfaceCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const CbSectionLabel(
                label: 'Delivery pin',
                icon: Icons.local_shipping_outlined,
              ),
              const SizedBox(height: 8),
              Text(
                pin == null
                    ? '—'
                    : '${pin.latitude.toStringAsFixed(5)}, ${pin.longitude.toStringAsFixed(5)}',
                style: theme.textTheme.bodyMedium,
              ),
              if (state.landmark.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  state.landmark,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.mutedForeground,
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),
        CbSurfaceCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: CbSectionLabel(
                      label: 'Itemized Bill of Goods',
                      icon: Icons.inventory_2_outlined,
                    ),
                  ),
                  Text(
                    '${state.lines.length} SKUS · $packCount PACKS',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: AppColors.mutedForeground,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              for (final line in state.lines)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(line.displayName),
                            Text(
                              '${line.quantity.round()} × ${_kes(line.unitPrice)}',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: AppColors.mutedForeground,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        _kes(line.lineTotal),
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.accentSoft,
                  borderRadius: BorderRadius.circular(AppColors.radius - 2),
                ),
                child: Row(
                  children: [
                    Text(
                      'TOTAL PAYABLE',
                      style: theme.textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      _kes(state.subtotal),
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          key: const Key('visit_notes'),
          controller: notesController,
          decoration: const InputDecoration(
            labelText: 'Notes for the office (optional)',
            border: OutlineInputBorder(),
          ),
          maxLines: 2,
          onChanged: onNotes,
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.accentSoft,
            borderRadius: BorderRadius.circular(AppColors.radius),
          ),
          child: Row(
            children: [
              const Icon(Icons.cloud_done_outlined, color: AppColors.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'This order goes to the office to pack and mark ready for pickup.',
                  style: theme.textTheme.bodySmall,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
