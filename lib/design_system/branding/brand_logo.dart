import 'package:flutter/material.dart';

import '../../core/branding/brand_assets.dart';

/// Hero / splash brand mark — one composition, brand first.
class BrandLogo extends StatelessWidget {
  const BrandLogo({
    super.key,
    this.height = 160,
    this.showTagline = false,
  });

  final double height;
  final bool showTagline;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Image.asset(
          BrandAssets.logo,
          key: const Key('brand_logo'),
          height: height,
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
                  color: const Color(0xFF5B2C8A),
                ),
          ),
        ],
      ],
    );
  }
}
