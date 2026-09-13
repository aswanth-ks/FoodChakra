import 'package:flutter/material.dart';

import '../../../core/error/failures.dart';
import 'widgets/rescue_widgets.dart';

/// Changes the password for someone who already knows it.
///
/// Distinct from the reset flow, which proves identity with an emailed code
/// because the user has forgotten it. Here the current password is the proof,
/// which is what stops a borrowed unlocked phone becoming a stolen account.
///
/// The server revokes every session on success, so the caller is signed out
/// afterwards and signs in again with what they just chose. The screen says so
/// before it is pressed rather than surprising anyone.
///
/// Nothing typed here is logged, stored or echoed. The three values exist only
/// in the controllers, which are disposed with the screen.
class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({
    super.key,
    this.minLength = 8,
    this.saving = false,
    this.error,
    this.onBack,
    this.onSubmit,
  });

  /// Mirrors the backend's own minimum. Checked here only so the user is told
  /// before a round trip; the server remains the authority.
  final int minLength;

  final bool saving;
  final Object? error;
  final VoidCallback? onBack;

  final void Function({
    required String currentPassword,
    required String newPassword,
  })?
  onSubmit;

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _current = TextEditingController();
  final _next = TextEditingController();
  final _confirm = TextEditingController();

  bool _showCurrent = false;
  bool _showNext = false;

  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    _confirm.dispose();
    super.dispose();
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    widget.onSubmit?.call(
      currentPassword: _current.text,
      newPassword: _next.text,
    );
  }

  @override
  Widget build(BuildContext context) {
    final error = widget.error;

    return Scaffold(
      backgroundColor: RescueColors.surface,
      appBar: AppBar(
        backgroundColor: RescueColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          onPressed: widget.saving ? null : widget.onBack,
          icon: const Icon(Icons.arrow_back, size: 20),
          color: RescueColors.ink,
          tooltip: 'Go back',
        ),
        title: Text(
          'Change password',
          style: rescueFont(16, 700, color: RescueColors.ink),
        ),
      ),
      body: SafeArea(
        top: false,
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            children: [
              _Field(
                label: 'CURRENT PASSWORD',
                controller: _current,
                obscure: !_showCurrent,
                enabled: !widget.saving,
                onToggleVisibility: () =>
                    setState(() => _showCurrent = !_showCurrent),
                validator: (value) => (value ?? '').isEmpty
                    ? 'Enter your current password.'
                    : null,
              ),
              const SizedBox(height: 16),
              _Field(
                label: 'NEW PASSWORD',
                controller: _next,
                obscure: !_showNext,
                enabled: !widget.saving,
                onToggleVisibility: () =>
                    setState(() => _showNext = !_showNext),
                validator: (value) {
                  final password = value ?? '';
                  if (password.isEmpty) return 'Choose a new password.';
                  if (password.length < widget.minLength) {
                    return 'Use at least ${widget.minLength} characters.';
                  }
                  if (password == _current.text) {
                    return 'Choose a password you have not used here.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              _Field(
                label: 'CONFIRM NEW PASSWORD',
                controller: _confirm,
                obscure: !_showNext,
                enabled: !widget.saving,
                textInputAction: TextInputAction.done,
                onSubmitted: _submit,
                validator: (value) =>
                    value == _next.text ? null : 'Both entries must match.',
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0F5F1),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFE3EBE5)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.info_outline_rounded,
                      size: 16,
                      color: RescueColors.primary,
                    ),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Text(
                        'Changing your password signs you out on every '
                        'device, including this one. You will sign in again '
                        'with your new password.',
                        style: rescueFont(
                          12.5,
                          500,
                          color: const Color(0xFF2C3E33),
                          height: 1.45,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (error != null) ...[
                const SizedBox(height: 16),
                _SubmitError(error: error),
              ],
              const SizedBox(height: 24),
              SizedBox(
                height: 52,
                child: FilledButton(
                  onPressed: widget.saving ? null : _submit,
                  style: FilledButton.styleFrom(
                    backgroundColor: RescueColors.primary,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: const Color(0xFFCFD8D2),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: widget.saving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.4,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          'Change password',
                          style: rescueFont(15.5, 600, color: Colors.white),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({
    required this.label,
    required this.controller,
    required this.obscure,
    required this.enabled,
    required this.validator,
    this.onToggleVisibility,
    this.textInputAction = TextInputAction.next,
    this.onSubmitted,
  });

  final String label;
  final TextEditingController controller;
  final bool obscure;
  final bool enabled;
  final String? Function(String?) validator;
  final VoidCallback? onToggleVisibility;
  final TextInputAction textInputAction;
  final VoidCallback? onSubmitted;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: rescueFont(
            11,
            700,
            color: RescueColors.muted,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          enabled: enabled,
          obscureText: obscure,
          autocorrect: false,
          enableSuggestions: false,
          textInputAction: textInputAction,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          validator: validator,
          onFieldSubmitted: (_) => onSubmitted?.call(),
          decoration: InputDecoration(
            filled: true,
            fillColor: RescueColors.card,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            suffixIcon: onToggleVisibility == null
                ? null
                : IconButton(
                    onPressed: onToggleVisibility,
                    icon: Icon(
                      obscure
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                      size: 19,
                      color: RescueColors.muted,
                    ),
                    tooltip: obscure ? 'Show password' : 'Hide password',
                  ),
          ),
        ),
      ],
    );
  }
}

class _SubmitError extends StatelessWidget {
  const _SubmitError({required this.error});

  final Object error;

  @override
  Widget build(BuildContext context) {
    final failure = error is Failure ? error as Failure : null;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFDF2F2),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFF3D6D6)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.error_outline_rounded,
            size: 16,
            color: Color(0xFFB3261E),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              failure?.message ?? "Couldn't change your password.",
              style: rescueFont(
                12.5,
                500,
                color: const Color(0xFF7A2019),
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
