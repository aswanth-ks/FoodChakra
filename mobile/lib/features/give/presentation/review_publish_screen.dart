import 'package:flutter/material.dart';

import '../../rescue/presentation/widgets/rescue_widgets.dart';
import '../domain/surplus_draft.dart';
import 'widgets/give_widgets.dart';

/// "FoodLoop Consumer Review & Publish Screen" — step 3 of 3.
///
/// Faithful translation of the Stitch design
/// (screen `807b6f65ad7c4528a68c2ca235f4ff36`).
///
/// The last step of the give flow: everything entered so far, read back for
/// confirmation. Publishing is simulated until the Phase 5 listings API
/// exists; the button walks through the design's three states first.
class ReviewPublishScreen extends StatefulWidget {
  const ReviewPublishScreen({
    super.key,
    required this.draft,
    this.onBack,
    this.onEditFood,
    this.onEditPickup,
    this.onPublished,
  });

  final SurplusDraft draft;
  final VoidCallback? onBack;
  final VoidCallback? onEditFood;
  final VoidCallback? onEditPickup;

  /// Fired once the publish animation completes.
  final void Function(SurplusDraft draft)? onPublished;

  @override
  State<ReviewPublishScreen> createState() => _ReviewPublishScreenState();
}

enum _PublishState { idle, publishing, live }

class _ReviewPublishScreenState extends State<ReviewPublishScreen> {
  _PublishState _state = _PublishState.idle;

  Future<void> _publish() async {
    if (_state != _PublishState.idle) return;
    setState(() => _state = _PublishState.publishing);

    // PHASE 5: POST the draft. The delay stands in so the design's three
    // button states are all reachable.
    await Future<void>.delayed(const Duration(milliseconds: 1200));
    if (!mounted) return;

    setState(() => _state = _PublishState.live);
    await Future<void>.delayed(const Duration(milliseconds: 800));
    if (!mounted) return;

    widget.onPublished?.call(widget.draft);
  }

  @override
  Widget build(BuildContext context) {
    final draft = widget.draft;
    final publishing = _state == _PublishState.publishing;
    final live = _state == _PublishState.live;

    return Scaffold(
      backgroundColor: RescueColors.surface,
      body: SafeArea(
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 430),
            child: Column(
              children: [
                GiveStepAppBar(
                  title: 'Review & publish',
                  stepLabel: '3 of 3',
                  onBack: widget.onBack,
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
                    children: [
                      Text(
                        'Ready to share?',
                        style: rescueFont(
                          27,
                          800,
                          color: RescueColors.ink,
                          height: 1.2,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Review your details before making this surplus '
                        'available to rescuers nearby.',
                        style: rescueFont(
                          14,
                          400,
                          color: RescueColors.muted,
                          height: 1.55,
                        ),
                      ),
                      const SizedBox(height: 20),
                      _FoodSummaryCard(draft: draft, onEdit: widget.onEditFood),
                      const SizedBox(height: 16),
                      _PickupSummaryCard(
                        draft: draft,
                        onEdit: widget.onEditPickup,
                      ),
                      const SizedBox(height: 16),
                      _ConditionCard(onEdit: widget.onEditFood),
                      const SizedBox(height: 16),
                      const _GoLivePanel(),
                    ],
                  ),
                ),
                GiveActionBar(
                  label: switch (_state) {
                    _PublishState.idle => 'Publish surplus food',
                    _PublishState.publishing => 'Publishing surplus…',
                    _PublishState.live => 'Surplus is live ✓',
                  },
                  height: 56,
                  leading: publishing
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation(Colors.white),
                          ),
                        )
                      : null,
                  onPressed: (publishing || live) ? null : _publish,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Card header: dot, uppercase caption and an Edit action.
class _SummaryHeader extends StatelessWidget {
  const _SummaryHeader({required this.title, this.onEdit});

  final String title;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Flexible(
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
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  title.toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: rescueFont(
                    13,
                    700,
                    color: RescueColors.muted,
                    letterSpacing: 0.9,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (onEdit != null)
          GestureDetector(
            onTap: onEdit,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              child: Text(
                'Edit',
                style: rescueFont(13, 600, color: RescueColors.primary),
              ),
            ),
          ),
      ],
    );
  }
}

class _FoodSummaryCard extends StatelessWidget {
  const _FoodSummaryCard({required this.draft, this.onEdit});

  final SurplusDraft draft;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    return RescueCard(
      radius: 20,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SummaryHeader(title: 'Your surplus food', onEdit: onEdit),
          const RescueDivider(vertical: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _PhotoThumbnail(photoPath: draft.photoPath),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      draft.quantitySummary,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: rescueFont(17, 700, color: RescueColors.ink),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      draft.foodSummary,
                      style: rescueFont(
                        13,
                        500,
                        color: const Color(0xFF2D503D),
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      draft.servingsSummary,
                      style: rescueFont(12, 400, color: RescueColors.muted),
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

/// The attached photo, or a neutral placeholder while none is set.
class _PhotoThumbnail extends StatelessWidget {
  const _PhotoThumbnail({this.photoPath});

  final String? photoPath;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 80,
      height: 80,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFFEEF3EF),
            border: Border.all(color: const Color(0xFFDCE6DF)),
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Center(
            child: Icon(
              Icons.photo_camera_outlined,
              size: 24,
              color: RescueColors.primary,
            ),
          ),
        ),
      ),
    );
  }
}

class _PickupSummaryCard extends StatelessWidget {
  const _PickupSummaryCard({required this.draft, this.onEdit});

  final SurplusDraft draft;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    return RescueCard(
      radius: 20,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SummaryHeader(title: 'Pickup schedule & location', onEdit: onEdit),
          const RescueDivider(vertical: 12),
          _SummaryRow(
            icon: Icons.schedule_rounded,
            caption: 'Pickup window',
            value: draft.pickupWindowSummary,
          ),
          const SizedBox(height: 14),
          _SummaryRow(
            icon: Icons.location_on_outlined,
            caption: 'Pickup point',
            value: draft.pickupLocation,
            trailingValue: ' · ${draft.pickupDistanceLabel}',
          ),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.icon,
    required this.caption,
    required this.value,
    this.trailingValue,
  });

  final IconData icon;
  final String caption;
  final String value;

  /// Appended in a lighter weight, e.g. the distance after a place name.
  final String? trailingValue;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F2),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE0EBE3)),
          ),
          child: Icon(icon, size: 18, color: RescueColors.primary),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                caption.toUpperCase(),
                style: rescueFont(
                  11,
                  600,
                  color: const Color(0xFF6F7E75),
                  letterSpacing: 0.6,
                ),
              ),
              const SizedBox(height: 2),
              Text.rich(
                TextSpan(
                  text: value,
                  style: rescueFont(15, 700, color: RescueColors.ink),
                  children: [
                    if (trailingValue != null)
                      TextSpan(
                        text: trailingValue,
                        style: rescueFont(13, 400, color: RescueColors.muted),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ConditionCard extends StatelessWidget {
  const _ConditionCard({this.onEdit});

  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    return RescueCard(
      radius: 20,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: const BoxDecoration(
              color: RescueColors.primary,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.check_rounded,
              size: 18,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Safe and suitable to share',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: rescueFont(14, 700, color: RescueColors.ink),
                ),
                const SizedBox(height: 2),
                Text(
                  'Stored and handled safely',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: rescueFont(12, 400, color: RescueColors.muted),
                ),
              ],
            ),
          ),
          if (onEdit != null) ...[
            const SizedBox(width: 8),
            GestureDetector(
              onTap: onEdit,
              child: Text(
                'Edit',
                style: rescueFont(13, 600, color: RescueColors.primary),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _GoLivePanel extends StatelessWidget {
  const _GoLivePanel();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFEEF4F0),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: giveSageBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const LiveDot(size: 10),
              const SizedBox(width: 8),
              Text(
                'Ready to go live',
                style: rescueFont(
                  13,
                  700,
                  color: RescueColors.primary,
                  letterSpacing: -0.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Once published, FoodLoop will start looking for the best rescue '
            'option nearby.',
            style: rescueFont(
              12,
              400,
              color: const Color(0xFF4D5D54),
              height: 1.55,
            ),
          ),
        ],
      ),
    );
  }
}
