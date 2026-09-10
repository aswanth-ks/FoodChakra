import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../domain/rescue.dart';
import 'widgets/rescue_widgets.dart';

/// "Confirm handover" — the food owner's side of a rescue.
///
/// The smallest screen that closes the loop. FoodLoop had no owner-side
/// surface at all: a rescuer could arrive and receive a code, but nobody could
/// confirm it, so a rescue could never legitimately complete.
///
/// Deliberately **not** partner-specific. `listings.owner_user_id` is set on
/// every listing, so a consumer who shares surplus is just as much the owner
/// as a restaurant is, and reaches this same screen.
///
/// Built entirely from the existing rescue tokens and widgets — no new design
/// language, no new navigation pattern.
class HandoverConfirmationScreen extends StatefulWidget {
  const HandoverConfirmationScreen({
    super.key,
    required this.rescue,
    this.onBack,
    this.onConfirm,
    this.onDone,
    this.submitting = false,
    this.errorMessage,
    this.verified = false,
  });

  /// The rescue awaiting confirmation, read from the server.
  final Rescue rescue;

  final VoidCallback? onBack;

  /// Submits the code the rescuer read out. The backend decides whether it is
  /// correct — nothing is validated against a local copy, because the client
  /// never holds one.
  final void Function(String code)? onConfirm;

  /// Leaves the screen once the handover is confirmed.
  final VoidCallback? onDone;

  final bool submitting;

  /// A server-supplied message: wrong code, expired, too many attempts.
  final String? errorMessage;

  /// True once the backend has confirmed the handover.
  final bool verified;

  @override
  State<HandoverConfirmationScreen> createState() =>
      _HandoverConfirmationScreenState();
}

class _HandoverConfirmationScreenState
    extends State<HandoverConfirmationScreen> {
  final _controller = TextEditingController();

  /// Set when the field itself is wrong — six digits or nothing. Kept separate
  /// from [widget.errorMessage], which is the server's verdict on a code that
  /// was well-formed enough to submit.
  String? _localError;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Rejects a malformed code before spending one of the attempt allowance.
  void _submit() {
    final code = _controller.text.trim();
    if (code.length != 6 || !RegExp(r'^\d{6}$').hasMatch(code)) {
      setState(() => _localError = 'Enter the six digits the rescuer read out.');
      return;
    }
    setState(() => _localError = null);
    widget.onConfirm?.call(code);
  }

  @override
  Widget build(BuildContext context) {
    final listing = widget.rescue.listing;
    final error = _localError ?? widget.errorMessage;

    return Scaffold(
      backgroundColor: RescueColors.surface,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 430),
            child: Column(
              children: [
                _Header(onBack: widget.onBack),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                    children: [
                      Text(
                        widget.verified
                            ? 'Handover confirmed'
                            : 'Confirm the handover',
                        style: rescueFont(
                          26,
                          700,
                          color: RescueColors.ink,
                          letterSpacing: -0.6,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        widget.verified
                            ? 'Thank you. ${listing.title} is on its way to '
                                  'being rescued.'
                            : 'Ask the rescuer for the six-digit code on their '
                                  'phone, then enter it below.',
                        style: rescueFont(
                          14.5,
                          500,
                          color: RescueColors.muted,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 20),
                      _SurplusSummary(rescue: widget.rescue),
                      const SizedBox(height: 24),
                      if (!widget.verified) ...[
                        _CodeField(
                          controller: _controller,
                          enabled: !widget.submitting,
                          hasError: error != null,
                          onSubmitted: (_) => _submit(),
                        ),
                        if (error != null) ...[
                          const SizedBox(height: 10),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(
                                Icons.error_outline_rounded,
                                size: 16,
                                color: RescueColors.amber,
                              ),
                              const SizedBox(width: 7),
                              Expanded(
                                child: Text(
                                  error,
                                  style: rescueFont(
                                    13,
                                    500,
                                    color: RescueColors.amber,
                                    height: 1.4,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ],
                  ),
                ),
                Container(
                  decoration: const BoxDecoration(
                    color: RescueColors.surface,
                    border: Border(
                      top: BorderSide(color: RescueColors.border),
                    ),
                  ),
                  child: SafeArea(
                    top: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                      child: Column(
                        children: [
                          RescuePrimaryButton(
                            label: widget.verified
                                ? 'Done'
                                : (widget.submitting
                                      ? 'Confirming…'
                                      : 'Confirm handover'),
                            icon: widget.verified
                                ? Icons.check_circle_outline_rounded
                                : null,
                            height: 56,
                            onPressed: widget.verified
                                ? widget.onDone
                                : (widget.submitting ? null : _submit),
                          ),
                          const SizedBox(height: 8),
                          const HomeIndicator(),
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
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({this.onBack});

  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
      child: Row(
        children: [
          IconButton(
            onPressed: onBack,
            icon: const Icon(
              Icons.arrow_back_rounded,
              color: RescueColors.ink,
            ),
          ),
          Expanded(
            child: Text(
              'Handover',
              textAlign: TextAlign.center,
              style: rescueFont(16, 700, color: RescueColors.ink),
            ),
          ),
          const SizedBox(width: 48),
        ],
      ),
    );
  }
}

/// What is being handed over, so the owner confirms the right rescue.
class _SurplusSummary extends StatelessWidget {
  const _SurplusSummary({required this.rescue});

  final Rescue rescue;

  @override
  Widget build(BuildContext context) {
    final listing = rescue.listing;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: RescueColors.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: RescueColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: RescueColors.sageSubtle,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.shopping_bag_outlined,
              size: 21,
              color: RescueColors.primary,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  listing.title,
                  style: rescueFont(15.5, 700, color: RescueColors.ink),
                ),
                const SizedBox(height: 3),
                Text(
                  '${listing.category} · ${rescue.reference}',
                  style: rescueFont(13, 500, color: RescueColors.muted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CodeField extends StatelessWidget {
  const _CodeField({
    required this.controller,
    required this.enabled,
    required this.hasError,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final bool enabled;
  final bool hasError;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      enabled: enabled,
      autofocus: true,
      keyboardType: TextInputType.number,
      textAlign: TextAlign.center,
      maxLength: 6,
      // Digits only, capped at six: the keyboard and the formatter both say
      // so, rather than relying on the user to get it right.
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(6),
      ],
      onSubmitted: onSubmitted,
      style: rescueFont(30, 700, color: RescueColors.ink, letterSpacing: 10),
      decoration: InputDecoration(
        counterText: '',
        hintText: '000000',
        hintStyle: rescueFont(
          30,
          700,
          color: RescueColors.border,
          letterSpacing: 10,
        ),
        filled: true,
        fillColor: RescueColors.card,
        contentPadding: const EdgeInsets.symmetric(vertical: 18),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(
            color: hasError ? RescueColors.amber : RescueColors.border,
            width: 1.5,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(
            color: hasError ? RescueColors.amber : RescueColors.primary,
            width: 1.8,
          ),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: RescueColors.border, width: 1.5),
        ),
      ),
    );
  }
}
