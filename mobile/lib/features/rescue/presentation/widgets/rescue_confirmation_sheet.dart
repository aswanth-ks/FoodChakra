import 'package:flutter/material.dart';

import '../../domain/food_listing.dart';
import 'rescue_widgets.dart';

/// "FoodLoop Consumer Rescue Confirmation Bottom Sheet".
///
/// Faithful translation of the Stitch design
/// (screen `a1032738300c4089ab43b5b3a57ed769`).
///
/// Presented over the Food Details screen when the user taps "Rescue this
/// food". Resolves to `true` once the reservation completes, `null` if the
/// user backs out — the caller then routes on to Active Rescue.
Future<bool?> showRescueConfirmationSheet(
  BuildContext context, {
  required FoodListing listing,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    // The design dims the screen behind to 25% black.
    barrierColor: Colors.black.withValues(alpha: 0.25),
    builder: (_) => _RescueConfirmationSheet(listing: listing),
  );
}

class _RescueConfirmationSheet extends StatefulWidget {
  const _RescueConfirmationSheet({required this.listing});

  final FoodListing listing;

  @override
  State<_RescueConfirmationSheet> createState() =>
      _RescueConfirmationSheetState();
}

/// Where the confirm button has got to.
enum _ConfirmState { idle, reserving, confirmed }

class _RescueConfirmationSheetState extends State<_RescueConfirmationSheet> {
  bool _committed = false;
  final _ConfirmState _state = _ConfirmState.idle;

  /// Closes the sheet with the user's decision. It does **not** reserve
  /// anything.
  ///
  /// This used to sit through two timed delays and show "Rescue confirmed"
  /// before any request had been made — a success state the server had not
  /// agreed to, on a claim that can legitimately lose a race. The real claim
  /// and its progress belong to the details screen, which owns the outcome.
  void _confirm() {
    if (!_committed || _state != _ConfirmState.idle) return;
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final listing = widget.listing;
    final reserving = _state == _ConfirmState.reserving;
    final confirmed = _state == _ConfirmState.confirmed;

    return Container(
      decoration: const BoxDecoration(
        color: RescueColors.card,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        border: Border(top: BorderSide(color: Color(0xFFE7EBE8))),
        boxShadow: [
          BoxShadow(
            color: Color(0x29121F17),
            blurRadius: 40,
            spreadRadius: -8,
            offset: Offset(0, -10),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 44,
                    height: 6,
                    decoration: BoxDecoration(
                      color: const Color(0xFFD4DDD7),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: Text(
                        'Ready to rescue?',
                        style: rescueFont(
                          21,
                          700,
                          color: RescueColors.ink,
                          letterSpacing: -0.4,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    const LivePill(
                      label: 'Live availability',
                      background: Color(0xFFE0ECE5),
                      dotColor: RescueColors.live,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _SummaryCard(listing: listing),
                const SizedBox(height: 12),
                _PickupBlock(listing: listing),
                const SizedBox(height: 14),
                Text(
                  'Please make sure you can collect the food within the '
                  'pickup window.',
                  style: rescueFont(
                    12.5,
                    400,
                    color: RescueColors.muted,
                    height: 1.55,
                  ),
                ),
                const SizedBox(height: 16),
                _CommitCheckbox(
                  value: _committed,
                  // Locked once the reservation is under way.
                  onChanged: _state == _ConfirmState.idle
                      ? (v) => setState(() => _committed = v)
                      : null,
                ),
                const SizedBox(height: 16),
                RescuePrimaryButton(
                  // One label only: nothing here can report a rescue as
                  // confirmed, because nothing here has asked the server.
                  label: 'Confirm rescue',
                  icon: confirmed
                      ? Icons.check_rounded
                      : (reserving ? null : Icons.shopping_bag_outlined),
                  leading: reserving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation(Colors.white),
                          ),
                        )
                      : null,
                  background: confirmed
                      ? RescueColors.live
                      : RescueColors.primary,
                  onPressed: _committed && _state == _ConfirmState.idle
                      ? _confirm
                      : null,
                ),
                const SizedBox(height: 4),
                TextButton(
                  onPressed: _state == _ConfirmState.idle
                      ? () => Navigator.of(context).pop()
                      : null,
                  style: TextButton.styleFrom(
                    foregroundColor: RescueColors.muted,
                  ),
                  child: Text(
                    'Not now',
                    style: rescueFont(13, 500, color: RescueColors.muted),
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

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.listing});

  final FoodListing listing;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: RescueColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE7EBE8)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  // The design's mock renders this lowercase; the canonical
                  // title is used instead so the item reads identically on
                  // Details, the sheet and Active Rescue.
                  listing.title,
                  style: rescueFont(
                    17,
                    700,
                    color: RescueColors.ink,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${listing.category} · ${listing.preparedNote}',
                  style: rescueFont(13, 500, color: RescueColors.muted),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: RescueColors.card,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: const Color(0xFFE7EBE8)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.check_rounded,
                  size: 14,
                  color: RescueColors.live,
                ),
                const SizedBox(width: 4),
                Text(
                  'Available now',
                  style: rescueFont(12, 600, color: RescueColors.primary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PickupBlock extends StatelessWidget {
  const _PickupBlock({required this.listing});

  final FoodListing listing;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F7F4),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2EBE5)),
      ),
      child: Column(
        children: [
          DetailRow(
            icon: Icons.schedule_rounded,
            label: 'Pickup window',
            uppercaseLabel: true,
            value: listing.pickupWindow,
            tileSize: 32,
            tileBackground: RescueColors.card,
            tileBorderColor: const Color(0xFFE0ECE5),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: ColoredBox(
              color: Color(0xFFE2EBE5),
              child: SizedBox(height: 1, width: double.infinity),
            ),
          ),
          DetailRow(
            icon: Icons.location_on_outlined,
            label: 'Pickup location',
            uppercaseLabel: true,
            value: '${listing.pickupLocation} · ${listing.distanceLabel}',
            tileSize: 32,
            tileBackground: RescueColors.card,
            tileBorderColor: const Color(0xFFE0ECE5),
          ),
        ],
      ),
    );
  }
}

/// The commitment checkbox that gates the confirm button.
class _CommitCheckbox extends StatelessWidget {
  const _CommitCheckbox({required this.value, this.onChanged});

  final bool value;
  final void Function(bool value)? onChanged;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onChanged == null ? null : () => onChanged!(!value),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                color: value ? RescueColors.primary : RescueColors.card,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: value
                      ? RescueColors.primary
                      : const Color(0xFFA8BDB1),
                  width: 2,
                ),
              ),
              child: value
                  ? const Icon(
                      Icons.check_rounded,
                      size: 14,
                      color: Colors.white,
                    )
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'I can collect within this pickup window.',
                style: rescueFont(
                  13.5,
                  600,
                  color: RescueColors.ink,
                  height: 1.35,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
