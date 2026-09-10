import 'package:flutter/material.dart';

import '../../../app/theme/app_typography.dart';
import 'widgets/auth_widgets.dart';

/// The second half of "forgot password": enter the emailed code, choose a new
/// password.
///
/// The Stitch set has no screen for this step — it stops at "Forgot Password",
/// which was as far as the design went while reset was inert. Rather than
/// invent a look, this is assembled from the same `auth_widgets.dart` pieces,
/// with the same header, spacing and footer as [ForgotPasswordScreen]. It
/// reads as the next page of that flow because it is built from that flow.
class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({
    super.key,
    required this.email,
    this.onBack,
    this.onSubmit,
    this.onResend,
    this.onBackToSignIn,
  });

  /// The address the code was sent to, shown so the user can check it.
  final String email;

  final VoidCallback? onBack;

  /// Called with the code and the chosen password. Returns true when the
  /// server accepted it — the confirmation state depends on that answer, not
  /// on the tap.
  final Future<bool> Function(String code, String newPassword)? onSubmit;

  /// Asks for another code. Reuses the forgot-password endpoint.
  final Future<void> Function()? onResend;

  final VoidCallback? onBackToSignIn;

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _code = TextEditingController();
  final _password = TextEditingController();

  bool _obscured = true;
  bool _busy = false;

  @override
  void dispose() {
    _code.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _busy = true);
    // The screen shows nothing hopeful until the server has answered. A
    // failed reset must not look like a successful one.
    final ok = await widget.onSubmit?.call(
      _code.text.trim(),
      _password.text,
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok ?? false) {
      // Clearing the code stops a second tap replaying a code the server has
      // already consumed.
      _code.clear();
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
                      tooltip: 'Back',
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
                            const Center(child: _ResetBadge()),
                            const SizedBox(height: 24),
                            _Header(email: widget.email),
                            const SizedBox(height: 28),
                            AuthTextField(
                              key: const Key('resetPassword_code'),
                              label: 'Verification code',
                              hint: '6-digit code',
                              controller: _code,
                              keyboardType: TextInputType.number,
                              validator: _validateCode,
                            ),
                            const SizedBox(height: 16),
                            AuthTextField(
                              key: const Key('resetPassword_password'),
                              label: 'New password',
                              hint: 'At least 8 characters',
                              controller: _password,
                              obscureText: _obscured,
                              autofillHints: const [
                                AutofillHints.newPassword,
                              ],
                              validator: _validatePassword,
                              onSubmitted: (_) => _submit(),
                              suffix: IconButton(
                                onPressed: () =>
                                    setState(() => _obscured = !_obscured),
                                icon: Icon(
                                  _obscured
                                      ? Icons.visibility_outlined
                                      : Icons.visibility_off_outlined,
                                  size: 20,
                                  color: AuthColors.textSecondary,
                                ),
                                tooltip: _obscured
                                    ? 'Show password'
                                    : 'Hide password',
                              ),
                            ),
                            const SizedBox(height: 20),
                            AuthPrimaryButton(
                              label: _busy
                                  ? 'Updating…'
                                  : 'Set new password',
                              onPressed: _busy ? null : _submit,
                            ),
                            const SizedBox(height: 12),
                            Center(
                              child: TextButton(
                                onPressed: _busy ? null : widget.onResend,
                                child: Text(
                                  'Send another code',
                                  style: TextStyle(
                                    fontFamily: AppTypography.fontFamily,
                                    fontSize: 14.5,
                                    fontWeight: FontWeight.w600,
                                    fontVariations: const [
                                      FontVariation('wght', 600),
                                    ],
                                    color: AuthColors.primary,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
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

  static String? _validateCode(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'Enter the code from your email.';
    if (v.length != 6) return 'The code is 6 digits.';
    return null;
  }

  static String? _validatePassword(String? value) {
    final v = value ?? '';
    if (v.isEmpty) return 'Choose a new password.';
    // Matches the backend's minimum. The server is still the authority; this
    // only saves a round trip and a wasted attempt.
    if (v.length < 8) return 'Use at least 8 characters.';
    return null;
  }
}

class _ResetBadge extends StatelessWidget {
  const _ResetBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
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
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.email});

  final String email;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          'Set a new password',
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
            email.isEmpty
                ? 'Enter the 6-digit code we emailed you, then choose a new '
                      'password.'
                : 'Enter the 6-digit code sent to $email, then choose a new '
                      'password.',
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
