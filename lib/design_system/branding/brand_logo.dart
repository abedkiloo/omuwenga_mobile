import 'package:flutter/material.dart';

import '../../core/branding/brand_assets.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';

/// Hero / splash brand mark — one composition, brand first.
class BrandLogo extends StatelessWidget {
  const BrandLogo({
    super.key,
    this.height = 160,
    this.showTagline = false,
    this.showWordmark = false,
  });

  final double height;
  final bool showTagline;
  final bool showWordmark;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (showWordmark) ...[
          Text(
            BrandAssets.wordmark,
            key: const Key('brand_wordmark'),
            textAlign: TextAlign.center,
            style: AppTypography.brandWordmark(
              fontSize: height >= 120 ? 32 : 24,
            ),
          ),
          const SizedBox(height: 10),
          Container(
            width: 72,
            height: 2,
            color: AppColors.primary.withValues(alpha: 0.85),
          ),
          const SizedBox(height: 16),
        ],
        Image.asset(
          BrandAssets.logo,
          key: const Key('brand_logo'),
          height: showWordmark ? height * 0.55 : height,
          fit: BoxFit.contain,
          filterQuality: FilterQuality.high,
        ),
        if (showTagline) ...[
          const SizedBox(height: 12),
          Text(
            BrandAssets.tagline,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontStyle: FontStyle.italic,
                  color: AppColors.accent,
                  fontWeight: FontWeight.w500,
                ),
          ),
        ],
      ],
    );
  }
}

/// Compact header brand — heavy all-caps OMUWENGA (design cue).
class BrandWordmark extends StatelessWidget {
  const BrandWordmark({super.key, this.fontSize = 20});

  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return Text(
      BrandAssets.wordmark,
      key: const Key('brand_wordmark_compact'),
      style: AppTypography.brandWordmark(fontSize: fontSize),
    );
  }
}
