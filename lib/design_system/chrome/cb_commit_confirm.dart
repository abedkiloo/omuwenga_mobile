import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

class CommitSummaryRow {
  const CommitSummaryRow({
    required this.label,
    required this.value,
    this.emphasis = false,
  });

  final String label;
  final String value;
  final bool emphasis;
}

/// Shared “review then confirm” dialog before sending data to the backend.
Future<bool> showCommitConfirm({
  required BuildContext context,
  required String title,
  String? description,
  List<CommitSummaryRow> rows = const [],
  String confirmLabel = 'Confirm & send',
  String cancelLabel = 'Back',
  Key confirmKey = const Key('commit_confirm'),
  Key cancelKey = const Key('commit_cancel'),
}) async {
  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) {
      return AlertDialog(
        title: Text(title),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (description != null && description.isNotEmpty) ...[
                Text(description),
                const SizedBox(height: 12),
              ],
              for (final row in rows)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          row.label,
                          style: const TextStyle(
                            color: AppColors.mutedForeground,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Flexible(
                        child: Text(
                          row.value,
                          textAlign: TextAlign.right,
                          style: TextStyle(
                            fontWeight: row.emphasis
                                ? FontWeight.w700
                                : FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            key: cancelKey,
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(cancelLabel),
          ),
          FilledButton(
            key: confirmKey,
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(confirmLabel),
          ),
        ],
      );
    },
  );
  return result == true;
}
