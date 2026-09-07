import 'package:flutter/material.dart';

import '../domain/food_listing.dart';
import 'widgets/rescue_widgets.dart';

/// "FoodLoop Consumer Food Details / Rescue Details Screen".
///
/// Faithful translation of the Stitch design
/// (screen `87586e9ef13d4197977c3d229a7a4b91`).
///
/// UI only. Bookmarking is local state and [onRescue] opens the confirmation
/// sheet; nothing is reserved until the Phase 5 rescue service exists.
class FoodDetailsScreen extends StatefulWidget {
  const FoodDetailsScreen({
    super.key,
    required this.listing,
    this.onBack,
    this.onRescue,
    this.onViewOnMap,
  });

  final FoodListing listing;
  final VoidCallback? onBack;

  /// Opens the rescue confirmation sheet.
  final VoidCallback? onRescue;

  final VoidCallback? onViewOnMap;

  @override
  State<FoodDetailsScreen> createState() => _FoodDetailsScreenState();
}

class _FoodDetailsScreenState extends State<FoodDetailsScreen> {
  bool _bookmarked = false;

  void _toggleBookmark() {
    setState(() => _bookmarked = !_bookmarked);
    _toast(
      _bookmarked ? 'Saved to your food rescues' : 'Removed from rescues',
      _bookmarked ? Icons.bookmark_added_outlined : Icons.bookmark_remove_outlined,
    );
  }

  void _viewOnMap() {
    widget.onViewOnMap?.call();
    _toast(
      'Directions to ${widget.listing.pickupLocation} opened',
      Icons.near_me_outlined,
    );
  }

  /// The design's floating pill toast, as a styled SnackBar.
  void _toast(String message, IconData icon) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFF2F312F),
        duration: const Duration(milliseconds: 2400),
        elevation: 6,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(999),
        ),
        margin: const EdgeInsets.fromLTRB(24, 0, 24, 96),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        content: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: RescueColors.sage),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                message,
                style: rescueFont(13, 500, color: const Color(0xFFF2F1EE)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final listing = widget.listing;

    return Scaffold(
      backgroundColor: RescueColors.surface,
      body: SafeArea(
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 430),
            child: Column(
              children: [
                _DetailsAppBar(
                  bookmarked: _bookmarked,
                  onBack: widget.onBack,
                  onToggleBookmark: _toggleBookmark,
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                    children: [
                      _HeroImage(listing: listing),
                      const SizedBox(height: 16),
                      _AvailabilityRow(listing: listing),
                      const SizedBox(height: 10),
                      Text(
                        listing.title,
                        style: rescueFont(
                          26,
                          700,
                          color: RescueColors.ink,
                          height: 32 / 26,
                          letterSpacing: -0.02 * 26,
                        ),
                      ),
                      const SizedBox(height: 6),
                      _MetaLine(listing: listing),
                      const SizedBox(height: 20),
                      _CollectionDetailsCard(
                        listing: listing,
                        onViewOnMap: _viewOnMap,
                      ),
                      const SizedBox(height: 16),
                      _AboutCard(listing: listing),
                      const SizedBox(height: 16),
                      _SharedByCard(listing: listing),
                    ],
                  ),
                ),
                _StickyRescueBar(onRescue: widget.onRescue),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DetailsAppBar extends StatelessWidget {
  const _DetailsAppBar({
    required this.bookmarked,
    this.onBack,
    this.onToggleBookmark,
  });

  final bool bookmarked;
  final VoidCallback? onBack;
  final VoidCallback? onToggleBookmark;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          children: [
            RescueIconButton(
              icon: Icons.arrow_back,
              tooltip: 'Go back',
              onPressed: onBack,
            ),
            Expanded(
              child: Text(
                'Food details',
                textAlign: TextAlign.center,
                style: rescueFont(
                  17,
                  600,
                  color: RescueColors.ink,
                  letterSpacing: -0.17,
                ),
              ),
            ),
            RescueIconButton(
              icon: bookmarked
                  ? Icons.bookmark_rounded
                  : Icons.bookmark_border_rounded,
              tooltip: bookmarked ? 'Remove bookmark' : 'Save to bookmarks',
              onPressed: onToggleBookmark,
              color: bookmarked ? RescueColors.primary : RescueColors.ink,
            ),
          ],
        ),
      ),
    );
  }
}

class _HeroImage extends StatelessWidget {
  const _HeroImage({required this.listing});

  final FoodListing listing;

  @override
  Widget build(BuildContext context) {
    final remaining = listing.remainingLabel;

    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: SizedBox(
        height: 250,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(
              listing.imageAsset,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => const ColoredBox(
                color: RescueColors.sageSubtle,
                child: Icon(
                  Icons.restaurant_rounded,
                  size: 48,
                  color: RescueColors.primary,
                ),
              ),
            ),
            if (remaining != null)
              Positioned(
                left: 12,
                bottom: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: RescueColors.surface.withValues(alpha: 0.95),
                    borderRadius: BorderRadius.circular(999),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x1A183B2B),
                        blurRadius: 6,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const LiveDot(size: 7, color: Color(0xFFC26700)),
                      const SizedBox(width: 6),
                      Text(
                        'Expiring in ${remaining.replaceAll(' remaining', '')}'
                            .toUpperCase(),
                        style: rescueFont(
                          11,
                          700,
                          color: const Color(0xFF8A4B00),
                          letterSpacing: 0.6,
                        ),
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

class _AvailabilityRow extends StatelessWidget {
  const _AvailabilityRow({required this.listing});

  final FoodListing listing;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        LivePill(
          label: 'Live availability',
          background: RescueColors.sage.withValues(alpha: 0.5),
          foreground: const Color(0xFF316E52),
          dotColor: RescueColors.live,
          uppercase: true,
        ),
        Text(
          'Available now',
          style: rescueFont(
            12,
            600,
            color: const Color(0xFF2C694E),
            letterSpacing: 0.48,
          ),
        ),
      ],
    );
  }
}

class _MetaLine extends StatelessWidget {
  const _MetaLine({required this.listing});

  final FoodListing listing;

  @override
  Widget build(BuildContext context) {
    const dot = TextSpan(
      text: '  •  ',
      style: TextStyle(color: RescueColors.border),
    );
    return Text.rich(
      TextSpan(
        style: rescueFont(14, 400, color: RescueColors.muted, height: 20 / 14),
        children: [
          TextSpan(text: listing.category),
          dot,
          TextSpan(text: listing.preparedNote),
          dot,
          TextSpan(
            text: 'Approx. ${listing.servings} servings',
            style: rescueFont(14, 500, color: RescueColors.primary),
          ),
        ],
      ),
    );
  }
}

class _CollectionDetailsCard extends StatelessWidget {
  const _CollectionDetailsCard({required this.listing, this.onViewOnMap});

  final FoodListing listing;
  final VoidCallback? onViewOnMap;

  @override
  Widget build(BuildContext context) {
    return RescueCard(
      radius: 18,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Collection details',
            style: rescueFont(16, 600, color: RescueColors.ink),
          ),
          const RescueDivider(),
          DetailRow(
            icon: Icons.schedule_rounded,
            label: 'Pickup window',
            value: listing.pickupWindow,
            caption: 'Must be collected within this window',
            tileBackground: RescueColors.surface,
          ),
          const RescueDivider(),
          DetailRow(
            icon: Icons.location_on_outlined,
            label: 'Pickup location',
            value: '${listing.pickupLocation} · ${listing.distanceLabel}',
            actionLabel: 'View on map →',
            onAction: onViewOnMap,
            tileBackground: RescueColors.surface,
          ),
        ],
      ),
    );
  }
}

class _AboutCard extends StatelessWidget {
  const _AboutCard({required this.listing});

  final FoodListing listing;

  @override
  Widget build(BuildContext context) {
    return RescueCard(
      radius: 18,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'About this food',
            style: rescueFont(
              17,
              600,
              color: RescueColors.ink,
              letterSpacing: -0.17,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            listing.description,
            style: rescueFont(
              14,
              400,
              color: RescueColors.muted,
              height: 1.6,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final tag in listing.tags)
                RescueChip(
                  label: tag,
                  background: RescueColors.surface,
                  foreground: RescueColors.muted,
                  borderColor: RescueColors.border,
                  fontWeight: 500,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SharedByCard extends StatelessWidget {
  const _SharedByCard({required this.listing});

  final FoodListing listing;

  /// "Community Event Organizer" -> "CE".
  static String initialsOf(String name) {
    final words = name.trim().split(RegExp(r'\s+'));
    if (words.isEmpty || words.first.isEmpty) return '?';
    if (words.length == 1) return words.first.characters.first.toUpperCase();
    return (words[0].characters.first + words[1].characters.first)
        .toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return RescueCard(
      radius: 18,
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: Color(0xFFAEEECB),
              shape: BoxShape.circle,
            ),
            child: Text(
              initialsOf(listing.sharedBy),
              style: rescueFont(15, 600, color: const Color(0xFF316E52)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'SHARED BY',
                  style: rescueFont(
                    11,
                    700,
                    color: RescueColors.muted,
                    letterSpacing: 0.9,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  listing.sharedBy,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: rescueFont(14, 500, color: RescueColors.ink),
                ),
                if (listing.sharedByVerified) ...[
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      const Icon(
                        Icons.verified_rounded,
                        size: 14,
                        color: Color(0xFF2C694E),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Verified community partner',
                        style: rescueFont(
                          12,
                          500,
                          color: const Color(0xFF2C694E),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StickyRescueBar extends StatelessWidget {
  const _StickyRescueBar({this.onRescue});

  final VoidCallback? onRescue;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: RescueColors.surface.withValues(alpha: 0.95),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0F183B2B),
            blurRadius: 24,
            offset: Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
          child: RescuePrimaryButton(
            label: 'Rescue this food',
            icon: Icons.shopping_bag_outlined,
            onPressed: onRescue,
          ),
        ),
      ),
    );
  }
}
