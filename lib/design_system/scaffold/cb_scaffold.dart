import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

class CbScaffold extends StatelessWidget {
  const CbScaffold({
    super.key,
    required this.title,
    required this.body,
    this.floatingActionButton,
  });

  final String title;
  final Widget body;
  final Widget? floatingActionButton;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: body,
      ),
      floatingActionButton: floatingActionButton,
      backgroundColor: AppColors.background,
    );
  }
}
