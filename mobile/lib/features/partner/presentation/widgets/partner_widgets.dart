import 'package:flutter/material.dart';

import '../../../rescue/presentation/widgets/rescue_widgets.dart';
import '../../domain/partner_dashboard.dart';

/// Shared chrome for the restaurant-partner screens.
///
/// The partner designs use the same brand scale as the consumer ones, so
/// [RescueColors] and [rescueFont] carry over; only the operational tones the
/// partner app adds are defined here.

/// Amber, for anything close to its pickup window.
const Color partnerAmber = Color(0xFFB45309);
const Color partnerAmberDeep = Color(0xFF78350F);
const Color partnerAmberBg = Color(0xFFFFFBEB);
const Color partnerAmberBorder = Color(0xFFFDE68A);
const Color partnerAmberTile = Color(0xFFFEF3C7);

/// Emerald, for "live", "matched" and "collected".
const Color partnerEmerald = Color(0xFF047857);
const Color partnerEmeraldDeep = Color(0xFF065F46);
const Color partnerEmeraldBg = Color(0xFFECFDF5);
const Color partnerEmeraldBorder = Color(0xFFD1FAE5);

/// Neutral stone, for closed and unscheduled states.
const Color partnerStoneBg = Color(0xFFF5F5F4);
const Color partnerStoneBorder = Color(0xFFE7E5E4);

/// Small status pill used across the partner cards.
class PartnerTag extends StatelessWidget {
  const PartnerTag({
    super.key,
    required this.label,
    required this.foreground,
    required this.background,
    required this.borderColor,
    this.dotColor,
    this.icon,
  });

  final String label;
  final Color foreground;
  final Color background;
  final Color borderColor;

  /// Leading dot, as on the design's LIVE tag.
  final Color? dotColor;

  /// Leading icon, used instead of [dotColor].
  final IconData? icon;

  /// The green "LIVE" tag.
  factory PartnerTag.live() => const PartnerTag(
    label: 'LIVE',
    foreground: partnerEmeraldDeep,
    background: partnerEmeraldBg,
    borderColor: partnerEmeraldBorder,
    dotColor: partnerEmerald,
  );

  /// The tag for a batch's matching state.
  factory PartnerTag.status(PartnerSurplusStatus status) => switch (status) {
    PartnerSurplusStatus.rescuerMatched => const PartnerTag(
      label: 'Rescuer matched',
      foreground: RescueColors.primary,
      background: RescueColors.sage,
      borderColor: RescueColors.sage,
      icon: Icons.check_circle_outline_rounded,
    ),
    PartnerSurplusStatus.lookingForRescuer => const PartnerTag(
      label: 'Looking for rescuer',
      foreground: partnerAmber,
      background: partnerAmberBg,
      borderColor: partnerAmberBorder,
      dotColor: partnerAmber,
    ),
    PartnerSurplusStatus.awaitingHandover => const PartnerTag(
      label: 'Awaiting handover',
      foreground: RescueColors.primary,
      background: RescueColors.sage,
      borderColor: RescueColors.sage,
      icon: Icons.pending_outlined,
    ),
    PartnerSurplusStatus.draft => const PartnerTag(
      label: 'Draft',
      foreground: RescueColors.muted,
      background: partnerStoneBg,
      borderColor: partnerStoneBorder,
      icon: Icons.edit_outlined,
    ),
    PartnerSurplusStatus.collected => const PartnerTag(
      label: 'Collected',
      foreground: partnerEmeraldDeep,
      background: partnerEmeraldBg,
      borderColor: partnerEmeraldBorder,
      icon: Icons.check_rounded,
    ),
    PartnerSurplusStatus.expired => const PartnerTag(
      label: 'Expired',
      foreground: RescueColors.muted,
      background: partnerStoneBg,
      borderColor: partnerStoneBorder,
      icon: Icons.history_rounded,
    ),
  };

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (dotColor != null) ...[
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: dotColor,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 5),
          ] else if (icon != null) ...[
            Icon(icon, size: 11, color: foreground),
            const SizedBox(width: 4),
          ],
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              softWrap: false,
              style: rescueFont(10.5, 700, color: foreground),
            ),
          ),
        ],
      ),
    );
  }
}

/// The full surplus card used on the Surplus Management screen.
///
/// Richer than the dashboard's card: it leads with the status tags and the
/// countdown, and carries the pickup point, because this is where the
/// partner manages a batch rather than glances at it.
class PartnerSurplusCard extends StatelessWidget {
  const PartnerSurplusCard({
    super.key,
    required this.surplus,
    this.onOpen,
    this.onManage,
  });

  final PartnerSurplus surplus;
  final VoidCallback? onOpen;
  final VoidCallback? onManage;

  @override
  Widget build(BuildContext context) {
    final matched = surplus.status == PartnerSurplusStatus.rescuerMatched;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: RescueColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: RescueColors.border),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    if (surplus.isLive) ...[
                      PartnerTag.live(),
                      const SizedBox(width: 6),
                    ],
                    Flexible(child: PartnerTag.status(surplus.status)),
                  ],
                ),
              ),
              if (surplus.remainingLabel != null) ...[
                const SizedBox(width: 8),
                _Countdown(label: surplus.remainingLabel!, urgent: matched),
              ],
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              PartnerThumbnail(asset: surplus.imageAsset, size: 84),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      surplus.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: rescueFont(
                        16,
                        700,
                        color: RescueColors.ink,
                        height: 1.3,
                      ),
                    ),
                    if (surplus.detailLine != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        surplus.detailLine!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: rescueFont(12, 500, color: RescueColors.muted),
                      ),
                    ],
                    const SizedBox(height: 8),
                    _MetaRow(
                      icon: Icons.schedule_rounded,
                      label: surplus.windowLabel,
                      emphasised: true,
                    ),
                    if (surplus.pickupPoint != null) ...[
                      const SizedBox(height: 4),
                      _MetaRow(
                        icon: Icons.place_outlined,
                        label: surplus.pickupPoint!,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const RescueDivider(),
          const SizedBox(height: 10),
          Row(
            children: [
              TextButton(
                onPressed: onManage,
                style: TextButton.styleFrom(
                  foregroundColor: RescueColors.muted,
                  minimumSize: const Size(0, 32),
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Manage',
                      style: rescueFont(12, 600, color: RescueColors.muted),
                    ),
                    const SizedBox(width: 2),
                    const Icon(Icons.expand_more_rounded, size: 14),
                  ],
                ),
              ),
              const Spacer(),
              FilledButton(
                onPressed: onOpen,
                style: FilledButton.styleFrom(
                  backgroundColor: matched
                      ? RescueColors.primary
                      : RescueColors.sageSubtle,
                  foregroundColor: matched
                      ? Colors.white
                      : RescueColors.primary,
                  elevation: 0,
                  minimumSize: const Size(0, 34),
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  side: matched
                      ? null
                      : const BorderSide(color: RescueColors.sage),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      surplus.actionLabel,
                      style: rescueFont(
                        12.5,
                        700,
                        color: matched ? Colors.white : RescueColors.primary,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      Icons.arrow_forward_rounded,
                      size: 13,
                      color: matched ? Colors.white : RescueColors.primary,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// The card's time-left chip: emerald once matched, neutral while waiting.
class _Countdown extends StatelessWidget {
  const _Countdown({required this.label, required this.urgent});

  final String label;
  final bool urgent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: urgent ? partnerEmeraldBg : partnerStoneBg,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: urgent ? partnerEmeraldBorder : partnerStoneBorder,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.schedule_rounded,
            size: 11,
            color: urgent ? partnerEmeraldDeep : RescueColors.muted,
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: rescueFont(
              11.5,
              700,
              color: urgent ? partnerEmeraldDeep : RescueColors.muted,
            ),
          ),
        ],
      ),
    );
  }
}

/// One icon-and-text line under a card's title.
class _MetaRow extends StatelessWidget {
  const _MetaRow({
    required this.icon,
    required this.label,
    this.emphasised = false,
  });

  final IconData icon;
  final String label;

  /// Darker treatment for the pickup window, as in the design.
  final bool emphasised;

  @override
  Widget build(BuildContext context) {
    final color = emphasised ? RescueColors.ink : RescueColors.muted;
    return Row(
      children: [
        Icon(icon, size: 12, color: color),
        const SizedBox(width: 5),
        Expanded(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: rescueFont(11.5, 500, color: color),
          ),
        ),
      ],
    );
  }
}

/// Rounded food thumbnail, with an optional LIVE tag.
class PartnerThumbnail extends StatelessWidget {
  const PartnerThumbnail({
    super.key,
    required this.asset,
    required this.size,
    this.showLive = false,
  });

  final String asset;
  final double size;
  final bool showLive;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        width: size,
        height: size,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(
              asset,
              fit: BoxFit.cover,
              // Keeps the row intact if an asset is ever missing.
              errorBuilder: (context, error, stackTrace) => Container(
                color: RescueColors.sageSubtle,
                child: const Icon(
                  Icons.restaurant_rounded,
                  size: 18,
                  color: RescueColors.primary,
                ),
              ),
            ),
            if (showLive)
              Positioned(
                top: 6,
                left: 6,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 5,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: RescueColors.primary.withValues(alpha: 0.8),
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: Text(
                    'LIVE',
                    style: rescueFont(9, 700, letterSpacing: 0.5),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
