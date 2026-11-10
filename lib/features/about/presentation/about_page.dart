import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/app_build_info.dart';
import '../../../core/branding/brand_assets.dart';
import '../../../core/theme/app_colors.dart';
import '../../../design_system/branding/brand_logo.dart';
import '../../../design_system/buttons/cb_primary_button.dart';
import '../../../design_system/chrome/cb_surface_card.dart';
import '../../../design_system/scaffold/cb_scaffold.dart';
import '../../../design_system/states/async_states.dart';
import '../../auth/application/auth_controller.dart';
import '../../health/providers.dart';

/// About / version — the shop-floor “what app is this?” screen.
///
/// Mental model:
/// - Brand first, then version staff can read to support.
/// - Signed-in identity (who am I on this phone?).
/// - Environment only when non-prod (UAT), so prod stays calm.
/// - Connection check is secondary (“is the till talking to the shop?”),
///   not the headline — that was the old “API health” confusion.
class AboutPage extends ConsumerWidget {
  const AboutPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final env = ref.watch(appEnvProvider);
    final session = ref.watch(authControllerProvider).session;
    final envLabel = env.environmentLabel;
    final role = (session?.profile.roleDisplay ?? session?.profile.role ?? '')
        .trim();
    final who = session?.user.displayName ?? 'Signed out';

    return CbScaffold(
      title: 'About',
      body: ListView(
        children: [
          CbSurfaceCard(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const BrandLogo(height: 96, showWordmark: true, showTagline: true),
                const SizedBox(height: 16),
                Text(
                  BrandAssets.appName,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Version ${AppBuildInfo.displayLabel}',
                  key: const Key('about_version'),
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (envLabel.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Center(
                    child: Container(
                      key: const Key('about_env_badge'),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.accent.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(AppColors.radiusSm),
                      ),
                      child: Text(
                        '$envLabel build — not live shop data',
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
          CbSurfaceCard(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(
              children: [
                _InfoRow(
                  label: 'Signed in as',
                  value: who,
                  key: const Key('about_signed_in'),
                ),
                if (role.isNotEmpty)
                  _InfoRow(
                    label: 'Role',
                    value: role,
                    key: const Key('about_role'),
                  ),
                _InfoRow(
                  label: 'Server',
                  value: _shortHost(env.apiBaseUrl),
                  key: const Key('about_server'),
                  onCopy: () => _copy(
                    context,
                    env.apiBaseUrl,
                    'Server address copied',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'When something fails at the till, tell support your version '
            '(${AppBuildInfo.displayLabel}) and whether you are on $who.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: AppColors.mutedForeground,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Connection',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Checks that this phone can reach the shop server. '
            'You do not need this for normal sales.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: AppColors.mutedForeground,
            ),
          ),
          const SizedBox(height: 12),
          const _ConnectionCheckCard(),
          const SizedBox(height: 24),
          Text(
            BrandAssets.operationsFooter,
            textAlign: TextAlign.center,
            style: theme.textTheme.labelSmall?.copyWith(
              color: AppColors.mutedForeground,
            ),
          ),
        ],
      ),
    );
  }

  static String _shortHost(String apiBaseUrl) {
    try {
      final uri = Uri.parse(apiBaseUrl);
      if (uri.host.isEmpty) return apiBaseUrl;
      return uri.host;
    } on Object {
      return apiBaseUrl;
    }
  }

  static Future<void> _copy(
    BuildContext context,
    String value,
    String snack,
  ) async {
    await Clipboard.setData(ClipboardData(text: value));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(snack)));
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    super.key,
    required this.label,
    required this.value,
    this.onCopy,
  });

  final String label;
  final String value;
  final VoidCallback? onCopy;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 108,
            child: Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppColors.mutedForeground,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: theme.textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (onCopy != null)
            IconButton(
              tooltip: 'Copy',
              onPressed: onCopy,
              icon: const Icon(Icons.copy_outlined, size: 18),
              visualDensity: VisualDensity.compact,
            ),
        ],
      ),
    );
  }
}

class _ConnectionCheckCard extends ConsumerWidget {
  const _ConnectionCheckCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(healthCheckProvider);
    final theme = Theme.of(context);

    return CbSurfaceCard(
      padding: const EdgeInsets.all(16),
      child: async.when(
        loading: () => const LoadingState(label: 'Checking connection…'),
        error: (error, _) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Could not reach the server',
              style: theme.textTheme.titleMedium?.copyWith(
                color: AppColors.destructive,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Check Wi‑Fi or mobile data, then try again.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppColors.mutedForeground,
              ),
            ),
            const SizedBox(height: 12),
            CbPrimaryButton(
              label: 'Try again',
              onPressed: () => ref.invalidate(healthCheckProvider),
            ),
          ],
        ),
        data: (result) => result.when(
          success: (status) => status.ok
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.check_circle_outline,
                          color: AppColors.primary,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Server reachable',
                          key: const Key('about_connection_ok'),
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'This phone can talk to the shop system.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: AppColors.mutedForeground,
                      ),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton(
                      onPressed: () => ref.invalidate(healthCheckProvider),
                      child: const Text('Check again'),
                    ),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Server responded with an error',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: AppColors.destructive,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 12),
                    CbPrimaryButton(
                      label: 'Try again',
                      onPressed: () => ref.invalidate(healthCheckProvider),
                    ),
                  ],
                ),
          failure: (error, _) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Could not reach the server',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: AppColors.destructive,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              CbPrimaryButton(
                label: 'Try again',
                onPressed: () => ref.invalidate(healthCheckProvider),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
