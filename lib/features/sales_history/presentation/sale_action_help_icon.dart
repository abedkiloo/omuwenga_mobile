import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../domain/sale_action_help.dart';

class SaleActionHelpIcon extends StatelessWidget {
  const SaleActionHelpIcon({super.key, required this.help});

  final SaleActionHelp help;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: '${help.body} ${help.contrast}',
      waitDuration: Duration.zero,
      showDuration: const Duration(seconds: 8),
      child: IconButton(
        key: Key('sale_help_${help.shortLabel}'),
        onPressed: () => showDialog<void>(
          context: context,
          builder: (context) {
            return AlertDialog(
              title: Text(help.title),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(help.body),
                  const SizedBox(height: 12),
                  Text(
                    help.contrast,
                    style: const TextStyle(color: AppColors.warning),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Got it'),
                ),
              ],
            );
          },
        ),
        icon: const Icon(Icons.help_outline, size: 18),
      ),
    );
  }
}
