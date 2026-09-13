import 'package:flutter/material.dart';

import '../../../core/error/failures.dart';
import 'widgets/rescue_widgets.dart';

/// Edits the one thing about an account its holder may change: their name.
///
/// Email is shown and deliberately not editable. Changing it would move the
/// address that verification codes and password resets are sent to, so it
/// needs its own confirmed flow rather than riding along with a display name —
/// and a field that silently refuses to save is worse than one that explains
/// why it cannot.
///
/// Plain parameters and no providers: the connector owns the saving.
class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({
    super.key,
    required this.initialName,
    required this.email,
    this.saving = false,
    this.error,
    this.onBack,
    this.onSave,
  });

  final String initialName;
  final String email;

  /// Swaps the button for a spinner and blocks a second submission.
  final bool saving;

  /// The last failed save, shown above the button.
  final Object? error;

  final VoidCallback? onBack;

  /// Receives the trimmed name. Only called when validation passes.
  final void Function(String fullName)? onSave;

  /// The longest name the backend will store.
  static const int maxNameLength = 120;

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name = TextEditingController(
    text: widget.initialName,
  );

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  /// Whether the field holds something different from what is already stored.
  ///
  /// Saving an unchanged name would spend a round trip to achieve nothing, so
  /// the button stays inert until there is an actual edit.
  bool get _changed => _name.text.trim() != widget.initialName.trim();

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    widget.onSave?.call(_name.text.trim());
  }

  static String? _validateName(String? value) {
    final name = (value ?? '').trim();
    if (name.isEmpty) return 'Your name cannot be empty.';
    if (name.length > EditProfileScreen.maxNameLength) {
      return 'Please use ${EditProfileScreen.maxNameLength} characters or fewer.';
    }
    return null;
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
          'Edit profile',
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
              Text(
                'FULL NAME',
                style: rescueFont(
                  11,
                  700,
                  color: RescueColors.muted,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _name,
                enabled: !widget.saving,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.done,
                maxLength: EditProfileScreen.maxNameLength,
                autovalidateMode: AutovalidateMode.onUserInteraction,
                validator: _validateName,
                onFieldSubmitted: (_) => _submit(),
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: 'Your name',
                  filled: true,
                  fillColor: RescueColors.card,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'EMAIL',
                style: rescueFont(
                  11,
                  700,
                  color: RescueColors.muted,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 8),
              _ReadOnlyEmail(email: widget.email),
              if (error != null) ...[
                const SizedBox(height: 16),
                _SaveError(error: error),
              ],
              const SizedBox(height: 24),
              SizedBox(
                height: 52,
                child: FilledButton(
                  // Inert while saving, and while there is nothing to save.
                  onPressed: widget.saving || !_changed ? null : _submit,
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
                          'Save changes',
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

/// The address, shown but not editable, with the reason stated.
class _ReadOnlyEmail extends StatelessWidget {
  const _ReadOnlyEmail({required this.email});

  final String email;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
          decoration: BoxDecoration(
            color: const Color(0xFFF1F3F1),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: RescueColors.border),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.lock_outline_rounded,
                size: 16,
                color: RescueColors.muted,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  email,
                  style: rescueFont(14, 500, color: RescueColors.muted),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Your email is how you sign in and where verification codes go, so '
          'it cannot be changed here.',
          style: rescueFont(12, 400, color: RescueColors.muted, height: 1.45),
        ),
      ],
    );
  }
}

class _SaveError extends StatelessWidget {
  const _SaveError({required this.error});

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
              // The server's own wording where there is one; never raw
              // exception text.
              failure?.message ?? "Couldn't save your changes.",
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
