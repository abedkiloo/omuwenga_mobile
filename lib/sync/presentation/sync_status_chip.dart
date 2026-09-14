import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../application/sync_status_controller.dart';

class SyncStatusChip extends StatelessWidget {
  const SyncStatusChip({
    super.key,
    required this.status,
    this.onTap,
  });

  final SyncStatus status;
  final VoidCallback? onTap;

  Color get _bg {
    switch (status.tone) {
      case SyncChipTone.error:
        return AppColors.destructive.withValues(alpha: 0.12);
      case SyncChipTone.offline:
        return AppColors.warning.withValues(alpha: 0.14);
      case SyncChipTone.pending:
        return AppColors.secondary;
      case SyncChipTone.online:
        return AppColors.success.withValues(alpha: 0.12);
    }
  }

  Color get _fg {
    switch (status.tone) {
      case SyncChipTone.error:
        return AppColors.destructive;
      case SyncChipTone.offline:
        return const Color(0xFFB45309);
      case SyncChipTone.pending:
        return AppColors.mutedForeground;
      case SyncChipTone.online:
        return AppColors.success;
    }
  }

  IconData get _icon {
    switch (status.tone) {
      case SyncChipTone.error:
        return Icons.error_outline;
      case SyncChipTone.offline:
        return Icons.cloud_off_outlined;
      case SyncChipTone.pending:
        return Icons.cloud_upload_outlined;
      case SyncChipTone.online:
        return Icons.cloud_done_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _bg,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        key: const Key('sync_status_chip'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(_icon, size: 16, color: _fg),
              const SizedBox(width: 6),
              Text(
                status.label,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(color: _fg),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
