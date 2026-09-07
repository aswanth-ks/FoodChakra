import 'package:flutter/material.dart';

import '../../../shared/widgets/consumer_nav_bar.dart';
import '../../rescue/data/sample_listings.dart';
import '../../rescue/domain/food_listing.dart';
import '../../rescue/presentation/widgets/rescue_widgets.dart';
import '../../rescue/presentation/widgets/stylised_map.dart';

/// "FoodLoop Consumer Home Screen".
///
/// Faithful translation of the Stitch design
/// (screen `ec02ee8746be482d8c189b1a0c8f1ae7`).
///
/// UI only. The listings, counts and impact figures come in as parameters and
/// default to the design's fixtures; Phase 5 swaps those defaults for a
/// repository read without touching the layout.
class HomeScreen extends StatelessWidget {
  const HomeScreen({
    super.key,
    this.userName = 'Aswanth',
    this.location = 'Karur, Tamil Nadu',
    this.opportunityCount = 12,
    this.nearestDistanceLabel = 'Nearest: 650m away',
    this.listings = SampleListings.nearby,
    this.mealsRescued = 24,
    this.foodDivertedKg = 8.2,
    this.onChangeLocation,
    this.onNotifications,
    this.onExploreNearby,
    this.onRescueFood,
    this.onGiveFood,
    this.onSeeAll,
    this.onOpenListing,
    this.onViewImpact,
    this.onSelectTab,
  });

  final String userName;
  final String location;
  final int opportunityCount;
  final String nearestDistanceLabel;
  final List<FoodListing> listings;
  final int mealsRescued;
  final double foodDivertedKg;

  final VoidCallback? onChangeLocation;
  final VoidCallback? onNotifications;
  final VoidCallback? onExploreNearby;
  final VoidCallback? onRescueFood;
  final VoidCallback? onGiveFood;
  final VoidCallback? onSeeAll;
  final void Function(FoodListing listing)? onOpenListing;
  final VoidCallback? onViewImpact;
  final void Function(ConsumerTab tab)? onSelectTab;

  /// The design shows "Good morning"; the other two are the obvious
  /// counterparts for the rest of the day.
  static String greetingFor(DateTime now) {
    if (now.hour < 12) return 'Good morning';
    if (now.hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: RescueColors.surface,
      bottomNavigationBar: ConsumerNavBar(
        current: ConsumerTab.home,
        onSelect: onSelectTab,
      ),
      body: SafeArea(
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 430),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _GreetingHeader(
                  greeting: greetingFor(DateTime.now()),
                  userName: userName,
                  location: location,
                  onChangeLocation: onChangeLocation,
                  onNotifications: onNotifications,
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                    children: [
                      _LiveHeroCard(
                        opportunityCount: opportunityCount,
                        nearestDistanceLabel: nearestDistanceLabel,
                        onExploreNearby: onExploreNearby,
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'What would you like to do?',
                        style: rescueFont(
                          17,
                          700,
                          color: RescueColors.ink,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _ActionCard(
                              icon: Icons.inventory_2_outlined,
                              title: 'Rescue food',
                              subtitle: 'Find surplus food nearby',
                              primary: true,
                              onTap: onRescueFood,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: _ActionCard(
                              icon: Icons.volunteer_activism_outlined,
                              title: 'Give food',
                              subtitle: 'Share food from home or events',
                              primary: false,
                              onTap: onGiveFood,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      SectionHeader(
                        title: 'Nearby opportunities',
                        live: true,
                        actionLabel: 'See all',
                        onAction: onSeeAll,
                      ),
                      const SizedBox(height: 12),
                      // Indexed rather than `listing != listings.last`:
                      // identical const listings canonicalise to one instance,
                      // so equality is not a safe position test.
                      for (var i = 0; i < listings.length; i++) ...[
                        if (i > 0) const SizedBox(height: 12),
                        ListingCard(
                          listing: listings[i],
                          onTap: () => onOpenListing?.call(listings[i]),
                          onRescue: () => onOpenListing?.call(listings[i]),
                        ),
                      ],
                      const SizedBox(height: 24),
                      _ImpactPreview(
                        mealsRescued: mealsRescued,
                        foodDivertedKg: foodDivertedKg,
                        onViewImpact: onViewImpact,
                      ),
                    ],
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

class _GreetingHeader extends StatelessWidget {
  const _GreetingHeader({
    required this.greeting,
    required this.userName,
    required this.location,
    this.onChangeLocation,
    this.onNotifications,
  });

  final String greeting;
  final String userName;
  final String location;
  final VoidCallback? onChangeLocation;
  final VoidCallback? onNotifications;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$greeting, $userName 👋',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: rescueFont(
                    20,
                    700,
                    color: RescueColors.ink,
                    letterSpacing: -0.4,
                  ),
                ),
                const SizedBox(height: 2),
                InkWell(
                  onTap: onChangeLocation,
                  borderRadius: BorderRadius.circular(6),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.location_on_outlined,
                          size: 14,
                          color: RescueColors.primary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          location,
                          style: rescueFont(
                            13,
                            500,
                            color: RescueColors.ink,
                          ),
                        ),
                        const SizedBox(width: 2),
                        const Icon(
                          Icons.keyboard_arrow_down_rounded,
                          size: 15,
                          color: RescueColors.muted,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          RescueIconButton(
            icon: Icons.notifications_none_rounded,
            tooltip: 'Notifications',
            onPressed: onNotifications,
            background: RescueColors.card,
            showBadge: true,
            size: 44,
          ),
        ],
      ),
    );
  }
}

/// The real-time hero: live badge, opportunity count and the map preview.
class _LiveHeroCard extends StatelessWidget {
  const _LiveHeroCard({
    required this.opportunityCount,
    required this.nearestDistanceLabel,
    this.onExploreNearby,
  });

  final int opportunityCount;
  final String nearestDistanceLabel;
  final VoidCallback? onExploreNearby;

  @override
  Widget build(BuildContext context) {
    return RescueCard(
      radius: 22,
      elevated: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const LivePill(label: 'Live'),
              const SizedBox(width: 8),
              Text(
                'Within 5 km',
                style: rescueFont(12, 500, color: RescueColors.muted),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Food waiting nearby',
            style: rescueFont(
              18,
              700,
              color: RescueColors.ink,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 2),
          Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: '$opportunityCount rescue opportunities',
                  style: rescueFont(13.5, 700, color: RescueColors.primary),
                ),
                TextSpan(
                  text: ' available now',
                  style: rescueFont(13.5, 500, color: RescueColors.muted),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Container(
              height: 126,
              decoration: BoxDecoration(
                border: Border.all(color: RescueColors.border),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  const NearbyMap(),
                  Positioned(
                    left: 10,
                    bottom: 10,
                    child: _MapBadge(label: nearestDistanceLabel),
                  ),
                  Positioned(
                    right: 10,
                    bottom: 10,
                    child: _ExploreButton(onPressed: onExploreNearby),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MapBadge extends StatelessWidget {
  const _MapBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: RescueColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: const BoxDecoration(
              color: RescueColors.live,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(label, style: rescueFont(11, 600, color: RescueColors.ink)),
        ],
      ),
    );
  }
}

class _ExploreButton extends StatelessWidget {
  const _ExploreButton({this.onPressed});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: RescueColors.primary,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Explore nearby',
                style: rescueFont(12, 600, color: Colors.white),
              ),
              const SizedBox(width: 4),
              const Icon(Icons.arrow_forward, size: 13, color: Colors.white),
            ],
          ),
        ),
      ),
    );
  }
}

/// One of the two "What would you like to do?" tiles.
class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.primary,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  /// The filled forest-green variant. The other is the white outlined one.
  final bool primary;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final fg = primary ? Colors.white : RescueColors.ink;
    final subFg = primary
        ? Colors.white.withValues(alpha: 0.8)
        : RescueColors.muted;

    return Material(
      color: primary ? RescueColors.primary : RescueColors.card,
      borderRadius: BorderRadius.circular(20),
      elevation: 0,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          height: 152,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: primary ? Colors.transparent : RescueColors.border,
            ),
            boxShadow: [
              primary
                  ? const BoxShadow(
                      color: Color(0x2E183B2B),
                      blurRadius: 16,
                      offset: Offset(0, 4),
                    )
                  : const BoxShadow(
                      color: Color(0x08000000),
                      blurRadius: 10,
                      offset: Offset(0, 2),
                    ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconTile(
                    icon: icon,
                    background: primary
                        ? Colors.white.withValues(alpha: 0.15)
                        : RescueColors.sageSubtle,
                    foreground: primary ? Colors.white : RescueColors.primary,
                  ),
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: primary
                          ? Colors.white.withValues(alpha: 0.1)
                          : RescueColors.surface,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.arrow_forward,
                      size: 13,
                      color: primary ? Colors.white : RescueColors.muted,
                    ),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: rescueFont(
                      16,
                      700,
                      color: fg,
                      height: 1.15,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: rescueFont(12, 400, color: subFg, height: 1.3),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Horizontal listing row: photo, title, meta and the timing/action line.
///
/// Lives here rather than in `rescue_widgets.dart` because it is the Home
/// screen's own composition — Explore (Phase 5) will reuse it.
class ListingCard extends StatelessWidget {
  const ListingCard({
    super.key,
    required this.listing,
    this.onTap,
    this.onRescue,
  });

  final FoodListing listing;
  final VoidCallback? onTap;
  final VoidCallback? onRescue;

  @override
  Widget build(BuildContext context) {
    final expiring = listing.urgency == ListingUrgency.expiring;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: RescueCard(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _ListingThumbnail(listing: listing),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      listing.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: rescueFont(
                        15.5,
                        700,
                        color: RescueColors.ink,
                        height: 1.15,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      listing.subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: rescueFont(12, 500, color: RescueColors.muted),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(
                          child: expiring
                              ? RescueChip(
                                  label:
                                      listing.remainingLabel ?? 'Expiring soon',
                                  icon: Icons.schedule_rounded,
                                  background: RescueColors.amberBg,
                                  foreground: RescueColors.amber,
                                  borderColor: RescueColors.amberBorder,
                                  fontSize: 11,
                                )
                              : Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.schedule_rounded,
                                      size: 14,
                                      color: RescueColors.muted,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      'Ready for pickup',
                                      style: rescueFont(
                                        11.5,
                                        500,
                                        color: RescueColors.muted,
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                        const SizedBox(width: 8),
                        RescueMiniButton(label: 'Rescue', onPressed: onRescue),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ListingThumbnail extends StatelessWidget {
  const _ListingThumbnail({required this.listing});

  final FoodListing listing;

  @override
  Widget build(BuildContext context) {
    final expiring = listing.urgency == ListingUrgency.expiring;

    return SizedBox(
      width: 88,
      height: 88,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(15),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(
              listing.imageAsset,
              fit: BoxFit.cover,
              // The bundled fixtures always resolve; a listing photo fetched
              // over the network in Phase 5 may not.
              errorBuilder: (_, _, _) => const ColoredBox(
                color: RescueColors.sageSubtle,
                child: Icon(
                  Icons.restaurant_rounded,
                  size: 24,
                  color: RescueColors.primary,
                ),
              ),
            ),
            Positioned(
              top: 6,
              left: 6,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 6,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: expiring
                      ? RescueColors.amber.withValues(alpha: 0.95)
                      : RescueColors.primary.withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (expiring) ...[
                      const LiveDot(size: 4, color: Colors.white),
                      const SizedBox(width: 3),
                    ],
                    Text(
                      expiring ? 'Expiring' : 'Available',
                      style: rescueFont(9.5, 700, color: Colors.white),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ImpactPreview extends StatelessWidget {
  const _ImpactPreview({
    required this.mealsRescued,
    required this.foodDivertedKg,
    this.onViewImpact,
  });

  final int mealsRescued;
  final double foodDivertedKg;
  final VoidCallback? onViewImpact;

  @override
  Widget build(BuildContext context) {
    return RescueCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.eco_outlined,
                    size: 16,
                    color: RescueColors.primary,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Your impact',
                    style: rescueFont(
                      15,
                      700,
                      color: RescueColors.ink,
                      letterSpacing: -0.2,
                    ),
                  ),
                ],
              ),
              GestureDetector(
                onTap: onViewImpact,
                child: Row(
                  children: [
                    Text(
                      'View impact',
                      style: rescueFont(
                        12.5,
                        600,
                        color: RescueColors.primary,
                      ),
                    ),
                    const SizedBox(width: 2),
                    const Icon(
                      Icons.arrow_forward,
                      size: 13,
                      color: RescueColors.primary,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _Metric(
                  value: '$mealsRescued',
                  label: 'meals rescued',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _Metric(
                  value: '$foodDivertedKg kg',
                  label: 'food diverted',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: RescueColors.sageSubtle.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: RescueColors.sage.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: rescueFont(
              18,
              700,
              color: RescueColors.primary,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 2),
          Text(label, style: rescueFont(11.5, 500, color: RescueColors.muted)),
        ],
      ),
    );
  }
}
