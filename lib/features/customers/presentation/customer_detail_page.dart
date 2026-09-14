import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../design_system/states/async_states.dart';
import '../../auth/application/auth_controller.dart';
import '../application/customers_controllers.dart';
import '../domain/customer.dart';
import '../domain/wallet_debt.dart';

class CustomerDetailPage extends ConsumerWidget {
  const CustomerDetailPage({super.key, required this.customerId});

  final int customerId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(customerDetailProvider(customerId));
    final auth = ref.watch(authControllerProvider);
    final settings = ref.watch(customersSettingsProvider).maybeWhen(
          data: (s) => s,
          orElse: () => const CustomersModuleSettings(),
        );

    final detail = state.detail;
    final showSettle = detail != null &&
        canSettleCustomerDebt(
          auth: auth,
          settings: settings,
          debtAmount: detail.debtAmount,
        );
    final canEdit = (auth.session?.permissions.canUpdateCustomers ?? false) &&
        settings.enableCustomerEdit;

    return Scaffold(
      appBar: AppBar(
        title: Text(detail?.name ?? 'Customer'),
        actions: [
          if (canEdit && detail != null)
            IconButton(
              key: const Key('customer_edit'),
              icon: const Icon(Icons.edit_outlined),
              onPressed: () => context.push(AppRoutes.customerEdit(detail.id)),
            ),
        ],
      ),
      body: _body(context, ref, state),
      bottomNavigationBar: showSettle
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: CbPrimaryButton(
                  key: const Key('customer_settle'),
                  label: 'Receive payment',
                  onPressed: () =>
                      context.push(AppRoutes.customerSettle(detail.id)),
                ),
              ),
            )
          : null,
    );
  }

  Widget _body(
    BuildContext context,
    WidgetRef ref,
    CustomerDetailState state,
  ) {
    if (state.loading && state.detail == null) {
      return const LoadingState(label: 'Loading customer…');
    }
    if (state.error != null && state.detail == null) {
      return ErrorState(
        message: state.error!,
        onRetry: () =>
            ref.read(customerDetailProvider(customerId).notifier).load(customerId),
      );
    }
    final detail = state.detail;
    if (detail == null) {
      return EmptyState(
        title: 'Customer not found',
        message: 'This customer may have been removed.',
        primaryLabel: 'Back',
        onPrimary: () => Navigator.of(context).maybePop(),
      );
    }

    final standingColor = switch (detail.standing) {
      CustomerStanding.debt => AppColors.destructive,
      CustomerStanding.credit => AppColors.success,
      CustomerStanding.good => AppColors.primary,
    };

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        Text(
          key: const Key('customer_standing_hero'),
          detail.standingHeadline,
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                color: standingColor,
                fontWeight: FontWeight.w600,
              ),
        ),
        const SizedBox(height: 4),
        Text(
          'Wallet ${detail.walletBalance?.toStringAsFixed(2) ?? '—'}',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.mutedForeground,
              ),
        ),
        const SizedBox(height: 24),
        Text('Identity', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        _InfoRow(label: 'Name', value: detail.name),
        if (detail.customerCode != null && detail.customerCode!.isNotEmpty)
          _InfoRow(label: 'Code', value: detail.customerCode!),
        if (detail.phone != null && detail.phone!.isNotEmpty)
          _InfoRow(label: 'Phone', value: detail.phone!),
        if (detail.email != null && detail.email!.isNotEmpty)
          _InfoRow(label: 'Email', value: detail.email!),
        if (detail.address != null && detail.address!.isNotEmpty)
          _InfoRow(label: 'Address', value: detail.address!),
        const SizedBox(height: 24),
        Text('Recent sales', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        if (detail.recentOrders.isEmpty)
          Text(
            'No recent sales',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.mutedForeground,
                ),
          )
        else
          for (final order in detail.recentOrders.take(8))
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(order.saleNumber),
              subtitle: order.createdAt == null ? null : Text(order.createdAt!),
              trailing: Text(order.total.toStringAsFixed(2)),
            ),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 88,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.mutedForeground,
                  ),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}
