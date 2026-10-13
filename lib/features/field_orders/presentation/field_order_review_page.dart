import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/format/money.dart';
import '../../../core/theme/app_colors.dart';
import '../../../design_system/design_system.dart';
import '../../pos/application/pos_controllers.dart';
import '../../pos/domain/cart.dart';
import '../../pos/presentation/variant_picker_sheet.dart';
import '../application/field_order_controllers.dart';
import '../domain/field_order_commit.dart';

/// Review: site map/photos first, then lines, then submit.
class FieldOrderReviewPage extends ConsumerWidget {
  const FieldOrderReviewPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(fieldOrderCartProvider);
    final cart = state.cart;

    return Scaffold(
      appBar: AppBar(title: const Text('Review field order')),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Text('Site', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Container(
            key: const Key('fo_site_map'),
            height: 120,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.secondary,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              cart.latitude == null
                  ? 'No pin'
                  : '${cart.latitude!.toStringAsFixed(4)}, ${cart.longitude!.toStringAsFixed(4)}',
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 64,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: cart.photoUrls.isEmpty ? 1 : cart.photoUrls.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, i) {
                if (cart.photoUrls.isEmpty) {
                  return const SizedBox(
                    width: 64,
                    child: ColoredBox(
                      color: AppColors.secondary,
                      child: Icon(Icons.image_not_supported_outlined),
                    ),
                  );
                }
                return Container(
                  key: Key('fo_photo_$i'),
                  width: 64,
                  color: AppColors.secondary,
                  child: const Icon(Icons.image_outlined),
                );
              },
            ),
          ),
          const SizedBox(height: 16),
          Text(
            cart.siteLabel.isEmpty ? 'Site #${cart.siteId}' : cart.siteLabel,
          ),
          const SizedBox(height: 16),
          Text('Lines', style: Theme.of(context).textTheme.titleMedium),
          for (final line in cart.lines)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(line.displayName),
              subtitle: Text(
                '${line.quantity} × ${formatGroupedNumber(line.unitPrice)}',
              ),
              trailing: Text(formatGroupedNumber(line.lineTotal)),
            ),
          if (state.error != null)
            Text(
              state.error!,
              key: const Key('fo_submit_error'),
              style: const TextStyle(color: AppColors.destructive),
            ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: CbPrimaryButton(
            key: const Key('fo_submit'),
            label: state.submitting ? 'Submitting…' : 'Submit to store',
            onPressed: state.canSubmit
                ? () async {
                    final error = fieldOrderReviewError(cart);
                    if (error != null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(error)),
                      );
                      return;
                    }
                    final confirmed = await showCommitConfirm(
                      context: context,
                      title: 'Submit this field order?',
                      description:
                          'The store will pack it and mark it ready for pickup. Nothing is sent until you confirm.',
                      rows: fieldOrderReviewRows(cart),
                      confirmLabel: 'Confirm & send',
                      confirmKey: const Key('fo_submit_confirm'),
                      cancelKey: const Key('fo_submit_cancel'),
                    );
                    if (!confirmed || !context.mounted) return;
                    await ref.read(fieldOrderCartProvider.notifier).submit();
                  }
                : null,
          ),
        ),
      ),
    );
  }
}

/// Field order cart: search API catalog, add lines, then review.
class FieldOrderCartPage extends ConsumerStatefulWidget {
  const FieldOrderCartPage({super.key, required this.siteId});

  final int siteId;

  @override
  ConsumerState<FieldOrderCartPage> createState() => _FieldOrderCartPageState();
}

class _FieldOrderCartPageState extends ConsumerState<FieldOrderCartPage> {
  final _search = TextEditingController();
  List<CatalogProduct> _results = const [];
  bool _searching = false;
  String? _searchError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(fieldOrderCartProvider.notifier).bindSite(siteId: widget.siteId);
    });
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _runSearch([String? raw]) async {
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
    ref.read(fieldOrderCartProvider.notifier).bindSite(siteId: widget.siteId);
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
          .read(fieldOrderCartProvider.notifier)
          .addProduct(pick.product, variant: pick.variant, qty: pick.quantity);
    } else {
      ref.read(fieldOrderCartProvider.notifier).addProduct(product);
    }
    setState(() {
      _results = const [];
      _search.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(fieldOrderCartProvider);
    final cart = state.cart;

    return Scaffold(
      appBar: AppBar(title: const Text('Field order cart')),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            child: Text(
              'Building order for site #${widget.siteId}',
              style: Theme.of(context).textTheme.titleSmall,
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              key: const Key('fo_search'),
              controller: _search,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                labelText: 'Search products',
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  key: const Key('fo_search_button'),
                  tooltip: 'Search',
                  icon: const Icon(Icons.search),
                  onPressed: _searching ? null : () => _runSearch(),
                ),
              ),
              onSubmitted: _runSearch,
            ),
          ),
          if (_searching) const LinearProgressIndicator(minHeight: 2),
          if (_searchError != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                _searchError!,
                key: const Key('fo_search_error'),
                style: const TextStyle(color: AppColors.destructive),
              ),
            ),
          Expanded(
            child: _results.isNotEmpty
                ? ListView.separated(
                    key: const Key('fo_search_results'),
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    itemCount: _results.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (context, i) {
                      final p = _results[i];
                      return ListTile(
                        key: Key('fo_product_${p.id}'),
                        title: Text(p.name),
                        subtitle: Text(
                          [
                            if (p.hasVariants) 'Has variants',
                            if (p.sku != null && p.sku!.isNotEmpty) p.sku!,
                            formatGroupedNumber(p.price),
                          ].join(' · '),
                        ),
                        trailing: Icon(
                          p.hasVariants
                              ? Icons.layers_outlined
                              : Icons.add_circle_outline,
                        ),
                        onTap: () => _selectProduct(p),
                      );
                    },
                  )
                : cart.lines.isEmpty
                ? EmptyState(
                    key: const Key('fo_empty_cart'),
                    title: 'No products yet',
                    message: 'Search the catalog and tap a product to add it.',
                    primaryLabel: 'Focus search',
                    onPrimary: () {},
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
                    itemCount: cart.lines.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, i) {
                      final line = cart.lines[i];
                      return _FieldOrderLineCard(
                        line: line,
                        onSetQuantity: (qty) => ref
                            .read(fieldOrderCartProvider.notifier)
                            .setQuantity(line.lineKey, qty),
                        onSetPrice: (raw) {
                          final parsed = double.tryParse(raw.trim());
                          final error = ref
                              .read(fieldOrderCartProvider.notifier)
                              .setUnitPrice(
                                line.lineKey,
                                parsed ?? double.nan,
                              );
                          if (error != null && context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(error)),
                            );
                          }
                        },
                        onRemove: () => ref
                            .read(fieldOrderCartProvider.notifier)
                            .removeLine(line.lineKey),
                      );
                    },
                  ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: CbPrimaryButton(
            key: const Key('fo_to_review'),
            label: 'Review',
            onPressed: cart.lines.isEmpty
                ? null
                : () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const FieldOrderReviewPage(),
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

class _FieldOrderLineCard extends StatefulWidget {
  const _FieldOrderLineCard({
    required this.line,
    required this.onSetQuantity,
    required this.onSetPrice,
    required this.onRemove,
  });

  final CartLine line;
  final ValueChanged<double> onSetQuantity;
  final ValueChanged<String> onSetPrice;
  final VoidCallback onRemove;

  @override
  State<_FieldOrderLineCard> createState() => _FieldOrderLineCardState();
}

class _FieldOrderLineCardState extends State<_FieldOrderLineCard> {
  late final TextEditingController _priceController;

  @override
  void initState() {
    super.initState();
    _priceController = TextEditingController(
      text: _formatPrice(widget.line.unitPrice),
    );
  }

  @override
  void didUpdateWidget(covariant _FieldOrderLineCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.line.unitPrice != widget.line.unitPrice) {
      final next = _formatPrice(widget.line.unitPrice);
      if (_priceController.text != next) {
        _priceController.text = next;
      }
    }
  }

  @override
  void dispose() {
    _priceController.dispose();
    super.dispose();
  }

  String _formatPrice(double value) {
    if (value.truncateToDouble() == value) {
      return value.toStringAsFixed(0);
    }
    return value.toStringAsFixed(2);
  }

  void _commitPrice() {
    widget.onSetPrice(_priceController.text);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _priceController.text = _formatPrice(widget.line.unitPrice);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final line = widget.line;
    final markedUp = line.unitPrice > line.catalogPrice + 0.009;

    return Card(
      key: Key('fo_line_${line.lineKey}'),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
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
                      if (markedUp)
                        Text(
                          'Custom price',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                    ],
                  ),
                ),
                Text(
                  formatKes(line.lineTotal),
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                IconButton(
                  onPressed: widget.onRemove,
                  icon: const Icon(
                    Icons.delete_outline,
                    color: AppColors.destructive,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Text(
                  '@',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: AppColors.mutedForeground,
                  ),
                ),
                const SizedBox(width: 4),
                SizedBox(
                  width: 88,
                  height: 36,
                  child: TextField(
                    key: Key('fo_line_price_${line.lineKey}'),
                    controller: _priceController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    textAlign: TextAlign.right,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                    decoration: InputDecoration(
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 8,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      hintText: _formatPrice(line.catalogPrice),
                    ),
                    onEditingComplete: _commitPrice,
                    onSubmitted: (_) => _commitPrice(),
                    onTapOutside: (_) => _commitPrice(),
                  ),
                ),
                const Spacer(),
                CbQtyStepper(
                  quantity: line.quantity,
                  min: 0,
                  max: line.stockQuantity,
                  onChanged: widget.onSetQuantity,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
