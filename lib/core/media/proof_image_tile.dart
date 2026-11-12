import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Compact thumbnail that opens a full-screen viewer for payment/sale proof.
///
/// Used on debt collections, customer ledger, and sale detail so uploaded
/// screenshots stay reviewable after the payment is saved.
class ProofImageTile extends StatelessWidget {
  const ProofImageTile({
    super.key,
    required this.url,
    this.label = 'Receipt',
  });

  /// Absolute or app-resolved media URL. Empty → renders nothing.
  final String url;

  /// Caption shown under the thumb and in the viewer title.
  final String label;

  Future<void> _open(BuildContext context) {
    return showDialog<void>(
      context: context,
      builder: (ctx) {
        return Dialog(
          insetPadding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        label,
                        style: Theme.of(ctx).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                    ),
                    IconButton(
                      key: const Key('proof_image_close'),
                      onPressed: () => Navigator.pop(ctx),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
              Flexible(
                child: InteractiveViewer(
                  child: Image.network(
                    url,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) => const Padding(
                      padding: EdgeInsets.all(24),
                      child: Text('Could not load image'),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final trimmed = url.trim();
    if (trimmed.isEmpty) return const SizedBox.shrink();

    return Material(
      key: const Key('proof_image_tile'),
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _open(context),
        borderRadius: BorderRadius.circular(8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Image.network(
                trimmed,
                width: 44,
                height: 44,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(
                  width: 44,
                  height: 44,
                  color: AppColors.secondary,
                  alignment: Alignment.center,
                  child: const Icon(Icons.broken_image_outlined, size: 18),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                'View $label',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
