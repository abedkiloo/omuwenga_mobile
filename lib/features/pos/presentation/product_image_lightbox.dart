import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

/// Full-screen product image viewer (web ProductImageLightbox parity).
Future<void> showProductImageLightbox(
  BuildContext context, {
  required String imageUrl,
  required String title,
  String? subtitle,
}) {
  return showDialog<void>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.85),
    builder: (ctx) {
      return Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: _ProductImageLightboxBody(
          imageUrl: imageUrl,
          title: title,
          subtitle: subtitle,
        ),
      );
    },
  );
}

class _ProductImageLightboxBody extends StatefulWidget {
  const _ProductImageLightboxBody({
    required this.imageUrl,
    required this.title,
    this.subtitle,
  });

  final String imageUrl;
  final String title;
  final String? subtitle;

  @override
  State<_ProductImageLightboxBody> createState() =>
      _ProductImageLightboxBodyState();
}

class _ProductImageLightboxBodyState extends State<_ProductImageLightboxBody> {
  double _scale = 1;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Align(
          alignment: Alignment.centerRight,
          child: IconButton(
            tooltip: 'Close',
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close, color: Colors.white),
          ),
        ),
        Flexible(
          child: GestureDetector(
            onTap: () => setState(() => _scale = _scale > 1 ? 1 : 1.75),
            child: InteractiveViewer(
              minScale: 1,
              maxScale: 4,
              child: AnimatedScale(
                scale: _scale,
                duration: const Duration(milliseconds: 180),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(
                    widget.imageUrl,
                    fit: BoxFit.contain,
                    errorBuilder: (_, _, _) => Container(
                      height: 220,
                      color: AppColors.surface,
                      alignment: Alignment.center,
                      child: const Icon(Icons.broken_image_outlined, size: 48),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
          decoration: BoxDecoration(
            color: const Color(0xFF18181B),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleSmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (widget.subtitle != null &&
                  widget.subtitle!.trim().isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  widget.subtitle!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.white70,
                  ),
                ),
              ],
              const SizedBox(height: 6),
              Text(
                _scale > 1 ? 'Tap image to zoom out' : 'Tap image to zoom',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: Colors.white54,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
