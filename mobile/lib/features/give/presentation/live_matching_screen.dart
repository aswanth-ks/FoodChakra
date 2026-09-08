import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../rescue/presentation/widgets/rescue_widgets.dart';
import '../domain/surplus_draft.dart';
import 'widgets/give_widgets.dart';

/// How far along the search for a rescuer is.
///
/// The design shows the first step active and the other two dimmed. Phase 5
/// drives this from the matching service; until then the screen is opened at
/// [searching] and stays there.
enum MatchingStage {
  searching('Looking for a rescuer', 'Checking nearby rescue options.'),
  expanding('Expanding the search', 'Reaching rescuers a little further out.'),
  found('Rescuer found', 'Someone is on their way to collect.');

  const MatchingStage(this.title, this.subtitle);

  /// The status card's heading.
  final String title;

  /// The line under the heading.
  final String subtitle;
}

/// "FoodLoop Consumer Live Rescue Matching Screen".
///
/// Faithful translation of the Stitch design
/// (screen `0483482c28fe4d19932a48305d8d054f`).
///
/// The giver's view after publishing surplus: the post is live, and FoodLoop
/// is looking for someone to collect it. Reached from Review & publish and
/// from an Activity entry that is still being matched.
class LiveMatchingScreen extends StatefulWidget {
  const LiveMatchingScreen({
    super.key,
    required this.draft,
    this.stage = MatchingStage.searching,
    this.onBack,
    this.onHelp,
    this.onManagePost,
  });

  final SurplusDraft draft;
  final MatchingStage stage;

  final VoidCallback? onBack;

  /// Help and support. Inert until the Phase 5 support surface exists.
  final VoidCallback? onHelp;

  /// Editing or withdrawing the live post. Needs the Phase 5 listings service.
  final VoidCallback? onManagePost;

  @override
  State<LiveMatchingScreen> createState() => _LiveMatchingScreenState();
}

class _LiveMatchingScreenState extends State<LiveMatchingScreen> {
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    // The pickup window closes on the wall clock, so the countdown is
    // recomputed rather than decremented — it stays right across a pause.
    _ticker = Timer.periodic(
      const Duration(seconds: 20),
      (_) => setState(() {}),
    );
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  /// Minutes left in the pickup window, floored at zero.
  int get _minutesRemaining {
    final now = DateTime.now();
    final until = DateTime(
      now.year,
      now.month,
      now.day,
      widget.draft.pickupUntil.hour,
      widget.draft.pickupUntil.minute,
    );
    // A window ending after midnight, or one already past, rolls to tomorrow
    // so the screen never shows a negative countdown.
    final end = until.isAfter(now) ? until : until.add(const Duration(days: 1));
    return end.difference(now).inMinutes;
  }

  @override
  Widget build(BuildContext context) {
    final draft = widget.draft;
    final minutes = _minutesRemaining;

    return Scaffold(
      backgroundColor: RescueColors.surface,
      body: SafeArea(
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 430),
            child: Column(
              children: [
                _MatchingAppBar(onBack: widget.onBack, onHelp: widget.onHelp),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 6, 20, 20),
                    children: [
                      _StatusHeader(minutesRemaining: minutes),
                      const SizedBox(height: 14),
                      _SurplusSummaryCard(draft: draft),
                      const SizedBox(height: 14),
                      _MatchingMap(locality: draft.pickupLocation),
                      const SizedBox(height: 14),
                      _SearchStatusCard(stage: widget.stage),
                      const SizedBox(height: 14),
                      const GiveInfoPanel(
                        message:
                            'FoodLoop will keep checking while your pickup '
                            'window is open. We’ll notify you as soon as a '
                            'rescuer accepts.',
                      ),
                    ],
                  ),
                ),
                _ManagePostBar(onManagePost: widget.onManagePost),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Back, a pulsing "Live rescue" pill, and help.
class _MatchingAppBar extends StatelessWidget {
  const _MatchingAppBar({this.onBack, this.onHelp});

  final VoidCallback? onBack;
  final VoidCallback? onHelp;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
      child: Row(
        children: [
          RescueIconButton(
            icon: Icons.arrow_back_ios_new_rounded,
            tooltip: 'Go back',
            onPressed: onBack,
          ),
          Expanded(
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0EEE6),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const LiveDot(color: RescueColors.primary, size: 8),
                    const SizedBox(width: 6),
                    Text(
                      'Live rescue',
                      style: rescueFont(
                        13,
                        600,
                        color: RescueColors.primary,
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
            tooltip: 'Help and support',
            onPressed: onHelp,
          ),
        ],
      ),
    );
  }
}

/// LIVE badge, the pickup-window countdown, and the page heading.
class _StatusHeader extends StatelessWidget {
  const _StatusHeader({required this.minutesRemaining});

  final int minutesRemaining;

  /// The design turns the countdown amber in the last quarter hour.
  bool get _urgent => minutesRemaining <= 15;

  @override
  Widget build(BuildContext context) {
    final hours = minutesRemaining ~/ 60;
    final label = hours >= 1
        ? '$hours hr remaining'
        : '$minutesRemaining min remaining';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFFEAF3ED),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: const Color(0xFFC2DED0)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const LiveDot(color: Color(0xFF247048), size: 6),
                  const SizedBox(width: 6),
                  Text(
                    'LIVE',
                    style: rescueFont(
                      11,
                      700,
                      color: const Color(0xFF1E5C3C),
                      letterSpacing: 1,
                    ),
                  ),
                ],
              ),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: _urgent ? RescueColors.amberBg : RescueColors.card,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: _urgent
                      ? RescueColors.amberBorder
                      : RescueColors.border,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.schedule_rounded,
                    size: 14,
                    color: _urgent
                        ? RescueColors.amber
                        : const Color(0xFF247048),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    label,
                    style: rescueFont(
                      12,
                      600,
                      color: _urgent
                          ? RescueColors.amber
                          : RescueColors.primary,
                      letterSpacing: -0.2,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          'Your food is live',
          style: rescueFont(
            25,
            700,
            color: const Color(0xFF102419),
            height: 1.2,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'FoodLoop is looking for the best rescue option nearby.',
          style: rescueFont(
            13.5,
            500,
            color: const Color(0xFF4F6155),
            height: 1.5,
          ),
        ),
      ],
    );
  }
}

/// One-line recap of what was published, read straight off the draft.
class _SurplusSummaryCard extends StatelessWidget {
  const _SurplusSummaryCard({required this.draft});

  final SurplusDraft draft;

  @override
  Widget build(BuildContext context) {
    final title = draft.foodName.trim().isEmpty
        ? draft.quantitySummary
        : draft.foodName.trim();

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: RescueColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE6E3DA)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFFEEF4F0),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFD2E3D8)),
            ),
            child: const Icon(
              Icons.inventory_2_outlined,
              size: 20,
              color: RescueColors.primary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: rescueFont(
                          14.5,
                          600,
                          color: const Color(0xFF14261D),
                        ),
                      ),
                    ),
                    if (draft.foodType != null) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF0F7F3),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFFD8EBE0)),
                        ),
                        child: Text(
                          draft.foodType!.label,
                          style: rescueFont(
                            11.5,
                            600,
                            color: const Color(0xFF247048),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '${draft.servingsSummary} · Pickup by '
                  '${SurplusDraft.formatTime(draft.pickupUntil)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: rescueFont(12, 400, color: const Color(0xFF55675C)),
                ),
                Text(
                  draft.pickupLocation,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: rescueFont(11, 400, color: const Color(0xFF8C9C91)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The stylised map with radar ripples spreading from the food marker.
///
/// Like the other consumer maps, this is drawn rather than fetched; Phase 8
/// replaces it with a real map centred on the pickup point. The nearby nodes
/// are deliberately anonymous — no rescuer identity is shown while matching.
class _MatchingMap extends StatefulWidget {
  const _MatchingMap({required this.locality});

  final String locality;

  @override
  State<_MatchingMap> createState() => _MatchingMapState();
}

class _MatchingMapState extends State<_MatchingMap>
    with TickerProviderStateMixin {
  late final AnimationController _ripple = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 3600),
  )..repeat();

  late final AnimationController _float = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 4),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _ripple.dispose();
    _float.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: Container(
        height: 190,
        decoration: BoxDecoration(
          color: const Color(0xFFE8ECE7),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: const Color(0xFFD6DED5)),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            const Positioned.fill(
              child: CustomPaint(painter: _MatchingMapPainter()),
            ),
            // The three ripple rings share one controller, staggered a third
            // of a cycle apart.
            Positioned.fill(
              child: AnimatedBuilder(
                animation: _ripple,
                builder: (context, _) => CustomPaint(
                  painter: _RipplePainter(progress: _ripple.value),
                ),
              ),
            ),
            _FloatingNode(
              controller: _float,
              top: 42,
              right: 75,
              size: 24,
              dotSize: 10,
              dotColor: const Color(0xFF3D7A57),
            ),
            _FloatingNode(
              controller: _float,
              bottom: 46,
              left: 55,
              size: 20,
              dotSize: 8,
              dotColor: const Color(0xFF528A69),
              // Offset so the nodes do not bob in lockstep.
              reverse: true,
            ),
            _FloatingNode(
              controller: _float,
              top: 135,
              right: 40,
              size: 20,
              dotSize: 8,
              dotColor: const Color(0xFF6A9E80),
            ),
            const _FoodMarker(),
            Positioned(
              left: 12,
              bottom: 10,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                decoration: BoxDecoration(
                  color: RescueColors.card.withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFD6DED5)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.place_rounded,
                      size: 12,
                      color: Color(0xFF2A6D47),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      '${widget.locality} area',
                      style: rescueFont(
                        10.5,
                        500,
                        color: const Color(0xFF44554B),
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

/// Grid, streets and park shapes behind the radar.
class _MatchingMapPainter extends CustomPainter {
  const _MatchingMapPainter();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xFFEDF1EC),
    );

    // 34px grid, matching the design's SVG pattern.
    final grid = Paint()
      ..color = const Color(0xFFD5DFD5)
      ..strokeWidth = 0.8;
    for (double x = 0; x < size.width; x += 34) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), grid);
    }
    for (double y = 0; y < size.height; y += 34) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }

    // Park blobs.
    final park = Paint()..color = const Color(0xFFE0EADF);
    canvas.drawCircle(const Offset(280, 70), 32, park);
    canvas.drawCircle(const Offset(65, 160), 42, park);

    final broad = Paint()
      ..color = const Color(0xFFDFE6DE)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawPath(
      Path()
        ..moveTo(-20, 60)
        ..quadraticBezierTo(90, 90, 195, 50)
        ..quadraticBezierTo(300, 10, 420, 110),
      broad..strokeWidth = 16,
    );
    canvas.drawLine(
      const Offset(195, -10),
      const Offset(195, 240),
      broad..strokeWidth = 12,
    );
    canvas.drawPath(
      Path()
        ..moveTo(40, 220)
        ..cubicTo(120, 180, 240, 220, 360, 160),
      broad..strokeWidth = 9,
    );

    final lane = Paint()
      ..color = RescueColors.mapRoad
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 2.5;
    canvas.drawPath(
      Path()
        ..moveTo(-10, 130)
        ..quadraticBezierTo(140, 120, 280, 180)
        ..quadraticBezierTo(360, 210, 410, 150),
      lane,
    );
    canvas.drawLine(
      const Offset(195, -10),
      const Offset(195, 240),
      lane..strokeWidth = 2.2,
    );
  }

  @override
  bool shouldRepaint(_MatchingMapPainter oldDelegate) => false;
}

/// Three rings expanding out of the centre, a third of a cycle apart.
class _RipplePainter extends CustomPainter {
  const _RipplePainter({required this.progress});

  /// 0..1 through one ripple cycle.
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final centre = Offset(size.width / 2, size.height / 2);

    for (var i = 0; i < 3; i++) {
      final t = (progress + i / 3) % 1;
      // The design scales each ring from 0.4 to 2.4 of its base radius while
      // fading it out over the second half of the cycle.
      final radius = 60 * (0.4 + t * 2.0);
      final opacity = t < 0.5 ? 0.85 - t * 0.9 : (1 - t) * 0.8;
      if (opacity <= 0) continue;

      canvas.drawCircle(
        centre,
        radius,
        Paint()
          ..color = const Color(0xFF2E7D52).withValues(alpha: opacity * 0.06),
      );
      canvas.drawCircle(
        centre,
        radius,
        Paint()
          ..color = const Color(0xFF2E7D52).withValues(alpha: opacity)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1,
      );
    }
  }

  @override
  bool shouldRepaint(_RipplePainter oldDelegate) =>
      oldDelegate.progress != progress;
}

/// An anonymous nearby rescue option, bobbing gently.
class _FloatingNode extends StatelessWidget {
  const _FloatingNode({
    required this.controller,
    required this.size,
    required this.dotSize,
    required this.dotColor,
    this.top,
    this.bottom,
    this.left,
    this.right,
    this.reverse = false,
  });

  final AnimationController controller;
  final double size;
  final double dotSize;
  final Color dotColor;
  final double? top;
  final double? bottom;
  final double? left;
  final double? right;
  final bool reverse;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: top,
      bottom: bottom,
      left: left,
      right: right,
      child: AnimatedBuilder(
        animation: controller,
        builder: (context, child) {
          final wave = math.sin(controller.value * math.pi);
          return Transform.translate(
            offset: Offset(0, (reverse ? wave : -wave) * 4),
            child: child,
          );
        },
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: RescueColors.card.withValues(alpha: 0.9),
            shape: BoxShape.circle,
            border: Border.all(color: const Color(0xFFBDD4C5)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x14122019),
                blurRadius: 4,
                offset: Offset(0, 1),
              ),
            ],
          ),
          child: Center(
            child: Container(
              width: dotSize,
              height: dotSize,
              decoration: BoxDecoration(
                color: dotColor,
                shape: BoxShape.circle,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The user's own post, pinned at the centre of the search.
class _FoodMarker extends StatelessWidget {
  const _FoodMarker();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: RescueColors.primary,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white, width: 2),
            boxShadow: const [
              BoxShadow(
                color: Color(0x26122019),
                blurRadius: 8,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: const Icon(
            Icons.place_outlined,
            size: 20,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: RescueColors.primary,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const LiveDot(color: Color(0xFF49DF8E), size: 6),
              const SizedBox(width: 5),
              Text(
                'Food available',
                style: rescueFont(10.5, 600, color: RescueColors.surface),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// What the search is doing right now, plus the three-step progress row.
class _SearchStatusCard extends StatelessWidget {
  const _SearchStatusCard({required this.stage});

  final MatchingStage stage;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: RescueColors.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE6E3DA)),
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const LiveDot(color: Color(0xFF247048), size: 10),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            stage.title,
                            style: rescueFont(
                              16,
                              700,
                              color: const Color(0xFF14261D),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Padding(
                      padding: const EdgeInsets.only(left: 18),
                      child: Text(
                        stage.subtitle,
                        style: rescueFont(
                          12.5,
                          500,
                          color: const Color(0xFF55695E),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Container(
                width: 28,
                height: 28,
                decoration: const BoxDecoration(
                  color: Color(0xFFEEF4F0),
                  shape: BoxShape.circle,
                ),
                child: const _SlowSpinner(),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1, color: Color(0xFFF0EEE7)),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _StageStep(
                icon: Icons.search_rounded,
                label: 'Searching\nnearby',
                active: stage.index >= MatchingStage.searching.index,
              ),
              _StageStep(
                icon: Icons.add_circle_outline_rounded,
                label: 'Expanding\nsearch',
                active: stage.index >= MatchingStage.expanding.index,
              ),
              _StageStep(
                icon: Icons.check_rounded,
                label: 'Rescue\nfound',
                active: stage.index >= MatchingStage.found.index,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// The design's 4-second spin — slow enough to read as "working", not "loading".
class _SlowSpinner extends StatefulWidget {
  const _SlowSpinner();

  @override
  State<_SlowSpinner> createState() => _SlowSpinnerState();
}

class _SlowSpinnerState extends State<_SlowSpinner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 4),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RotationTransition(
      turns: _controller,
      child: const Icon(
        Icons.refresh_rounded,
        size: 16,
        color: Color(0xFF247048),
      ),
    );
  }
}

/// One of the three matching steps, dimmed until reached.
class _StageStep extends StatelessWidget {
  const _StageStep({
    required this.icon,
    required this.label,
    required this.active,
  });

  final IconData icon;
  final String label;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Opacity(
        opacity: active ? 1 : 0.45,
        child: Column(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: active ? RescueColors.primary : const Color(0xFFE6E3DA),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 14,
                color: active ? Colors.white : const Color(0xFF55675C),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              textAlign: TextAlign.center,
              style: rescueFont(
                11,
                active ? 700 : 600,
                color: active ? RescueColors.primary : const Color(0xFF55675C),
                height: 1.25,
                letterSpacing: -0.1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Footer holding the single "Manage post" action.
class _ManagePostBar extends StatelessWidget {
  const _ManagePostBar({this.onManagePost});

  final VoidCallback? onManagePost;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: RescueColors.surface,
        border: Border(top: BorderSide(color: Color(0xFFEEEBE3))),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
          child: Column(
            children: [
              TextButton.icon(
                onPressed: onManagePost,
                icon: const Icon(Icons.settings_outlined, size: 16),
                label: Text(
                  'Manage post',
                  style: rescueFont(13, 600, color: const Color(0xFF247048)),
                ),
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF247048),
                  disabledForegroundColor: giveDisabledText,
                  minimumSize: const Size(0, 44),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  shape: const StadiumBorder(),
                ),
              ),
              const SizedBox(height: 8),
              const HomeIndicator(),
            ],
          ),
        ),
      ),
    );
  }
}
