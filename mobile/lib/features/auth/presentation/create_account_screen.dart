import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../../app/theme/app_typography.dart';
import 'widgets/auth_widgets.dart';

/// "FoodLoop Consumer Account Creation Screen".
///
/// Faithful translation of the Stitch design
/// (screen `2abb740e1ba741bfa7b7c6a6acdc1e7f`).
///
/// This is the landing point for a new user once onboarding finishes: UI
/// only, nothing is submitted anywhere. [onCreateAccount] is wired to the
/// real auth service in Phase 3.
class CreateAccountScreen extends StatefulWidget {
  const CreateAccountScreen({
    super.key,
    this.onBack,
    this.onSkip,
    this.onCreateAccount,
    this.onGoogle,
    this.onApple,
    this.onSignIn,
    this.onTerms,
    this.onPrivacyPolicy,
  });

  final VoidCallback? onBack;
  final VoidCallback? onSkip;

  /// Receives the entered details once the form passes local validation.
  final void Function(String name, String email, String password)?
  onCreateAccount;

  final VoidCallback? onGoogle;
  final VoidCallback? onApple;
  final VoidCallback? onSignIn;
  final VoidCallback? onTerms;
  final VoidCallback? onPrivacyPolicy;

  @override
  State<CreateAccountScreen> createState() => _CreateAccountScreenState();
}

class _CreateAccountScreenState extends State<CreateAccountScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  void _submit() {
    if (_formKey.currentState?.validate() ?? false) {
      widget.onCreateAccount?.call(
        _name.text.trim(),
        _email.text.trim(),
        _password.text,
      );
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
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        onPressed: widget.onBack,
                        icon: const Icon(Icons.arrow_back, size: 20),
                        color: AuthColors.textPrimary,
                        tooltip: 'Go back',
                      ),
                      TextButton(
                        onPressed: widget.onSkip,
                        style: TextButton.styleFrom(
                          foregroundColor: AuthColors.textSecondary,
                        ),
                        child: Text('Skip', style: _label(14, 500)),
                      ),
                    ],
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const _Header(),
                            const SizedBox(height: 20),
                            AuthTextField(
                              key: const Key('createAccount_name'),
                              label: 'Full name',
                              hint: 'Your name',
                              controller: _name,
                              keyboardType: TextInputType.name,
                              autofillHints: const [AutofillHints.name],
                              validator: _validateName,
                            ),
                            const SizedBox(height: 12),
                            AuthTextField(
                              key: const Key('createAccount_email'),
                              label: 'Email address',
                              hint: 'you@example.com',
                              controller: _email,
                              keyboardType: TextInputType.emailAddress,
                              autofillHints: const [AutofillHints.email],
                              validator: _validateEmail,
                            ),
                            const SizedBox(height: 12),
                            AuthTextField(
                              key: const Key('createAccount_password'),
                              label: 'Password',
                              hint: 'Create a password',
                              controller: _password,
                              obscureText: _obscure,
                              autofillHints: const [AutofillHints.newPassword],
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
                            Padding(
                              padding: const EdgeInsets.only(top: 6, left: 2),
                              child: Text(
                                'Use at least 8 characters.',
                                style: _label(11.5, 400, AuthColors.textMuted),
                              ),
                            ),
                            const SizedBox(height: 12),
                            AuthPrimaryButton(
                              label: 'Create account',
                              onPressed: _submit,
                            ),
                            const SizedBox(height: 16),
                            const AuthDivider(label: 'or continue with'),
                            const SizedBox(height: 16),
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
                            const SizedBox(height: 16),
                            _TermsNotice(
                              onTerms: widget.onTerms,
                              onPrivacyPolicy: widget.onPrivacyPolicy,
                            ),
                            const SizedBox(height: 8),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  AuthFooterPrompt(
                    prompt: 'Already have an account?',
                    action: 'Sign in',
                    onAction: widget.onSignIn,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  static String? _validateName(String? value) {
    if ((value ?? '').trim().isEmpty) return 'Enter your name.';
    return null;
  }

  static String? _validateEmail(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'Enter your email address.';
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(v)) {
      return 'Enter a valid email address.';
    }
    return null;
  }

  static String? _validatePassword(String? value) {
    final v = value ?? '';
    if (v.isEmpty) return 'Create a password.';
    if (v.length < 8) return 'Use at least 8 characters.';
    return null;
  }
}

TextStyle _label(double size, int weight, [Color? color]) => TextStyle(
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
          'Create your FoodLoop account',
          style: TextStyle(
            fontFamily: AppTypography.fontFamily,
            fontSize: 28,
            height: 1.22,
            fontWeight: FontWeight.w700,
            fontVariations: const [FontVariation('wght', 700)],
            color: AuthColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Join the community rescuing good food from going to waste.',
          style: TextStyle(
            fontFamily: AppTypography.fontFamily,
            fontSize: 14.5,
            height: 1.4,
            fontWeight: FontWeight.w400,
            fontVariations: const [FontVariation('wght', 400)],
            color: AuthColors.textSecondary,
          ),
        ),
      ],
    );
  }
}

class _TermsNotice extends StatelessWidget {
  const _TermsNotice({this.onTerms, this.onPrivacyPolicy});

  final VoidCallback? onTerms;
  final VoidCallback? onPrivacyPolicy;

  @override
  Widget build(BuildContext context) {
    final base = _label(
      11.5,
      400,
      AuthColors.textSecondary,
    ).copyWith(height: 1.5);
    final link = base.copyWith(
      color: AuthColors.textPrimary,
      fontWeight: FontWeight.w500,
      fontVariations: const [FontVariation('wght', 500)],
      decoration: TextDecoration.underline,
      decorationColor: const Color(0xFFC4C1B7),
    );

    return Text.rich(
      TextSpan(
        text: 'By creating an account, you agree to FoodLoop’s ',
        style: base,
        children: [
          TextSpan(
            text: 'Terms',
            style: link,
            recognizer: TapGestureRecognizer()..onTap = onTerms,
          ),
          const TextSpan(text: ' and '),
          TextSpan(
            text: 'Privacy Policy',
            style: link,
            recognizer: TapGestureRecognizer()..onTap = onPrivacyPolicy,
          ),
          const TextSpan(text: '.'),
        ],
      ),
      textAlign: TextAlign.center,
    );
  }
}
