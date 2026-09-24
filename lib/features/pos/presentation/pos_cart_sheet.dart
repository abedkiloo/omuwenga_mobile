import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../design_system/design_system.dart';
import '../application/pos_controllers.dart';
import '../domain/cart.dart';

String _kes(num value) => 'KES ${value.toStringAsFixed(2)}';

/// Opens a cart drawer for reviewing lines, editing qty, and starting checkout.
Future<void> showPosCartSheet({
  required BuildContext context,
  required VoidCallback onCheckout,
  Future<void> Function()? onClearCart,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: AppColors.background,
    builder: (context) => PosCartSheet(
      onCheckout: onCheckout,
      onClearCart: onClearCart,
    ),
  );
}

class PosCartSheet extends ConsumerWidget {
  const PosCartSheet({
    super.key,
    required this.onCheckout,
    this.onClearCart,
  });

  final VoidCallback onCheckout;
  final Future<void> Function()? onClearCart;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cart = ref.watch(cartControllerProvider);
    final theme = Theme.of(context);
    return SafeArea(
      child: CbSheetFrame(
        heightFactor: 0.88,
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 8, 8),
                child: Row(
                  children: [
                    const Icon(
                      Icons.shopping_cart_outlined,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Current cart',
                            key: const Key('pos_cart_sheet_title'),
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Text(
                            cart.isEmpty
                                ? 'No items yet — add products from the catalog'
                                : '${cart.itemCount} packs · ${cart.lines.length} SKUs'
                                      '${cart.customerName == null ? '' : ' · ${cart.customerName}'}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: AppColors.mutedForeground,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (!cart.isEmpty)
                      TextButton(
                        key: const Key('pos_cart_sheet_clear'),
                        onPressed: () async {
                          if (onClearCart != null) {
                            await onClearCart!();
                          } else {
                            ref.read(cartControllerProvider.notifier).clear();
                          }
                        },
                        child: const Text(
                          'Clear',
                          style: TextStyle(color: AppColors.destructive),
                        ),
                      ),
                    IconButton(
                      key: const Key('pos_cart_sheet_close'),
                      tooltip: 'Close cart',
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: cart.isEmpty
                    ? EmptyState(
                        key: const Key('pos_cart_sheet_empty'),
                        title: 'Cart is empty',
                        message:
                            'Tap products in the catalog to add them, then open the cart to edit quantities and check out.',
                        primaryLabel: 'Keep shopping',
                        onPrimary: () => Navigator.pop(context),
                      )
                    : ListView.separated(
                        key: const Key('pos_cart_sheet_list'),
                        padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                        itemCount: cart.lines.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final line = cart.lines[index];
                          return _CartSheetLine(
                            line: line,
                            onDec: () => ref
                                .read(cartControllerProvider.notifier)
                                .setQuantity(line.lineKey, line.quantity - 1),
                            onInc:
                                line.stockQuantity == null ||
                                    line.quantity >= line.stockQuantity!
                                ? null
                                : () => ref
                                      .read(cartControllerProvider.notifier)
                                      .setQuantity(
                                        line.lineKey,
                                        line.quantity + 1,
                                      ),
                            onRemove: () => ref
                                .read(cartControllerProvider.notifier)
                                .removeProduct(line.lineKey),
                          );
                        },
                      ),
              ),
              CbStickyActionBar(
                summary: cart.isEmpty
                    ? null
                    : '${cart.itemCount} packs · ${cart.lines.length} SKUs',
                summaryTrailing: cart.isEmpty ? null : _kes(cart.total),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (!cart.isEmpty) ...[
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'NET TOTAL',
                              style: theme.textTheme.labelMedium?.copyWith(
                                color: AppColors.mutedForeground,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          Text(
                            key: const Key('pos_cart_sheet_total'),
                            _kes(cart.total),
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                    ],
                    CbPrimaryButton(
                      key: const Key('pos_cart_sheet_checkout'),
                      label: cart.isEmpty
                          ? 'Add items to continue'
                          : 'Proceed to payment',
                      onPressed: cart.isEmpty
                          ? null
                          : () {
                              Navigator.pop(context);
                              onCheckout();
                            },
                    ),
                    if (cart.isEmpty) ...[
                      const SizedBox(height: 8),
                      TextButton(
                        key: const Key('pos_cart_sheet_keep_shopping'),
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Back to catalog'),
                      ),
                    ],
                  ],
                ),
              ),
            ],
        ),
      ),
    );
  }
}

class _CartSheetLine extends StatelessWidget {
  const _CartSheetLine({
    required this.line,
    required this.onDec,
    required this.onInc,
    required this.onRemove,
  });

  final CartLine line;
  final VoidCallback onDec;
  final VoidCallback? onInc;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final stock = line.stockQuantity;

    return CbSurfaceCard(
      key: Key('pos_cart_sheet_line_${line.lineKey}'),
      padding: const EdgeInsets.all(12),
      child: Column(
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
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (line.sku != null && line.sku!.isNotEmpty)
                      Text(
                        line.sku!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppColors.mutedForeground,
                        ),
                      ),
                    if (stock != null)
                      Text(
                        'Stock ${stock.round()}',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: AppColors.mutedForeground,
                        ),
                      ),
                  ],
                ),
              ),
              Text(
                _kes(line.lineTotal),
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _SheetQtyButton(
                key: Key('pos_cart_sheet_dec_${line.lineKey}'),
                icon: Icons.remove,
                onTap: onDec,
              ),
              Container(
                width: 44,
                height: 36,
                alignment: Alignment.center,
                margin: const EdgeInsets.symmetric(horizontal: 6),
                decoration: BoxDecoration(
                  color: AppColors.accentSoft,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  key: Key('pos_cart_sheet_qty_${line.lineKey}'),
                  line.quantity.round().toString(),
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              _SheetQtyButton(
                key: Key('pos_cart_sheet_inc_${line.lineKey}'),
                icon: Icons.add,
                onTap: onInc,
              ),
              const Spacer(),
              IconButton(
                key: Key('pos_cart_sheet_remove_${line.lineKey}'),
                tooltip: 'Remove item',
                onPressed: onRemove,
                icon: const Icon(
                  Icons.delete_outline,
                  color: AppColors.destructive,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SheetQtyButton extends StatelessWidget {
  const _SheetQtyButton({
    super.key,
    required this.icon,
    required this.onTap,
  });

  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: onTap == null ? AppColors.secondary : AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: AppColors.border),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: SizedBox(
          width: 36,
          height: 36,
          child: Icon(
            icon,
            size: 18,
            color: onTap == null
                ? AppColors.mutedForeground
                : AppColors.foreground,
          ),
        ),
      ),
    );
  }
}
