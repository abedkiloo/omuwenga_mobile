import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../core/theme/app_colors.dart';
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
    final tone = snapshot.today.tone;
    final accent = AppColors.starTone(tone);

    return Positioned.fill(
      child: Material(
        color: const Color(0xF2080C14),
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: AppraisalProgressCard(
                  key: const Key('appraisal_greeting'),
                  snapshot: snapshot,
                  emphasis: true,
                  footer: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () =>
                              ref.read(appraisalsProvider.notifier).dismissGreeting(),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            side: const BorderSide(color: Colors.white70, width: 1.6),
                            minimumSize: const Size(0, 48),
                          ),
                          child: const Text('Continue'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: FilledButton(
                          onPressed: () {
                            ref.read(appraisalsProvider.notifier).dismissGreeting();
                            context.push(AppRoutes.appraisals);
                          },
                          style: FilledButton.styleFrom(
                            backgroundColor: accent,
                            foregroundColor: AppColors.onStar(tone),
                            minimumSize: const Size(0, 48),
                          ),
                          child: const Text(
                            'Open my progress',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
