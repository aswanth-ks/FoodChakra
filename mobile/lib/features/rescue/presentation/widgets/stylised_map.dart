import 'package:flutter/material.dart';

import 'rescue_widgets.dart';

/// The two stylised maps in the consumer designs.
///
/// Stitch draws both as inline SVG — soft parcel shapes, a white street grid
/// and a handful of markers. They are decorative geometry, not real
/// cartography, so they are painted rather than pulled from a tile provider.
/// PHASE 8 replaces both with a real map widget fed by the listings API.

/// Home hero: neighbourhood overview with the user and four opportunities.
///
/// Drawn against the design's 340x126 viewBox and scaled to fit.
class NearbyMap extends StatelessWidget {
  const NearbyMap({super.key});

  @override
  Widget build(BuildContext context) => CustomPaint(
    painter: _NearbyMapPainter(),
    size: Size.infinite,
    isComplex: true,
  );
}

class _NearbyMapPainter extends CustomPainter {
  static const Size _viewBox = Size(340, 126);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / _viewBox.width, size.height / _viewBox.height);
    canvas.clipRect(Offset.zero & _viewBox);

    // Land base.
    canvas.drawRect(
      Offset.zero & _viewBox,
      Paint()..color = const Color(0xFFF2EDE4),
    );

    // Soft parcel zones.
    final parcel = Paint()..color = RescueColors.mapParcel;
    canvas.drawPath(
      Path()
        ..moveTo(0, 0)
        ..relativeLineTo(120, 0)
        ..relativeLineTo(0, 45)
        ..relativeCubicTo(-20, 10, -60, 15, -120, 12)
        ..close(),
      parcel,
    );
    canvas.drawPath(
      Path()
        ..moveTo(220, 70)
        ..relativeCubicTo(40, -10, 80, -5, 120, 10)
        ..relativeLineTo(0, 46)
        ..lineTo(200, 126)
        ..close(),
      parcel,
    );
    canvas.drawPath(
      Path()
        ..moveTo(140, 10)
        ..relativeCubicTo(30, 0, 70, 15, 80, 40)
        ..relativeLineTo(-40, 25)
        ..relativeCubicTo(-30, -10, -50, -20, -40, -65)
        ..close(),
      Paint()..color = const Color(0xFFE2EDD9).withValues(alpha: 0.75),
    );

    // Street grid — wide white casing, then a hairline seam on the majors.
    final majors = Path()
      ..moveTo(-10, 40)
      ..lineTo(350, 40)
      ..moveTo(-10, 85)
      ..lineTo(350, 85)
      ..moveTo(90, -10)
      ..lineTo(90, 140)
      ..moveTo(240, -10)
      ..lineTo(240, 140);
    final diagonals = Path()
      ..moveTo(30, 130)
      ..lineTo(160, -10)
      ..moveTo(170, 135)
      ..lineTo(310, -10);

    final road = Paint()
      ..color = RescueColors.mapRoad
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(majors, road);
    canvas.drawPath(diagonals, road);
    canvas.drawPath(
      majors,
      Paint()
        ..color = const Color(0xFFDCD6C9)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );

    // User position.
    _drawUserPin(canvas, const Offset(105, 62), haloRadius: 10, dotRadius: 4.5);

    // Plain opportunity nodes.
    for (final node in const [
      (Offset(68, 32), 7.0),
      (Offset(288, 88), 7.0),
      (Offset(152, 103), 6.0),
    ]) {
      canvas.drawCircle(
        node.$1,
        node.$2,
        Paint()..color = RescueColors.primaryLight,
      );
      canvas.drawCircle(node.$1, 2.5, Paint()..color = Colors.white);
    }

    // Featured opportunity: pinged halo behind a rounded square with a
    // package glyph.
    canvas.drawCircle(
      const Offset(209, 50),
      13,
      Paint()..color = RescueColors.primary.withValues(alpha: 0.2),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(195, 36, 28, 28),
        const Radius.circular(8),
      ),
      Paint()..color = RescueColors.primary,
    );
    final glyph = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(
      Path()
        ..moveTo(204, 47)
        ..lineTo(209, 44)
        ..lineTo(214, 47)
        ..lineTo(214, 53)
        ..lineTo(209, 56)
        ..lineTo(204, 53)
        ..close(),
      glyph,
    );
    canvas.drawPath(
      Path()
        ..moveTo(209, 44)
        ..lineTo(209, 56)
        ..moveTo(204, 47)
        ..lineTo(214, 53),
      glyph..strokeWidth = 1.2,
    );

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Active rescue: the walking/driving route from the user to the pickup point.
///
/// Drawn against the design's 380x240 viewBox and scaled to fit.
class RouteMap extends StatelessWidget {
  const RouteMap({super.key});

  @override
  Widget build(BuildContext context) => CustomPaint(
    painter: _RouteMapPainter(),
    size: Size.infinite,
    isComplex: true,
  );
}

class _RouteMapPainter extends CustomPainter {
  static const Size _viewBox = Size(380, 240);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / _viewBox.width, size.height / _viewBox.height);
    canvas.clipRect(Offset.zero & _viewBox);

    canvas.drawRect(
      Offset.zero & _viewBox,
      Paint()..color = RescueColors.mapLand,
    );

    // Park / green areas.
    final green = Paint()
      ..color = RescueColors.mapGreen.withValues(alpha: 0.6);
    canvas.drawPath(
      Path()
        ..moveTo(20, 20)
        ..cubicTo(60, 10, 110, 30, 90, 80)
        ..cubicTo(70, 120, 20, 110, 10, 60)
        ..close(),
      green,
    );
    canvas.drawPath(
      Path()
        ..moveTo(270, 110)
        ..cubicTo(320, 100, 370, 140, 360, 200)
        ..cubicTo(330, 230, 280, 220, 260, 170)
        ..close(),
      green,
    );
    canvas.drawPath(
      Path()
        ..moveTo(170, 10)
        ..cubicTo(210, 5, 230, 40, 200, 60)
        ..cubicTo(170, 70, 150, 40, 170, 10)
        ..close(),
      Paint()..color = RescueColors.mapGreen.withValues(alpha: 0.4),
    );

    // Streets.
    void street(Offset a, Offset b, double width) => canvas.drawLine(
      a,
      b,
      Paint()
        ..color = RescueColors.mapRoad
        ..strokeWidth = width
        ..strokeCap = StrokeCap.round,
    );
    street(const Offset(-10, 60), const Offset(390, 60), 9);
    street(const Offset(-10, 170), const Offset(390, 170), 8);
    street(const Offset(110, -10), const Offset(110, 250), 9);
    street(const Offset(260, -10), const Offset(260, 250), 9);
    street(const Offset(20, 230), const Offset(200, -10), 6);
    street(const Offset(180, 250), const Offset(370, 40), 6);

    // Navigation route: user (70,170) to the hall (285,60).
    final route = Path()
      ..moveTo(70, 170)
      ..lineTo(110, 170)
      ..quadraticBezierTo(130, 170, 130, 150)
      ..lineTo(130, 85)
      ..quadraticBezierTo(130, 60, 155, 60)
      ..lineTo(285, 60);
    canvas.drawPath(
      route,
      Paint()
        ..color = RescueColors.primary
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
    canvas.drawPath(
      _dashed(route, dash: 3, gap: 5),
      Paint()
        ..color = RescueColors.route
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round,
    );

    _drawUserPin(canvas, const Offset(70, 170), haloRadius: 14, dotRadius: 7);

    // Destination marker: rounded square with a house glyph.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(272, 34, 36, 36),
        const Radius.circular(10),
      ),
      Paint()..color = RescueColors.primary,
    );
    canvas.drawPath(
      Path()
        ..moveTo(290, 44)
        ..lineTo(283, 50)
        ..lineTo(283, 60)
        ..lineTo(297, 60)
        ..lineTo(297, 50)
        ..close(),
      Paint()..color = Colors.white,
    );
    canvas.drawRect(
      const Rect.fromLTWH(288, 53, 4, 7),
      Paint()..color = RescueColors.primary,
    );

    canvas.restore();
  }

  /// Flutter strokes have no dash support, so the dashed overlay is rebuilt
  /// segment by segment from the path's metrics.
  static Path _dashed(Path source, {required double dash, required double gap}) {
    final result = Path();
    for (final metric in source.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final end = (distance + dash).clamp(0.0, metric.length);
        result.addPath(metric.extractPath(distance, end), Offset.zero);
        distance = end + gap;
      }
    }
    return result;
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Halo, solid dot and white core — the user marker both maps share.
void _drawUserPin(
  Canvas canvas,
  Offset centre, {
  required double haloRadius,
  required double dotRadius,
}) {
  canvas.drawCircle(
    centre,
    haloRadius,
    Paint()..color = RescueColors.primary.withValues(alpha: 0.14),
  );
  canvas.drawCircle(centre, dotRadius, Paint()..color = RescueColors.primary);
  canvas.drawCircle(centre, dotRadius * 0.4, Paint()..color = Colors.white);
}
