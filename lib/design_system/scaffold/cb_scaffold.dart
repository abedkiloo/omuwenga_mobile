import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../chrome/cb_atmosphere.dart';

class CbScaffold extends StatelessWidget {
  const CbScaffold({
    super.key,
    required this.title,
    required this.body,
    this.floatingActionButton,
    this.atmosphere = true,
  });

  final String title;
  final Widget body;
  final Widget? floatingActionButton;
  final bool atmosphere;

  @override
  Widget build(BuildContext context) {
    final content = Padding(padding: const EdgeInsets.all(16), child: body);
    return Scaffold(
      appBar: AppBar(
        title: Text(
          title,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: AppColors.primary,
                fontWeight: FontWeight.w700,
              ),
        ),
      ),
      body: atmosphere ? CbAtmosphere(child: content) : content,
      floatingActionButton: floatingActionButton,
      backgroundColor: AppColors.background,
    );
  }
}
