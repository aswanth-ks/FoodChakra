import 'package:flutter/material.dart';

import '../../../shared/widgets/consumer_nav_bar.dart';
import '../domain/food_listing.dart';
import 'widgets/rescue_widgets.dart';

/// "FoodLoop Consumer Explore Food Screen".
///
/// Faithful translation of the Stitch design
/// (screen `03d1ce15100b42a2bddce7b60f3274df`).
///
/// UI only. Search, the filter chips and the list/map toggle keep their state
/// locally but do not filter the results yet — the query goes to the listings
/// API in Phase 5, at which point [listings] is fed from a repository.
class ExploreScreen extends StatefulWidget {
  const ExploreScreen({
    super.key,
    this.location = 'Karur, Tamil Nadu',
    this.listings = const [],
    this.newOpportunityCount = 3,
    this.selectedFilter,
    this.onSelectFilter,
    this.onChangeLocation,
    this.onFilters,
    this.onOpenListing,
    this.onSelectTab,
  });

  final String location;
  final List<FoodListing> listings;

  /// Drives the "3 new opportunities" counter on the live banner.
  final int newOpportunityCount;

  /// The active chip. Lifted out of the screen so the chosen filter can drive
  /// the actual query — a chip that looks selected while returning unfiltered
  /// results is worse than no filter at all.
  final String? selectedFilter;
  final void Function(String filter)? onSelectFilter;

  final VoidCallback? onChangeLocation;
  final VoidCallback? onFilters;
  final void Function(FoodListing listing)? onOpenListing;
  final void Function(ConsumerTab tab)? onSelectTab;

  /// The design's chip row. "Nearby" is selected on entry.
  static const List<String> filters = [
    'Nearby',
    'Ready now',
    'Expiring soon',
    'Vegetarian',
    'Vegan',
    'Event food',
  ];

  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

enum _ResultView { list, map }

class _ExploreScreenState extends State<ExploreScreen> {
  final _search = TextEditingController();
  String _localFilter = ExploreScreen.filters.first;

  /// The caller owns the filter when it passes one in.
  String get _selectedFilter => widget.selectedFilter ?? _localFilter;
  _ResultView _view = _ResultView.list;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final listings = widget.listings;

    return Scaffold(
      backgroundColor: RescueColors.surface,
      bottomNavigationBar: ConsumerNavBar(
        current: ConsumerTab.explore,
        onSelect: widget.onSelectTab,
      ),
      body: SafeArea(
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 430),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              children: [
                _Header(onFilters: widget.onFilters),
                const SizedBox(height: 14),
                _SearchField(controller: _search),
                const SizedBox(height: 10),
                _LocationRow(
                  location: widget.location,
                  onChange: widget.onChangeLocation,
                ),
                const SizedBox(height: 16),
                _FilterChipRow(
                  filters: ExploreScreen.filters,
                  selected: _selectedFilter,
                  onSelect: (f) {
                    setState(() => _localFilter = f);
                    widget.onSelectFilter?.call(f);
                  },
                ),
                const SizedBox(height: 16),
                _ResultControls(
                  count: listings.length,
                  view: _view,
                  onViewChanged: (v) => setState(() => _view = v),
                ),
                const SizedBox(height: 14),
                _LiveStreamBanner(newCount: widget.newOpportunityCount),
                const SizedBox(height: 12),
                if (_view == _ResultView.list)
                  for (var i = 0; i < listings.length; i++) ...[
                    if (i > 0) const SizedBox(height: 12),
                    ExploreListingCard(
                      listing: listings[i],
                      onTap: () => widget.onOpenListing?.call(listings[i]),
                      onRescue: () => widget.onOpenListing?.call(listings[i]),
                    ),
                  ]
                else
                  const _MapViewPlaceholder(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({this.onFilters});

  final VoidCallback? onFilters;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Explore',
                style: rescueFont(
                  28,
                  700,
                  color: RescueColors.ink,
                  height: 1.15,
                  letterSpacing: -0.6,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Find good food before it goes to waste.',
                style: rescueFont(13.5, 400, color: RescueColors.muted),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        RescueIconButton(
          icon: Icons.filter_list_rounded,
          tooltip: 'Filters',
          onPressed: onFilters,
          color: RescueColors.primary,
          background: RescueColors.card,
        ),
      ],
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 50,
      child: TextField(
        controller: controller,
        style: rescueFont(14, 400, color: RescueColors.ink),
        cursorColor: RescueColors.primary,
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          hintText: 'Search meals, food, or events',
          hintStyle: rescueFont(14, 400, color: const Color(0xFF8C9891)),
          filled: true,
          fillColor: RescueColors.card,
          prefixIcon: const Icon(
            Icons.search_rounded,
            size: 19,
            color: RescueColors.muted,
          ),
          contentPadding: const EdgeInsets.symmetric(vertical: 14),
          border: _border(RescueColors.border),
          enabledBorder: _border(RescueColors.border),
          focusedBorder: _border(RescueColors.primary, width: 1.5),
        ),
      ),
    );
  }

  static OutlineInputBorder _border(Color color, {double width = 1}) =>
      OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: color, width: width),
      );
}

class _LocationRow extends StatelessWidget {
  const _LocationRow({required this.location, this.onChange});

  final String location;
  final VoidCallback? onChange;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.location_on_outlined,
                  size: 14,
                  color: RescueColors.primary,
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    'Near $location',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: rescueFont(
                      12.5,
                      500,
                      color: const Color(0xFF2D3A33),
                    ),
                  ),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: onChange,
            child: Text(
              'Change',
              style: rescueFont(12, 600, color: RescueColors.primary),
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterChipRow extends StatelessWidget {
  const _FilterChipRow({
    required this.filters,
    required this.selected,
    required this.onSelect,
  });

  final List<String> filters;
  final String selected;
  final void Function(String filter) onSelect;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 32,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: filters.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final filter = filters[i];
          final active = filter == selected;
          return GestureDetector(
            onTap: () => onSelect(filter),
            child: Container(
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: active ? RescueColors.primary : RescueColors.card,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: active ? RescueColors.primary : RescueColors.border,
                ),
              ),
              child: Text(
                filter,
                style: rescueFont(
                  12.5,
                  active ? 600 : 500,
                  color: active ? Colors.white : const Color(0xFF2D3A33),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ResultControls extends StatelessWidget {
  const _ResultControls({
    required this.count,
    required this.view,
    required this.onViewChanged,
  });

  final int count;
  final _ResultView view;
  final void Function(_ResultView view) onViewChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$count rescue opportunities',
                style: rescueFont(15.5, 700, color: RescueColors.ink),
              ),
              const SizedBox(height: 2),
              Row(
                children: [
                  // Flexible so a narrow handset ellipsises rather than
                  // overflowing; unchanged at normal widths.
                  Flexible(
                    child: Text(
                      'Sorted by distance',
                      overflow: TextOverflow.ellipsis,
                      style: rescueFont(11.5, 400, color: RescueColors.muted),
                    ),
                  ),
                  const SizedBox(width: 3),
                  const Icon(
                    Icons.keyboard_arrow_down_rounded,
                    size: 13,
                    color: RescueColors.muted,
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        _ViewToggle(view: view, onChanged: onViewChanged),
      ],
    );
  }
}

/// Segmented List / Map control.
class _ViewToggle extends StatelessWidget {
  const _ViewToggle({required this.view, required this.onChanged});

  final _ResultView view;
  final void Function(_ResultView view) onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFF0EDE6),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: RescueColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _segment(
            label: 'List',
            icon: Icons.view_list_rounded,
            active: view == _ResultView.list,
            onTap: () => onChanged(_ResultView.list),
          ),
          _segment(
            label: 'Map',
            icon: Icons.map_outlined,
            active: view == _ResultView.map,
            onTap: () => onChanged(_ResultView.map),
          ),
        ],
      ),
    );
  }

  Widget _segment({
    required String label,
    required IconData icon,
    required bool active,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: active ? RescueColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 13,
              color: active ? Colors.white : RescueColors.muted,
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: rescueFont(
                11.5,
                600,
                color: active ? Colors.white : RescueColors.muted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LiveStreamBanner extends StatelessWidget {
  const _LiveStreamBanner({required this.newCount});

  final int newCount;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: RescueColors.sageSubtle,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFD6E5DC)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            child: Row(
              children: [
                const LiveDot(size: 8),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    'Live nearby stream',
                    overflow: TextOverflow.ellipsis,
                    style: rescueFont(11.5, 500, color: RescueColors.primary),
                  ),
                ),
              ],
            ),
          ),
          Text(
            '$newCount new opportunities',
            overflow: TextOverflow.ellipsis,
            style: rescueFont(11, 600, color: RescueColors.primary),
          ),
        ],
      ),
    );
  }
}

/// Explore's own result row.
///
/// Close to Home's `ListingCard` but genuinely a different composition: a
/// 92px photo, the distance chip in the corner, a readiness line and a ruled
/// footer carrying the urgency chip.
class ExploreListingCard extends StatelessWidget {
  const ExploreListingCard({
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
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: RescueCard(
          radius: 16,
          padding: const EdgeInsets.all(12),
          // The stretch below is what lets the content column fill the row so
          // its footer sits on the bottom edge. That needs a bounded height,
          // which an unbounded ListView does not give -- and a hard 92 (the
          // photo's size) clips the text at larger scales. IntrinsicHeight
          // bounds it to whichever child is tallest instead.
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _Thumbnail(listing: listing),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Text(
                                  listing.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: rescueFont(
                                    15.5,
                                    700,
                                    color: RescueColors.ink,
                                    height: 1.25,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: RescueColors.sageSubtle,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  listing.distanceChipLabel,
                                  style: rescueFont(
                                    11,
                                    600,
                                    color: RescueColors.primary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            listing.exploreSubtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: rescueFont(
                              12,
                              400,
                              color: RescueColors.muted,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            listing.readinessLabel,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: rescueFont(
                              11.5,
                              500,
                              // A scheduled listing is not collectable yet, so
                              // its readiness line stays muted.
                              color: listing.urgency == ListingUrgency.scheduled
                                  ? RescueColors.muted
                                  : const Color(0xFF2D3A33),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.only(top: 6),
                        decoration: const BoxDecoration(
                          border: Border(
                            top: BorderSide(color: Color(0xFFF4F3F0)),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Flexible(child: _UrgencyChip(listing: listing)),
                            const SizedBox(width: 8),
                            _RescueButton(onPressed: onRescue),
                          ],
                        ),
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

class _Thumbnail extends StatelessWidget {
  const _Thumbnail({required this.listing});

  final FoodListing listing;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 92,
      height: 92,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
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
                  size: 26,
                  color: RescueColors.primary,
                ),
              ),
            ),
            if (listing.isLive)
              Positioned(
                top: 6,
                left: 6,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: RescueColors.primary.withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 4,
                        height: 4,
                        decoration: const BoxDecoration(
                          color: Color(0xFF34D399),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'LIVE',
                        style: rescueFont(
                          9.5,
                          700,
                          color: Colors.white,
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

/// Four tiers, each with its own colour: available, expiring, critical and
/// scheduled. Red is reserved for [ListingUrgency.critical] alone.
class _UrgencyChip extends StatelessWidget {
  const _UrgencyChip({required this.listing});

  final FoodListing listing;

  @override
  Widget build(BuildContext context) {
    final (Color bg, Color fg, int weight) = switch (listing.urgency) {
      ListingUrgency.critical => (
        const Color(0xFFFEE2E2),
        const Color(0xFFB91C1C),
        600,
      ),
      ListingUrgency.expiring => (
        const Color(0xFFFEF3C7),
        const Color(0xFFB45309),
        600,
      ),
      ListingUrgency.available => (
        RescueColors.sageSubtle,
        RescueColors.primary,
        500,
      ),
      ListingUrgency.scheduled => (
        const Color(0xFFF4F3F0),
        RescueColors.muted,
        500,
      ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.schedule_rounded, size: 11, color: fg),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              listing.urgencyLabel,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: rescueFont(11, weight, color: fg),
            ),
          ),
        ],
      ),
    );
  }
}

class _RescueButton extends StatelessWidget {
  const _RescueButton({this.onPressed});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 28,
      child: FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: RescueColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        child: Text('Rescue', style: rescueFont(12, 600)),
      ),
    );
  }
}

/// The map half of the segmented control.
///
/// PHASE 8: replaced by the real map, alongside the two stylised maps on Home
/// and Active Rescue. Until then the toggle is honest about what it has.
class _MapViewPlaceholder extends StatelessWidget {
  const _MapViewPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 280,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: RescueColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: RescueColors.border),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.map_outlined, size: 28, color: RescueColors.primary),
          const SizedBox(height: 10),
          Text(
            'Map view is coming soon',
            style: rescueFont(14, 600, color: RescueColors.ink),
          ),
          const SizedBox(height: 4),
          Text(
            'Switch back to List to browse opportunities.',
            textAlign: TextAlign.center,
            style: rescueFont(12.5, 400, color: RescueColors.muted),
          ),
        ],
      ),
    );
  }
}
