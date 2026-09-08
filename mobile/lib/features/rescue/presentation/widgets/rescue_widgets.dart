import 'package:flutter/material.dart';

import '../../../../app/theme/app_typography.dart';

/// Shared chrome for the consumer discovery-and-rescue flow: Home, Food
/// Details, the Rescue Confirmation sheet and Active Rescue.
///
/// The four Stitch designs share one Tailwind `brand` scale, so it lives here
/// once rather than being re-derived per screen — the same arrangement
/// `AuthColors` uses for the auth designs.

/// Palette from the consumer designs' Tailwind `brand` scale.
class RescueColors {
  const RescueColors._();

  static const Color primary = Color(0xFF183B2B);
  static const Color primaryDark = Color(0xFF112A1F);
  static const Color primaryLight = Color(0xFF23523D);

  static const Color surface = Color(0xFFFAF9F6);
  static const Color card = Color(0xFFFFFFFF);
  static const Color border = Color(0xFFE7E5DF);

  /// Sage accents: the filled badge tone and the paler card wash.
  static const Color sage = Color(0xFFDBECE2);
  static const Color sageSubtle = Color(0xFFEDF6F1);

  static const Color ink = Color(0xFF121F17);
  static const Color muted = Color(0xFF5A6960);

  /// Restrained amber, reserved for "expiring soon".
  static const Color amber = Color(0xFFB86B1B);
  static const Color amberBg = Color(0xFFFDF6EE);
  static const Color amberBorder = Color(0xFFF0E0C8);

  /// Positive live-status green, distinct from the brand forest.
  static const Color live = Color(0xFF1E874B);
  static const Color route = Color(0xFF38A169);

  // Stylised map geometry.
  static const Color mapLand = Color(0xFFEBE8E1);
  static const Color mapParcel = Color(0xFFE7E2D7);
  static const Color mapGreen = Color(0xFFDBECE2);
  static const Color mapRoad = Color(0xFFFFFFFF);
}

/// Plus Jakarta Sans at an explicit size and weight.
///
/// The bundled face is variable, so the `wght` axis has to be set alongside
/// `fontWeight` — see [AppTypography].
TextStyle rescueFont(
  double size,
  int weight, {
  Color? color,
  double? height,
  double? letterSpacing,
}) => TextStyle(
  fontFamily: AppTypography.fontFamily,
  fontSize: size,
  height: height,
  letterSpacing: letterSpacing,
  fontWeight: FontWeight.values[(weight ~/ 100) - 1],
  fontVariations: [FontVariation('wght', weight.toDouble())],
  color: color,
);

/// White panel with the designs' hairline border and soft ambient shadow.
class RescueCard extends StatelessWidget {
  const RescueCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.radius = 20,
    this.color = RescueColors.card,
    this.borderColor = RescueColors.border,
    this.elevated = false,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final Color color;
  final Color borderColor;

  /// The hero cards carry a slightly deeper green-tinted shadow.
  final bool elevated;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: borderColor),
        boxShadow: [
          elevated
              ? const BoxShadow(
                  color: Color(0x0F183B2B),
                  blurRadius: 20,
                  offset: Offset(0, 4),
                )
              : const BoxShadow(
                  color: Color(0x0A121F17),
                  blurRadius: 10,
                  offset: Offset(0, 2),
                ),
        ],
      ),
      child: child,
    );
  }
}

/// Slowly pulsing dot used for every "live" affordance in the designs.
class LiveDot extends StatefulWidget {
  const LiveDot({super.key, this.size = 6, this.color = RescueColors.primary});

  final double size;
  final Color color;

  @override
  State<LiveDot> createState() => _LiveDotState();
}

class _LiveDotState extends State<LiveDot> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2000),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // The design scales to 1.35 and fades to 0.6 at the midpoint.
    final curved = CurvedAnimation(parent: _c, curve: Curves.easeInOut);
    return SizedBox(
      width: widget.size * 1.35,
      height: widget.size * 1.35,
      child: Center(
        child: ScaleTransition(
          scale: Tween(begin: 1.0, end: 1.35).animate(curved),
          child: FadeTransition(
            opacity: Tween(begin: 1.0, end: 0.6).animate(curved),
            child: Container(
              width: widget.size,
              height: widget.size,
              decoration: BoxDecoration(
                color: widget.color,
                shape: BoxShape.circle,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Rounded sage chip pairing a [LiveDot] with a short label.
class LivePill extends StatelessWidget {
  const LivePill({
    super.key,
    required this.label,
    this.background = RescueColors.sageSubtle,
    this.foreground = RescueColors.primary,
    this.dotColor = RescueColors.primary,
    this.fontSize = 11,
    this.uppercase = false,
  });

  final String label;
  final Color background;
  final Color foreground;
  final Color dotColor;
  final double fontSize;
  final bool uppercase;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          LiveDot(size: fontSize * 0.55, color: dotColor),
          const SizedBox(width: 5),
          Text(
            uppercase ? label.toUpperCase() : label,
            style: rescueFont(
              fontSize,
              600,
              color: foreground,
              letterSpacing: uppercase ? 0.4 : 0.2,
            ),
          ),
        ],
      ),
    );
  }
}

/// Static chip (no pulse) — used for tags and the amber timing badge.
class RescueChip extends StatelessWidget {
  const RescueChip({
    super.key,
    required this.label,
    this.icon,
    this.background = RescueColors.sageSubtle,
    this.foreground = RescueColors.primary,
    this.borderColor,
    this.fontSize = 11,
    this.fontWeight = 600,
  });

  final String label;
  final IconData? icon;
  final Color background;
  final Color foreground;
  final Color? borderColor;
  final double fontSize;
  final int fontWeight;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(8),
        border: borderColor == null ? null : Border.all(color: borderColor!),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: fontSize + 1, color: foreground),
            const SizedBox(width: 5),
          ],
          Text(
            label,
            style: rescueFont(fontSize, fontWeight, color: foreground),
          ),
        ],
      ),
    );
  }
}

/// Section title with an optional trailing text action ("See all").
class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    this.live = false,
    this.badgeCount,
    this.actionLabel,
    this.onAction,
  });

  final String title;

  /// Appends the small pulsing "live stream active" dot after the title.
  final bool live;

  /// Sage counter pill after the title, e.g. the partner dashboard's "2"
  /// beside "Active surplus".
  final int? badgeCount;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Text(
              title,
              style: rescueFont(
                17,
                700,
                color: RescueColors.ink,
                letterSpacing: -0.3,
              ),
            ),
            if (live) ...[
              const SizedBox(width: 8),
              const LiveDot(size: 8, color: RescueColors.live),
            ],
            if (badgeCount != null) ...[
              const SizedBox(width: 8),
              Container(
                width: 20,
                height: 20,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  color: RescueColors.sage,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  '$badgeCount',
                  style: rescueFont(11, 700, color: RescueColors.primary),
                ),
              ),
            ],
          ],
        ),
        if (actionLabel != null)
          GestureDetector(
            onTap: onAction,
            child: Text(
              actionLabel!,
              style: rescueFont(13, 600, color: RescueColors.primary),
            ),
          ),
      ],
    );
  }
}

/// Rounded-square icon container that fronts every detail row in the designs.
class IconTile extends StatelessWidget {
  const IconTile({
    super.key,
    required this.icon,
    this.size = 40,
    this.iconSize = 20,
    this.background = RescueColors.sageSubtle,
    this.foreground = RescueColors.primary,
    this.radius = 12,
    this.borderColor,
  });

  final IconData icon;
  final double size;
  final double iconSize;
  final Color background;
  final Color foreground;
  final double radius;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(radius),
        border: borderColor == null ? null : Border.all(color: borderColor!),
      ),
      child: Icon(icon, size: iconSize, color: foreground),
    );
  }
}

/// Icon + small caption + prominent value, optionally with a trailing action.
class DetailRow extends StatelessWidget {
  const DetailRow({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    this.caption,
    this.actionLabel,
    this.onAction,
    this.uppercaseLabel = false,
    this.tileBackground = RescueColors.sageSubtle,
    this.tileBorderColor,
    this.tileSize = 40,
  });

  final IconData icon;
  final String label;
  final String value;
  final String? caption;
  final String? actionLabel;
  final VoidCallback? onAction;
  final bool uppercaseLabel;
  final Color tileBackground;
  final Color? tileBorderColor;
  final double tileSize;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        IconTile(
          icon: icon,
          size: tileSize,
          iconSize: tileSize * 0.5,
          background: tileBackground,
          borderColor: tileBorderColor,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                uppercaseLabel ? label.toUpperCase() : label,
                style: rescueFont(
                  uppercaseLabel ? 11 : 13,
                  uppercaseLabel ? 700 : 400,
                  color: RescueColors.muted,
                  letterSpacing: uppercaseLabel ? 0.6 : 0,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: rescueFont(
                  15,
                  700,
                  color: RescueColors.ink,
                  letterSpacing: -0.2,
                ),
              ),
              if (caption != null) ...[
                const SizedBox(height: 2),
                Text(
                  caption!,
                  style: rescueFont(12, 400, color: RescueColors.muted),
                ),
              ],
              if (actionLabel != null) ...[
                const SizedBox(height: 4),
                GestureDetector(
                  onTap: onAction,
                  child: Text(
                    actionLabel!,
                    style: rescueFont(13, 600, color: RescueColors.primary),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// Hairline rule used inside the detail cards.
class RescueDivider extends StatelessWidget {
  const RescueDivider({super.key, this.vertical = 12});

  final double vertical;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.symmetric(vertical: vertical),
    child: const ColoredBox(
      color: RescueColors.border,
      child: SizedBox(height: 1, width: double.infinity),
    ),
  );
}

/// Full-width filled CTA with an optional leading icon.
class RescuePrimaryButton extends StatelessWidget {
  const RescuePrimaryButton({
    super.key,
    required this.label,
    this.icon,
    this.onPressed,
    this.height = 54,
    this.background = RescueColors.primary,
    this.foreground = Colors.white,
    this.leading,
  });

  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final double height;
  final Color background;
  final Color foreground;

  /// Replaces [icon] outright — used for the sheet's "Reserving…" spinner.
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: enabled
            ? [
                BoxShadow(
                  color: background.withValues(alpha: 0.28),
                  blurRadius: 16,
                  spreadRadius: -2,
                  offset: const Offset(0, 4),
                ),
              ]
            : const [],
      ),
      child: SizedBox(
        height: height,
        child: FilledButton(
          onPressed: onPressed,
          style: FilledButton.styleFrom(
            backgroundColor: background,
            foregroundColor: foreground,
            disabledBackgroundColor: background.withValues(alpha: 0.4),
            disabledForegroundColor: foreground.withValues(alpha: 0.8),
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (leading != null) ...[
                leading!,
                const SizedBox(width: 8),
              ] else if (icon != null) ...[
                Icon(icon, size: 19),
                const SizedBox(width: 8),
              ],
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: rescueFont(15, 600, letterSpacing: -0.15),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Small pill button ("Rescue") used on the opportunity cards.
class RescueMiniButton extends StatelessWidget {
  const RescueMiniButton({super.key, required this.label, this.onPressed});

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 30,
      child: FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: RescueColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Text(label, style: rescueFont(12.5, 600)),
      ),
    );
  }
}

/// Circular icon button used in the screen headers.
class RescueIconButton extends StatelessWidget {
  const RescueIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    this.onPressed,
    this.color = RescueColors.ink,
    this.background,
    this.showBadge = false,
    this.size = 40,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final Color color;
  final Color? background;

  /// Unread dot for the notification bell.
  final bool showBadge;
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        children: [
          Material(
            color: background ?? Colors.transparent,
            shape: background == null
                ? const CircleBorder()
                : const CircleBorder(
                    side: BorderSide(color: RescueColors.border),
                  ),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onPressed,
              child: Tooltip(
                message: tooltip,
                child: Center(child: Icon(icon, size: 20, color: color)),
              ),
            ),
          ),
          if (showBadge)
            Positioned(
              top: 8,
              right: 8,
              child: Container(
                width: 9,
                height: 9,
                decoration: BoxDecoration(
                  color: RescueColors.primary,
                  shape: BoxShape.circle,
                  border: Border.all(color: RescueColors.card, width: 2),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// The 32x1 home-indicator bar the designs draw at the bottom of every screen.
class HomeIndicator extends StatelessWidget {
  const HomeIndicator({super.key, this.color});

  final Color? color;

  @override
  Widget build(BuildContext context) => Center(
    child: Container(
      width: 128,
      height: 4,
      decoration: BoxDecoration(
        color: color ?? RescueColors.ink.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(999),
      ),
    ),
  );
}
