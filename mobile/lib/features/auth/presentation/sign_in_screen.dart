import 'package:flutter/material.dart';

import '../../../app/theme/app_typography.dart';
import 'widgets/auth_widgets.dart';

/// "FoodLoop Consumer Sign In Screen".
///
/// Faithful translation of the Stitch design
/// (screen `266ac1989d5a4f338f57c6c51b367936`).
///
/// UI only. Credentials are not submitted anywhere: the auth service and its
/// repository arrive in Phase 3, at which point [onSignIn] is replaced by a
/// notifier call. No validation logic beyond field-level format checks lives
/// here.
class SignInScreen extends StatefulWidget {
  const SignInScreen({
    super.key,
    this.onBack,
    this.onSignIn,
    this.onForgotPassword,
    this.onCreateAccount,
    this.onGoogle,
    this.onApple,
  });

  final VoidCallback? onBack;

  /// Receives the entered credentials once the form passes local validation.
  final void Function(String email, String password)? onSignIn;

  final VoidCallback? onForgotPassword;
  final VoidCallback? onCreateAccount;
  final VoidCallback? onGoogle;
  final VoidCallback? onApple;

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  void _submit() {
    if (_formKey.currentState?.validate() ?? false) {
      widget.onSignIn?.call(_email.text.trim(), _password.text);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AuthColors.surface,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 390),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 4, 24, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: IconButton(
                      onPressed: widget.onBack,
                      icon: const Icon(Icons.arrow_back, size: 20),
                      color: AuthColors.textPrimary,
                      tooltip: 'Go back',
                    ),
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const _Header(),
                            const SizedBox(height: 24),
                            AuthTextField(
                              label: 'Email address',
                              hint: 'you@example.com',
                              controller: _email,
                              keyboardType: TextInputType.emailAddress,
                              autofillHints: const [AutofillHints.email],
                              validator: _validateEmail,
                            ),
                            const SizedBox(height: 14),
                            AuthTextField(
                              label: 'Password',
                              hint: 'Enter your password',
                              controller: _password,
                              obscureText: _obscure,
                              autofillHints: const [AutofillHints.password],
                              validator: _validatePassword,
                              onSubmitted: (_) => _submit(),
                              suffix: IconButton(
                                onPressed: () =>
                                    setState(() => _obscure = !_obscure),
                                icon: Icon(
                                  _obscure
                                      ? Icons.visibility_outlined
                                      : Icons.visibility_off_outlined,
                                  size: 19,
                                ),
                                color: AuthColors.textMuted,
                                tooltip: 'Toggle password visibility',
                              ),
                            ),
                            const SizedBox(height: 8),
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton(
                                onPressed: widget.onForgotPassword,
                                style: TextButton.styleFrom(
                                  minimumSize: Size.zero,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 4,
                                    vertical: 4,
                                  ),
                                  tapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                ),
                                child: Text(
                                  'Forgot password?',
                                  style: _label(12.5, 500, AuthColors.primary),
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            AuthPrimaryButton(
                              label: 'Sign in',
                              onPressed: _submit,
                            ),
                            const SizedBox(height: 20),
                            const AuthDivider(label: 'or continue with'),
                            const SizedBox(height: 20),
                            AuthSocialButton(
                              label: 'Continue with Google',
                              icon: const GoogleGlyph(size: 18),
                              onPressed: widget.onGoogle,
                            ),
                            const SizedBox(height: 10),
                            AuthSocialButton(
                              label: 'Continue with Apple',
                              icon: const Icon(
                                Icons.apple,
                                size: 20,
                                color: Colors.black,
                              ),
                              onPressed: widget.onApple,
                            ),
                            const SizedBox(height: 12),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  AuthFooterPrompt(
                    prompt: 'Don’t have an account?',
                    action: 'Create one',
                    onAction: widget.onCreateAccount,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  static String? _validateEmail(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'Enter your email address.';
    // Deliberately permissive: the backend is the authority on validity.
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(v)) {
      return 'Enter a valid email address.';
    }
    return null;
  }

  static String? _validatePassword(String? value) {
    if ((value ?? '').isEmpty) return 'Enter your password.';
    return null;
  }
}

TextStyle _label(double size, int weight, Color color) => TextStyle(
  fontFamily: AppTypography.fontFamily,
  fontSize: size,
  fontWeight: FontWeight.values[(weight ~/ 100) - 1],
  fontVariations: [FontVariation('wght', weight.toDouble())],
  color: color,
);

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Welcome back',
          style: TextStyle(
            fontFamily: AppTypography.fontFamily,
            fontSize: 29,
            height: 1.2,
            letterSpacing: -0.02 * 29,
            fontWeight: FontWeight.w700,
            fontVariations: const [FontVariation('wght', 700)],
            color: AuthColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 320),
          child: Text(
            'Sign in to continue rescuing and sharing surplus food.',
            style: TextStyle(
              fontFamily: AppTypography.fontFamily,
              fontSize: 14.5,
              height: 1.4,
              fontWeight: FontWeight.w400,
              fontVariations: const [FontVariation('wght', 400)],
              color: AuthColors.textSecondary,
            ),
          ),
        ),
      ],
    );
  }
}
