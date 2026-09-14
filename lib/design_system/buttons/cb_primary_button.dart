import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

class CbPrimaryButton extends StatelessWidget {
  const CbPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
  });

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.primaryForeground,
        ),
        child: Text(label),
      ),
    );
  }
}
