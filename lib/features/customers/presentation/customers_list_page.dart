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

class CustomersListPage extends ConsumerStatefulWidget {
  const CustomersListPage({super.key});

  @override
  ConsumerState<CustomersListPage> createState() => _CustomersListPageState();
}

class _CustomersListPageState extends ConsumerState<CustomersListPage> {
  final _search = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(customersListProvider.notifier).load();
    });
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(customersListProvider);
    final auth = ref.watch(authControllerProvider);
    final settings = ref.watch(customersSettingsProvider).maybeWhen(
          data: (s) => s,
          orElse: () => const CustomersModuleSettings(),
        );
    final canCreate = (auth.session?.permissions.canCreateCustomers ?? false) &&
        settings.enableCustomerCreate;

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Text(
                'Customers',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                key: const Key('customers_search'),
                controller: _search,
                textInputAction: TextInputAction.search,
                decoration: const InputDecoration(
                  labelText: 'Search customers',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.search),
                ),
                onSubmitted: (q) =>
                    ref.read(customersListProvider.notifier).load(search: q),
              ),
            ),
            if (state.loading) const LinearProgressIndicator(minHeight: 2),
            Expanded(
              child: _buildBody(context, state),
            ),
          ],
        ),
      ),
      floatingActionButton: canCreate
          ? FloatingActionButton.extended(
              key: const Key('customers_add'),
              onPressed: () => context.push(AppRoutes.customerNew),
              label: const Text('Add customer'),
              icon: const Icon(Icons.person_add_alt_1),
            )
          : null,
    );
  }

  Widget _buildBody(BuildContext context, CustomersListState state) {
    if (state.loading && state.items.isEmpty) {
      return const LoadingState(label: 'Loading customers…');
    }
    if (state.error != null && state.items.isEmpty) {
      return ErrorState(
        message: state.error!,
        onRetry: () => ref.read(customersListProvider.notifier).load(),
      );
    }
    if (state.items.isEmpty) {
      return EmptyState(
        key: const Key('customers_empty'),
        title: 'No customers',
        message: state.query.isEmpty
            ? 'Add a customer or search by name or phone.'
            : 'No matches for “${state.query}”.',
        primaryLabel: 'Refresh',
        onPrimary: () => ref.read(customersListProvider.notifier).load(),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 88),
      itemCount: state.items.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, i) {
        final c = state.items[i];
        return ListTile(
          key: Key('customer_row_${c.id}'),
          contentPadding: EdgeInsets.zero,
          title: Text(c.name),
          subtitle: Text(
            [
              if (c.customerCode != null && c.customerCode!.isNotEmpty)
                c.customerCode,
              if (c.phone != null && c.phone!.isNotEmpty) c.phone,
            ].whereType<String>().join(' · '),
          ),
          trailing: _StandingChip(customer: c),
          onTap: () => context.push(AppRoutes.customerDetail(c.id)),
        );
      },
    );
  }
}

class _StandingChip extends StatelessWidget {
  const _StandingChip({required this.customer});

  final CustomerSummary customer;

  @override
  Widget build(BuildContext context) {
    final color = switch (customer.standing) {
      CustomerStanding.debt => AppColors.destructive,
      CustomerStanding.credit => AppColors.success,
      CustomerStanding.good => AppColors.mutedForeground,
    };
    return Text(
      key: Key('customer_standing_${customer.id}'),
      standingLabel(
        customer.standing,
        debtAmount: customer.debtAmount,
        credit: customer.walletBalance != null && customer.walletBalance! > 0
            ? customer.walletBalance!
            : 0,
      ),
      style: Theme.of(context).textTheme.labelMedium?.copyWith(color: color),
    );
  }
}
