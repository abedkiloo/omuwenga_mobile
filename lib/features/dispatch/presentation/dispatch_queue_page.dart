import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../design_system/buttons/cb_primary_button.dart';
import '../../../design_system/chrome/cb_commit_confirm.dart';
import '../../../design_system/chrome/cb_status_pill.dart';
import '../../../design_system/chrome/cb_sticky_action_bar.dart';
import '../../../design_system/chrome/cb_surface_card.dart';
import '../../../design_system/states/async_states.dart';
import '../../auth/application/auth_controller.dart';
import '../../field_orders/domain/field_order.dart';
import '../../field_orders/domain/field_order_commit.dart';
import '../application/dispatch_controllers.dart';
import '../data/dispatch_api.dart';

CbStatusPillVariant _dispatchStatusVariant(FieldOrderStatus status) {
  switch (status) {
    case FieldOrderStatus.ready:
    case FieldOrderStatus.outForDelivery:
    case FieldOrderStatus.done:
      return CbStatusPillVariant.success;
    case FieldOrderStatus.cancelled:
      return CbStatusPillVariant.warning;
    case FieldOrderStatus.draft:
    case FieldOrderStatus.submitted:
    case FieldOrderStatus.packing:
      return CbStatusPillVariant.info;
  }
}

class DispatchQueuePage extends ConsumerStatefulWidget {
  const DispatchQueuePage({super.key});

  @override
  ConsumerState<DispatchQueuePage> createState() => _DispatchQueuePageState();
}

class _DispatchQueuePageState extends ConsumerState<DispatchQueuePage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(dispatchQueueProvider.notifier).load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(dispatchQueueProvider);
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Field sales')),
      body: state.loading && state.orders.isEmpty
          ? const LoadingState(label: 'Loading queue…')
          : state.error != null && state.orders.isEmpty
          ? ErrorState(
              message: state.error!,
              onRetry: () => ref.read(dispatchQueueProvider.notifier).load(),
            )
          : state.orders.isEmpty
          ? EmptyState(
              title: 'Queue clear',
              message: 'No visit orders waiting to be packed.',
              primaryLabel: 'Refresh',
              onPrimary: () => ref.read(dispatchQueueProvider.notifier).load(),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: state.orders.length,
              itemBuilder: (context, i) {
                final order = state.orders[i];
                final qty = order.lines.fold<double>(
                  0,
                  (sum, l) => sum + l.quantity,
                );
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: CbSurfaceCard(
                    key: Key('dispatch_order_${order.id}'),
                    padding: const EdgeInsets.all(14),
                    onTap: () =>
                        context.push(AppRoutes.dispatchOrder(order.id)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                order.customerName?.isNotEmpty == true
                                    ? order.customerName!
                                    : 'Order #${order.id}',
                                style: Theme.of(context).textTheme.titleSmall
                                    ?.copyWith(fontWeight: FontWeight.w600),
                              ),
                            ),
                            CbStatusPill(
                              label: order.status.name,
                              variant: _dispatchStatusVariant(order.status),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '#${order.id} · ${order.lines.length} lines · '
                          'qty ${qty.toStringAsFixed(0)}',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: AppColors.mutedForeground),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}

class DispatchOrderDetailPage extends ConsumerStatefulWidget {
  const DispatchOrderDetailPage({super.key, required this.orderId});

  final int orderId;

  @override
  ConsumerState<DispatchOrderDetailPage> createState() =>
      _DispatchOrderDetailPageState();
}

class _DispatchOrderDetailPageState
    extends ConsumerState<DispatchOrderDetailPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(dispatchQueueProvider.notifier).load();
    });
  }

  Future<void> _confirmPack(FieldOrderSummary order) async {
    final confirmed = await showCommitConfirm(
      context: context,
      title: 'Pack this order?',
      description:
          'Stock will be allocated and the order marked ready for pickup.',
      rows: dispatchPackRows(order),
      confirmLabel: 'Confirm & pack',
      confirmKey: const Key('dispatch_pack_confirm'),
      cancelKey: const Key('dispatch_pack_cancel'),
    );
    if (!confirmed || !mounted) return;
    await ref.read(dispatchQueueProvider.notifier).pack(order.id);
  }

  Future<void> _confirmAssign(FieldOrderSummary order) async {
    final state = ref.read(dispatchQueueProvider);
    final error = dispatchAssignError(
      canAssign: state.canAssign,
      driverId: state.selectedDeliveryDriverId,
    );
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
      return;
    }
    final driverName = state.drivers
            .where((d) => d.id == state.selectedDeliveryDriverId)
            .map((d) => d.displayName)
            .firstOrNull ??
        'Selected driver';
    final confirmed = await showCommitConfirm(
      context: context,
      title: 'Assign this order?',
      description: 'The driver will see it on their route after you confirm.',
      rows: dispatchAssignRows(order: order, driverName: driverName),
      confirmLabel: 'Confirm & assign',
      confirmKey: const Key('dispatch_assign_confirm'),
      cancelKey: const Key('dispatch_assign_cancel'),
    );
    if (!confirmed || !mounted) return;
    await ref.read(dispatchQueueProvider.notifier).assign(order.id);
  }

  Future<void> _addDriver() async {
    final name = TextEditingController();
    final phone = TextEditingController();
    final created = await showDialog<CreatedDeliveryDriver>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          key: const Key('dispatch_add_driver_dialog'),
          title: const Text('Add delivery driver'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                key: const Key('dispatch_add_driver_name'),
                controller: name,
                decoration: const InputDecoration(labelText: 'Full name'),
              ),
              TextField(
                key: const Key('dispatch_add_driver_phone'),
                controller: phone,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: 'Phone'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            TextButton(
              key: const Key('dispatch_add_driver_save'),
              onPressed: () async {
                final driver = await ref
                    .read(dispatchQueueProvider.notifier)
                    .createDriver(
                      displayName: name.text,
                      phone: phone.text,
                    );
                if (driver != null && ctx.mounted) {
                  Navigator.pop(ctx, driver);
                }
              },
              child: const Text('Add'),
            ),
          ],
        );
      },
    );
    name.dispose();
    phone.dispose();
    if (created == null || !mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        key: const Key('dispatch_driver_credentials'),
        title: const Text('Driver added'),
        content: Text(
          'Username: ${created.username}\n'
          'Temporary password: ${created.temporaryPassword}\n\n'
          'They must change this password on first login.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(dispatchQueueProvider);
    final canPack =
        ref
            .watch(authControllerProvider)
            .session
            ?.permissions
            .canUpdateDispatch ??
        false;
    final order = state.orders.where((o) => o.id == widget.orderId).firstOrNull;

    if (order == null) {
      return Scaffold(
        appBar: AppBar(title: Text('Order #${widget.orderId}')),
        body: state.loading
            ? const LoadingState(label: 'Loading…')
            : EmptyState(
                title: 'Order not in queue',
                message: state.error ?? 'Refresh the queue and try again.',
                primaryLabel: 'Back',
                onPrimary: () => Navigator.of(context).maybePop(),
              ),
      );
    }

    final alreadyReady =
        order.stockAllocated ||
        order.status == FieldOrderStatus.ready ||
        order.status == FieldOrderStatus.outForDelivery;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: Text('Order #${order.id}')),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Text(
            order.customerName?.isNotEmpty == true
                ? order.customerName!
                : 'Order #${order.id}',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Container(
            key: const Key('dispatch_map'),
            height: 120,
            alignment: Alignment.center,
            color: AppColors.secondary,
            child: Text(
              order.latitude == null
                  ? 'No pin'
                  : '${order.latitude}, ${order.longitude}',
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Products to pack',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          for (final line in order.lines)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(line.displayName),
              subtitle: Text(
                'Qty ${line.quantity} · ${line.unitPrice.toStringAsFixed(2)} each',
              ),
              trailing: Text(line.lineTotal.toStringAsFixed(2)),
            ),
          const SizedBox(height: 16),
          if (canPack)
            DropdownButtonFormField<int>(
              key: const Key('dispatch_driver_select'),
              initialValue: state.selectedDeliveryDriverId,
              decoration: const InputDecoration(
                labelText: 'Delivery driver',
                border: OutlineInputBorder(),
              ),
              items: [
                for (final d in state.drivers)
                  DropdownMenuItem(
                    value: d.id,
                    child: Text(d.displayName),
                  ),
              ],
              onChanged: state.drivers.isEmpty
                  ? null
                  : (v) => ref
                        .read(dispatchQueueProvider.notifier)
                        .selectDeliveryDriver(v),
            ),
          if (canPack && state.drivers.isEmpty && !state.loading)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'No delivery drivers yet. Add one to assign this order.',
                key: const Key('dispatch_no_drivers'),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.mutedForeground,
                ),
              ),
            ),
          if (canPack)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: OutlinedButton.icon(
                key: const Key('dispatch_add_driver'),
                onPressed: state.creatingDriver ? null : _addDriver,
                icon: const Icon(Icons.person_add_alt_1_outlined),
                label: const Text('Add driver'),
              ),
            ),
          if (state.error != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                state.error!,
                key: const Key('dispatch_error'),
                style: const TextStyle(color: AppColors.destructive),
              ),
            ),
        ],
      ),
      bottomNavigationBar: canPack
          ? CbStickyActionBar(
              primaryLabel: 'Actions',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  CbPrimaryButton(
                    key: const Key('dispatch_pack'),
                    label: alreadyReady
                        ? 'Ready for pickup'
                        : 'Pack & mark ready for pickup',
                    onPressed: state.acting || alreadyReady
                        ? null
                        : () => _confirmPack(order),
                  ),
                  const SizedBox(height: 8),
                  CbPrimaryButton(
                    key: const Key('dispatch_assign'),
                    label: 'Assign delivery driver',
                    onPressed: state.canAssign
                        ? () => _confirmAssign(order)
                        : null,
                  ),
                ],
              ),
            )
          : null,
    );
  }
}

extension<T> on Iterable<T> {
  T? get firstOrNull {
    final it = iterator;
    if (!it.moveNext()) return null;
    return it.current;
  }
}
