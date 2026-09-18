import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../design_system/branding/brand_logo.dart';
import '../../../design_system/buttons/cb_primary_button.dart';
import '../application/auth_controller.dart';

class ChangePasswordPage extends ConsumerStatefulWidget {
  const ChangePasswordPage({super.key});

  @override
  ConsumerState<ChangePasswordPage> createState() => _ChangePasswordPageState();
}

class _ChangePasswordPageState extends ConsumerState<ChangePasswordPage> {
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  String? _localError;

  @override
  void dispose() {
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _localError = null);
    final password = _password.text;
    final confirm = _confirm.text;
    if (password.length < 6) {
      setState(
        () => _localError = 'Password must be at least 6 characters.',
      );
      return;
    }
    if (password != confirm) {
      setState(() => _localError = 'Passwords do not match.');
      return;
    }
    await ref.read(authControllerProvider.notifier).changePassword(
          newPassword: password,
          confirmPassword: confirm,
        );
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);
    final theme = Theme.of(context);
    final error = _localError ?? auth.message;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final short = constraints.maxHeight < 560;
            return SingleChildScrollView(
              padding: const EdgeInsets.all(12),
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight - 48,
                ),
                child: IntrinsicHeight(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Spacer(),
                      BrandLogo(height: short ? 100 : 140),
                      const SizedBox(height: 16),
                      Text(
                        'Choose your password',
                        style: theme.textTheme.headlineSmall,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Your store owner set a temporary password. Pick one only you know before you continue.',
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: AppColors.mutedForeground,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _password,
                        key: const Key('change_password_new'),
                        decoration: const InputDecoration(
                          labelText: 'New password',
                          border: OutlineInputBorder(),
                        ),
                        obscureText: true,
                        enabled: !auth.busy,
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _confirm,
                        key: const Key('change_password_confirm'),
                        decoration: const InputDecoration(
                          labelText: 'Confirm password',
                          border: OutlineInputBorder(),
                        ),
                        obscureText: true,
                        onSubmitted: (_) => _submit(),
                        enabled: !auth.busy,
                      ),
                      if (error != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          error,
                          key: const Key('change_password_error'),
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: AppColors.destructive,
                          ),
                        ),
                      ],
                      const SizedBox(height: 12),
                      CbPrimaryButton(
                        label: auth.busy ? 'Saving…' : 'Save password and continue',
                        onPressed: auth.busy ? null : _submit,
                      ),
                      TextButton(
                        onPressed: auth.busy
                            ? null
                            : () => ref
                                .read(authControllerProvider.notifier)
                                .logout(),
                        child: const Text('Sign out instead'),
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
    );
  }
}
