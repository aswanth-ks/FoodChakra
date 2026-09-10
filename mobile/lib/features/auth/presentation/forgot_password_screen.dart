import 'package:flutter/material.dart';

import '../../../app/theme/app_typography.dart';
import 'widgets/auth_widgets.dart';

/// "FoodLoop Consumer Forgot Password Screen".
///
/// Faithful translation of the Stitch design
/// (screen `21993dcd125d4786bb20d167e90c2747`).
///
/// Wired to `POST /auth/forgot-password`. The backend answers identically
/// whether or not the address is registered, so this screen always moves on
/// to [ResetPasswordScreen] — branching on the result would leak exactly what
/// that design hides.
///
/// The design says "reset link". FoodLoop sends a 6-digit code instead, so the
/// copy says code: a screen that promises a link and delivers a code sends the
/// user hunting for a button that is not in the email.
class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({
    super.key,
    this.onBack,
    this.onSendResetLink,
    this.onBackToSignIn,
  });

  final VoidCallback? onBack;

  /// Receives the entered email once the form passes local validation.
  final void Function(String email)? onSendResetLink;

  final VoidCallback? onBackToSignIn;

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  void _submit() {
    if (_formKey.currentState?.validate() ?? false) {
      widget.onSendResetLink?.call(_email.text.trim());
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
                      tooltip: 'Back to sign in',
                    ),
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const SizedBox(height: 24),
                            Center(
                              child: Container(
                                width: 64,
                                height: 64,
                                decoration: const BoxDecoration(
                                  color: Color(0xFFD6EADF),
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Color(0x0A000000),
                                      blurRadius: 3,
                                      offset: Offset(0, 1),
                                    ),
                                  ],
                                ),
                                child: const Icon(
                                  Icons.lock_reset_outlined,
                                  size: 30,
                                  color: AuthColors.primary,
                                ),
                              ),
                            ),
                            const SizedBox(height: 24),
                            const _Header(),
                            const SizedBox(height: 28),
                            AuthTextField(
                              key: const Key('forgotPassword_email'),
                              label: 'Email address',
                              hint: 'you@example.com',
                              controller: _email,
                              keyboardType: TextInputType.emailAddress,
                              autofillHints: const [AutofillHints.email],
                              validator: _validateEmail,
                              onSubmitted: (_) => _submit(),
                            ),
                            const SizedBox(height: 20),
                            AuthPrimaryButton(
                              label: 'Send reset code',
                              onPressed: _submit,
                            ),
                            const SizedBox(height: 20),
                            AuthFooterPrompt(
                              prompt: 'Remember your password?',
                              action: 'Sign in',
                              onAction: widget.onBackToSignIn,
                            ),
                          ],
                        ),
                      ),
                    ),
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
}

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          'Forgot your password?',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: AppTypography.fontFamily,
            fontSize: 28,
            height: 1.22,
            letterSpacing: -0.02 * 28,
            fontWeight: FontWeight.w700,
            fontVariations: const [FontVariation('wght', 700)],
            color: AuthColors.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 310),
          child: Text(
            'No worries. Enter the email address linked to your FoodLoop '
            'account and we’ll send you a 6-digit reset code.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: AppTypography.fontFamily,
              fontSize: 14.5,
              height: 1.48,
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
