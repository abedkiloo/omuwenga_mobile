import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/branding/brand_assets.dart';
import '../../../core/theme/app_colors.dart';
import '../../../design_system/branding/brand_logo.dart';
import '../../../design_system/buttons/cb_primary_button.dart';
import '../../../design_system/chrome/cb_atmosphere.dart';
import '../../../design_system/chrome/cb_password_field.dart';
import '../../../design_system/chrome/cb_reminder_banner.dart';
import '../../../design_system/chrome/cb_surface_card.dart';
import '../application/auth_controller.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _username = TextEditingController();
  final _password = TextEditingController();
  String? _localError;

  @override
  void dispose() {
    _username.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _localError = null);
    final user = _username.text.trim();
    final pass = _password.text;
    if (user.isEmpty || pass.isEmpty) {
      setState(() => _localError = 'Enter your username and password.');
      return;
    }
    await ref
        .read(authControllerProvider.notifier)
        .login(username: user, password: pass);
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);
    final theme = Theme.of(context);
    final error = _localError ?? auth.message;

    final env = ref.watch(appEnvProvider);
    final envLabel = env.environmentLabel;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: CbAtmosphere(
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final short = constraints.maxHeight < 560;
              return SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: constraints.maxHeight - 32,
                  ),
                  child: IntrinsicHeight(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (envLabel.isNotEmpty) ...[
                          Align(
                            alignment: Alignment.centerRight,
                            child: Container(
                              key: const Key('login_env_badge'),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.accent.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(
                                  AppColors.radiusSm,
                                ),
                              ),
                              child: Text(
                                envLabel,
                                style: theme.textTheme.labelMedium?.copyWith(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                        ],
                        const Spacer(),
                        CbSurfaceCard(
                          padding: EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: short ? 20 : 28,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              BrandLogo(
                                height: short ? 100 : 140,
                                showWordmark: true,
                                showTagline: !short,
                              ),
                              const SizedBox(height: 20),
                              Text(
                                'Sign in to start your shift.',
                                style: theme.textTheme.bodyLarge?.copyWith(
                                  color: AppColors.mutedForeground,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 16),
                              TextField(
                                controller: _username,
                                key: const Key('login_username'),
                                decoration: const InputDecoration(
                                  labelText: 'Username',
                                  border: OutlineInputBorder(),
                                ),
                                textInputAction: TextInputAction.next,
                                autocorrect: false,
                                enabled: !auth.busy,
                              ),
                              const SizedBox(height: 12),
                              CbPasswordField(
                                fieldKey: const Key('login_password'),
                                toggleKey: const Key('login_password_toggle'),
                                controller: _password,
                                labelText: 'Password',
                                onSubmitted: (_) => _submit(),
                                enabled: !auth.busy,
                              ),
                              if (error != null) ...[
                                const SizedBox(height: 12),
                                Text(
                                  error,
                                  key: const Key('login_error'),
                                  style: theme.textTheme.bodyLarge?.copyWith(
                                    color: AppColors.destructive,
                                  ),
                                ),
                              ],
                              const SizedBox(height: 16),
                              CbPrimaryButton(
                                label: auth.busy ? 'Signing in…' : 'Sign in',
                                onPressed: auth.busy ? null : _submit,
                              ),
                              const SizedBox(height: 14),
                              const CbReminderBanner(
                                message:
                                    'Reminder: Keep your PIN private. Close the till before you leave the counter.',
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Please ensure all items are checked and verified • ${BrandAssets.operationsFooter}',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: AppColors.mutedForeground,
                          ),
                        ),
                        const Spacer(),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
