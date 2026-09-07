import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../app/theme/app_typography.dart';

/// Shared auth chrome, reused across sign in, account creation, forgot
/// password and email verification.

/// Palette from the Stitch auth designs' Tailwind `brand` scale.
class AuthColors {
  const AuthColors._();

  static const Color primary = Color(0xFF183B2B);
  static const Color primaryDark = Color(0xFF112B1F);
  static const Color primaryLight = Color(0xFF24523D);

  static const Color surface = Color(0xFFFAF9F6);
  static const Color field = Color(0xFFFFFFFF);
  static const Color border = Color(0xFFE4E3DF);

  static const Color textPrimary = Color(0xFF11261C);
  static const Color textSecondary = Color(0xFF5A6960);
  static const Color textMuted = Color(0xFF75837A);
  static const Color placeholder = Color(0xFF9DA8A1);
}

TextStyle _font(double size, int weight, {Color? color, double? height}) =>
    TextStyle(
      fontFamily: AppTypography.fontFamily,
      fontSize: size,
      height: height,
      fontWeight: FontWeight.values[(weight ~/ 100) - 1],
      fontVariations: [FontVariation('wght', weight.toDouble())],
      color: color,
    );

/// Labelled text field matching the design's 52px / 14px-radius input.
class AuthTextField extends StatelessWidget {
  const AuthTextField({
    super.key,
    required this.label,
    required this.hint,
    this.controller,
    this.keyboardType,
    this.obscureText = false,
    this.autofillHints,
    this.validator,
    this.suffix,
    this.onSubmitted,
  });

  final String label;
  final String hint;
  final TextEditingController? controller;
  final TextInputType? keyboardType;
  final bool obscureText;
  final Iterable<String>? autofillHints;
  final String? Function(String?)? validator;
  final Widget? suffix;
  final void Function(String)? onSubmitted;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 2, bottom: 6),
          child: Text(
            label,
            style: _font(12.5, 500, color: AuthColors.textPrimary),
          ),
        ),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          obscureText: obscureText,
          autofillHints: autofillHints,
          validator: validator,
          onFieldSubmitted: onSubmitted,
          style: _font(14.5, 400, color: AuthColors.textPrimary),
          cursorColor: AuthColors.primary,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: _font(14.5, 400, color: AuthColors.placeholder),
            filled: true,
            fillColor: AuthColors.field,
            suffixIcon: suffix,
            // 52px tall: 16px vertical padding around a ~20px line box.
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 16,
            ),
            border: _border(AuthColors.border),
            enabledBorder: _border(AuthColors.border),
            focusedBorder: _border(AuthColors.primary, width: 1.5),
            errorBorder: _border(Theme.of(context).colorScheme.error),
            focusedErrorBorder: _border(
              Theme.of(context).colorScheme.error,
              width: 1.5,
            ),
            errorStyle: _font(11.5, 500),
          ),
        ),
      ],
    );
  }

  static OutlineInputBorder _border(Color color, {double width = 1}) =>
      OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: color, width: width),
      );
}

/// Full-width filled CTA, 54px tall with the design's soft green shadow.
class AuthPrimaryButton extends StatelessWidget {
  const AuthPrimaryButton({super.key, required this.label, this.onPressed});

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [
          BoxShadow(
            color: Color(0x3D183B2B),
            blurRadius: 18,
            spreadRadius: -3,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: SizedBox(
        height: 54,
        child: FilledButton(
          onPressed: onPressed,
          style: FilledButton.styleFrom(
            backgroundColor: AuthColors.primary,
            foregroundColor: Colors.white,
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: _font(15, 600).copyWith(letterSpacing: -0.15),
          ),
        ),
      ),
    );
  }
}

/// White outlined button used for the social providers.
class AuthSocialButton extends StatelessWidget {
  const AuthSocialButton({
    super.key,
    required this.label,
    required this.icon,
    this.onPressed,
  });

  final String label;
  final Widget icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          backgroundColor: AuthColors.field,
          foregroundColor: AuthColors.textPrimary,
          side: const BorderSide(color: AuthColors.border),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            icon,
            const SizedBox(width: 10),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: _font(
                  14.5,
                  600,
                  color: AuthColors.textPrimary,
                ).copyWith(letterSpacing: -0.15),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Hairline rule with centred caption, e.g. "or continue with".
class AuthDivider extends StatelessWidget {
  const AuthDivider({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(child: Divider(color: AuthColors.border, height: 1)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            label,
            style: _font(11.5, 400, color: AuthColors.textMuted),
          ),
        ),
        const Expanded(child: Divider(color: AuthColors.border, height: 1)),
      ],
    );
  }
}

/// Footer line pairing a prompt with a single inline action.
class AuthFooterPrompt extends StatelessWidget {
  const AuthFooterPrompt({
    super.key,
    required this.prompt,
    required this.action,
    this.onAction,
  });

  final String prompt;
  final String action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(
        text: '$prompt ',
        style: _font(13, 400, color: AuthColors.textSecondary),
        children: [
          WidgetSpan(
            alignment: PlaceholderAlignment.baseline,
            baseline: TextBaseline.alphabetic,
            child: GestureDetector(
              onTap: onAction,
              child: Text(
                action,
                style: _font(13, 600, color: AuthColors.primary),
              ),
            ),
          ),
        ],
      ),
      textAlign: TextAlign.center,
    );
  }
}

/// The four-colour Google "G", rendered from the design's SVG asset.
class GoogleGlyph extends StatelessWidget {
  const GoogleGlyph({super.key, this.size = 18});

  final double size;

  @override
  Widget build(BuildContext context) => SvgPicture.asset(
    'assets/brand/google_g.svg',
    width: size,
    height: size,
    semanticsLabel: 'Google',
  );
}
