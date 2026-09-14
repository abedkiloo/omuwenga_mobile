import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../design_system/scaffold/cb_scaffold.dart';
import '../../../design_system/states/async_states.dart';
import '../providers.dart';

class HealthPage extends ConsumerWidget {
  const HealthPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(healthCheckProvider);

    return CbScaffold(
      title: 'API health',
      body: async.when(
        loading: () => const LoadingState(label: 'Checking API…'),
        error: (error, _) => ErrorState(
          message: error.toString(),
          onRetry: () => ref.invalidate(healthCheckProvider),
        ),
        data: (result) => result.when(
          success: (status) => status.ok
              ? EmptyState(
                  title: 'Backend reachable',
                  message: status.rawBody.isEmpty ? 'OK' : status.rawBody,
                  primaryLabel: 'Check again',
                  onPrimary: () => ref.invalidate(healthCheckProvider),
                )
              : ErrorState(
                  message: 'HTTP not OK: ${status.rawBody}',
                  onRetry: () => ref.invalidate(healthCheckProvider),
                ),
          failure: (error, _) => ErrorState(
            message: error.toString(),
            onRetry: () => ref.invalidate(healthCheckProvider),
          ),
        ),
      ),
    );
  }
}
