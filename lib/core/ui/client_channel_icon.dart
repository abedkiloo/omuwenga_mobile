import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Material `computer` / `smartphone` — the usual pair for web vs mobile app.
class ClientChannelIcon extends StatelessWidget {
  const ClientChannelIcon({
    super.key,
    required this.channel,
    this.size = 16,
  });

  final String? channel;
  final double size;

  @override
  Widget build(BuildContext context) {
    final normalized = (channel ?? '').toLowerCase();
    if (normalized == 'web') {
      return Icon(
        Icons.computer,
        size: size,
        color: AppColors.mutedForeground,
        semanticLabel: 'Web',
      );
    }
    if (normalized == 'mobile') {
      return Icon(
        Icons.smartphone,
        size: size,
        color: AppColors.mutedForeground,
        semanticLabel: 'Mobile app',
      );
    }
    return const SizedBox.shrink();
  }
}

class SaleNumberLabel extends StatelessWidget {
  const SaleNumberLabel({
    super.key,
    required this.saleNumber,
    this.channel,
    this.style,
    this.size = 16,
  });

  final String saleNumber;
  final String? channel;
  final TextStyle? style;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (channel == 'web' || channel == 'mobile') ...[
          ClientChannelIcon(channel: channel, size: size),
          const SizedBox(width: 6),
        ],
        Expanded(
          child: Text(
            saleNumber,
            overflow: TextOverflow.ellipsis,
            style: style,
          ),
        ),
      ],
    );
  }
}
