import 'package:flutter/material.dart';

import '../domain/food_listing.dart';
import 'widgets/rescue_widgets.dart';

/// "FoodLoop Consumer Rescue Complete".
///
/// Faithful translation of the Stitch design
/// (screen `41bd3493561546c4af16f9bf8ccdc75e`).
///
/// The end of the rescue flow: Active Rescue hands over here once the food has
/// been collected. UI only — the impact figures are derived from the listing
/// and nothing is persisted until the Phase 5 rescue service exists.
class RescueCompleteScreen extends StatelessWidget {
  const RescueCompleteScreen({
    super.key,
    required this.listing,
    this.collectedAtLabel = 'Today · 8:05 PM',
    this.onBack,
    this.onBackToHome,
    this.onViewImpact,
  });

  final FoodListing listing;

  /// "Today · 8:05 PM".
  final String collectedAtLabel;

  final VoidCallback? onBack;
  final VoidCallback? onBackToHome;
  final VoidCallback? onViewImpact;

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
                _CompleteAppBar(onBack: onBack),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                    children: [
                      const _SuccessHero(),
                      const SizedBox(height: 16),
                      _SummaryCard(
                        listing: listing,
                        collectedAtLabel: collectedAtLabel,
                      ),
                      const SizedBox(height: 16),
                      _ImpactCard(listing: listing),
                      const SizedBox(height: 16),
                      Text(
                        'Small actions help keep good food in circulation.',
                        textAlign: TextAlign.center,
                        style: rescueFont(
                          13,
                          400,
                          color: RescueColors.muted,
                          height: 1.55,
                        ),
                      ),
                    ],
                  ),
                ),
                _CompleteActionBar(
                  onBackToHome: onBackToHome,
                  onViewImpact: onViewImpact,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CompleteAppBar extends StatelessWidget {
  const _CompleteAppBar({this.onBack});

  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          children: [
            RescueIconButton(
              icon: Icons.arrow_back_ios_new_rounded,
              tooltip: 'Go back',
              onPressed: onBack,
            ),
            Expanded(
              child: Text(
                'Rescue complete',
                textAlign: TextAlign.center,
                style: rescueFont(
                  16,
                  600,
                  color: RescueColors.ink,
                  letterSpacing: -0.3,
                ),
              ),
            ),
            // Balances the back button so the title stays centred.
            const SizedBox(width: 40),
          ],
        ),
      ),
    );
  }
}

/// Badge, headline and the "food handed over" pill, with the design's
/// staggered entrance.
class _SuccessHero extends StatefulWidget {
  const _SuccessHero();

  @override
  State<_SuccessHero> createState() => _SuccessHeroState();
}

class _SuccessHeroState extends State<_SuccessHero>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 650),
  )..forward();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // The badge pops first, the copy fades up behind it.
    final pop = CurvedAnimation(
      parent: _c,
      curve: const Interval(0, 0.58, curve: Curves.easeOutBack),
    );
    final reveal = CurvedAnimation(
      parent: _c,
      curve: const Interval(0.25, 1, curve: Curves.easeOut),
    );

    return Column(
      children: [
        ScaleTransition(
          scale: Tween(begin: 0.85, end: 1.0).animate(pop),
          child: FadeTransition(
            opacity: pop,
            child: Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: RescueColors.primary,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: RescueColors.primary.withValues(alpha: 0.15),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Icon(
                Icons.check_rounded,
                size: 32,
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
                Text(
                  'Rescue complete',
                  textAlign: TextAlign.center,
                  style: rescueFont(
                    27,
                    700,
                    color: RescueColors.ink,
                    height: 1.15,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 4),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 280),
                  child: Text(
                    'Good food found a new destination.',
                    textAlign: TextAlign.center,
                    style: rescueFont(14, 400, color: RescueColors.muted),
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: RescueColors.sageSubtle,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: RescueColors.sage),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: RescueColors.primary,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'FOOD HANDED OVER',
                        style: rescueFont(
                          11.5,
                          500,
                          color: RescueColors.primary,
                          letterSpacing: 0.6,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.listing, required this.collectedAtLabel});

  final FoodListing listing;
  final String collectedAtLabel;

  @override
  Widget build(BuildContext context) {
    return RescueCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const IconTile(
                icon: Icons.inventory_2_outlined,
                background: Color(0xFFF4F3F0),
                borderColor: Color(0xFFE7E5E1),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      listing.title,
                      style: rescueFont(
                        18,
                        700,
                        color: RescueColors.ink,
                        height: 1.15,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Successfully rescued',
                      style: rescueFont(
                        12.5,
                        500,
                        color: RescueColors.primary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              RescueChip(
                label: listing.category.toUpperCase(),
                background: const Color(0xFFF4F3F0),
                foreground: RescueColors.muted,
                borderColor: const Color(0xFFE3E1DC),
              ),
            ],
          ),
          const RescueDivider(vertical: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: _MetaItem(
                  icon: Icons.location_on_outlined,
                  label: listing.pickupLocation,
                ),
              ),
              const SizedBox(width: 12),
              Flexible(
                child: _MetaItem(
                  icon: Icons.schedule_rounded,
                  label: collectedAtLabel,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MetaItem extends StatelessWidget {
  const _MetaItem({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: const Color(0xFF7A887E)),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: rescueFont(13, 400, color: RescueColors.muted),
          ),
        ),
      ],
    );
  }
}

class _ImpactCard extends StatelessWidget {
  const _ImpactCard({required this.listing});

  final FoodListing listing;

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
                'Your impact',
                style: rescueFont(
                  15,
                  700,
                  color: RescueColors.ink,
                  letterSpacing: -0.2,
                ),
              ),
              Text(
                'Logged to your profile',
                style: rescueFont(11.5, 500, color: const Color(0xFF7A887E)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _ServingsRing(servings: listing.servings),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  children: [
                    _MetricTile(
                      label: 'Food rescued',
                      value: listing.title,
                    ),
                    const SizedBox(height: 8),
                    _MetricTile(
                      label: 'Estimated reach',
                      value: 'Approx. ${listing.servings} servings',
                    ),
                  ],
                ),
              ),
            ],
          ),
          const RescueDivider(vertical: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
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
                    Flexible(
                      child: Text(
                        'Recorded in community tally',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: rescueFont(
                          12.5,
                          400,
                          color: RescueColors.muted,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Verified ✓',
                style: rescueFont(12.5, 500, color: RescueColors.primary),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// The 80px ring framing the rescued count.
class _ServingsRing extends StatelessWidget {
  const _ServingsRing({required this.servings});

  final int servings;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 80,
      height: 80,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: 72,
            height: 72,
            child: CircularProgressIndicator(
              // The design's dash offset leaves roughly 81% of the ring
              // filled. It is a decorative framing device, not a percentage.
              value: 0.81,
              strokeWidth: 5,
              strokeCap: StrokeCap.round,
              backgroundColor: RescueColors.sageSubtle,
              valueColor: const AlwaysStoppedAnimation(RescueColors.primary),
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$servings',
                style: rescueFont(
                  23,
                  800,
                  color: RescueColors.primary,
                  height: 1,
                  letterSpacing: -0.4,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'BOXES',
                style: rescueFont(
                  9.5,
                  600,
                  color: RescueColors.muted,
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: RescueColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFF0EEE9)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: rescueFont(
              11,
              500,
              color: const Color(0xFF7A887E),
              letterSpacing: 0.7,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: rescueFont(15, 700, color: RescueColors.ink, height: 1.15),
          ),
        ],
      ),
    );
  }
}

class _CompleteActionBar extends StatelessWidget {
  const _CompleteActionBar({this.onBackToHome, this.onViewImpact});

  final VoidCallback? onBackToHome;
  final VoidCallback? onViewImpact;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: RescueColors.surface,
        border: Border(top: BorderSide(color: Color(0xFFF0EEE9))),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
          child: Column(
            children: [
              RescuePrimaryButton(
                label: 'Back to home',
                onPressed: onBackToHome,
              ),
              const SizedBox(height: 4),
              TextButton(
                onPressed: onViewImpact,
                style: TextButton.styleFrom(
                  foregroundColor: RescueColors.primary,
                ),
                child: Text(
                  'View my impact',
                  style: rescueFont(13.5, 600, color: RescueColors.primary),
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
