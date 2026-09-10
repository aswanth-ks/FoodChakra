import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../app/theme/app_typography.dart';
import 'widgets/auth_widgets.dart';

/// "FoodLoop Consumer Email Verification Screen".
///
/// Faithful translation of the Stitch design
/// (screen `e8885e82739a4d58a8736084dad28b36`).
///
/// Reached straight after account creation, and also when someone tries to
/// sign in to an account whose address was never confirmed.
///
/// A real 6-digit code has been emailed to [email]; the user types it into the
/// code row and [onVerify] sends it to `POST /auth/verify-email`. Nothing here
/// knows or checks the code — the backend holds only a hash of it, and this
/// screen has no way to tell a right code from a wrong one until the server
/// answers.
class EmailVerificationScreen extends StatefulWidget {
  const EmailVerificationScreen({
    super.key,
    required this.email,
    this.onBack,
    this.onVerify,
    this.onResend,
    this.onChangeEmail,
    this.resendCountdown = const Duration(seconds: 30),
  });

  /// The address the code was sent to, shown under the heading.
  final String email;

  final VoidCallback? onBack;

  /// Receives the joined 6-digit code once every box is filled.
  final void Function(String code)? onVerify;

  /// Invoked when the user taps "Resend code" after the countdown elapses.
  final VoidCallback? onResend;

  final VoidCallback? onChangeEmail;

  /// How long "Resend code" stays disabled after entering the screen / a
  /// resend. Overridable so tests need not wait the full 30 seconds.
  final Duration resendCountdown;

  @override
  State<EmailVerificationScreen> createState() => _EmailVerificationScreenState();
}

class _EmailVerificationScreenState extends State<EmailVerificationScreen> {
  static const _digits = 6;

  final _controllers = List.generate(_digits, (_) => TextEditingController());
  final _nodes = List.generate(_digits, (_) => FocusNode());

  Timer? _timer;
  late int _secondsLeft;

  @override
  void initState() {
    super.initState();
    _startCountdown();
  }

  @override
  void dispose() {
    _timer?.cancel();
    for (final c in _controllers) {
      c.dispose();
    }
    for (final n in _nodes) {
      n.dispose();
    }
    super.dispose();
  }

  void _startCountdown() {
    _timer?.cancel();
    setState(() => _secondsLeft = widget.resendCountdown.inSeconds);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_secondsLeft <= 1) {
        t.cancel();
        setState(() => _secondsLeft = 0);
      } else {
        setState(() => _secondsLeft--);
      }
    });
  }

  String get _code => _controllers.map((c) => c.text).join();
  bool get _complete => _code.length == _digits;
  bool get _canResend => _secondsLeft == 0;

  void _onDigitChanged(int index, String value) {
    if (value.length > 1) {
      // A paste landed in one box: distribute across the row.
      final chars = value.replaceAll(RegExp(r'[^0-9]'), '').split('');
      for (var i = 0; i < _digits; i++) {
        _controllers[i].text = i < chars.length ? chars[i] : '';
      }
      final next = (chars.length).clamp(0, _digits - 1);
      _nodes[next].requestFocus();
      setState(() {});
      _maybeSubmit();
      return;
    }
    if (value.isNotEmpty && index < _digits - 1) {
      _nodes[index + 1].requestFocus();
    }
    setState(() {});
    _maybeSubmit();
  }

  KeyEventResult _onKey(int index, FocusNode node, KeyEvent event) {
    if (event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.backspace &&
        _controllers[index].text.isEmpty &&
        index > 0) {
      _controllers[index - 1].clear();
      _nodes[index - 1].requestFocus();
      setState(() {});
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  void _maybeSubmit() {
    if (_complete) {
      FocusScope.of(context).unfocus();
      widget.onVerify?.call(_code);
    }
  }

  void _resend() {
    if (!_canResend) return;
    for (final c in _controllers) {
      c.clear();
    }
    _nodes.first.requestFocus();
    widget.onResend?.call();
    _startCountdown();
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
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          const SizedBox(height: 32),
                          const _MailBadge(),
                          const SizedBox(height: 24),
                          Text(
                            'Check your inbox',
                            style: AppTypography.headlineLarge.copyWith(
                              color: AuthColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'We sent a 6-digit verification code to',
                            textAlign: TextAlign.center,
                            style: AppTypography.bodyMedium.copyWith(
                              color: AuthColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            widget.email.isEmpty
                                ? 'your email address'
                                : widget.email,
                            style: AppTypography.bodyMediumStrong.copyWith(
                              color: AuthColors.primary,
                            ),
                          ),
                          const SizedBox(height: 28),
                          _OtpRow(
                            controllers: _controllers,
                            nodes: _nodes,
                            onChanged: _onDigitChanged,
                            onKey: _onKey,
                          ),
                          const SizedBox(height: 20),
                          AuthPrimaryButton(
                            label: 'Verify',
                            onPressed: _complete ? _maybeSubmit : null,
                          ),
                          const SizedBox(height: 18),
                          _ResendRow(
                            canResend: _canResend,
                            secondsLeft: _secondsLeft,
                            onResend: _resend,
                          ),
                          const SizedBox(height: 10),
                          TextButton(
                            onPressed: widget.onChangeEmail,
                            style: TextButton.styleFrom(
                              foregroundColor: AuthColors.textSecondary,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: Text(
                              'Change email',
                              style: AppTypography.bodyMedium.copyWith(
                                color: AuthColors.textSecondary,
                                decoration: TextDecoration.underline,
                                decorationColor: const Color(0xFFC1C8C2),
                              ),
                            ),
                          ),
                        ],
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
}

/// Sage circular badge with a soft pulsing ring behind the mail glyph.
class _MailBadge extends StatefulWidget {
  const _MailBadge();

  @override
  State<_MailBadge> createState() => _MailBadgeState();
}

class _MailBadgeState extends State<_MailBadge>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2000),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 64,
      height: 64,
      child: Stack(
        alignment: Alignment.center,
        children: [
          FadeTransition(
            opacity: Tween(begin: 0.15, end: 0.4).animate(_pulse),
            child: Container(
              width: 64,
              height: 64,
              decoration: const BoxDecoration(
                color: Color(0xFF95D4B3),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: const Color(0xFFAEEECB).withValues(alpha: 0.4),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.mail_outline_rounded,
              size: 28,
              color: AuthColors.primary,
            ),
          ),
        ],
      ),
    );
  }
}

/// The six single-digit boxes.
class _OtpRow extends StatelessWidget {
  const _OtpRow({
    required this.controllers,
    required this.nodes,
    required this.onChanged,
    required this.onKey,
  });

  final List<TextEditingController> controllers;
  final List<FocusNode> nodes;
  final void Function(int index, String value) onChanged;
  final KeyEventResult Function(int index, FocusNode node, KeyEvent event) onKey;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(controllers.length, (i) {
        return Padding(
          padding: EdgeInsets.only(right: i == controllers.length - 1 ? 0 : 8),
          child: SizedBox(
            width: 48,
            height: 56,
            child: Focus(
              onKeyEvent: (node, event) => onKey(i, node, event),
              child: TextField(
                controller: controllers[i],
                focusNode: nodes[i],
                autofocus: i == 0,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                maxLength: 1,
                cursorColor: AuthColors.primary,
                style: AppTypography.headlineMedium.copyWith(
                  color: AuthColors.textPrimary,
                ),
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                onChanged: (v) => onChanged(i, v),
                decoration: InputDecoration(
                  counterText: '',
                  filled: true,
                  fillColor: AuthColors.field,
                  contentPadding: EdgeInsets.zero,
                  enabledBorder: _box(AuthColors.border),
                  focusedBorder: _box(AuthColors.primary, width: 1.5),
                ),
              ),
            ),
          ),
        );
      }),
    );
  }

  static OutlineInputBorder _box(Color color, {double width = 1}) =>
      OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: color, width: width),
      );
}

/// "Didn't receive the code? Resend code" plus the countdown caption.
class _ResendRow extends StatelessWidget {
  const _ResendRow({
    required this.canResend,
    required this.secondsLeft,
    required this.onResend,
  });

  final bool canResend;
  final int secondsLeft;
  final VoidCallback onResend;

  @override
  Widget build(BuildContext context) {
    final mm = (secondsLeft ~/ 60).toString().padLeft(2, '0');
    final ss = (secondsLeft % 60).toString().padLeft(2, '0');

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Didn’t receive the code? ',
              style: AppTypography.bodyMedium.copyWith(
                color: AuthColors.textSecondary,
              ),
            ),
            GestureDetector(
              onTap: canResend ? onResend : null,
              child: Text(
                'Resend code',
                style: AppTypography.bodyMediumStrong.copyWith(
                  color: canResend
                      ? AuthColors.primary
                      : AuthColors.primary.withValues(alpha: 0.4),
                  decoration:
                      canResend ? TextDecoration.underline : TextDecoration.none,
                ),
              ),
            ),
          ],
        ),
        if (!canResend) ...[
          const SizedBox(height: 4),
          Text(
            'RESEND AVAILABLE IN $mm:$ss',
            style: AppTypography.labelExtraSmall.copyWith(
              color: AuthColors.textMuted,
            ),
          ),
        ],
      ],
    );
  }
}
