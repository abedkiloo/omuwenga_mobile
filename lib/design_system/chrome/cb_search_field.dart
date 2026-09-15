import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

class CbSearchField extends StatelessWidget {
  const CbSearchField({
    super.key,
    required this.controller,
    this.hintText = 'Search',
    this.onSubmitted,
    this.onSearchTap,
    this.fieldKey,
    this.searchButtonKey,
  });

  final TextEditingController controller;
  final String hintText;
  final ValueChanged<String>? onSubmitted;
  final VoidCallback? onSearchTap;
  final Key? fieldKey;
  final Key? searchButtonKey;

  @override
  Widget build(BuildContext context) {
    return TextField(
      key: fieldKey,
      controller: controller,
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        hintText: hintText,
        prefixIcon: const Icon(Icons.search, color: AppColors.mutedForeground),
        suffixIcon: onSearchTap == null
            ? null
            : IconButton(
                key: searchButtonKey,
                icon: const Icon(Icons.search),
                onPressed: onSearchTap,
              ),
      ),
      onSubmitted: onSubmitted,
    );
  }
}
