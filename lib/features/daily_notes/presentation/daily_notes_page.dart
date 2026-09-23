import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../design_system/buttons/cb_primary_button.dart';
import '../../../design_system/chrome/cb_surface_card.dart';
import '../../../design_system/states/async_states.dart';
import '../../auth/application/auth_controller.dart';
import '../application/daily_notes_controllers.dart';
import '../domain/daily_note.dart';

class DailyNotesPage extends ConsumerStatefulWidget {
  const DailyNotesPage({super.key});

  @override
  ConsumerState<DailyNotesPage> createState() => _DailyNotesPageState();
}

class _DailyNotesPageState extends ConsumerState<DailyNotesPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final perms = ref.read(authControllerProvider).session?.permissions;
      ref.read(dailyNotesProvider.notifier).load(
            loadStaff: perms?.canViewAllDailyNotes ?? false,
          );
    });
  }

  Future<void> _addNote() async {
    final created = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _AddNoteSheet(),
    );
    if (created == true && mounted) {
      await ref.read(dailyNotesProvider.notifier).load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(dailyNotesProvider);
    final session = ref.watch(authControllerProvider).session;
    final userId = session?.user.id;
    final viewAll = session?.permissions.canViewAllDailyNotes ?? false;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Daily notes'),
        actions: [
          IconButton(
            key: const Key('daily_notes_refresh'),
            onPressed: () => ref.read(dailyNotesProvider.notifier).load(),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      floatingActionButton: (session?.permissions.canCreateDailyNotes ?? true)
          ? FloatingActionButton(
              key: const Key('daily_notes_add'),
              onPressed: _addNote,
              child: const Icon(Icons.add),
            )
          : null,
      body: state.loading && state.notes.isEmpty && state.tasks.isEmpty
          ? const LoadingState(label: 'Loading notes…')
          : ListView(
              padding: const EdgeInsets.all(12),
              children: [
                Text(
                  state.date,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                if (state.error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      state.error!,
                      key: const Key('daily_notes_error'),
                      style: const TextStyle(color: AppColors.destructive),
                    ),
                  ),
                const SizedBox(height: 12),
                Text('Tasks', style: Theme.of(context).textTheme.titleSmall),
                if (state.tasks.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Text('No tasks for this day.'),
                  ),
                for (final task in state.tasks)
                  CheckboxListTile(
                    key: Key('daily_task_${task.id}'),
                    value: task.isDone,
                    title: Text(task.title),
                    subtitle: task.description.isEmpty
                        ? null
                        : Text(task.description),
                    onChanged: (_) =>
                        ref.read(dailyNotesProvider.notifier).toggleTask(task.id),
                  ),
                const SizedBox(height: 16),
                Text('Notes', style: Theme.of(context).textTheme.titleSmall),
                if (state.notes.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Text('No notes for this day.'),
                  ),
                for (final note in state.notes)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: CbSurfaceCard(
                      key: Key('daily_note_${note.id}'),
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Checkbox(
                            key: Key('daily_note_tick_${note.id}'),
                            value: note.isDone,
                            onChanged:
                                canToggleDailyNote(note, userId, viewAll: viewAll)
                                ? (_) => ref
                                      .read(dailyNotesProvider.notifier)
                                      .toggleNote(note.id)
                                : null,
                          ),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  note.title.isEmpty ? note.kindLabel : note.title,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    decoration: note.isDone
                                        ? TextDecoration.lineThrough
                                        : null,
                                  ),
                                ),
                                Text(note.content),
                                Text(
                                  note.isSticky
                                      ? 'Sticky${note.assignedToName.isNotEmpty ? ' · ${note.assignedToName}' : ''}'
                                      : 'General',
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(color: AppColors.mutedForeground),
                                ),
                              ],
                            ),
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

class _AddNoteSheet extends ConsumerStatefulWidget {
  const _AddNoteSheet();

  @override
  ConsumerState<_AddNoteSheet> createState() => _AddNoteSheetState();
}

class _AddNoteSheetState extends ConsumerState<_AddNoteSheet> {
  final _content = TextEditingController();
  final _title = TextEditingController();
  bool _sticky = false;
  int? _assignedTo;

  @override
  void dispose() {
    _content.dispose();
    _title.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(dailyNotesProvider);
    final viewAll =
        ref.watch(authControllerProvider).session?.permissions.canViewAllDailyNotes ??
        false;
    final padding = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + padding),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            key: const Key('daily_note_title'),
            controller: _title,
            decoration: const InputDecoration(labelText: 'Title (optional)'),
          ),
          TextField(
            key: const Key('daily_note_content'),
            controller: _content,
            maxLines: 4,
            decoration: const InputDecoration(labelText: 'Note'),
          ),
          SwitchListTile(
            key: const Key('daily_note_sticky'),
            title: const Text('Sticky note'),
            subtitle: const Text(
              'Blocks the assignee until they tick it. General notes do not block.',
            ),
            value: _sticky,
            onChanged: (v) => setState(() => _sticky = v),
          ),
          if (_sticky && viewAll && state.staff.isNotEmpty)
            DropdownButtonFormField<int>(
              key: const Key('daily_note_assignee'),
              initialValue: _assignedTo,
              decoration: const InputDecoration(labelText: 'Assign to'),
              items: [
                for (final s in state.staff)
                  DropdownMenuItem(value: s.id, child: Text(s.displayName)),
              ],
              onChanged: (v) => setState(() => _assignedTo = v),
            ),
          const SizedBox(height: 12),
          CbPrimaryButton(
            key: const Key('daily_note_save'),
            label: 'Save note',
            onPressed: state.acting
                ? null
                : () async {
                    final ok = await ref.read(dailyNotesProvider.notifier).createNote(
                          content: _content.text,
                          title: _title.text,
                          isSticky: _sticky,
                          assignedTo: _assignedTo,
                        );
                    if (ok && context.mounted) Navigator.pop(context, true);
                  },
          ),
        ],
      ),
    );
  }
}
