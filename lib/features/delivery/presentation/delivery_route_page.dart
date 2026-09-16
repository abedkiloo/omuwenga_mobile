import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../design_system/chrome/cb_status_pill.dart';
import '../../../design_system/chrome/cb_sticky_action_bar.dart';
import '../../../design_system/chrome/cb_surface_card.dart';
import '../../../design_system/states/async_states.dart';
import '../../payments/presentation/stk_wait_page.dart';
import '../application/delivery_controllers.dart';
import '../domain/delivery_stop.dart';

/// Optional hook for Open in Maps / call (tests inject no-ops).
typedef ExternalUriHandler = Future<void> Function(Uri uri);

final deliveryExternalUriHandlerProvider = Provider<ExternalUriHandler>((ref) {
  return (_) async {};
});

class DeliveryRoutePage extends ConsumerStatefulWidget {
  const DeliveryRoutePage({super.key});

  @override
  ConsumerState<DeliveryRoutePage> createState() => _DeliveryRoutePageState();
}

class _DeliveryRoutePageState extends ConsumerState<DeliveryRoutePage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(deliveryRouteProvider.notifier).load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(deliveryRouteProvider);
    final next = state.nextStop;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Today’s route')),
      body: state.loading && state.route == null
          ? const LoadingState(label: 'Loading route…')
          : state.error != null && state.route == null
          ? ErrorState(
              message: state.error!,
              onRetry: () => ref.read(deliveryRouteProvider.notifier).load(),
            )
          : (state.route?.stops.isEmpty ?? true)
          ? EmptyState(
              title: 'No stops today',
              message: 'Assigned deliveries will appear here.',
              primaryLabel: 'Refresh',
              onPrimary: () => ref.read(deliveryRouteProvider.notifier).load(),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (next != null)
                  CbPrimaryButton(
                    key: const Key('delivery_next_stop'),
                    label: 'Next stop #${next.sequence}',
                    onPressed: () =>
                        context.push(AppRoutes.deliveryStop(next.id)),
                  ),
                const SizedBox(height: 16),
                for (final stop in state.route!.stops)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: CbSurfaceCard(
                      key: Key('delivery_route_stop_${stop.id}'),
                      padding: const EdgeInsets.all(14),
                      onTap: () =>
                          context.push(AppRoutes.deliveryStop(stop.id)),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  stop.site.label.isEmpty
                                      ? 'Stop ${stop.sequence}'
                                      : stop.site.label,
                                  style: Theme.of(context).textTheme.titleSmall
                                      ?.copyWith(fontWeight: FontWeight.w600),
                                ),
                                Text(
                                  'Stop #${stop.sequence}',
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(
                                        color: AppColors.mutedForeground,
                                      ),
                                ),
                              ],
                            ),
                          ),
                          CbStatusPill(
                            label: stop.status.name,
                            variant: stop.status == DeliveryStopStatus.completed
                                ? CbStatusPillVariant.success
                                : CbStatusPillVariant.info,
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}

/// Map-first stop screen (UX mental model F).
class DeliveryStopPage extends ConsumerStatefulWidget {
  const DeliveryStopPage({super.key, required this.stopId});

  final int stopId;

  @override
  ConsumerState<DeliveryStopPage> createState() => _DeliveryStopPageState();
}

class _DeliveryStopPageState extends ConsumerState<DeliveryStopPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (ref.read(deliveryRouteProvider).route == null) {
        ref.read(deliveryRouteProvider.notifier).load();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(deliveryRouteProvider);
    DeliveryStop? stop;
    for (final s in state.route?.stops ?? const <DeliveryStop>[]) {
      if (s.id == widget.stopId) {
        stop = s;
        break;
      }
    }

    if (stop == null) {
      return Scaffold(
        appBar: AppBar(title: Text('Stop #${widget.stopId}')),
        body: state.loading
            ? const LoadingState(label: 'Loading…')
            : EmptyState(
                title: 'Stop not found',
                message: state.error ?? 'Refresh the route.',
                primaryLabel: 'Back',
                onPrimary: () => Navigator.of(context).maybePop(),
              ),
      );
    }

    final current = stop;

    final theme = Theme.of(context);
    final pod = state.pod;
    final canComplete = current.canComplete || state.queuedPodOffline;
    final openUri = ref.watch(deliveryExternalUriHandlerProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(current.site.label.isEmpty ? 'Stop' : current.site.label),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            key: const Key('del_stop_map'),
            height: 160,
            alignment: Alignment.center,
            color: AppColors.secondary,
            child: Text(
              current.site.latitude == null
                  ? 'No pin'
                  : '${current.site.latitude}, ${current.site.longitude}',
            ),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            key: const Key('del_open_maps'),
            onPressed: current.site.latitude == null
                ? null
                : () => openUri(
                    Uri.parse(
                      'https://maps.google.com/?q=${current.site.latitude},${current.site.longitude}',
                    ),
                  ),
            child: const Text('Open in Maps'),
          ),
          const SizedBox(height: 16),
          SizedBox(
            key: const Key('del_stop_photos'),
            height: 72,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                for (
                  var i = 0;
                  i <
                      (current.site.photoUrls.isEmpty
                          ? 1
                          : current.site.photoUrls.length);
                  i++
                )
                  Container(
                    width: 72,
                    margin: const EdgeInsets.only(right: 8),
                    color: AppColors.secondary,
                    child: const Icon(Icons.image_outlined),
                  ),
              ],
            ),
          ),
          if (current.site.landmark.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(current.site.landmark, key: const Key('del_landmark')),
          ],
          const SizedBox(height: 16),
          ListTile(
            key: const Key('del_customer'),
            contentPadding: EdgeInsets.zero,
            title: Text(current.customerName ?? 'Customer'),
            subtitle: Text(current.customerPhone ?? ''),
            trailing:
                (current.customerPhone == null ||
                    current.customerPhone!.isEmpty)
                ? null
                : IconButton(
                    key: const Key('del_call'),
                    icon: const Icon(Icons.call_outlined),
                    onPressed: () =>
                        openUri(Uri.parse('tel:${current.customerPhone}')),
                  ),
          ),
          const SizedBox(height: 8),
          Text('Lines', style: theme.textTheme.titleMedium),
          for (final line in current.lines)
            ListTile(
              key: Key('del_line_${line.productId}'),
              contentPadding: EdgeInsets.zero,
              title: Text(line.productName),
              subtitle: Text(
                'Ordered ${line.orderedQuantity} · '
                'delivered ${line.deliveredQuantity} · '
                'returned ${line.returnedQuantity}',
              ),
            ),
          const SizedBox(height: 16),
          Text('Collect', style: theme.textTheme.titleMedium),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  key: const Key('del_collect_cash'),
                  onPressed: state.acting
                      ? null
                      : () => ref
                            .read(deliveryRouteProvider.notifier)
                            .collectCash(current.id),
                  child: const Text('Cash'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  key: const Key('del_collect_debt'),
                  onPressed: state.acting
                      ? null
                      : () => ref
                            .read(deliveryRouteProvider.notifier)
                            .collectDebt(current.id),
                  child: const Text('Mark debt'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            key: const Key('del_collect_mpesa'),
            onPressed: state.acting
                ? null
                : () async {
                    final phone =
                        (current.customerPhone ??
                                current.site.customerPhone ??
                                '')
                            .trim();
                    if (phone.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Customer phone required for M-Pesa'),
                        ),
                      );
                      return;
                    }
                    final amountCtrl = TextEditingController(
                      text: (current.collectionAmount ?? 0) > 0
                          ? current.collectionAmount!.toStringAsFixed(2)
                          : '',
                    );
                    final amount = await showDialog<double>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('M-Pesa amount'),
                        content: TextField(
                          key: const Key('del_mpesa_amount'),
                          controller: amountCtrl,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: const InputDecoration(
                            labelText: 'Amount (KES)',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx),
                            child: const Text('Cancel'),
                          ),
                          TextButton(
                            onPressed: () {
                              final v = double.tryParse(amountCtrl.text.trim());
                              Navigator.pop(ctx, v);
                            },
                            child: const Text('Continue'),
                          ),
                        ],
                      ),
                    );
                    amountCtrl.dispose();
                    if (amount == null || amount <= 0 || !context.mounted) {
                      return;
                    }
                    final paid = await showStkWaitSheet(
                      context,
                      amount: amount,
                      phone: phone,
                      purpose: 'delivery',
                      customerName: current.customerName ?? '',
                    );
                    if (paid == null || !context.mounted) return;
                    await ref
                        .read(deliveryRouteProvider.notifier)
                        .collectMpesa(
                          current.id,
                          amount: paid.amount,
                          receipt: paid.mpesaReceipt ?? paid.invoiceNumber,
                        );
                  },
            child: const Text('Request M-Pesa'),
          ),
          const SizedBox(height: 16),
          Text('Proof of delivery', style: theme.textTheme.titleMedium),
          SwitchListTile(
            key: const Key('del_pod_signature'),
            title: const Text('Signature captured'),
            value: pod.hasSignature,
            onChanged: (v) => ref
                .read(deliveryRouteProvider.notifier)
                .setPodDraft(pod.copyWith(hasSignature: v)),
          ),
          SwitchListTile(
            key: const Key('del_pod_photo'),
            title: const Text('POD photo captured'),
            value: pod.hasPhoto,
            onChanged: (v) => ref
                .read(deliveryRouteProvider.notifier)
                .setPodDraft(pod.copyWith(hasPhoto: v)),
          ),
          SwitchListTile(
            key: const Key('del_pod_pin'),
            title: const Text('Confirm GPS pin'),
            value: pod.latitude != null,
            onChanged: (v) => ref
                .read(deliveryRouteProvider.notifier)
                .setPodDraft(
                  v
                      ? pod.copyWith(
                          latitude: current.site.latitude ?? -1.29,
                          longitude: current.site.longitude ?? 36.82,
                        )
                      : pod.copyWith(clearPin: true),
                ),
          ),
          if (state.error != null)
            Text(
              state.error!,
              key: const Key('del_stop_error'),
              style: const TextStyle(color: AppColors.destructive),
            ),
        ],
      ),
      bottomNavigationBar: CbStickyActionBar(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (current.status == DeliveryStopStatus.pending)
              CbPrimaryButton(
                key: const Key('del_arrive'),
                label: 'Arrive',
                onPressed: state.acting
                    ? null
                    : () => ref
                          .read(deliveryRouteProvider.notifier)
                          .arrive(current.id),
              )
            else if (current.status == DeliveryStopStatus.arrived)
              CbPrimaryButton(
                key: const Key('del_start'),
                label: 'Start delivery',
                onPressed: state.acting
                    ? null
                    : () => ref
                          .read(deliveryRouteProvider.notifier)
                          .start(current.id),
              )
            else ...[
              CbPrimaryButton(
                key: const Key('del_save_pod'),
                label: state.queuedPodOffline
                    ? 'POD queued offline'
                    : 'Save POD',
                onPressed: state.acting || !pod.isComplete
                    ? null
                    : () => ref
                          .read(deliveryRouteProvider.notifier)
                          .submitPod(current.id),
              ),
              const SizedBox(height: 8),
              CbPrimaryButton(
                key: const Key('del_complete'),
                label: 'Complete stop',
                onPressed: state.acting || !canComplete
                    ? null
                    : () async {
                        final ok = await ref
                            .read(deliveryRouteProvider.notifier)
                            .complete(current.id);
                        if (!ok || !context.mounted) return;
                        final next = ref.read(deliveryRouteProvider).nextStop;
                        if (next != null) {
                          context.go(AppRoutes.deliveryStop(next.id));
                        } else {
                          context.go(AppRoutes.deliveryRoute);
                        }
                      },
              ),
            ],
          ],
        ),
      ),
    );
  }
}
