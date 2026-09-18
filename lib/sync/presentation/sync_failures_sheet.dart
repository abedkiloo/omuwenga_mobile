import 'package:flutter/material.dart';

import '../domain/outbox_entry.dart';

/// Minimal retry/discard surface for permanently failed outbox items.
class SyncFailuresSheet extends StatelessWidget {
  const SyncFailuresSheet({
    super.key,
    required this.items,
    required this.onRetry,
    required this.onDiscard,
  });

  final List<OutboxEntry> items;
  final ValueChanged<String> onRetry;
  final ValueChanged<String> onDiscard;

  static Future<void> show(
    BuildContext context, {
    required List<OutboxEntry> items,
    required ValueChanged<String> onRetry,
    required ValueChanged<String> onDiscard,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => SyncFailuresSheet(
        items: items,
        onRetry: onRetry,
        onDiscard: onDiscard,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(12),
        child: Text('No failed syncs.'),
      );
    }
    return SafeArea(
      child: ListView.separated(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(12, 6, 12, 12),
        itemCount: items.length + 1,
        separatorBuilder: (_, _) => const Divider(height: 1),
        itemBuilder: (context, index) {
          if (index == 0) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                'Could not sync',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            );
          }
          final item = items[index - 1];
          return Padding(
            key: Key('sync_fail_${item.id}'),
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(item.humanError ?? 'Sync failed'),
                const SizedBox(height: 4),
                Text(
                  '${item.method} ${item.path}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    TextButton(
                      onPressed: () {
                        onRetry(item.id);
                        Navigator.of(context).maybePop();
                      },
                      child: const Text('Retry'),
                    ),
                    TextButton(
                      onPressed: () {
                        onDiscard(item.id);
                        Navigator.of(context).maybePop();
                      },
                      child: const Text('Discard'),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
