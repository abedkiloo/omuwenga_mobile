import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../design_system/states/async_states.dart';
import '../domain/cart.dart';
import '../domain/product_variant.dart';

/// Result of the variant picker: parent + chosen variant (+ qty).
class VariantPickResult {
  const VariantPickResult({
    required this.product,
    required this.variant,
    this.quantity = 1,
  });

  final CatalogProduct product;
  final ProductVariant variant;
  final double quantity;
}

/// Bottom sheet matching web VariantSelector: size/color chips or flat list.
Future<VariantPickResult?> showVariantPickerSheet({
  required BuildContext context,
  required CatalogProduct product,
  required Future<List<ProductVariant>> Function() loadVariants,
}) {
  return showModalBottomSheet<VariantPickResult>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => _VariantPickerSheet(
      product: product,
      loadVariants: loadVariants,
    ),
  );
}

class _VariantPickerSheet extends StatefulWidget {
  const _VariantPickerSheet({
    required this.product,
    required this.loadVariants,
  });

  final CatalogProduct product;
  final Future<List<ProductVariant>> Function() loadVariants;

  @override
  State<_VariantPickerSheet> createState() => _VariantPickerSheetState();
}

class _VariantPickerSheetState extends State<_VariantPickerSheet> {
  bool _loading = true;
  String? _error;
  List<ProductVariant> _variants = const [];
  VariantPickerMode _mode = VariantPickerMode.none;
  int? _sizeId;
  int? _colorId;
  ProductVariant? _selected;
  double _qty = 1;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await widget.loadVariants();
      final active = list.where((v) => v.isActive).toList();
      if (!mounted) return;
      setState(() {
        _variants = active;
        _mode = getVariantPickerMode(active);
        _loading = false;
        if (active.length == 1) {
          _selected = active.first;
          _sizeId = active.first.sizeId;
          _colorId = active.first.colorId;
        }
      });
    } on Object catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  void _syncSelectionFromChips() {
    setState(() {
      _selected = findVariantForSelection(
        _variants,
        mode: _mode,
        sizeId: _sizeId,
        colorId: _colorId,
      );
    });
  }

  bool get _canAdd {
    if (_mode == VariantPickerMode.list || _mode == VariantPickerMode.none) {
      return _selected != null;
    }
    return _selected != null;
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: SafeArea(
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * 0.7,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.product.name,
                      key: const Key('variant_picker_title'),
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _selected == null
                          ? 'Choose a variant'
                          : '${_selected!.displayLabel} · ${_selected!.effectivePrice.toStringAsFixed(2)}',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppColors.mutedForeground,
                          ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(child: _body()),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    IconButton(
                      key: const Key('variant_qty_dec'),
                      onPressed: _qty <= 1
                          ? null
                          : () => setState(() => _qty -= 1),
                      icon: const Icon(Icons.remove_circle_outline),
                    ),
                    Text(
                      key: const Key('variant_qty'),
                      _qty.round().toString(),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    IconButton(
                      key: const Key('variant_qty_inc'),
                      onPressed: () => setState(() => _qty += 1),
                      icon: const Icon(Icons.add_circle_outline),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: CbPrimaryButton(
                        key: const Key('variant_add'),
                        label: 'Add to cart',
                        onPressed: !_canAdd
                            ? null
                            : () => Navigator.pop(
                                  context,
                                  VariantPickResult(
                                    product: widget.product,
                                    variant: _selected!,
                                    quantity: _qty,
                                  ),
                                ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _body() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return ErrorState(
        message: _error!,
        onRetry: _load,
      );
    }
    if (_variants.isEmpty) {
      return const Center(
        child: Text('No active variants for this product.'),
      );
    }

    if (_mode == VariantPickerMode.list || _mode == VariantPickerMode.none) {
      return ListView.separated(
        key: const Key('variant_list'),
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: _variants.length,
        separatorBuilder: (_, _) => const Divider(height: 1),
        itemBuilder: (context, i) {
          final v = _variants[i];
          final selected = _selected?.id == v.id;
          return ListTile(
            key: Key('variant_row_${v.id}'),
            selected: selected,
            title: Text(v.displayLabel),
            subtitle: Text(
              [
                if (v.sku != null && v.sku!.isNotEmpty) v.sku!,
                v.effectivePrice.toStringAsFixed(2),
                if (v.stockQuantity != null)
                  'stock ${v.stockQuantity!.toStringAsFixed(0)}',
              ].join(' · '),
            ),
            trailing: selected
                ? const Icon(Icons.check_circle, color: AppColors.primary)
                : null,
            onTap: () => setState(() => _selected = v),
          );
        },
      );
    }

    final sizes = pickerSizes(_variants);
    final colors = pickerColors(_variants, selectedSizeId: _sizeId);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (_mode == VariantPickerMode.sizeColor ||
            _mode == VariantPickerMode.sizeOnly) ...[
          Text('Size', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final s in sizes)
                ChoiceChip(
                  key: Key('variant_size_${s.id}'),
                  label: Text(s.name),
                  selected: _sizeId == s.id,
                  onSelected: (_) {
                    setState(() {
                      _sizeId = s.id;
                      if (_mode == VariantPickerMode.sizeColor) {
                        _colorId = null;
                      }
                    });
                    _syncSelectionFromChips();
                  },
                ),
            ],
          ),
          const SizedBox(height: 16),
        ],
        if (_mode == VariantPickerMode.sizeColor ||
            _mode == VariantPickerMode.colorOnly) ...[
          Text('Color', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final c in colors)
                ChoiceChip(
                  key: Key('variant_color_${c.id}'),
                  label: Text(c.name),
                  selected: _colorId == c.id,
                  onSelected: _mode == VariantPickerMode.sizeColor &&
                          _sizeId == null
                      ? null
                      : (_) {
                          setState(() => _colorId = c.id);
                          _syncSelectionFromChips();
                        },
                ),
            ],
          ),
        ],
      ],
    );
  }
}
