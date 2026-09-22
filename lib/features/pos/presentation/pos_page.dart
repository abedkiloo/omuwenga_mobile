import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../design_system/design_system.dart';
import '../../auth/application/auth_controller.dart';
import '../../customers/presentation/customer_picker_sheet.dart';
import '../../payments/presentation/stk_wait_page.dart';
import '../application/pos_controllers.dart';
import '../application/product_catalog_paging.dart';
import '../data/pos_api.dart';
import '../domain/cart.dart';
import '../domain/payment.dart';
import '../domain/pos_commit.dart';
import 'receipt_page.dart';
import 'pos_cart_sheet.dart';
import 'variant_picker_sheet.dart';

String _kes(num value) => 'KES ${value.toStringAsFixed(2)}';

class PosPage extends ConsumerStatefulWidget {
  const PosPage({super.key});

  @override
  ConsumerState<PosPage> createState() => _PosPageState();
}

class _PosPageState extends ConsumerState<PosPage> {
  final _search = TextEditingController();
  final _searchFocus = FocusNode();
  final _catalogScroll = ScrollController();
  final _catalog = ProductCatalogPaging();
  List<ProductCategory> _categories = const [];
  bool _chromeCollapsed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await Future.wait([_loadCatalog(), _loadCategories()]);
    });
  }

  @override
  void dispose() {
    _search.dispose();
    _searchFocus.dispose();
    _catalogScroll.dispose();
    super.dispose();
  }

  Future<void> _loadCategories() async {
    final result = await ref.read(posApiProvider).listCategories();
    if (!mounted) return;
    result.when(
      success: (list) => setState(() => _categories = list),
      failure: (_, _) {},
    );
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

  Future<void> _selectCategory(int? id) async {
    await _catalog.setCategory(
      ref.read(posApiProvider),
      categoryId: id,
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
    handleChromeScrollCollapse(
      notification: notification,
      collapsed: _chromeCollapsed,
      setCollapsed: (value) {
        if (_chromeCollapsed == value) return;
        setState(() => _chromeCollapsed = value);
      },
    );
    if (notification.metrics.extentAfter < 240) {
      _loadMore();
    }
    return false;
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
      final stock = pick.variant.stockQuantity;
      if (stock == null || stock <= 0 || pick.quantity > stock) {
        _showStockUnavailable(pick.variant.sku ?? pick.product.name);
        return;
      }
      ref
          .read(cartControllerProvider.notifier)
          .addProduct(pick.product, variant: pick.variant, qty: pick.quantity);
    } else {
      final stock = product.stockQuantity;
      if (stock == null || stock <= 0) {
        _showStockUnavailable(product.sku ?? product.name);
        return;
      }
      ref.read(cartControllerProvider.notifier).addProduct(product);
    }
  }

  void _showStockUnavailable(String product) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('$product has no available stock.')));
  }

  Future<void> _confirmClearCart() async {
    final clear = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear current sale?'),
        content: const Text(
          'This removes every item and customer from the current cart.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep sale'),
          ),
          FilledButton(
            key: const Key('pos_clear_confirm'),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Clear sale'),
          ),
        ],
      ),
    );
    if (clear == true) {
      ref.read(cartControllerProvider.notifier).clear();
    }
  }

  Future<bool> _confirmLeave() async {
    final cart = ref.read(cartControllerProvider);
    if (!cart.isDirty) return true;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Leave sale?'),
        content: const Text('Your cart has items. Leave without checking out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Stay'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Leave'),
          ),
        ],
      ),
    );
    return ok ?? false;
  }

  Future<void> _openCartSheet() async {
    await showPosCartSheet(
      context: context,
      onCheckout: _openPay,
      onClearCart: _confirmClearCart,
    );
  }

  Future<void> _openPay() async {
    final cart = ref.read(cartControllerProvider);
    final settings = ref
        .read(posSettingsProvider)
        .maybeWhen(data: (s) => s, orElse: () => const PosSettings());
    if (cart.isEmpty) return;

    final methods = settings.enabledPaymentMethods;
    final method = methods.isEmpty ? PosPaymentMethod.cash : methods.first;
    ref
        .read(checkoutControllerProvider.notifier)
        .setDraft(CheckoutDraft(method: method, amountPaid: cart.total));

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: AppColors.background,
      builder: (context) => const _PaySheet(),
    );

    final checkout = ref.read(checkoutControllerProvider);
    if (!mounted) return;
    if (checkout.phase == CheckoutPhase.success ||
        checkout.phase == CheckoutPhase.queued) {
      final receipt = checkout.receipt;
      if (receipt != null) {
        await Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => ReceiptPage(receipt: receipt),
          ),
        );
        ref.read(checkoutControllerProvider.notifier).resetPhase();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cart = ref.watch(cartControllerProvider);
    final settingsAsync = ref.watch(posSettingsProvider);
    final session = ref.watch(authControllerProvider).session;
    final theme = Theme.of(context);
    final userName = session?.user.displayName ?? 'Cashier';
    final roleLabel =
        session?.profile.roleDisplay ?? session?.profile.role ?? 'Cashier';

    return PopScope(
      canPop: !cart.isDirty,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (await _confirmLeave() && context.mounted) {
          ref.read(cartControllerProvider.notifier).clear();
          final router = GoRouter.maybeOf(context);
          if (router != null) {
            context.go(AppRoutes.home);
          } else {
            Navigator.of(context).maybePop();
          }
        }
      },
      child: Scaffold(
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
                collapsedLabel: 'Sale header & customer',
                collapsedSummary: cart.isEmpty
                    ? userName
                    : '${cart.itemCount} items · ${_kes(cart.total)}'
                          '${cart.customerName == null ? '' : ' · ${cart.customerName}'}',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                      child: _PosHeaderCard(
                        userName: userName,
                        roleLabel: roleLabel,
                        cartItemCount: cart.itemCount,
                        onCartTap: _openCartSheet,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                      child: _CustomerStrip(
                        cart: cart,
                        settingsAsync: settingsAsync,
                        onPickCustomer: () =>
                            showCustomerPickerSheet(context, ref),
                        onClearCustomer: () => ref
                            .read(cartControllerProvider.notifier)
                            .clearCustomer(),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 6, 12, 0),
                child: _PosSearchRow(
                  controller: _search,
                  focusNode: _searchFocus,
                  onSubmitted: _loadCatalog,
                  onSearchTap: _catalog.loading ? null : () => _loadCatalog(),
                ),
              ),
              if (_categories.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: SizedBox(
                    height: 36,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      children: [
                        _CategoryChip(
                          label: 'All',
                          count: null,
                          selected: _catalog.categoryId == null,
                          onTap: () => _selectCategory(null),
                        ),
                        const SizedBox(width: 8),
                        for (final c in _categories) ...[
                          _CategoryChip(
                            label: c.name,
                            count: c.productCount > 0 ? c.productCount : null,
                            selected: _catalog.categoryId == c.id,
                            onTap: () => _selectCategory(c.id),
                          ),
                          const SizedBox(width: 8),
                        ],
                      ],
                    ),
                  ),
                ),
              if (_catalog.loading && _catalog.items.isEmpty)
                const LinearProgressIndicator(minHeight: 2),
              if (_catalog.error != null)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: Text(
                    _catalog.error!,
                    style: const TextStyle(color: AppColors.destructive),
                  ),
                ),
              Expanded(
                child: NotificationListener<ScrollNotification>(
                  onNotification: _onScroll,
                  child: ListView(
                    key: const Key('pos_catalog_scroll'),
                    controller: _catalogScroll,
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                    children: [
                      if (!cart.isEmpty) ...[
                        Row(
                          children: [
                            Text(
                              'Active Cart Items',
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(width: 8),
                            CbStatusPill(
                              label: '${cart.lines.length} SKUs',
                              variant: CbStatusPillVariant.info,
                            ),
                            const Spacer(),
                            TextButton.icon(
                              key: const Key('pos_clear_cart'),
                              onPressed: _confirmClearCart,
                              icon: const Icon(
                                Icons.delete_outline,
                                size: 18,
                                color: AppColors.destructive,
                              ),
                              label: const Text(
                                'Clear',
                                style: TextStyle(color: AppColors.destructive),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        for (final line in cart.lines) ...[
                          _CartLineCard(
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
                          ),
                          const SizedBox(height: 8),
                        ],
                        const SizedBox(height: 8),
                      ],
                      Text(
                        _catalog.query.isEmpty && _catalog.categoryId == null
                            ? 'Products'
                            : 'Catalog',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (_catalog.isEmpty && !_catalog.loading)
                        EmptyState(
                          key: const Key('pos_empty_cart'),
                          title: _catalog.query.isEmpty
                              ? 'No products yet'
                              : 'No matches',
                          message: _catalog.query.isEmpty
                              ? 'Products will show here once the catalog is available.'
                              : 'Try another SKU, brand, or barcode.',
                          primaryLabel: 'Search products',
                          onPrimary: () => _searchFocus.requestFocus(),
                        )
                      else
                        for (final p in _catalog.items) ...[
                          _CatalogProductCard(
                            product: p,
                            onTap:
                                p.hasVariants ||
                                    (p.stockQuantity != null &&
                                        p.stockQuantity! > 0)
                                ? () => _selectProduct(p)
                                : null,
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
              CbStickyActionBar(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'SUBTOTAL (${cart.lines.fold<double>(0, (s, l) => s + l.quantity).round()} PACKS)',
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: AppColors.mutedForeground,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          _kes(cart.total),
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'NET TOTAL DUE',
                                style: theme.textTheme.labelMedium?.copyWith(
                                  color: AppColors.mutedForeground,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              Text(
                                key: const Key('pos_total'),
                                _kes(cart.total),
                                style: theme.textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.primary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        SizedBox(
                          width: 140,
                          child: CbPrimaryButton(
                            key: const Key('pos_pay'),
                            label: 'Proceed',
                            onPressed: cart.isEmpty ? null : _openPay,
                          ),
                        ),
                      ],
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
}

class _PosHeaderCard extends StatelessWidget {
  const _PosHeaderCard({
    required this.userName,
    required this.roleLabel,
    required this.cartItemCount,
    required this.onCartTap,
  });

  final String userName;
  final String roleLabel;
  final int cartItemCount;
  final VoidCallback? onCartTap;

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
          const SizedBox(width: 8),
          Stack(
            clipBehavior: Clip.none,
            children: [
              IconButton(
                key: const Key('pos_cart_icon'),
                tooltip: 'Current cart',
                onPressed: onCartTap,
                icon: const Icon(
                  Icons.shopping_cart_outlined,
                  color: AppColors.primary,
                ),
              ),
              if (cartItemCount > 0)
                Positioned(
                  right: 2,
                  top: 0,
                  child: Container(
                    constraints: const BoxConstraints(
                      minWidth: 18,
                      minHeight: 18,
                    ),
                    alignment: Alignment.center,
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: const BoxDecoration(
                      color: AppColors.destructive,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      cartItemCount > 99 ? '99+' : '$cartItemCount',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const CircleAvatar(
            radius: 16,
            backgroundColor: AppColors.primary,
            child: Icon(Icons.person, size: 16, color: Colors.white),
          ),
        ],
      ),
    );
  }
}

class _PosSearchRow extends StatelessWidget {
  const _PosSearchRow({
    required this.controller,
    required this.focusNode,
    required this.onSubmitted,
    required this.onSearchTap,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onSubmitted;
  final VoidCallback? onSearchTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            key: const Key('pos_search'),
            controller: controller,
            focusNode: focusNode,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: 'Search SKU, Brand or Scan…',
              prefixIcon: const Icon(
                Icons.search,
                color: AppColors.mutedForeground,
              ),
              filled: true,
              fillColor: AppColors.surface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppColors.radius),
                borderSide: const BorderSide(color: AppColors.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppColors.radius),
                borderSide: const BorderSide(color: AppColors.border),
              ),
            ),
            onSubmitted: onSubmitted,
          ),
        ),
        const SizedBox(width: 8),
        Material(
          color: AppColors.accentSoft,
          borderRadius: BorderRadius.circular(AppColors.radius),
          child: InkWell(
            key: const Key('pos_search_button'),
            onTap: onSearchTap,
            borderRadius: BorderRadius.circular(AppColors.radius),
            child: const SizedBox(
              width: 48,
              height: 48,
              child: Icon(Icons.qr_code_scanner, color: AppColors.primary),
            ),
          ),
        ),
      ],
    );
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.count,
  });

  final String label;
  final int? count;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final text = count == null ? label : '$label $count';
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
            text,
            style: theme.textTheme.labelMedium?.copyWith(
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

class _CartLineCard extends StatelessWidget {
  const _CartLineCard({
    required this.line,
    required this.onDec,
    required this.onInc,
  });

  final CartLine line;
  final VoidCallback onDec;
  final VoidCallback? onInc;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final stock = line.stockQuantity;
    final lowStock = stock != null && stock > 0 && stock <= 50;

    return CbSurfaceCard(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: AppColors.accentSoft,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.inventory_2_outlined,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 10),
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
                    if (line.sku != null && line.sku!.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        line.sku!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppColors.mutedForeground,
                        ),
                      ),
                    ],
                    if (stock != null) ...[
                      const SizedBox(height: 6),
                      CbStatusPill(
                        label: 'Stock ${stock.round()}',
                        variant: lowStock
                            ? CbStatusPillVariant.warning
                            : CbStatusPillVariant.success,
                      ),
                    ],
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    _kes(line.lineTotal),
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
                  ),
                  Text(
                    '@ ${line.unitPrice.toStringAsFixed(2)}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppColors.mutedForeground,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Text(
                'Unit Qty',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: AppColors.mutedForeground,
                ),
              ),
              const Spacer(),
              _QtyButton(
                key: Key('pos_dec_${line.lineKey}'),
                icon: Icons.remove,
                onTap: onDec,
              ),
              Container(
                width: 40,
                height: 36,
                alignment: Alignment.center,
                margin: const EdgeInsets.symmetric(horizontal: 6),
                decoration: BoxDecoration(
                  color: AppColors.accentSoft,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  line.quantity.round().toString(),
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              _QtyButton(
                key: Key('pos_inc_${line.lineKey}'),
                icon: Icons.add,
                onTap: onInc,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CatalogProductCard extends StatelessWidget {
  const _CatalogProductCard({required this.product, required this.onTap});

  final CatalogProduct product;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final stock = product.stockQuantity;
    final lowStock = stock != null && stock > 0 && stock <= 50;
    final unavailable = !product.hasVariants && (stock == null || stock <= 0);

    return CbSurfaceCard(
      key: Key('pos_product_card_${product.id}'),
      padding: const EdgeInsets.all(12),
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.accentSoft,
              borderRadius: BorderRadius.circular(10),
            ),
            clipBehavior: Clip.antiAlias,
            child: product.imageUrl != null && product.imageUrl!.isNotEmpty
                ? Image.network(
                    product.imageUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => const Icon(
                      Icons.inventory_2_outlined,
                      color: AppColors.primary,
                    ),
                  )
                : const Icon(
                    Icons.inventory_2_outlined,
                    color: AppColors.primary,
                  ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product.name,
                  key: Key('pos_product_${product.id}'),
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  [
                    if (product.hasVariants) 'Has variants',
                    if (product.sku != null && product.sku!.isNotEmpty)
                      product.sku!,
                    if (product.unit != null && product.unit!.isNotEmpty)
                      product.unit!,
                  ].where((s) => s.isNotEmpty).join(' · '),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.mutedForeground,
                  ),
                ),
                if (unavailable) ...[
                  const SizedBox(height: 6),
                  const CbStatusPill(
                    label: 'Stock unavailable',
                    variant: CbStatusPillVariant.neutral,
                  ),
                ] else if (stock != null) ...[
                  const SizedBox(height: 6),
                  CbStatusPill(
                    label: 'Stock ${stock.round()}',
                    variant: lowStock
                        ? CbStatusPillVariant.warning
                        : CbStatusPillVariant.success,
                  ),
                ],
              ],
            ),
          ),
          Text(
            _kes(product.price),
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(width: 4),
          Icon(
            product.hasVariants
                ? Icons.layers_outlined
                : Icons.add_circle_outline,
            color: unavailable ? AppColors.mutedForeground : AppColors.primary,
          ),
        ],
      ),
    );
  }
}

class _QtyButton extends StatelessWidget {
  const _QtyButton({super.key, required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: onTap == null ? AppColors.background : AppColors.surface,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.border),
          ),
          child: Icon(
            icon,
            size: 18,
            color: onTap == null
                ? AppColors.mutedForeground
                : AppColors.primary,
          ),
        ),
      ),
    );
  }
}

class _CustomerStrip extends StatelessWidget {
  const _CustomerStrip({
    required this.cart,
    required this.settingsAsync,
    required this.onPickCustomer,
    required this.onClearCustomer,
  });

  final PosCart cart;
  final AsyncValue<PosSettings> settingsAsync;
  final VoidCallback onPickCustomer;
  final VoidCallback onClearCustomer;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasCustomer = cart.customerId != null;
    final customerLabel = hasCustomer
        ? cart.customerName ?? 'Customer'
        : 'No customer assigned';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.accentSoft,
        borderRadius: BorderRadius.circular(AppColors.radius),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: const BoxDecoration(
              color: AppColors.surface,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.storefront_outlined,
              color: AppColors.primary,
              size: 18,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  hasCustomer ? 'CUSTOMER' : 'ASSIGN CUSTOMER',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
                Text(
                  key: const Key('pos_customer_label'),
                  customerLabel,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (!hasCustomer)
                  settingsAsync.maybeWhen(
                    data: (s) => s.requireCustomer
                        ? Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              'Customer required before pay',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: AppColors.warning,
                              ),
                            ),
                          )
                        : const SizedBox.shrink(),
                    orElse: () => const SizedBox.shrink(),
                  ),
              ],
            ),
          ),
          OutlinedButton(
            key: const Key('pos_add_customer'),
            onPressed: onPickCustomer,
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.primary,
              side: const BorderSide(color: AppColors.primary),
              backgroundColor: AppColors.surface,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(hasCustomer ? 'Change customer' : 'Select customer'),
                const SizedBox(width: 4),
                const Icon(Icons.keyboard_arrow_down, size: 18),
              ],
            ),
          ),
          if (hasCustomer)
            IconButton(
              key: const Key('pos_clear_customer'),
              tooltip: 'Clear customer',
              onPressed: onClearCustomer,
              icon: const Icon(Icons.close),
            ),
        ],
      ),
    );
  }
}

class _PaySheet extends ConsumerStatefulWidget {
  const _PaySheet();

  @override
  ConsumerState<_PaySheet> createState() => _PaySheetState();
}

class _PaySheetState extends ConsumerState<_PaySheet> {
  late final TextEditingController _amount;
  late final TextEditingController _reference;
  late final TextEditingController _phone;

  @override
  void initState() {
    super.initState();
    final cart = ref.read(cartControllerProvider);
    final draft = ref.read(checkoutControllerProvider).draft;
    final initial = draft.amountPaid > 0 ? draft.amountPaid : cart.total;
    _amount = TextEditingController(text: initial.toStringAsFixed(2));
    _reference = TextEditingController(text: draft.paymentReference);
    _phone = TextEditingController();
  }

  @override
  void dispose() {
    _amount.dispose();
    _reference.dispose();
    _phone.dispose();
    super.dispose();
  }

  void _pushDraft({PosPaymentMethod? method, bool? paymentOnAccount}) {
    final checkout = ref.read(checkoutControllerProvider);
    final amount = double.tryParse(_amount.text) ?? 0;
    ref
        .read(checkoutControllerProvider.notifier)
        .setDraft(
          CheckoutDraft(
            method: method ?? checkout.draft.method,
            amountPaid: amount,
            paymentReference: _reference.text,
            paymentOnAccount:
                paymentOnAccount ?? checkout.draft.paymentOnAccount,
          ),
        );
  }

  void _setPaid(double amount) {
    _amount.text = amount.toStringAsFixed(2);
    _pushDraft();
  }

  void _payFullAmountLater() {
    _amount.text = '0.00';
    _pushDraft(paymentOnAccount: true);
  }

  Future<bool?> _confirmCloseSale({
    required PosCart cart,
    required CheckoutKind kind,
    required double paid,
  }) {
    final balance = accountBalanceDue(cart.total, paid);
    final title = switch (kind) {
      CheckoutKind.payLater => 'Record full amount as pay later?',
      CheckoutKind.partial => 'Record balance as debt?',
      CheckoutKind.full => 'Confirm and close sale?',
    };
    final confirm = switch (kind) {
      CheckoutKind.payLater => 'Record sale — pay later',
      CheckoutKind.partial => 'Record sale & debt',
      CheckoutKind.full => 'Confirm & close sale',
    };
    final body = switch (kind) {
      CheckoutKind.payLater =>
        'No payment is collected now. The full ${ _kes(cart.total) } will be added to ${cart.customerName ?? 'the customer'}\'s account.',
      CheckoutKind.partial =>
        'Collected ${ _kes(paid) } now. Balance ${ _kes(balance) } will be added to ${cart.customerName ?? 'the customer'}\'s account.',
      CheckoutKind.full =>
        'Confirm payment of ${_kes(cart.total)} and record this sale. '
            'Choose Back to sale if you need to change any item first.',
    };
    return showCommitConfirm(
      context: context,
      title: title,
      description: body,
      rows: posCloseSaleRows(cart: cart, kind: kind, paid: paid),
      confirmLabel: confirm,
      cancelLabel: 'Back to sale',
      confirmKey: const Key('pos_close_sale_confirm'),
      cancelKey: const Key('pos_review_cart'),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cart = ref.watch(cartControllerProvider);
    final checkout = ref.watch(checkoutControllerProvider);
    final settings = ref
        .watch(posSettingsProvider)
        .maybeWhen(data: (s) => s, orElse: () => const PosSettings());
    final draft = checkout.draft;
    final valid = canSubmitCheckout(
      cart: cart,
      settings: settings,
      draft: draft,
    );
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    final theme = Theme.of(context);
    final amountPaid = double.tryParse(_amount.text) ?? 0;
    final changeDue = amountPaid > cart.total ? amountPaid - cart.total : 0.0;
    final isMpesa = draft.method == PosPaymentMethod.mpesa;
    final customerLabel = cart.customerName ?? 'No customer';

    final kind = checkoutKind(total: cart.total, paid: amountPaid);
    final balanceDue = accountBalanceDue(cart.total, amountPaid);
    final showAccount =
        settings.allowPartialPayment &&
        (draft.method == PosPaymentMethod.cash ||
            draft.method == PosPaymentMethod.mpesa);
    final collectNow = kind != CheckoutKind.payLater;
    final needsStk = isMpesa && collectNow;

    String confirmLabel;
    if (checkout.phase == CheckoutPhase.submitting) {
      confirmLabel = 'Processing…';
    } else if (kind == CheckoutKind.payLater) {
      confirmLabel = 'Pay later — ${_kes(cart.total)}';
    } else if (kind == CheckoutKind.partial) {
      confirmLabel =
          'Pay ${_kes(amountPaid)} · debt ${_kes(balanceDue)}';
    } else if (needsStk) {
      confirmLabel = 'Send STK Push';
    } else {
      confirmLabel = 'Confirm Payment - ${_kes(cart.total)}';
    }

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, 16 + bottom),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                IconButton(
                  key: const Key('pos_pay_back'),
                  tooltip: 'Back to sale',
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.arrow_back),
                ),
                Expanded(
                  child: Text(
                    'Checkout & Tender',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            CbSurfaceCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'AMOUNT DUE',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: AppColors.mutedForeground,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.4,
                          ),
                        ),
                      ),
                      CbStatusPill(
                        label:
                            '${cart.lines.fold<double>(0, (s, l) => s + l.quantity).round()} Packs',
                        variant: CbStatusPillVariant.info,
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'KES ${cart.total.toStringAsFixed(2)}',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      CbStatusPill(
                        label: customerLabel,
                        variant: CbStatusPillVariant.neutral,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                const Expanded(child: CbSectionLabel(label: 'Payment method')),
                Text(
                  'SELECT 1 TENDER',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: AppColors.mutedForeground,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            for (final m in settings.enabledPaymentMethods) ...[
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _TenderOptionCard(
                  method: m,
                  selected: draft.method == m,
                  onTap: () {
                    _pushDraft(method: m);
                    if (m == PosPaymentMethod.mpesa &&
                        !draft.paymentOnAccount) {
                      _setPaid(cart.total);
                      _pushDraft(method: m);
                    }
                  },
                ),
              ),
            ],
            if (showAccount) ...[
              const SizedBox(height: 4),
              CbSurfaceCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    InkWell(
                      key: const Key('pos_payment_on_account'),
                      onTap: () {
                        final on = !draft.paymentOnAccount;
                        if (!on && amountPaid <= 0) {
                          _amount.text = cart.total.toStringAsFixed(2);
                        }
                        _pushDraft(paymentOnAccount: on);
                      },
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Checkbox(
                            value: draft.paymentOnAccount,
                            onChanged: (checked) {
                              final on = checked == true;
                              if (!on && amountPaid <= 0) {
                                _amount.text = cart.total.toStringAsFixed(2);
                              }
                              _pushDraft(paymentOnAccount: on);
                            },
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Payment on customer account',
                                  style: theme.textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  cart.customerId == null
                                      ? 'Assign a customer to charge a balance to their account.'
                                      : 'Collect part now, or pay the full amount later. The balance is added to the customer account.',
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
                    if (draft.paymentOnAccount && cart.customerId != null) ...[
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        key: const Key('pos_pay_later'),
                        onPressed: _payFullAmountLater,
                        icon: const Icon(Icons.schedule, size: 18),
                        label: const Text('Pay full amount later'),
                      ),
                      if (kind != CheckoutKind.full) ...[
                        const SizedBox(height: 8),
                        Text(
                          kind == CheckoutKind.payLater
                              ? 'Pay later: entire ${_kes(cart.total)} will be added to the customer account.'
                              : 'Balance on account: ${_kes(balanceDue)}',
                          key: const Key('pos_account_balance'),
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: AppColors.warning,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ],
                  ],
                ),
              ),
            ],
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final amount in [1000.0, 2000.0, 5000.0, cart.total])
                  ChoiceChip(
                    label: Text(
                      amount == cart.total
                          ? 'Exact ${cart.total.toStringAsFixed(2)}'
                          : 'KES ${amount.toStringAsFixed(0)}',
                    ),
                    selected: (double.tryParse(_amount.text) ?? 0) == amount,
                    selectedColor: AppColors.accentSoft,
                    onSelected: (_) => _setPaid(amount),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              key: const Key('pos_amount_paid'),
              controller: _amount,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: 'Amount paid',
                border: OutlineInputBorder(),
              ),
              onChanged: (_) => _pushDraft(),
            ),
            if (changeDue > 0) ...[
              const SizedBox(height: 8),
              Text(
                'Change due: KES ${changeDue.toStringAsFixed(2)}',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: AppColors.success,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            if (needsStk) ...[
              const SizedBox(height: 8),
              TextField(
                key: const Key('pos_mpesa_phone'),
                controller: _phone,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Target Safaricom line',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
            if (draft.method.requiresReference && collectNow) ...[
              const SizedBox(height: 12),
              TextField(
                key: const Key('pos_payment_ref'),
                controller: _reference,
                decoration: const InputDecoration(
                  labelText: 'Payment reference',
                  border: OutlineInputBorder(),
                ),
                onChanged: (_) => _pushDraft(),
              ),
            ],
            if (checkout.message != null) ...[
              const SizedBox(height: 8),
              Text(
                checkout.message!,
                key: const Key('pos_checkout_error'),
                style: const TextStyle(color: AppColors.destructive),
              ),
            ],
            const SizedBox(height: 16),
            CbPrimaryButton(
              key: const Key('pos_confirm_pay'),
              label: confirmLabel,
              onPressed: !valid || checkout.phase == CheckoutPhase.submitting
                  ? null
                  : () async {
                      final phone = _phone.text.trim();
                      if (needsStk && phone.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Enter M-Pesa phone')),
                        );
                        return;
                      }

                      final closeSale = await _confirmCloseSale(
                        cart: cart,
                        kind: kind,
                        paid: amountPaid,
                      );
                      if (!context.mounted) return;
                      if (closeSale == false) {
                        Navigator.pop(context);
                        return;
                      }
                      if (closeSale != true) return;

                      if (needsStk) {
                        final stkAmount = amountPaid > 0
                            ? amountPaid
                            : cart.total;
                        final paid = await showStkWaitSheet(
                          context,
                          amount: stkAmount,
                          phone: phone,
                          purpose: 'pos',
                        );
                        if (paid == null || !context.mounted) return;
                        _reference.text =
                            paid.mpesaReceipt ?? paid.invoiceNumber;
                        _pushDraft();
                      }
                      final ok = await ref
                          .read(checkoutControllerProvider.notifier)
                          .submit();
                      if (ok && context.mounted) Navigator.pop(context);
                    },
            ),
          ],
        ),
      ),
    );
  }
}

class _TenderOptionCard extends StatelessWidget {
  const _TenderOptionCard({
    required this.method,
    required this.selected,
    required this.onTap,
  });

  final PosPaymentMethod method;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final icon = switch (method) {
      PosPaymentMethod.mpesa => Icons.phone_android,
      PosPaymentMethod.cash => Icons.payments_outlined,
      PosPaymentMethod.card => Icons.credit_card,
      PosPaymentMethod.other => Icons.account_balance_wallet_outlined,
    };
    final subtitle = switch (method) {
      PosPaymentMethod.mpesa => 'Prompts PIN on customer handset',
      PosPaymentMethod.cash => 'Direct till physical note collection',
      PosPaymentMethod.card => 'Card or bank transfer reference',
      PosPaymentMethod.other => 'Other recorded tender',
    };

    return CbSurfaceCard(
      key: Key('pos_method_${method.name}'),
      padding: const EdgeInsets.all(14),
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppColors.radius - 2),
          border: Border.all(
            color: selected ? AppColors.success : Colors.transparent,
            width: 1.5,
          ),
        ),
        padding: selected ? const EdgeInsets.all(2) : EdgeInsets.zero,
        child: Row(
          children: [
            Icon(icon, color: selected ? AppColors.success : AppColors.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        method == PosPaymentMethod.mpesa
                            ? 'M-PESA Express STK'
                            : method.label,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (method == PosPaymentMethod.mpesa) ...[
                        const SizedBox(width: 8),
                        const CbStatusPill(
                          label: 'Instant',
                          variant: CbStatusPillVariant.success,
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppColors.mutedForeground,
                    ),
                  ),
                ],
              ),
            ),
            if (selected)
              const Icon(Icons.check_circle, color: AppColors.success)
            else
              const Icon(Icons.circle_outlined, color: AppColors.border),
          ],
        ),
      ),
    );
  }
}
