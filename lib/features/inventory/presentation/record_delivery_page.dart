import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../design_system/chrome/cb_commit_confirm.dart';
import '../../auth/application/auth_controller.dart';
import '../../pos/application/pos_controllers.dart';
import '../../pos/domain/cart.dart';
import '../data/stock_purchase_api.dart';
import '../domain/delivery_payload.dart';

final stockPurchaseApiProvider = Provider<StockPurchaseApi>((ref) {
  return StockPurchaseApi(ref.watch(apiClientProvider));
});

/// Record a delivery: new price until the person chooses the current price.
class RecordDeliveryPage extends ConsumerStatefulWidget {
  const RecordDeliveryPage({super.key});

  @override
  ConsumerState<RecordDeliveryPage> createState() => _RecordDeliveryPageState();
}

class _RecordDeliveryPageState extends ConsumerState<RecordDeliveryPage> {
  final _search = TextEditingController();
  final _qty = TextEditingController(text: '1');
  final _sell = TextEditingController();
  final _mrp = TextEditingController();
  List<CatalogProduct> _results = const [];
  CatalogProduct? _product;
  bool _newPrice = true;
  bool _saving = false;
  List<DeliveryLayer> _layers = const [];
  final _costs = <int, TextEditingController>{};
  final _prices = <int, TextEditingController>{};

  bool get _priceMissing => _newPrice && _sell.text.trim().isEmpty;

  @override
  void dispose() {
    _search.dispose();
    _qty.dispose();
    _sell.dispose();
    _mrp.dispose();
    for (final c in _costs.values) {
      c.dispose();
    }
    for (final c in _prices.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _searchProducts() async {
    final result = await ref.read(posApiProvider).searchProducts(_search.text);
    if (!mounted) return;
    result.when(
      success: (rows) => setState(() => _results = rows),
      failure: (e, _) => _toast(e.toString()),
    );
  }

  Future<void> _choose(CatalogProduct product) async {
    setState(() {
      _product = product;
      _results = const [];
      _newPrice = true;
      _sell.clear();
      _mrp.clear();
    });
    final layers = await ref.read(stockPurchaseApiProvider).pendingPrices(product.id);
    if (!mounted) return;
    layers.when(
      success: (rows) => setState(() => _layers = rows),
      failure: (_, _) => setState(() => _layers = const []),
    );
  }

  Future<void> _save() async {
    final product = _product;
    final qty = int.tryParse(_qty.text.trim()) ?? 0;
    if (product == null || qty < 1) {
      _toast('Choose a product and a quantity of at least 1.');
      return;
    }
    final selling = _sell.text.trim();
    final mrp = _mrp.text.trim();
    final confirmed = await showCommitConfirm(
      context: context,
      title: 'Save this delivery?',
      description: 'Check what you entered, then save.',
      confirmLabel: 'Save',
      rows: [
        CommitSummaryRow(label: 'Product', value: product.name, emphasis: true),
        CommitSummaryRow(label: 'Quantity', value: '$qty', emphasis: true),
        CommitSummaryRow(
          label: 'Price choice',
          value: _newPrice ? 'New price' : 'Old price',
        ),
        CommitSummaryRow(
          label: 'Selling price',
          value: !_newPrice
              ? 'Current price'
              : (selling.isEmpty
                  ? CatalogProduct.newSalePriceUnsetLabel
                  : selling),
        ),
        if (_newPrice && mrp.isNotEmpty) CommitSummaryRow(label: 'MRP', value: mrp),
      ],
    );
    if (!confirmed || !mounted) return;
    setState(() => _saving = true);
    final result = await ref.read(stockPurchaseApiProvider).record(
          deliveryWriteBody(
            productId: product.id,
            quantity: qty,
            newPrice: _newPrice,
            sellingPrice: _sell.text,
            mrp: _mrp.text,
          ),
        );
    if (!mounted) return;
    setState(() => _saving = false);
    result.when(
      success: (_) {
        _toast(
          _priceMissing
              ? CatalogProduct.newSalePriceUnsetLabel
              : 'Delivery recorded.',
        );
        _choose(product);
      },
      failure: (e, _) => _toast(e.toString()),
    );
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final superAdmin =
        ref.watch(authControllerProvider).session?.user.isSuperuser ?? false;
    return Scaffold(
      appBar: AppBar(title: const Text('Record delivery')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            key: const Key('delivery_search'),
            controller: _search,
            decoration: const InputDecoration(
              labelText: 'Product',
              border: OutlineInputBorder(),
            ),
            onSubmitted: (_) => _searchProducts(),
          ),
          const SizedBox(height: 8),
          for (final product in _results)
            ListTile(
              key: Key('delivery_product_${product.id}'),
              title: Text(product.name),
              subtitle: product.newSalePriceUnset
                  ? const Text(CatalogProduct.newSalePriceUnsetLabel)
                  : null,
              onTap: () => _choose(product),
            ),
          if (_product != null) ...[
            const SizedBox(height: 12),
            Text(_product!.name, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            TextField(
              key: const Key('delivery_qty'),
              controller: _qty,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Quantity',
                border: OutlineInputBorder(),
              ),
            ),
            SegmentedButton<bool>(
              key: const Key('delivery_price_mode'),
              segments: const [
                ButtonSegment(value: true, label: Text('New price')),
                ButtonSegment(value: false, label: Text('Old price')),
              ],
              selected: {_newPrice},
              onSelectionChanged: (next) => setState(() => _newPrice = next.first),
            ),
            if (_newPrice) ...[
              TextField(
                key: const Key('delivery_sell'),
                controller: _sell,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'New selling price',
                  border: OutlineInputBorder(),
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _mrp,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'New MRP (optional)',
                  border: OutlineInputBorder(),
                ),
              ),
              if (_priceMissing)
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Text(
                    CatalogProduct.newSalePriceUnsetLabel,
                    key: Key('delivery_price_unset'),
                    style: TextStyle(
                      color: Color(0xFFB45309),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
            const SizedBox(height: 12),
            FilledButton(
              key: const Key('delivery_save'),
              onPressed: _saving ? null : _save,
              child: Text(_saving ? 'Saving…' : 'Review and save'),
            ),
            for (final layer in _layers.where((row) => row.salePricePending)) ...[
              const SizedBox(height: 12),
              Text('${layer.quantity} pieces. ${CatalogProduct.newSalePriceUnsetLabel}'),
              TextField(
                controller: _prices.putIfAbsent(layer.layerId, TextEditingController.new),
                decoration: const InputDecoration(labelText: 'Selling price'),
              ),
              OutlinedButton(
                onPressed: () async {
                  final raw = _prices[layer.layerId]?.text ?? '';
                  final saved = await ref.read(stockPurchaseApiProvider).setSalePrice(
                        layerId: layer.layerId,
                        unitSellPrice: raw,
                      );
                  if (!mounted) return;
                  saved.when(
                    success: (_) => _toast('Selling price saved. These pieces can be sold.'),
                    failure: (e, _) => _toast(e.toString()),
                  );
                },
                child: const Text('Save price'),
              ),
            ],
            if (superAdmin)
              for (final layer in _layers) ...[
                const SizedBox(height: 8),
                Text('Cost for ${layer.quantity} pieces still in stock'),
                TextField(
                  controller: _costs.putIfAbsent(layer.layerId, TextEditingController.new),
                  decoration: InputDecoration(
                    labelText: layer.unitCost == null ? 'Cost' : 'Cost (now ${layer.unitCost})',
                  ),
                ),
                OutlinedButton(
                  onPressed: () async {
                    final raw = _costs[layer.layerId]?.text ?? '';
                    final saved = await ref.read(stockPurchaseApiProvider).setLayerCost(
                          layerId: layer.layerId,
                          unitCost: raw,
                        );
                    if (!mounted) return;
                    saved.when(
                      success: (_) => _toast('Cost saved for the pieces still in stock.'),
                      failure: (e, _) => _toast(e.toString()),
                    );
                  },
                  child: const Text('Save cost'),
                ),
              ],
          ],
        ],
      ),
    );
  }
}
