import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../design_system/buttons/cb_primary_button.dart';
import '../../auth/application/auth_controller.dart';
import '../application/daily_notes_controllers.dart';
import '../domain/approval_return.dart';
import '../domain/daily_note.dart';

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
    ref.listen(authControllerProvider, (prev, next) {
      if (next.isAuthenticated && !(prev?.isAuthenticated ?? false)) {
        ref.read(stickyNotesGateProvider.notifier).load();
      }
      if (!next.isAuthenticated) {
        ref.read(stickyNotesGateProvider.notifier).reset();
      }
    });

    final auth = ref.watch(authControllerProvider);
    if (!auth.isAuthenticated) return const SizedBox.shrink();
    final state = ref.watch(stickyNotesGateProvider);
    if (state.loading || !state.shouldShow) return const SizedBox.shrink();

    final maxHeight = MediaQuery.sizeOf(context).height * 0.9;
    final notes = state.openNotes;
    final blocking = state.isBlocking;
    final returnedSaleOpen = notes.any((n) => n.requiresSaleFix);

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
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            blocking
                                ? (returnedSaleOpen
                                    ? 'Returned sale — open and send back'
                                    : 'Notes that must be ticked')
                                : 'Notes for you',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            blocking
                                ? (returnedSaleOpen
                                    ? 'The manager left a comment. Open that sale, update it, then send it back for approval. Ticking this note is not enough.'
                                    : 'Tick each must-tick note before you continue. You cannot use the rest of the system until these are sorted.')
                                : 'These notes were assigned to you. Read them, tick them if you are done, or continue.',
                          ),
                        ],
                      ),
                    ),
                    Flexible(
                      child: ListView(
                        shrinkWrap: true,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        children: [
                          for (final note in notes)
                            if (note.requiresSaleFix)
                              ListTile(
                                key: Key('sticky_gate_open_sale_${note.id}'),
                                contentPadding: EdgeInsets.zero,
                                title: Text(
                                  note.title.isEmpty
                                      ? note.kindLabel
                                      : note.title,
                                ),
                                subtitle: Text(
                                  [
                                    note.content,
                                    if (carriedOverLabel(
                                      note.daysCarriedOver,
                                    ).isNotEmpty)
                                      carriedOverLabel(note.daysCarriedOver),
                                  ].join('\n'),
                                ),
                                trailing: FilledButton(
                                  onPressed: () {
                                    final path = rejectedSaleFixPath(
                                      content: note.content,
                                      title: note.title,
                                    );
                                    ref
                                        .read(stickyNotesGateProvider.notifier)
                                        .releaseForFix(note.id);
                                    if (path != null) context.go(path);
                                  },
                                  child: const Text('Open sale'),
                                ),
                              )
                            else
                              CheckboxListTile(
                                key: Key('sticky_gate_tick_${note.id}'),
                                contentPadding: EdgeInsets.zero,
                                value: note.isDone,
                                title: Text(
                                  note.title.isEmpty
                                      ? (note.isSticky ? 'Sticky note' : 'Note')
                                      : note.title,
                                ),
                                subtitle: Text(
                                  [
                                    note.content,
                                    if (carriedOverLabel(
                                      note.daysCarriedOver,
                                    ).isNotEmpty)
                                      carriedOverLabel(note.daysCarriedOver),
                                  ].join('\n'),
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
                                style: const TextStyle(
                                  color: AppColors.destructive,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          CbPrimaryButton(
                            key: const Key('sticky_gate_refresh'),
                            label: 'Refresh',
                            onPressed: () =>
                                ref.read(stickyNotesGateProvider.notifier).load(),
                          ),
                          if (!blocking)
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: FilledButton(
                                key: const Key('sticky_gate_continue'),
                                onPressed: () => ref
                                    .read(stickyNotesGateProvider.notifier)
                                    .dismissGeneral(),
                                child: const Text('Continue'),
                              ),
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
