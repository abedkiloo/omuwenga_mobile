import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../design_system/states/async_states.dart';
import '../../customers/presentation/customer_picker_sheet.dart';
import '../../payments/presentation/stk_wait_page.dart';
import '../application/pos_controllers.dart';
import '../domain/cart.dart';
import '../domain/payment.dart';
import 'receipt_page.dart';
import 'variant_picker_sheet.dart';

class PosPage extends ConsumerStatefulWidget {
  const PosPage({super.key});

  @override
  ConsumerState<PosPage> createState() => _PosPageState();
}

class _PosPageState extends ConsumerState<PosPage> {
  final _search = TextEditingController();
  final _searchFocus = FocusNode();
  List<CatalogProduct> _results = const [];
  bool _searching = false;
  String? _searchError;

  @override
  void dispose() {
    _search.dispose();
    _searchFocus.dispose();
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
      ref.read(cartControllerProvider.notifier).addProduct(
            pick.product,
            variant: pick.variant,
            qty: pick.quantity,
          );
    } else {
      ref.read(cartControllerProvider.notifier).addProduct(product);
    }
    setState(() => _results = const []);
    _search.clear();
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

  Future<void> _openPay() async {
    final cart = ref.read(cartControllerProvider);
    final settings = ref.read(posSettingsProvider).maybeWhen(
          data: (s) => s,
          orElse: () => const PosSettings(),
        );
    if (cart.isEmpty) return;

    final methods = settings.enabledPaymentMethods;
    final method = methods.isEmpty ? PosPaymentMethod.cash : methods.first;
    ref.read(checkoutControllerProvider.notifier).setDraft(
          CheckoutDraft(method: method, amountPaid: cart.total),
        );

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
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
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'New sale',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          if (cart.customerId != null)
                            Text(
                              key: const Key('pos_customer_label'),
                              'Customer: ${cart.customerName}',
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: AppColors.mutedForeground,
                                  ),
                            )
                          else
                            settingsAsync.maybeWhen(
                              data: (s) => s.requireCustomer
                                  ? Text(
                                      key: const Key('pos_customer_label'),
                                      'Customer required before pay',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(color: AppColors.warning),
                                    )
                                  : const SizedBox.shrink(),
                              orElse: () => const SizedBox.shrink(),
                            ),
                        ],
                      ),
                    ),
                    TextButton(
                      key: const Key('pos_add_customer'),
                      onPressed: () => showCustomerPickerSheet(context, ref),
                      child: Text(
                        cart.customerId == null ? 'New customer' : 'Change',
                      ),
                    ),
                    if (cart.customerId != null)
                      IconButton(
                        key: const Key('pos_clear_customer'),
                        tooltip: 'Clear customer',
                        onPressed: () => ref
                            .read(cartControllerProvider.notifier)
                            .clearCustomer(),
                        icon: const Icon(Icons.close),
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: TextField(
                  key: const Key('pos_search'),
                  controller: _search,
                  focusNode: _searchFocus,
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    labelText: 'Search or scan barcode',
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      key: const Key('pos_search_button'),
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
                    style: const TextStyle(color: AppColors.destructive),
                  ),
                ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_results.isNotEmpty)
                      Expanded(
                        child: ListView.separated(
                          key: const Key('pos_search_results'),
                          padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                          itemCount: _results.length,
                          separatorBuilder: (_, _) => const Divider(height: 1),
                          itemBuilder: (context, i) {
                            final p = _results[i];
                            return ListTile(
                              key: Key('pos_product_${p.id}'),
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
                        ),
                      ),
                    if (_results.isEmpty && cart.isEmpty)
                      Expanded(
                        child: EmptyState(
                          key: const Key('pos_empty_cart'),
                          title: 'Cart is empty',
                          message: 'Search a product or scan a barcode to start.',
                          primaryLabel: 'Search products',
                          onPrimary: () => _searchFocus.requestFocus(),
                        ),
                      ),
                    if (!cart.isEmpty)
                      Expanded(
                        child: ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                          itemCount: cart.lines.length,
                          separatorBuilder: (_, _) => const Divider(height: 1),
                          itemBuilder: (context, i) {
                            final line = cart.lines[i];
                            return ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: Text(line.displayName),
                              subtitle: Text(
                                '${line.quantity} × ${line.unitPrice.toStringAsFixed(2)}',
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    key: Key('pos_dec_${line.lineKey}'),
                                    onPressed: () => ref
                                        .read(cartControllerProvider.notifier)
                                        .setQuantity(
                                          line.lineKey,
                                          line.quantity - 1,
                                        ),
                                    icon: const Icon(Icons.remove_circle_outline),
                                  ),
                                  Text(line.quantity.round().toString()),
                                  IconButton(
                                    key: Key('pos_inc_${line.lineKey}'),
                                    onPressed: () => ref
                                        .read(cartControllerProvider.notifier)
                                        .setQuantity(
                                          line.lineKey,
                                          line.quantity + 1,
                                        ),
                                    icon: const Icon(Icons.add_circle_outline),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                  ],
                ),
              ),
              Material(
                elevation: 8,
                color: AppColors.background,
                child: SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Total',
                                style: Theme.of(context).textTheme.labelMedium,
                              ),
                              Text(
                                key: const Key('pos_total'),
                                cart.total.toStringAsFixed(2),
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                            ],
                          ),
                        ),
                        SizedBox(
                          width: 160,
                          child: CbPrimaryButton(
                            key: const Key('pos_pay'),
                            label: 'Pay',
                            onPressed: cart.isEmpty ? null : _openPay,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
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

  void _pushDraft({PosPaymentMethod? method}) {
    final checkout = ref.read(checkoutControllerProvider);
    final amount = double.tryParse(_amount.text) ?? 0;
    ref.read(checkoutControllerProvider.notifier).setDraft(
          CheckoutDraft(
            method: method ?? checkout.draft.method,
            amountPaid: amount,
            paymentReference: _reference.text,
          ),
        );
  }

  @override
  Widget build(BuildContext context) {
    final cart = ref.watch(cartControllerProvider);
    final checkout = ref.watch(checkoutControllerProvider);
    final settings = ref.watch(posSettingsProvider).maybeWhen(
          data: (s) => s,
          orElse: () => const PosSettings(),
        );
    final draft = checkout.draft;
    final valid = canSubmitCheckout(
      cart: cart,
      settings: settings,
      draft: draft,
    );
    final bottom = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, 16 + bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Take payment', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Text('Total ${cart.total.toStringAsFixed(2)}'),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: [
              for (final m in settings.enabledPaymentMethods)
                ChoiceChip(
                  key: Key('pos_method_${m.name}'),
                  label: Text(m.label),
                  selected: draft.method == m,
                  onSelected: (_) => _pushDraft(method: m),
                ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            key: const Key('pos_amount_paid'),
            controller: _amount,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Amount paid',
              border: OutlineInputBorder(),
            ),
            onChanged: (_) => _pushDraft(),
          ),
          if (draft.method == PosPaymentMethod.mpesa) ...[
            const SizedBox(height: 12),
            TextField(
              key: const Key('pos_mpesa_phone'),
              controller: _phone,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Customer M-Pesa phone',
                border: OutlineInputBorder(),
              ),
            ),
          ],
          if (draft.method.requiresReference) ...[
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
            label: checkout.phase == CheckoutPhase.submitting
                ? 'Processing…'
                : draft.method == PosPaymentMethod.mpesa
                    ? 'Send M-Pesa prompt'
                    : 'Confirm pay',
            onPressed: !valid || checkout.phase == CheckoutPhase.submitting
                ? null
                : () async {
                    if (draft.method == PosPaymentMethod.mpesa) {
                      final phone = _phone.text.trim();
                      if (phone.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Enter M-Pesa phone')),
                        );
                        return;
                      }
                      final amount = double.tryParse(_amount.text) ?? cart.total;
                      final paid = await showStkWaitSheet(
                        context,
                        amount: amount,
                        phone: phone,
                        purpose: 'pos',
                      );
                      if (paid == null || !context.mounted) return;
                      _reference.text = paid.mpesaReceipt ?? paid.invoiceNumber;
                      _pushDraft();
                    }
                    final ok =
                        await ref.read(checkoutControllerProvider.notifier).submit();
                    if (ok && context.mounted) Navigator.pop(context);
                  },
          ),
        ],
      ),
    );
  }
}
