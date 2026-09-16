import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import 'cb_status_pill.dart';

class CbFlowHeader extends StatelessWidget implements PreferredSizeWidget {
  const CbFlowHeader({
    super.key,
    required this.title,
    this.leadingIcon,
    this.subtitle,
    this.showOnline = true,
    this.onlineLabel = 'Online',
    this.trailing,
    this.onBack,
  });

  final String title;
  final IconData? leadingIcon;
  final String? subtitle;
  final bool showOnline;
  final String onlineLabel;
  final Widget? trailing;
  final VoidCallback? onBack;

  @override
  Size get preferredSize => Size.fromHeight(subtitle != null ? 96 : 72);

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(4, 4, 12, 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: onBack ?? () => Navigator.maybePop(context),
                color: AppColors.foreground,
              ),
              if (leadingIcon != null) ...[
                Icon(leadingIcon, size: 22, color: AppColors.primary),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppColors.foreground,
                      ),
                    ),
                    if (subtitle != null)
                      Text(
                        subtitle!,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.mutedForeground,
                        ),
                      ),
                  ],
                ),
              ),
              if (showOnline)
                CbStatusPill(
                  label: onlineLabel,
                  variant: CbStatusPillVariant.online,
                  showOnlineDot: true,
                )
              else
                ?trailing,
              if (showOnline && trailing != null) ...[
                const SizedBox(width: 8),
                trailing!,
              ],
            ],
          ),
        ),
      ),
    );
  }
}
