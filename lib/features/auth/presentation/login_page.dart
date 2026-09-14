import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../design_system/branding/brand_logo.dart';
import '../../../design_system/buttons/cb_primary_button.dart';
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
    await ref.read(authControllerProvider.notifier).login(
          username: user,
          password: pass,
        );
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);
    final theme = Theme.of(context);
    final error = _localError ?? auth.message;

    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final short = constraints.maxHeight < 560;
            return SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight - 48),
                child: IntrinsicHeight(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Spacer(),
                      BrandLogo(height: short ? 120 : 160),
                      const SizedBox(height: 16),
                      Text(
                        'Sign in to start your shift.',
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: AppColors.mutedForeground,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
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
                      TextField(
                        controller: _password,
                        key: const Key('login_password'),
                        decoration: const InputDecoration(
                          labelText: 'Password',
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
                          key: const Key('login_error'),
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: AppColors.destructive,
                          ),
                        ),
                      ],
                      const SizedBox(height: 24),
                      CbPrimaryButton(
                        label: auth.busy ? 'Signing in…' : 'Sign in',
                        onPressed: auth.busy ? null : _submit,
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
