// login_screen.dart
//
// Responsibility:
// Presents the email/password form and forwards sign-in intent to the auth
// controller. Credentials are never stored by this widget.

import 'package:flutter/material.dart';

import '../controllers/admin_auth_controller.dart';

class LoginScreen extends StatefulWidget {
  final AdminAuthController controller;

  const LoginScreen({super.key, required this.controller});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    await widget.controller.signIn(
      email: _emailController.text,
      password: _passwordController.text,
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Card(
                elevation: 2,
                clipBehavior: Clip.antiAlias,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(32, 34, 32, 30),
                  child: AutofillGroup(
                    child: Form(
                      key: _formKey,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Align(
                            child: Container(
                              width: 64,
                              height: 64,
                              decoration: BoxDecoration(
                                color: scheme.primaryContainer,
                                borderRadius: BorderRadius.circular(18),
                              ),
                              child: Icon(
                                Icons.storefront_outlined,
                                size: 34,
                                color: scheme.onPrimaryContainer,
                              ),
                            ),
                          ),
                          const SizedBox(height: 22),
                          Text(
                            'Survey Production Admin',
                            textAlign: TextAlign.center,
                            style: Theme.of(context)
                                .textTheme
                                .headlineSmall
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Sign in with your authorized Supabase account.',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                          const SizedBox(height: 26),
                          if (controller.noticeMessage != null) ...[
                            _LoginMessage(
                              message: controller.noticeMessage!,
                              backgroundColor: scheme.secondaryContainer,
                              foregroundColor: scheme.onSecondaryContainer,
                              icon: Icons.info_outline,
                            ),
                            const SizedBox(height: 14),
                          ],
                          if (controller.errorMessage != null) ...[
                            _LoginMessage(
                              message: controller.errorMessage!,
                              backgroundColor: scheme.errorContainer,
                              foregroundColor: scheme.onErrorContainer,
                              icon: Icons.error_outline,
                            ),
                            const SizedBox(height: 14),
                          ],
                          TextFormField(
                            controller: _emailController,
                            enabled: !controller.isSubmitting,
                            autofocus: true,
                            keyboardType: TextInputType.emailAddress,
                            textInputAction: TextInputAction.next,
                            autofillHints: const [
                              AutofillHints.username,
                              AutofillHints.email,
                            ],
                            decoration: const InputDecoration(
                              labelText: 'Email',
                              hintText: 'name@company.com',
                              prefixIcon: Icon(Icons.email_outlined),
                              border: OutlineInputBorder(),
                            ),
                            validator: (value) {
                              final email = value?.trim() ?? '';
                              if (email.isEmpty) {
                                return 'Enter your email address.';
                              }
                              if (!email.contains('@')) {
                                return 'Enter a valid email address.';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _passwordController,
                            enabled: !controller.isSubmitting,
                            obscureText: _obscurePassword,
                            textInputAction: TextInputAction.done,
                            autofillHints: const [AutofillHints.password],
                            onFieldSubmitted: (_) => _submit(),
                            decoration: InputDecoration(
                              labelText: 'Password',
                              prefixIcon: const Icon(Icons.lock_outline),
                              border: const OutlineInputBorder(),
                              suffixIcon: IconButton(
                                tooltip: _obscurePassword
                                    ? 'Show password'
                                    : 'Hide password',
                                onPressed: controller.isSubmitting
                                    ? null
                                    : () => setState(
                                          () => _obscurePassword =
                                              !_obscurePassword,
                                        ),
                                icon: Icon(
                                  _obscurePassword
                                      ? Icons.visibility_outlined
                                      : Icons.visibility_off_outlined,
                                ),
                              ),
                            ),
                            validator: (value) => (value ?? '').isEmpty
                                ? 'Enter your password.'
                                : null,
                          ),
                          const SizedBox(height: 22),
                          FilledButton.icon(
                            onPressed:
                                controller.isSubmitting ? null : _submit,
                            icon: controller.isSubmitting
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.login),
                            label: Text(
                              controller.isSubmitting
                                  ? 'Signing in...'
                                  : 'Sign in',
                            ),
                            style: FilledButton.styleFrom(
                              minimumSize: const Size.fromHeight(50),
                            ),
                          ),
                          const SizedBox(height: 18),
                          Text(
                            'This browser will stay signed in for up to seven '
                            'days. You can sign out sooner from the account '
                            'menu.',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LoginMessage extends StatelessWidget {
  final String message;
  final Color backgroundColor;
  final Color foregroundColor;
  final IconData icon;

  const _LoginMessage({
    required this.message,
    required this.backgroundColor,
    required this.foregroundColor,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: foregroundColor),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: foregroundColor),
            ),
          ),
        ],
      ),
    );
  }
}
