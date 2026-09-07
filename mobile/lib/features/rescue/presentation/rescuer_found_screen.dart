import 'package:flutter/material.dart';

import '../domain/food_listing.dart';
import 'widgets/rescue_widgets.dart';

/// "FoodLoop Consumer Rescuer Found Screen".
///
/// Faithful translation of the Stitch design
/// (screen `e722e6e8aa6c4460b93d55a5310a6f28`).
///
/// Sits between the rescue confirmation sheet and Active Rescue: the match has
/// been made and the pickup is arranged. UI only — the rescuer identity and
/// progress are placeholders until the Phase 5 rescue service exists.
class RescuerFoundScreen extends StatelessWidget {
  const RescuerFoundScreen({
    super.key,
    required this.listing,
    this.rescuerName = 'Community Rescuer',
    this.rescuerStatus = 'En route for scheduled collection',
    this.timeRemaining,
    this.onBack,
    this.onHelp,
    this.onViewActiveRescue,
    this.onDone,
  });

  final FoodListing listing;

  /// Deliberately non-identifying: the design shows only initials and a role,
  /// never a real name, so the rescuer's identity stays private pre-handover.
  final String rescuerName;
  final String rescuerStatus;

  /// Falls back to the listing's own window, then to the design's value, so
  /// the countdown matches Active Rescue for the same rescue.
  final Duration? timeRemaining;

  final VoidCallback? onBack;
  final VoidCallback? onHelp;
  final VoidCallback? onViewActiveRescue;
  final VoidCallback? onDone;

  Duration get _remaining =>
      timeRemaining ?? listing.timeRemaining ?? const Duration(minutes: 58);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: RescueColors.surface,
      body: SafeArea(
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 430),
            child: Column(
              children: [
                _FoundAppBar(onBack: onBack, onHelp: onHelp),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                    children: [
                      _SuccessHero(remaining: _remaining),
                      const SizedBox(height: 16),
                      _PickupSummaryCard(listing: listing),
                      const SizedBox(height: 16),
                      _RescuerCard(
                        name: rescuerName,
                        status: rescuerStatus,
                      ),
                      const SizedBox(height: 16),
                      const _ProgressCard(),
                      const SizedBox(height: 14),
                      const _UpdatesNote(),
                    ],
                  ),
                ),
                _FoundActionBar(
                  onViewActiveRescue: onViewActiveRescue,
                  onDone: onDone,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Verified-green accent used for the headline tick and the confirmed line.
const Color _accent = Color(0xFF226042);

/// Sage border tone specific to this design's chips and step nodes.
const Color _sageBorder = Color(0xFFCBE0D3);

class _FoundAppBar extends StatelessWidget {
  const _FoundAppBar({this.onBack, this.onHelp});

  final VoidCallback? onBack;
  final VoidCallback? onHelp;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          children: [
            RescueIconButton(
              icon: Icons.arrow_back_ios_new_rounded,
              tooltip: 'Back to home',
              onPressed: onBack,
            ),
            // Centre title pill, in place of a plain title.
            Expanded(
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: RescueColors.card,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: RescueColors.border),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const LiveDot(size: 7),
                      const SizedBox(width: 6),
                      Text(
                        'Rescue matched',
                        style: rescueFont(
                          12,
                          600,
                          color: RescueColors.ink,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            RescueIconButton(
              icon: Icons.help_outline_rounded,
              tooltip: 'Help and FAQ',
              onPressed: onHelp,
              color: RescueColors.muted,
            ),
          ],
        ),
      ),
    );
  }
}

/// Check badge, headline and the matched / countdown chip row.
class _SuccessHero extends StatefulWidget {
  const _SuccessHero({required this.remaining});

  final Duration remaining;

  @override
  State<_SuccessHero> createState() => _SuccessHeroState();
}

class _SuccessHeroState extends State<_SuccessHero>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 600),
  )..forward();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pop = CurvedAnimation(
      parent: _c,
      curve: const Interval(0, 0.62, curve: Curves.easeOutBack),
    );
    final reveal = CurvedAnimation(
      parent: _c,
      curve: const Interval(0.2, 1, curve: Curves.easeOut),
    );

    final minutes = widget.remaining.inMinutes;
    final remainingLabel = widget.remaining.inHours >= 1
        ? '${widget.remaining.inHours} hr remaining'
        : '$minutes min remaining';

    return Column(
      children: [
        ScaleTransition(
          scale: Tween(begin: 0.85, end: 1.0).animate(pop),
          child: FadeTransition(
            opacity: pop,
            child: Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: RescueColors.primary,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: RescueColors.primary.withValues(alpha: 0.18),
                    blurRadius: 18,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Icon(
                Icons.check_rounded,
                size: 28,
                color: Colors.white,
              ),
            ),
          ),
        ),
        const SizedBox(height: 14),
        FadeTransition(
          opacity: reveal,
          child: SlideTransition(
            position: Tween(
              begin: const Offset(0, 0.15),
              end: Offset.zero,
            ).animate(reveal),
            child: Column(
              children: [
                Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: 'Rescuer found ',
                        style: rescueFont(
                          25,
                          700,
                          color: RescueColors.ink,
                          height: 1.15,
                          letterSpacing: -0.5,
                        ),
                      ),
                      TextSpan(
                        text: '✓',
                        style: rescueFont(25, 700, color: _accent),
                      ),
                    ],
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 4),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 280),
                  child: Text(
                    'Your surplus has been matched for pickup.',
                    textAlign: TextAlign.center,
                    style: rescueFont(
                      14,
                      400,
                      color: RescueColors.muted,
                      height: 1.35,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: RescueColors.sageSubtle,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: _sageBorder),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(
                              color: RescueColors.primary,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'RESCUE MATCHED',
                            style: rescueFont(
                              11,
                              700,
                              color: RescueColors.primary,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: RescueColors.card,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: RescueColors.border),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.schedule_rounded,
                            size: 13,
                            color: RescueColors.muted,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            remainingLabel,
                            style: rescueFont(
                              11,
                              600,
                              color: RescueColors.ink,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _PickupSummaryCard extends StatelessWidget {
  const _PickupSummaryCard({required this.listing});

  final FoodListing listing;

  @override
  Widget build(BuildContext context) {
    return RescueCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              IconTile(
                icon: Icons.lunch_dining_outlined,
                background: RescueColors.sageSubtle,
                borderColor: _sageBorder.withValues(alpha: 0.5),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      listing.title,
                      style: rescueFont(
                        17,
                        600,
                        color: RescueColors.ink,
                        height: 1.15,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${listing.category} · Approx. '
                      '${listing.servings} servings',
                      style: rescueFont(13, 400, color: RescueColors.muted),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              RescueChip(
                label: listing.category,
                background: RescueColors.sageSubtle,
                foreground: RescueColors.primary,
                fontWeight: 500,
              ),
            ],
          ),
          const RescueDivider(vertical: 12),
          _InfoLine(
            icon: Icons.location_on_outlined,
            text: listing.pickupLocation,
            trailingMuted: '· ${listing.distanceLabel}',
          ),
          const SizedBox(height: 8),
          _InfoLine(
            icon: Icons.schedule_rounded,
            text: listing.pickupWindow,
            badge: 'Pickup by ${listing.pickupDeadline}',
          ),
        ],
      ),
    );
  }
}

class _InfoLine extends StatelessWidget {
  const _InfoLine({
    required this.icon,
    required this.text,
    this.trailingMuted,
    this.badge,
  });

  final IconData icon;
  final String text;
  final String? trailingMuted;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: RescueColors.primary),
        const SizedBox(width: 10),
        Flexible(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: rescueFont(13, 500, color: RescueColors.ink),
          ),
        ),
        if (trailingMuted != null) ...[
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              trailingMuted!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: rescueFont(12, 400, color: RescueColors.muted),
            ),
          ),
        ],
        if (badge != null) ...[
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: RescueColors.surface,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: RescueColors.border),
            ),
            child: Text(
              badge!,
              style: rescueFont(11, 500, color: RescueColors.muted),
            ),
          ),
        ],
      ],
    );
  }
}

/// Privacy-preserving trust card: initials and a role, never a real identity.
class _RescuerCard extends StatelessWidget {
  const _RescuerCard({required this.name, required this.status});

  final String name;
  final String status;

  /// "Community Rescuer" -> "CR".
  static String initialsOf(String value) {
    final words = value.trim().split(RegExp(r'\s+'));
    if (words.isEmpty || words.first.isEmpty) return '?';
    if (words.length == 1) return words.first.characters.first.toUpperCase();
    return (words[0].characters.first + words[1].characters.first)
        .toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return RescueCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'PICKUP ARRANGED',
                style: rescueFont(
                  12,
                  700,
                  color: RescueColors.muted,
                  letterSpacing: 0.9,
                ),
              ),
              Row(
                children: [
                  const Icon(
                    Icons.check_rounded,
                    size: 14,
                    color: RescueColors.primary,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Pickup confirmed',
                    style: rescueFont(12, 600, color: RescueColors.primary),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: RescueColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: RescueColors.border),
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    color: RescueColors.primary,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    initialsOf(name),
                    style: rescueFont(
                      14,
                      700,
                      color: Colors.white,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: rescueFont(
                                15,
                                700,
                                color: RescueColors.ink,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            width: 16,
                            height: 16,
                            decoration: const BoxDecoration(
                              color: RescueColors.sageSubtle,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.check_rounded,
                              size: 10,
                              color: RescueColors.primary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        status,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: rescueFont(
                          12,
                          400,
                          color: RescueColors.muted,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  Icons.shield_outlined,
                  size: 20,
                  color: RescueColors.primary.withValues(alpha: 0.6),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The simplified three-stage track this screen shows, distinct from Active
/// Rescue's five-stage lifecycle.
class _ProgressCard extends StatelessWidget {
  const _ProgressCard();

  @override
  Widget build(BuildContext context) {
    return RescueCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'RESCUE PROGRESS',
            style: rescueFont(
              12,
              700,
              color: RescueColors.muted,
              letterSpacing: 0.9,
            ),
          ),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, constraints) {
              const count = 3;
              final column = constraints.maxWidth / count;
              final firstCentre = column / 2;
              // The design fills the track to the midpoint — matched is done,
              // pickup is in progress.
              final activeCentre = column + column / 2;

              return SizedBox(
                // 28px node + 6px gap + the label's line box; 52 leaves the
                // label room at larger text scales.
                height: 52,
                child: Stack(
                  children: [
                    Positioned(
                      left: firstCentre,
                      right: firstCentre,
                      top: 13,
                      child: Container(height: 2, color: RescueColors.border),
                    ),
                    Positioned(
                      left: firstCentre,
                      width: activeCentre - firstCentre,
                      top: 13,
                      child: Container(
                        height: 2,
                        color: RescueColors.primary,
                      ),
                    ),
                    const Row(
                      children: [
                        Expanded(
                          child: _Step(label: 'MATCHED', state: _StepState.done),
                        ),
                        Expanded(
                          child: _Step(
                            label: 'PICKUP',
                            state: _StepState.active,
                          ),
                        ),
                        Expanded(
                          child: _Step(
                            label: 'COLLECTED',
                            state: _StepState.upcoming,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

enum _StepState { done, active, upcoming }

class _Step extends StatelessWidget {
  const _Step({required this.label, required this.state});

  final String label;
  final _StepState state;

  @override
  Widget build(BuildContext context) {
    final Widget node = switch (state) {
      _StepState.done => Container(
        width: 28,
        height: 28,
        decoration: const BoxDecoration(
          color: RescueColors.primary,
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.check_rounded, size: 14, color: Colors.white),
      ),
      _StepState.active => Container(
        width: 28,
        height: 28,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: RescueColors.sageSubtle,
          shape: BoxShape.circle,
          border: Border.all(color: RescueColors.primary, width: 2),
        ),
        child: const LiveDot(size: 8),
      ),
      _StepState.upcoming => Container(
        width: 28,
        height: 28,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: RescueColors.surface,
          shape: BoxShape.circle,
          border: Border.all(color: RescueColors.border),
        ),
        child: Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: RescueColors.muted.withValues(alpha: 0.4),
            shape: BoxShape.circle,
          ),
        ),
      ),
    };

    final labelColor = switch (state) {
      _StepState.done => RescueColors.primary,
      _StepState.active => RescueColors.ink,
      _StepState.upcoming => RescueColors.muted,
    };

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        node,
        const SizedBox(height: 6),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: rescueFont(
            11,
            state == _StepState.upcoming ? 600 : 700,
            color: labelColor,
          ),
        ),
      ],
    );
  }
}

class _UpdatesNote extends StatelessWidget {
  const _UpdatesNote();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(
          Icons.notifications_none_rounded,
          size: 16,
          color: RescueColors.primary,
        ),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            'We’ll keep you updated as the rescue progresses.',
            style: rescueFont(12.5, 400, color: RescueColors.muted),
          ),
        ),
      ],
    );
  }
}

class _FoundActionBar extends StatelessWidget {
  const _FoundActionBar({this.onViewActiveRescue, this.onDone});

  final VoidCallback? onViewActiveRescue;
  final VoidCallback? onDone;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: RescueColors.surface,
        border: Border(top: BorderSide(color: RescueColors.border)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
          child: Column(
            children: [
              RescuePrimaryButton(
                label: 'View active rescue',
                onPressed: onViewActiveRescue,
              ),
              const SizedBox(height: 4),
              TextButton(
                onPressed: onDone,
                style: TextButton.styleFrom(
                  foregroundColor: RescueColors.muted,
                ),
                child: Text(
                  'Done',
                  style: rescueFont(13.5, 500, color: RescueColors.muted),
                ),
              ),
              const SizedBox(height: 4),
              const HomeIndicator(),
            ],
          ),
        ),
      ),
    );
  }
}
