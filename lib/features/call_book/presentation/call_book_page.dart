import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/result/result.dart';
import '../../../core/theme/app_colors.dart';
import '../application/call_book_controller.dart';
import '../domain/call_book.dart';

/// Call centre on the phone.
///
/// Staff copy a number and call on their own phone, then record the result.
/// The list is ten customers at a time. A recorded call leaves the list.
class CallBookPage extends ConsumerStatefulWidget {
  const CallBookPage({super.key});

  @override
  ConsumerState<CallBookPage> createState() => _CallBookPageState();
}

class _CallBookPageState extends ConsumerState<CallBookPage> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(callBookControllerProvider.notifier).load());
  }

  @override
  Widget build(BuildContext context) {
    final view = ref.watch(callBookControllerProvider);
    final theme = Theme.of(context);
    final summary = view.book?.summary;
    return Scaffold(
      backgroundColor: AppColors.background,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
        children: [
          Text('Call centre', style: theme.textTheme.titleLarge),
          const SizedBox(height: 4),
          Text(
            'Copy the number and call on your phone. Then record what happened.',
            style: theme.textTheme.bodyMedium,
          ),
          if (summary != null) ...[
            const SizedBox(height: 12),
            Text(
              'Recorded ${summary.called} of ${summary.callable}. ${view.total} still on this list.',
              key: const Key('call_book_summary'),
            ),
          ],
          if (summary != null && !summary.isCallDay)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text('The weekend shows who was missed. Recording opens again on Monday.'),
            ),
          if (summary != null) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: [
                for (final day in summary.days)
                  ChoiceChip(
                    key: Key('call_day_${day.weekday}'),
                    label: Text(
                      '${callWeekdayLabel(day.weekday).substring(0, 3)} ${day.notCalled}',
                    ),
                    selected: view.weekday == day.weekday,
                    onSelected: (_) => ref
                        .read(callBookControllerProvider.notifier)
                        .setWeekday(day.weekday),
                  ),
              ],
            ),
          ],
          if (view.loading && view.book == null)
            const Padding(
              padding: EdgeInsets.only(top: 24),
              child: Center(child: CircularProgressIndicator()),
            ),
          if (view.error.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(view.error, style: TextStyle(color: theme.colorScheme.error)),
            ),
          if (!view.loading && view.rows.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 16),
              child: Text('Everyone on this day already has a result, or the list is empty.'),
            ),
          for (final row in view.rows)
            ListTile(
              key: Key('call_customer_${row.customerId}'),
              title: Text(row.name),
              subtitle: Text(row.place.isEmpty ? 'Open to record the call' : row.place),
              trailing: row.callLaterDue
                  ? const Text('Due')
                  : const Icon(Icons.chevron_right),
              onTap: summary == null
                  ? null
                  : () => _openRecord(context, row, summary.isCallDay),
            ),
          if (view.total > 0) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                OutlinedButton(
                  key: const Key('call_previous_page'),
                  onPressed: view.page <= 1
                      ? null
                      : () => ref.read(callBookControllerProvider.notifier).setPage(view.page - 1),
                  child: const Text('Previous page'),
                ),
                Expanded(
                  child: Text(
                    'Page ${view.page} of ${view.pageCount}',
                    textAlign: TextAlign.center,
                  ),
                ),
                OutlinedButton(
                  key: const Key('call_next_page'),
                  onPressed: view.page >= view.pageCount
                      ? null
                      : () => ref.read(callBookControllerProvider.notifier).setPage(view.page + 1),
                  child: const Text('Next page'),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _openRecord(BuildContext context, CallBookRow row, bool markingOpen) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (context) => _RecordSheet(row: row, markingOpen: markingOpen),
    );
    if (saved == true) {
      await ref.read(callBookControllerProvider.notifier).load();
    }
  }
}

class _RecordSheet extends ConsumerStatefulWidget {
  const _RecordSheet({required this.row, required this.markingOpen});

  final CallBookRow row;
  final bool markingOpen;

  @override
  ConsumerState<_RecordSheet> createState() => _RecordSheetState();
}

class _RecordSheetState extends ConsumerState<_RecordSheet> {
  String _outcome = 'called';
  final _notes = TextEditingController();
  final _date = TextEditingController();
  final _time = TextEditingController();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _notes.text = widget.row.previousSummary;
  }

  @override
  void dispose() {
    _notes.dispose();
    _date.dispose();
    _time.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final row = widget.row;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.all(16),
        children: [
          Text(row.name, style: Theme.of(context).textTheme.titleMedium),
          if (row.place.isNotEmpty) Text(row.place),
          const SizedBox(height: 8),
          SelectableText(row.phone, key: const Key('call_phone')),
          if (row.callLaterDue)
            const Text('The time to call again has been reached.'),
          const SizedBox(height: 8),
          OutlinedButton(
            key: const Key('call_copy_phone'),
            onPressed: _copy,
            child: const Text('Copy phone number'),
          ),
          if (!widget.markingOpen)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text('Recording opens again on Monday.'),
            ),
          if (widget.markingOpen) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                for (final item in const [
                  ('called', 'Called'),
                  ('ask_later', 'Call later'),
                  ('no_answer', 'No answer'),
                  ('unreachable', 'Unreachable'),
                ])
                  ChoiceChip(
                    label: Text(item.$2),
                    selected: _outcome == item.$1,
                    onSelected: (_) => setState(() => _outcome = item.$1),
                  ),
              ],
            ),
            TextField(
              key: Key('call_notes_${row.customerId}'),
              controller: _notes,
              maxLength: 500,
              decoration: const InputDecoration(labelText: 'Notes'),
            ),
            TextField(
              key: Key('call_date_${row.customerId}'),
              controller: _date,
              decoration: const InputDecoration(labelText: 'Follow-up date YYYY-MM-DD'),
            ),
            if (_outcome == 'ask_later')
              TextField(
                key: Key('call_time_${row.customerId}'),
                controller: _time,
                decoration: const InputDecoration(labelText: 'Time to call again HH:MM'),
              ),
            const SizedBox(height: 8),
            FilledButton(
              key: const Key('call_save'),
              onPressed: _saving ? null : _save,
              child: Text(_saving ? 'Saving…' : 'Save record'),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _copy() async {
    final result = await ref.read(callBookApiProvider).hold(widget.row.customerId);
    if (!mounted) return;
    if (result.isFailure) {
      _toast('${(result as Failure).error}');
      return;
    }
    await Clipboard.setData(ClipboardData(text: widget.row.phone));
    if (!mounted) return;
    _toast('Number copied. Call from your phone, then record the result.');
  }

  Future<void> _save() async {
    final time = _time.text.trim();
    if (_outcome == 'ask_later' && !RegExp(r'^([01]\d|2[0-3]):[0-5]\d$').hasMatch(time)) {
      _toast('Choose the time to call again.');
      return;
    }
    setState(() => _saving = true);
    final result = await ref.read(callBookApiProvider).mark(
          customerId: widget.row.customerId,
          outcome: _outcome,
          summary: _notes.text.trim(),
          followUpOn: _date.text.trim(),
          followUpTime: _outcome == 'ask_later' ? time : '',
        );
    if (!mounted) return;
    setState(() => _saving = false);
    if (result.isFailure) {
      _toast('${(result as Failure).error}');
      return;
    }
    Navigator.of(context).pop(true);
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }
}
