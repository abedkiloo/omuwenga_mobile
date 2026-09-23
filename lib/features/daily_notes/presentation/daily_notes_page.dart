import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../design_system/buttons/cb_primary_button.dart';
import '../../../design_system/chrome/cb_surface_card.dart';
import '../../../design_system/states/async_states.dart';
import '../../auth/application/auth_controller.dart';
import '../../auth/domain/auth_session.dart';
import '../application/daily_notes_controllers.dart';
import '../domain/daily_note.dart';

bool _canAssign(AuthSession? session) {
  if (session == null) return false;
  return sessionCanAssignDailyNotes(
    viewAll: session.permissions.canViewAllDailyNotes,
    isAdmin: session.profile.isAdmin,
    isSuperAdmin: session.profile.isSuperAdmin,
    isSuperuser: session.user.isSuperuser,
  );
}

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
      final session = ref.read(authControllerProvider).session;
      ref.read(dailyNotesProvider.notifier).load(
            loadStaff: _canAssign(session),
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
    final canAssign = _canAssign(session);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Daily notes'),
        actions: [
          IconButton(
            key: const Key('daily_notes_refresh'),
            onPressed: () => ref.read(dailyNotesProvider.notifier).load(
                  loadStaff: canAssign,
                ),
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
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 88),
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
                    contentPadding: EdgeInsets.zero,
                    value: task.isDone,
                    title: Text(
                      task.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: task.description.isEmpty
                        ? null
                        : Text(
                            task.description,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                          ),
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
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    decoration: note.isDone
                                        ? TextDecoration.lineThrough
                                        : null,
                                  ),
                                ),
                                Text(
                                  note.content,
                                  maxLines: 8,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  _noteMeta(note),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
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

String _noteMeta(DailyNote note) {
  final audience = noteAudienceLabel(note);
  final kind = note.isSticky ? 'Sticky' : 'General';
  if (audience.isEmpty) return kind;
  return '$kind · $audience';
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
  bool _assignToRole = false;
  int? _assignedTo;
  int? _assignedRole;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_canAssign(ref.read(authControllerProvider).session)) {
        ref.read(dailyNotesProvider.notifier).loadAssignees();
      }
    });
  }

  @override
  void dispose() {
    _content.dispose();
    _title.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(dailyNotesProvider);
    final canAssign = _canAssign(ref.watch(authControllerProvider).session);
    final padding = MediaQuery.viewInsetsOf(context).bottom;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + padding),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Add note', style: Theme.of(context).textTheme.titleMedium),
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
                contentPadding: EdgeInsets.zero,
                title: const Text('Sticky note'),
                subtitle: const Text(
                  'Blocks the person (or everyone in the role) until they tick it.',
                ),
                value: _sticky,
                onChanged: (v) => setState(() => _sticky = v),
              ),
              if (canAssign) ...[
                const SizedBox(height: 4),
                const Text('Assign to'),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ChoiceChip(
                      key: const Key('daily_note_assign_person'),
                      label: const Text('Someone'),
                      selected: !_assignToRole,
                      onSelected: (_) => setState(() {
                        _assignToRole = false;
                        _assignedRole = null;
                      }),
                    ),
                    ChoiceChip(
                      key: const Key('daily_note_assign_role'),
                      label: const Text('A role'),
                      selected: _assignToRole,
                      onSelected: (_) => setState(() {
                        _assignToRole = true;
                        _assignedTo = null;
                      }),
                    ),
                  ],
                ),
                if (!_assignToRole)
                  DropdownButtonFormField<int?>(
                    key: ValueKey('daily_note_assignee_${state.staff.length}'),
                    initialValue: _assignedTo,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Person'),
                    items: [
                      const DropdownMenuItem<int?>(
                        value: null,
                        child: Text(
                          'Select person…',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      for (final s in state.staff)
                        DropdownMenuItem<int?>(
                          value: s.id,
                          child: Text(
                            s.displayName,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                    onChanged: (v) => setState(() => _assignedTo = v),
                  )
                else
                  DropdownButtonFormField<int?>(
                    key: ValueKey('daily_note_role_${state.roles.length}'),
                    initialValue: _assignedRole,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Everyone with this role',
                    ),
                    items: [
                      const DropdownMenuItem<int?>(
                        value: null,
                        child: Text(
                          'Select role…',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      for (final r in state.roles)
                        DropdownMenuItem<int?>(
                          value: r.id,
                          child: Text(
                            r.name,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                    onChanged: (v) => setState(() => _assignedRole = v),
                  ),
                if (_sticky)
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Text(
                      'Sticky notes need a person or a role so someone can tick them.',
                    ),
                  ),
              ] else if (_sticky)
                const Padding(
                  padding: EdgeInsets.only(top: 4),
                  child: Text(
                    'This sticky note will block you until you tick it.',
                  ),
                ),
              if (state.error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    state.error!,
                    style: const TextStyle(color: AppColors.destructive),
                  ),
                ),
              const SizedBox(height: 12),
              CbPrimaryButton(
                key: const Key('daily_note_save'),
                label: 'Save note',
                onPressed: state.acting
                    ? null
                    : () async {
                        final ok =
                            await ref.read(dailyNotesProvider.notifier).createNote(
                                  content: _content.text,
                                  title: _title.text,
                                  isSticky: _sticky,
                                  assignedTo: _assignToRole ? null : _assignedTo,
                                  assignedRole: _assignToRole ? _assignedRole : null,
                                );
                        if (ok && context.mounted) Navigator.pop(context, true);
                      },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
