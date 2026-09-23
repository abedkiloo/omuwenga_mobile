import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../design_system/buttons/cb_primary_button.dart';
import '../../auth/application/auth_controller.dart';
import '../application/daily_notes_controllers.dart';

class StickyNotesGate extends ConsumerStatefulWidget {
  const StickyNotesGate({super.key});

  @override
  ConsumerState<StickyNotesGate> createState() => _StickyNotesGateState();
}

class _StickyNotesGateState extends ConsumerState<StickyNotesGate> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (ref.read(authControllerProvider).isAuthenticated) {
        ref.read(stickyNotesGateProvider.notifier).load();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);
    if (!auth.isAuthenticated) return const SizedBox.shrink();
    final state = ref.watch(stickyNotesGateProvider);
    if (state.loading || !state.isBlocking) return const SizedBox.shrink();

    final maxHeight = MediaQuery.sizeOf(context).height * 0.8;

    return Positioned.fill(
      child: Material(
        color: Colors.black.withValues(alpha: 0.72),
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: 420, maxHeight: maxHeight),
              child: Card(
                key: const Key('sticky_notes_gate'),
                margin: const EdgeInsets.all(16),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Sticky notes need attention',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Tick each sticky note before you continue. You cannot use the rest of the system until these are sorted.',
                      ),
                      const SizedBox(height: 12),
                      for (final note in state.notes)
                        CheckboxListTile(
                          key: Key('sticky_gate_tick_${note.id}'),
                          contentPadding: EdgeInsets.zero,
                          value: note.isDone,
                          title: Text(
                            note.title.isEmpty ? 'Sticky note' : note.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(
                            note.content,
                            maxLines: 6,
                            overflow: TextOverflow.ellipsis,
                          ),
                          onChanged: state.acting
                              ? null
                              : (_) => ref
                                    .read(stickyNotesGateProvider.notifier)
                                    .tick(note.id),
                        ),
                      if (state.error != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            state.error!,
                            style: const TextStyle(color: AppColors.destructive),
                          ),
                        ),
                      const SizedBox(height: 8),
                      CbPrimaryButton(
                        key: const Key('sticky_gate_refresh'),
                        label: 'Refresh',
                        onPressed: () =>
                            ref.read(stickyNotesGateProvider.notifier).load(),
                      ),
                      TextButton(
                        key: const Key('sticky_gate_sign_out'),
                        onPressed: () =>
                            ref.read(authControllerProvider.notifier).logout(),
                        child: const Text('Sign out'),
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
