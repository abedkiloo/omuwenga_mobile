import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/theme/app_theme.dart';
import '../core/branding/brand_assets.dart';
import 'router.dart';

class CompleteByteApp extends ConsumerWidget {
  const CompleteByteApp({
    super.key,
    this.router,
    this.fetchRuntimeFonts = true,
  });

  final GoRouter? router;
  final bool fetchRuntimeFonts;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final goRouter = router ?? ref.watch(routerProvider);
    return MaterialApp.router(
      title: BrandAssets.appName,
      theme: AppTheme.light(fetchRuntimeFonts: fetchRuntimeFonts),
      routerConfig: goRouter,
      debugShowCheckedModeBanner: false,
    );
  }
}
