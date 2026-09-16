import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../design_system/states/async_states.dart';
import '../../pos/application/pos_controllers.dart';
import '../../pos/domain/cart.dart';
import '../../pos/presentation/variant_picker_sheet.dart';
import '../application/field_order_controllers.dart';

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
        padding: const EdgeInsets.all(16),
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
                '${line.quantity} × ${line.unitPrice.toStringAsFixed(2)}',
              ),
              trailing: Text(line.lineTotal.toStringAsFixed(2)),
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
          padding: const EdgeInsets.all(16),
          child: CbPrimaryButton(
            key: const Key('fo_submit'),
            label: state.submitting ? 'Submitting…' : 'Submit to store',
            onPressed: state.canSubmit
                ? () => ref.read(fieldOrderCartProvider.notifier).submit()
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
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Text(
              'Building order for site #${widget.siteId}',
              style: Theme.of(context).textTheme.titleSmall,
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
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
              padding: const EdgeInsets.symmetric(horizontal: 16),
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
                            p.price.toStringAsFixed(2),
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
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                    itemCount: cart.lines.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (context, i) {
                      final line = cart.lines[i];
                      return ListTile(
                        key: Key('fo_line_${line.lineKey}'),
                        title: Text(line.displayName),
                        subtitle: Text(
                          '${line.quantity} × ${line.unitPrice.toStringAsFixed(2)}',
                        ),
                        trailing: Text(line.lineTotal.toStringAsFixed(2)),
                      );
                    },
                  ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
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
