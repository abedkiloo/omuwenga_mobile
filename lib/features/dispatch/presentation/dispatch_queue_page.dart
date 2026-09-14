import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../design_system/states/async_states.dart';
import '../../auth/application/auth_controller.dart';
import '../../field_orders/domain/field_order.dart';
import '../application/dispatch_controllers.dart';

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
                      onPrimary: () =>
                          ref.read(dispatchQueueProvider.notifier).load(),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: state.orders.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (context, i) {
                        final order = state.orders[i];
                        final qty = order.lines.fold<double>(
                          0,
                          (sum, l) => sum + l.quantity,
                        );
                        return ListTile(
                          key: Key('dispatch_order_${order.id}'),
                          title: Text(
                            order.customerName?.isNotEmpty == true
                                ? order.customerName!
                                : 'Order #${order.id}',
                          ),
                          subtitle: Text(
                            '#${order.id} · ${order.status.name} · '
                            '${order.lines.length} lines · qty ${qty.toStringAsFixed(0)}',
                          ),
                          onTap: () =>
                              context.push(AppRoutes.dispatchOrder(order.id)),
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

class _DispatchOrderDetailPageState extends ConsumerState<DispatchOrderDetailPage> {
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
    final canPack =
        ref.watch(authControllerProvider).session?.permissions.canUpdateDispatch ??
            false;
    final order =
        state.orders.where((o) => o.id == widget.orderId).firstOrNull;

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

    final alreadyReady = order.stockAllocated ||
        order.status == FieldOrderStatus.ready ||
        order.status == FieldOrderStatus.outForDelivery;

    return Scaffold(
      appBar: AppBar(title: Text('Order #${order.id}')),
      body: ListView(
        padding: const EdgeInsets.all(16),
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
          Text('Products to pack', style: Theme.of(context).textTheme.titleSmall),
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
              items: const [
                DropdownMenuItem(value: 101, child: Text('Driver A (101)')),
                DropdownMenuItem(value: 102, child: Text('Driver B (102)')),
              ],
              onChanged: (v) =>
                  ref.read(dispatchQueueProvider.notifier).selectDeliveryDriver(v),
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
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CbPrimaryButton(
                      key: const Key('dispatch_pack'),
                      label: alreadyReady
                          ? 'Ready for pickup'
                          : 'Pack & mark ready for pickup',
                      onPressed: state.acting || alreadyReady
                          ? null
                          : () => ref
                              .read(dispatchQueueProvider.notifier)
                              .pack(order.id),
                    ),
                    const SizedBox(height: 8),
                    CbPrimaryButton(
                      key: const Key('dispatch_assign'),
                      label: 'Assign delivery driver',
                      onPressed: state.canAssign
                          ? () => ref
                              .read(dispatchQueueProvider.notifier)
                              .assign(order.id)
                          : null,
                    ),
                  ],
                ),
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
