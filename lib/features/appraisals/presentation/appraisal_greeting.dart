import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../design_system/buttons/cb_primary_button.dart';
import '../../auth/application/auth_controller.dart';
import '../../daily_notes/application/daily_notes_controllers.dart';
import '../application/appraisals_controller.dart';
import 'appraisal_progress_card.dart';

class AppraisalGreeting extends ConsumerStatefulWidget {
  const AppraisalGreeting({super.key});

  @override
  ConsumerState<AppraisalGreeting> createState() => _AppraisalGreetingState();
}

class _AppraisalGreetingState extends ConsumerState<AppraisalGreeting> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (ref.read(authControllerProvider).isAuthenticated) {
        ref.read(appraisalsProvider.notifier).load();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(authControllerProvider, (prev, next) {
      if (next.isAuthenticated && !(prev?.isAuthenticated ?? false)) {
        ref.read(appraisalsProvider.notifier).load();
      }
      if (!next.isAuthenticated) {
        ref.read(appraisalsProvider.notifier).reset();
      }
    });

    final auth = ref.watch(authControllerProvider);
    if (!auth.isAuthenticated) return const SizedBox.shrink();
    final notes = ref.watch(stickyNotesGateProvider);
    final appraisals = ref.watch(appraisalsProvider);
    if (!appraisalGreetingVisible(appraisals, notes)) {
      return const SizedBox.shrink();
    }
    final snapshot = appraisals.snapshot;
    if (snapshot == null) return const SizedBox.shrink();

    return SizedBox.expand(
      child: Material(
        color: Colors.black.withValues(alpha: 0.55),
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AppraisalProgressCard(key: const Key('appraisal_greeting'), snapshot: snapshot),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () =>
                                ref.read(appraisalsProvider.notifier).dismissGreeting(),
                            child: const Text('Continue'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: CbPrimaryButton(
                            label: 'Open appraisals',
                            onPressed: () {
                              ref.read(appraisalsProvider.notifier).dismissGreeting();
                              context.push(AppRoutes.appraisals);
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
