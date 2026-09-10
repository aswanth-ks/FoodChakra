import 'package:flutter/material.dart';

import '../../../core/navigation/maps_launcher.dart';
import '../domain/food_listing.dart';
import 'widgets/rescue_widgets.dart';
import 'widgets/stylised_map.dart';

/// "FoodLoop Consumer Active Rescue / Live Tracking Screen".
///
/// Faithful translation of the Stitch design
/// (screen `8a01e8c064ff4d16ad96343f5ad4d6c4`).
///
/// Reached once the rescue confirmation sheet completes. The stage, countdown
/// and route are passed in and default to the design's values, so Phase 5 can
/// drive them from a live rescue stream without touching layout.
///
/// "Start navigation" and "View route" are live: both hand off to the device's
/// maps app through [MapsLauncher].
class ActiveRescueScreen extends StatefulWidget {
  const ActiveRescueScreen({
    super.key,
    required this.listing,
    this.stage = RescueStage.ready,
    this.timeRemaining = const Duration(minutes: 42),
    this.routeSummary = 'Fastest route: 6 mins (1.4 km)',
    this.onBack,
    this.onHelp,
    this.onReportProblem,
    this.onCancelRescue,
    this.onOnTheWay,
    this.onArrived,
    this.onCollected,
    this.handoverCode,
    this.mapsLauncher = const MapsLauncher(),
  });

  final FoodListing listing;
  final RescueStage stage;
  final Duration timeRemaining;
  final String routeSummary;

  final VoidCallback? onBack;
  final VoidCallback? onHelp;
  final VoidCallback? onReportProblem;
  final VoidCallback? onCancelRescue;

  /// Confirms the rescuer has actually set off (`matched -> onTheWay`).
  ///
  /// Deliberately separate from "Start navigation": opening a maps app proves
  /// only that someone looked at a route, not that they are travelling. The
  /// rescue stays `matched` until the rescuer says otherwise.
  final VoidCallback? onOnTheWay;

  /// Tells the backend the rescuer has reached the pickup point
  /// (`onTheWay -> arrived`), which is what issues the handover code.
  final VoidCallback? onArrived;

  /// The one-time handover code, once the backend has issued it.
  ///
  /// Held in memory for this screen only. It is deliberately never stored:
  /// the server returns it exactly once, and a local copy would quietly
  /// undo that guarantee.
  final String? handoverCode;

  /// Advances to Rescue Complete.
  ///
  /// DIVERGENCE FROM THE DESIGN: the Stitch screen has no forward action — it
  /// assumes the stage advances from a live backend as the partner verifies
  /// the handover. Until that service exists (Phase 5) the flow would dead-end
  /// here, so a restrained secondary button stands in for the handover event.
  /// Remove it once the rescue stream drives [stage] to
  /// [RescueStage.collected] on its own.
  final VoidCallback? onCollected;

  /// Injected so tests can assert the hand-off without a platform channel.
  final MapsLauncher mapsLauncher;

  @override
  State<ActiveRescueScreen> createState() => _ActiveRescueScreenState();
}

class _ActiveRescueScreenState extends State<ActiveRescueScreen> {
  /// Guards against a second tap while the maps app is being handed control.
  bool _launching = false;

  Future<void> _startNavigation() => _handOff(directions: true);

  Future<void> _viewRoute() => _handOff(directions: false);

  Future<void> _handOff({required bool directions}) async {
    if (_launching) return;
    setState(() => _launching = true);

    final listing = widget.listing;
    final outcome = directions
        ? await widget.mapsLauncher.openDirections(
            destinationLabel: listing.destinationLabel,
            latitude: listing.latitude,
            longitude: listing.longitude,
          )
        : await widget.mapsLauncher.openPlace(
            label: listing.destinationLabel,
            latitude: listing.latitude,
            longitude: listing.longitude,
          );

    if (!mounted) return;
    setState(() => _launching = false);

    if (outcome != MapsOutcome.opened) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Could not open a maps app for '
            '${listing.pickupLocation}.',
          ),
        ),
      );
    }
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
                _ActiveRescueAppBar(
                  onBack: widget.onBack,
                  onHelp: widget.onHelp,
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                    children: [
                      _StatusHeroCard(
                        listing: listing,
                        timeRemaining: widget.timeRemaining,
                      ),
                      // Directly under the hero: once the code exists it is
                      // the only thing the rescuer needs, and it should not
                      // be something they have to scroll for.
                      if (widget.handoverCode != null) ...[
                        const SizedBox(height: 16),
                        _HandoverCodeCard(code: widget.handoverCode!),
                      ],
                      const SizedBox(height: 16),
                      _LifecycleStepper(stage: widget.stage),
                      const SizedBox(height: 16),
                      _PickupInfoCard(
                        listing: listing,
                        onViewRoute: _launching ? null : _viewRoute,
                      ),
                      const SizedBox(height: 16),
                      _RouteMapCard(
                        destination: listing.pickupLocation,
                        routeSummary: widget.routeSummary,
                        onTap: _launching ? null : _viewRoute,
                      ),
                      const SizedBox(height: 16),
                      const _LiveStatusMessage(
                        message:
                            'Food is ready. Please arrive within the pickup '
                            'window.',
                      ),
                    ],
                  ),
                ),
                _StickyActionBar(
                  launching: _launching,
                  onStartNavigation: _launching ? null : _startNavigation,
                  onReportProblem: widget.onReportProblem,
                  onCancelRescue: widget.onCancelRescue,
                  onOnTheWay: widget.onOnTheWay,
                  onArrived: widget.onArrived,
                  onCollected: widget.onCollected,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ActiveRescueAppBar extends StatelessWidget {
  const _ActiveRescueAppBar({this.onBack, this.onHelp});

  final VoidCallback? onBack;
  final VoidCallback? onHelp;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: RescueColors.border)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          RescueIconButton(
            icon: Icons.arrow_back,
            tooltip: 'Back to home',
            onPressed: onBack,
          ),
          Expanded(
            child: Text(
              'Active rescue',
              textAlign: TextAlign.center,
              style: rescueFont(
                16,
                700,
                color: RescueColors.ink,
                letterSpacing: -0.3,
              ),
            ),
          ),
          RescueIconButton(
            icon: Icons.help_outline_rounded,
            tooltip: 'Help and assistance',
            onPressed: onHelp,
            color: RescueColors.muted,
          ),
        ],
      ),
    );
  }
}

/// Live badge, countdown, headline and the item/partner summary.
class _StatusHeroCard extends StatelessWidget {
  const _StatusHeroCard({required this.listing, required this.timeRemaining});

  final FoodListing listing;
  final Duration timeRemaining;

  @override
  Widget build(BuildContext context) {
    return RescueCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const LiveDot(size: 8),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        'LIVE · RESCUE CONFIRMED',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: rescueFont(
                          12,
                          600,
                          color: RescueColors.primary,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _CountdownPill(remaining: timeRemaining),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            'Ready for pickup',
            style: rescueFont(
              23,
              700,
              color: RescueColors.ink,
              height: 1.15,
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'Arrive by ${listing.pickupDeadline}',
            style: rescueFont(13, 400, color: RescueColors.muted),
          ),
          const RescueDivider(vertical: 14),
          Text(
            listing.title,
            style: rescueFont(17, 700, color: RescueColors.ink),
          ),
          const SizedBox(height: 2),
          Text(
            '${listing.category} · ${listing.preparedNote}',
            style: rescueFont(13, 400, color: RescueColors.muted),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Flexible(
                child: Text.rich(
                  TextSpan(
                    style: rescueFont(12, 400, color: RescueColors.muted),
                    children: [
                      const TextSpan(text: 'Shared by '),
                      TextSpan(
                        text: listing.sharedBy,
                        style: rescueFont(12, 500, color: RescueColors.ink),
                      ),
                    ],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (listing.sharedByVerified) ...[
                const SizedBox(width: 6),
                const Icon(
                  Icons.check_circle_outline_rounded,
                  size: 14,
                  color: RescueColors.primary,
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _CountdownPill extends StatelessWidget {
  const _CountdownPill({required this.remaining});

  final Duration remaining;

  @override
  Widget build(BuildContext context) {
    final label = remaining.inHours >= 1
        ? '${remaining.inHours} hr remaining'
        : '${remaining.inMinutes} min remaining';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: RescueColors.sageSubtle,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: RescueColors.sage),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.schedule_rounded,
            size: 14,
            color: RescueColors.primary,
          ),
          const SizedBox(width: 5),
          Text(label, style: rescueFont(12, 600, color: RescueColors.primary)),
        ],
      ),
    );
  }
}

/// Five-stage horizontal progress track.
class _LifecycleStepper extends StatelessWidget {
  const _LifecycleStepper({required this.stage});

  final RescueStage stage;

  static const _labels = {
    RescueStage.confirmed: 'Confirmed',
    RescueStage.preparing: 'Preparing',
    RescueStage.ready: 'Ready',
    RescueStage.pickup: 'Pickup',
    RescueStage.collected: 'Collected',
  };

  @override
  Widget build(BuildContext context) {
    final stages = RescueStage.values;
    final currentIndex = stages.indexOf(stage);

    return RescueCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'RESCUE LIFECYCLE',
            style: rescueFont(
              12,
              700,
              color: RescueColors.ink,
              letterSpacing: 0.9,
            ),
          ),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, constraints) {
              // Node centres sit at the middle of each equal-width column, so
              // the track spans from the first centre to the current one.
              final column = constraints.maxWidth / stages.length;
              final firstCentre = column / 2;
              final currentCentre = column * currentIndex + column / 2;

              return SizedBox(
                // Same budget as Rescuer Found's track: node + gap + label.
                height: 54,
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
                      width: (currentCentre - firstCentre).clamp(
                        0.0,
                        constraints.maxWidth,
                      ),
                      top: 13,
                      child: Container(height: 2, color: RescueColors.primary),
                    ),
                    Row(
                      children: [
                        for (var i = 0; i < stages.length; i++)
                          Expanded(
                            child: _StepNode(
                              label: _labels[stages[i]]!,
                              index: i,
                              done: i < currentIndex,
                              active: i == currentIndex,
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

class _StepNode extends StatelessWidget {
  const _StepNode({
    required this.label,
    required this.index,
    required this.done,
    required this.active,
  });

  final String label;
  final int index;
  final bool done;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final reached = done || active;

    Widget node = Container(
      width: 28,
      height: 28,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: reached ? RescueColors.primary : RescueColors.card,
        shape: BoxShape.circle,
        border: reached
            ? null
            : Border.all(color: RescueColors.border, width: 2),
        // The active node carries the design's sage focus ring.
        boxShadow: active
            ? const [BoxShadow(color: RescueColors.sage, spreadRadius: 4)]
            : null,
      ),
      child: done
          ? const Icon(Icons.check_rounded, size: 14, color: Colors.white)
          : Text(
              '${index + 1}',
              style: rescueFont(
                active ? 12 : 11,
                active ? 700 : 500,
                color: active ? Colors.white : RescueColors.muted,
              ),
            ),
    );

    if (!reached) node = Opacity(opacity: 0.6, child: node);

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
            active ? 700 : 500,
            color: active
                ? RescueColors.primary
                : (done ? RescueColors.ink : RescueColors.muted),
          ),
        ),
      ],
    );
  }
}

class _PickupInfoCard extends StatelessWidget {
  const _PickupInfoCard({required this.listing, this.onViewRoute});

  final FoodListing listing;
  final VoidCallback? onViewRoute;

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
                icon: Icons.location_on_outlined,
                size: 36,
                iconSize: 19,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'PICKUP LOCATION',
                      style: rescueFont(
                        11,
                        600,
                        color: RescueColors.muted,
                        letterSpacing: 0.7,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      listing.pickupLocation,
                      style: rescueFont(16, 700, color: RescueColors.ink),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      [
                        listing.distanceLabel,
                        if (listing.travelEstimate != null)
                          listing.travelEstimate!,
                      ].join(' · '),
                      style: rescueFont(12, 400, color: RescueColors.muted),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: onViewRoute,
                child: Text(
                  'View route →',
                  style: rescueFont(13, 600, color: RescueColors.primary),
                ),
              ),
            ],
          ),
          const RescueDivider(vertical: 12),
          Row(
            children: [
              const Icon(
                Icons.schedule_rounded,
                size: 16,
                color: RescueColors.primary,
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  listing.pickupWindow,
                  style: rescueFont(12, 500, color: RescueColors.ink),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RouteMapCard extends StatelessWidget {
  const _RouteMapCard({
    required this.destination,
    required this.routeSummary,
    this.onTap,
  });

  final String destination;
  final String routeSummary;

  /// Tapping the map opens it in the device's maps app.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Container(
        height: 240,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: RescueColors.border),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            const RouteMap(),
            Positioned.fill(
              child: Material(
                color: Colors.transparent,
                child: InkWell(onTap: onTap),
              ),
            ),
            Positioned(
              left: 12,
              bottom: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
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
                        color: RescueColors.route,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      routeSummary,
                      style: rescueFont(12, 600, color: RescueColors.ink),
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              right: 12,
              top: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: RescueColors.primary,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  destination,
                  style: rescueFont(
                    11,
                    600,
                    color: Colors.white,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LiveStatusMessage extends StatelessWidget {
  const _LiveStatusMessage({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: RescueColors.sageSubtle,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: RescueColors.sage),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 20,
            height: 20,
            decoration: const BoxDecoration(
              color: RescueColors.primary,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.check_rounded,
              size: 13,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: rescueFont(
                13,
                600,
                color: RescueColors.primary,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StickyActionBar extends StatelessWidget {
  const _StickyActionBar({
    required this.launching,
    this.onStartNavigation,
    this.onReportProblem,
    this.onCancelRescue,
    this.onOnTheWay,
    this.onArrived,
    this.onCollected,
  });

  /// Swaps the CTA for a spinner while the maps app is being opened.
  final bool launching;
  final VoidCallback? onStartNavigation;
  final VoidCallback? onReportProblem;
  final VoidCallback? onCancelRescue;
  final VoidCallback? onOnTheWay;
  final VoidCallback? onArrived;
  final VoidCallback? onCollected;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: RescueColors.surface,
        border: Border(top: BorderSide(color: RescueColors.border)),
        boxShadow: [
          BoxShadow(
            color: Color(0x0A121F17),
            blurRadius: 20,
            offset: Offset(0, -6),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Column(
            children: [
              RescuePrimaryButton(
                label: launching ? 'Opening maps…' : 'Start navigation',
                icon: launching ? null : Icons.navigation_outlined,
                leading: launching
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation(Colors.white),
                        ),
                      )
                    : null,
                height: 56,
                onPressed: onStartNavigation,
              ),
              // Exactly one forward action is offered at a time, decided by
              // the rescue's server-side state: setting off, then arrival,
              // then collection once the owner has confirmed the handover.
              if (onOnTheWay != null) ...[
                const SizedBox(height: 10),
                _SecondaryAction(
                  icon: Icons.directions_walk_rounded,
                  label: "I'm on my way",
                  onPressed: onOnTheWay,
                ),
              ],
              if (onArrived != null) ...[
                const SizedBox(height: 10),
                _SecondaryAction(
                  icon: Icons.place_outlined,
                  label: "I've arrived",
                  onPressed: onArrived,
                ),
              ],
              if (onCollected != null) ...[
                const SizedBox(height: 10),
                _SecondaryAction(
                  icon: Icons.check_circle_outline_rounded,
                  label: 'I have collected this food',
                  onPressed: onCollected,
                ),
              ],
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Both are Flexible so the row cannot overflow on a narrow
                  // handset; at normal widths the labels are unchanged.
                  Flexible(
                    child: TextButton.icon(
                      onPressed: onReportProblem,
                      icon: const Icon(
                        Icons.error_outline_rounded,
                        size: 15,
                        color: RescueColors.muted,
                      ),
                      label: Text(
                        'Something wrong?',
                        overflow: TextOverflow.ellipsis,
                        style: rescueFont(13, 500, color: RescueColors.muted),
                      ),
                      style: TextButton.styleFrom(
                        foregroundColor: RescueColors.muted,
                      ),
                    ),
                  ),
                  Flexible(
                    child: TextButton(
                      onPressed: onCancelRescue,
                      style: TextButton.styleFrom(
                        foregroundColor: RescueColors.muted,
                      ),
                      child: Text(
                        'Cancel rescue',
                        overflow: TextOverflow.ellipsis,
                        style: rescueFont(13, 500, color: RescueColors.muted),
                      ),
                    ),
                  ),
                ],
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

/// A restrained outlined action beneath the primary CTA.
///
/// Every forward step in a rescue — setting off, arriving, confirming
/// collection — uses this one treatment. Deliberately outlined rather than
/// filled so none of them competes with "Start navigation", which the design
/// keeps as the primary action.
class _SecondaryAction extends StatelessWidget {
  const _SecondaryAction({
    required this.icon,
    required this.label,
    this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 50,
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 19, color: RescueColors.primary),
        label: Text(
          label,
          style: rescueFont(
            14.5,
            600,
            color: RescueColors.primary,
            letterSpacing: -0.15,
          ),
        ),
        style: OutlinedButton.styleFrom(
          backgroundColor: RescueColors.card,
          side: const BorderSide(color: RescueColors.sage, width: 1.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }
}

/// The one-time handover code, shown to the rescuer to read out.
///
/// Built from the existing rescue tokens rather than new styling: the same
/// card treatment as [_PickupInfoCard], with the code itself given the weight
/// the design reserves for a primary figure.
class _HandoverCodeCard extends StatelessWidget {
  const _HandoverCodeCard({required this.code});

  final String code;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
      decoration: BoxDecoration(
        color: RescueColors.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: RescueColors.sage, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.lock_outline_rounded,
                size: 17,
                color: RescueColors.primary,
              ),
              const SizedBox(width: 8),
              Text(
                'Your handover code',
                style: rescueFont(
                  13.5,
                  700,
                  color: RescueColors.primary,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            // Grouped 3-3 so it is easy to read aloud.
            '${code.substring(0, 3)} ${code.substring(3)}',
            style: rescueFont(
              34,
              700,
              color: RescueColors.ink,
              letterSpacing: 6,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Read this code out to the person giving the food. They confirm '
            'it on their phone, and then you can collect.',
            style: rescueFont(13, 500, color: RescueColors.muted, height: 1.45),
          ),
        ],
      ),
    );
  }
}
