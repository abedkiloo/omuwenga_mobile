import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../design_system/buttons/cb_primary_button.dart';
import '../../../design_system/states/async_states.dart';
import '../domain/site_pin.dart';
import 'map_pin_picker.dart';
import '../../customers/application/customers_controllers.dart';
import '../../customers/domain/customer.dart';
import '../../customers/presentation/customer_form_page.dart';
import '../../pos/application/pos_controllers.dart';
import '../../pos/domain/cart.dart';
import '../../pos/presentation/variant_picker_sheet.dart';
import '../application/visit_order_controller.dart';

/// Sales visit: customer → products → map location → place order for the office.
class VisitOrderPage extends ConsumerStatefulWidget {
  VisitOrderPage({
    super.key,
    MapPinPickerBuilder? mapBuilder,
  }) : mapBuilder = mapBuilder ?? defaultMapPinPickerBuilder;

  final MapPinPickerBuilder mapBuilder;

  @override
  ConsumerState<VisitOrderPage> createState() => _VisitOrderPageState();
}

class _VisitOrderPageState extends ConsumerState<VisitOrderPage> {
  final _search = TextEditingController();
  final _landmark = TextEditingController();
  final _notes = TextEditingController();
  List<CatalogProduct> _results = const [];
  bool _searching = false;
  String? _searchError;
  bool _locating = false;

  @override
  void dispose() {
    _search.dispose();
    _landmark.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _runProductSearch([String? raw]) async {
    final q = (raw ?? _search.text).trim();
    if (q.isEmpty) {
      setState(() {
        _results = const [];
        _searchError = null;
      });
      return;
    }
    setState(() {
      _searching = true;
      _searchError = null;
    });
    final result = await ref.read(posApiProvider).searchProducts(q);
    if (!mounted) return;
    result.when(
      success: (list) => setState(() {
        _results = list;
        _searching = false;
      }),
      failure: (e, _) => setState(() {
        _searching = false;
        _searchError = e.toString();
        _results = const [];
      }),
    );
  }

  Future<void> _selectProduct(CatalogProduct product) async {
    if (product.hasVariants) {
      final pick = await showVariantPickerSheet(
        context: context,
        product: product,
        loadVariants: () async {
          final result =
              await ref.read(posApiProvider).fetchVariants(product.id);
          return result.when(
            success: (list) => list,
            failure: (e, _) => throw e,
          );
        },
      );
      if (!mounted || pick == null) return;
      ref.read(visitOrderProvider.notifier).addProduct(
            pick.product,
            variant: pick.variant,
            qty: pick.quantity,
          );
    } else {
      ref.read(visitOrderProvider.notifier).addProduct(product);
    }
    setState(() {
      _results = const [];
      _search.clear();
    });
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
      ref.read(visitOrderProvider.notifier).setPin(
            SitePin(
              latitude: pos.latitude,
              longitude: pos.longitude,
              accuracy: pos.accuracy,
              label: 'Current location',
            ),
          );
    } on Object catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not get location: $e')),
      );
    } finally {
      if (mounted) setState(() => _locating = false);
    }
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

    return Scaffold(
      appBar: AppBar(
        title: const Text('Visit order'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () {
            ref.read(visitOrderProvider.notifier).reset();
            final router = GoRouter.maybeOf(context);
            if (router != null) {
              context.go(AppRoutes.home);
            } else {
              Navigator.of(context).maybePop();
            }
          },
        ),
      ),
      body: Column(
        children: [
          _StepHeader(step: state.step),
          Expanded(child: _buildStep(state)),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: _bottomBar(state),
        ),
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
          search: _search,
          searching: _searching,
          searchError: _searchError,
          results: _results,
          lines: state.lines,
          onSearch: _runProductSearch,
          onSelectProduct: _selectProduct,
          onSetQuantity: (key, qty) =>
              ref.read(visitOrderProvider.notifier).setQuantity(key, qty),
          onRemove: (key) =>
              ref.read(visitOrderProvider.notifier).removeLine(key),
        );
      case VisitOrderStep.location:
        return _LocationStep(
          mapBuilder: widget.mapBuilder,
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
    switch (state.step) {
      case VisitOrderStep.customer:
        return CbPrimaryButton(
          key: const Key('visit_next_customer'),
          label: 'Continue',
          onPressed: state.hasCustomer
              ? () => ref
                  .read(visitOrderProvider.notifier)
                  .goTo(VisitOrderStep.products)
              : null,
        );
      case VisitOrderStep.products:
        return Row(
          children: [
            TextButton(
              onPressed: () => ref
                  .read(visitOrderProvider.notifier)
                  .goTo(VisitOrderStep.customer),
              child: const Text('Back'),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: CbPrimaryButton(
                key: const Key('visit_next_products'),
                label: 'Continue',
                onPressed: state.hasProducts
                    ? () => ref
                        .read(visitOrderProvider.notifier)
                        .goTo(VisitOrderStep.location)
                    : null,
              ),
            ),
          ],
        );
      case VisitOrderStep.location:
        return Row(
          children: [
            TextButton(
              onPressed: () => ref
                  .read(visitOrderProvider.notifier)
                  .goTo(VisitOrderStep.products),
              child: const Text('Back'),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: CbPrimaryButton(
                key: const Key('visit_next_location'),
                label: 'Review',
                onPressed: state.hasPin
                    ? () => ref
                        .read(visitOrderProvider.notifier)
                        .goTo(VisitOrderStep.review)
                    : null,
              ),
            ),
          ],
        );
      case VisitOrderStep.review:
        return Row(
          children: [
            TextButton(
              onPressed: state.submitting
                  ? null
                  : () => ref
                      .read(visitOrderProvider.notifier)
                      .goTo(VisitOrderStep.location),
              child: const Text('Back'),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: CbPrimaryButton(
                key: const Key('visit_place_order'),
                label: state.submitting ? 'Placing…' : 'Place order',
                onPressed: state.canPlace ? _place : null,
              ),
            ),
          ],
        );
    }
  }
}

class _StepHeader extends StatelessWidget {
  const _StepHeader({required this.step});
  final VisitOrderStep step;

  @override
  Widget build(BuildContext context) {
    final labels = ['Customer', 'Products', 'Location', 'Review'];
    final index = VisitOrderStep.values.indexOf(step);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Row(
        children: [
          for (var i = 0; i < labels.length; i++) ...[
            if (i > 0) const SizedBox(width: 6),
            Expanded(
              child: Column(
                children: [
                  Container(
                    height: 4,
                    decoration: BoxDecoration(
                      color: i <= index
                          ? AppColors.primary
                          : AppColors.secondary,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    labels[i],
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: i <= index
                              ? AppColors.foreground
                              : AppColors.mutedForeground,
                        ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
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
    final result =
        await ref.read(customersApiProvider).list(search: q ?? _search.text);
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            'Who are you visiting?',
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        if (widget.selected != null)
          ListTile(
            key: const Key('visit_selected_customer'),
            leading: const Icon(Icons.check_circle, color: AppColors.primary),
            title: Text(widget.selected!.name),
            subtitle: Text(widget.selected!.phone ?? 'Selected customer'),
          ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: TextField(
            key: const Key('visit_customer_search'),
            controller: _search,
            decoration: InputDecoration(
              labelText: 'Search customers',
              border: const OutlineInputBorder(),
              suffixIcon: IconButton(
                icon: const Icon(Icons.search),
                onPressed: () => _load(),
              ),
            ),
            onSubmitted: _load,
          ),
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: OutlinedButton.icon(
            key: const Key('visit_add_customer'),
            onPressed: _addCustomer,
            icon: const Icon(Icons.person_add_outlined),
            label: const Text('Add new customer'),
          ),
        ),
        if (_loading) const LinearProgressIndicator(minHeight: 2),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(_error!, style: const TextStyle(color: AppColors.destructive)),
          ),
        Expanded(
          child: ListView.separated(
            itemCount: _items.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final c = _items[i];
              return ListTile(
                key: Key('visit_customer_${c.id}'),
                title: Text(c.name),
                subtitle: Text(c.phone ?? c.customerCode ?? ''),
                onTap: () => widget.onSelected(c),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _ProductsStep extends StatelessWidget {
  const _ProductsStep({
    required this.search,
    required this.searching,
    required this.searchError,
    required this.results,
    required this.lines,
    required this.onSearch,
    required this.onSelectProduct,
    required this.onSetQuantity,
    required this.onRemove,
  });

  final TextEditingController search;
  final bool searching;
  final String? searchError;
  final List<CatalogProduct> results;
  final List<CartLine> lines;
  final ValueChanged<String?> onSearch;
  final ValueChanged<CatalogProduct> onSelectProduct;
  final void Function(String lineKey, double qty) onSetQuantity;
  final ValueChanged<String> onRemove;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(
            'What do they need?',
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: TextField(
            key: const Key('visit_product_search'),
            controller: search,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              labelText: 'Search products',
              border: const OutlineInputBorder(),
              suffixIcon: IconButton(
                icon: const Icon(Icons.search),
                onPressed: searching ? null : () => onSearch(null),
              ),
            ),
            onSubmitted: onSearch,
          ),
        ),
        if (searching) const LinearProgressIndicator(minHeight: 2),
        if (searchError != null)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              searchError!,
              style: const TextStyle(color: AppColors.destructive),
            ),
          ),
        if (results.isNotEmpty)
          Expanded(
            child: ListView.separated(
              key: const Key('visit_product_results'),
              itemCount: results.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, i) {
                final p = results[i];
                return ListTile(
                  key: Key('visit_product_${p.id}'),
                  title: Text(p.name),
                  subtitle: Text(
                    [
                      if (p.hasVariants) 'Has variants',
                      if (p.sku != null && p.sku!.isNotEmpty) p.sku!,
                      p.price.toStringAsFixed(2),
                    ].join(' · '),
                  ),
                  trailing: Icon(
                    p.hasVariants
                        ? Icons.layers_outlined
                        : Icons.add_circle_outline,
                  ),
                  onTap: () => onSelectProduct(p),
                );
              },
            ),
          )
        else
          Expanded(
            child: lines.isEmpty
                ? const EmptyState(
                    key: Key('visit_empty_products'),
                    title: 'No products yet',
                    message: 'Search the catalog and add what they need.',
                    primaryLabel: 'OK',
                    onPrimary: _noop,
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(8),
                    itemCount: lines.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (context, i) {
                      final line = lines[i];
                      return ListTile(
                        key: Key('visit_line_${line.lineKey}'),
                        title: Text(line.displayName),
                        subtitle: Text(line.unitPrice.toStringAsFixed(2)),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              onPressed: () =>
                                  onSetQuantity(line.lineKey, line.quantity - 1),
                              icon: const Icon(Icons.remove_circle_outline),
                            ),
                            Text(line.quantity.round().toString()),
                            IconButton(
                              onPressed: () =>
                                  onSetQuantity(line.lineKey, line.quantity + 1),
                              icon: const Icon(Icons.add_circle_outline),
                            ),
                            IconButton(
                              onPressed: () => onRemove(line.lineKey),
                              icon: const Icon(Icons.delete_outline),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
      ],
    );
  }
}

void _noop() {}

class _LocationStep extends StatelessWidget {
  const _LocationStep({
    required this.mapBuilder,
    required this.pin,
    required this.landmarkController,
    required this.locating,
    required this.onPin,
    required this.onLandmark,
    required this.onUseCurrent,
  });

  final MapPinPickerBuilder mapBuilder;
  final SitePin? pin;
  final TextEditingController landmarkController;
  final bool locating;
  final ValueChanged<SitePin> onPin;
  final ValueChanged<String> onLandmark;
  final VoidCallback onUseCurrent;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(
            'Where are they located?',
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: CbPrimaryButton(
            key: const Key('visit_use_current_location'),
            label: locating ? 'Getting location…' : 'Use current location',
            onPressed: locating ? null : onUseCurrent,
          ),
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'Or tap the map to drop a pin',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.mutedForeground,
                ),
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: mapBuilder(
                context,
                selected: pin,
                onChanged: onPin,
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            key: const Key('visit_landmark'),
            controller: landmarkController,
            decoration: const InputDecoration(
              labelText: 'Landmark / place name (optional)',
              hintText: 'e.g. Near Kenya Power, blue gate',
              border: OutlineInputBorder(),
            ),
            onChanged: onLandmark,
          ),
        ),
        if (pin != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text(
              key: const Key('visit_pin_coords'),
              '${pin!.latitude.toStringAsFixed(5)}, ${pin!.longitude.toStringAsFixed(5)}'
              '${pin!.label.isNotEmpty ? ' · ${pin!.label}' : ''}',
              style: Theme.of(context).textTheme.bodySmall,
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
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Review & place', style: Theme.of(context).textTheme.titleMedium),
        if (state.error != null) ...[
          const SizedBox(height: 12),
          Text(
            state.error!,
            key: const Key('visit_place_error'),
            maxLines: 6,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: AppColors.destructive),
          ),
        ],
        const SizedBox(height: 12),
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Customer'),
          subtitle: Text(state.customer?.name ?? '—'),
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Location'),
          subtitle: Text(
            pin == null
                ? '—'
                : '${pin.latitude.toStringAsFixed(5)}, ${pin.longitude.toStringAsFixed(5)}'
                    '${state.landmark.isNotEmpty ? '\n${state.landmark}' : ''}',
          ),
        ),
        const Divider(),
        Text('Products', style: Theme.of(context).textTheme.titleSmall),
        for (final line in state.lines)
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(line.displayName),
            subtitle: Text('${line.quantity} × ${line.unitPrice.toStringAsFixed(2)}'),
            trailing: Text(line.lineTotal.toStringAsFixed(2)),
          ),
        const SizedBox(height: 8),
        Text(
          'Subtotal ${state.subtotal.toStringAsFixed(2)}',
          style: Theme.of(context).textTheme.titleSmall,
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
        Text(
          'This order goes to the office to pack and mark ready for pickup.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.mutedForeground,
              ),
        ),
      ],
    );
  }
}
