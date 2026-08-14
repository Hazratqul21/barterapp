import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../widgets/common.dart';
import 'girih.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Illustrations
// ─────────────────────────────────────────────────────────────────────────────
// Drawn with paths, not assembled from icons in boxes.
//
// An icon is a sign — it stands for a word. An illustration is a picture of
// something happening, and what happens here is specific: two people hand each
// other goods, sometimes with money closing the gap. No icon set has that, so
// it is drawn.
//
// Everything reads its colour from the palette, so a single set of drawings
// serves both themes and any future change of brand colour.

/// Geometry every drawing here shares.
abstract final class _Ink {
  static const stroke = 2.4;
  static const radius = 10.0;
}

Paint _line(Color color, [double width = _Ink.stroke]) => Paint()
  ..style = PaintingStyle.stroke
  ..strokeWidth = width
  ..strokeCap = StrokeCap.round
  ..strokeJoin = StrokeJoin.round
  ..color = color;

Paint _fill(Color color) => Paint()..color = color;

/// A crate: the goods themselves, banded like a parcel.
///
/// Deliberately not a phone or a sack of grain. This app moves laptops,
/// tractors, cattle and roof sheeting; the one shape that stands for all of
/// them is a box with something in it.
void _crate(
  Canvas canvas,
  Rect rect, {
  required Color stroke,
  required Color tint,
  double lean = 0,
}) {
  canvas.save();
  canvas.translate(rect.center.dx, rect.center.dy);
  canvas.rotate(lean);
  canvas.translate(-rect.center.dx, -rect.center.dy);

  final body = RRect.fromRectAndRadius(
    rect,
    const Radius.circular(_Ink.radius),
  );
  canvas.drawRRect(body, _fill(tint));
  canvas.drawRRect(body, _line(stroke));

  // The strap across the middle, and the lid seam — enough to read as a parcel
  // rather than a rounded rectangle.
  final midY = rect.top + rect.height * 0.38;
  canvas.drawLine(
    Offset(rect.left, midY),
    Offset(rect.right, midY),
    _line(stroke, _Ink.stroke * 0.8),
  );
  canvas.drawLine(
    Offset(rect.center.dx, midY),
    Offset(rect.center.dx, rect.bottom),
    _line(stroke, _Ink.stroke * 0.8),
  );

  canvas.restore();
}

/// One curved arrow from [from] to [to], bowing by [bow].
void _arrow(
  Canvas canvas,
  Offset from,
  Offset to, {
  required Color color,
  required double bow,
}) {
  final middle = Offset.lerp(from, to, 0.5)!;
  final direction = to - from;
  final normal = Offset(-direction.dy, direction.dx);
  final length = direction.distance;
  final control = middle + normal / length * bow;

  canvas.drawPath(
    Path()
      ..moveTo(from.dx, from.dy)
      ..quadraticBezierTo(control.dx, control.dy, to.dx, to.dy),
    _line(color, _Ink.stroke),
  );

  // The head points along the tangent at the end of the curve, which for a
  // quadratic is the line from the control point to the finish.
  final tangent = to - control;
  final angle = math.atan2(tangent.dy, tangent.dx);
  const wing = 11.0;
  const spread = 0.42;

  canvas.drawPath(
    Path()
      ..moveTo(to.dx, to.dy)
      ..lineTo(
        to.dx - wing * math.cos(angle - spread),
        to.dy - wing * math.sin(angle - spread),
      )
      ..moveTo(to.dx, to.dy)
      ..lineTo(
        to.dx - wing * math.cos(angle + spread),
        to.dy - wing * math.sin(angle + spread),
      ),
    _line(color, _Ink.stroke),
  );
}

/// A coin, for the cash that closes the gap between two unequal sides.
void _coin(Canvas canvas, Offset centre, double radius, Color color, Color tint) {
  canvas.drawCircle(centre, radius, _fill(tint));
  canvas.drawCircle(centre, radius, _line(color, _Ink.stroke * 0.9));
  canvas.drawCircle(centre, radius * 0.52, _line(color, _Ink.stroke * 0.7));
}

// ─────────────────────────────────────────────────────────────────────────────
// 1 · The swap
// ─────────────────────────────────────────────────────────────────────────────

class _SwapPainter extends CustomPainter {
  const _SwapPainter(this.p);
  final BarterPalette p;

  @override
  void paint(Canvas canvas, Size size) {
    final unit = size.width / 260;
    final box = 84.0 * unit;
    final y = size.height * 0.5;

    final left = Rect.fromCenter(
      center: Offset(size.width * 0.19, y + 6 * unit),
      width: box,
      height: box,
    );
    final right = Rect.fromCenter(
      center: Offset(size.width * 0.81, y + 6 * unit),
      width: box,
      height: box,
    );

    // A slight lean each way: goods in motion, not stacked in a warehouse.
    _crate(canvas, left, stroke: p.give, tint: p.giveSoft, lean: -0.06);
    _crate(canvas, right, stroke: p.take, tint: p.takeSoft, lean: 0.06);

    // Two arrows, each bowing the opposite way, so together they circulate.
    final over = 26.0 * unit;
    _arrow(
      canvas,
      Offset(left.right + 8 * unit, y - 6 * unit),
      Offset(right.left - 8 * unit, y - 6 * unit),
      color: p.give,
      bow: -over,
    );
    _arrow(
      canvas,
      Offset(right.left - 8 * unit, y + 22 * unit),
      Offset(left.right + 8 * unit, y + 22 * unit),
      color: p.take,
      bow: -over * 0.75,
    );

    _coin(
      canvas,
      Offset(size.width / 2, y + 46 * unit),
      13 * unit,
      p.money,
      p.moneySoft,
    );
  }

  @override
  bool shouldRepaint(_SwapPainter old) => old.p != p;
}

/// Two crates changing hands, with a coin for the difference.
class SwapIllustration extends StatelessWidget {
  const SwapIllustration({super.key, this.size = const Size(260, 200)});

  final Size size;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _SwapPainter(palette(context)), size: size);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 2 · The match
// ─────────────────────────────────────────────────────────────────────────────

class _MatchPainter extends CustomPainter {
  const _MatchPainter(this.p);
  final BarterPalette p;

  /// Half a disc with a tab on its flat edge — or a notch, mirrored. Two of
  /// them meet and lock, which is what a match is: not two similar things, two
  /// things that fit.
  Path _half(Offset centre, double radius, {required bool tab}) {
    final path = Path();
    final tabRadius = radius * 0.26;

    path.moveTo(centre.dx, centre.dy - radius);
    path.arcToPoint(
      Offset(centre.dx, centre.dy + radius),
      radius: Radius.circular(radius),
      clockwise: false,
    );
    path.lineTo(centre.dx, centre.dy + tabRadius);
    path.arcToPoint(
      Offset(centre.dx, centre.dy - tabRadius),
      radius: Radius.circular(tabRadius),
      clockwise: !tab,
    );
    path.close();
    return path;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final unit = size.width / 260;
    final radius = 52.0 * unit;
    final y = size.height * 0.44;
    final seam = size.width / 2;

    // Pulled slightly apart — a beat before they lock, which reads as movement.
    final gap = 5.0 * unit;

    canvas.save();
    canvas.translate(-gap, 0);
    final give = _half(Offset(seam, y), radius, tab: true);
    canvas.drawPath(give, _fill(p.giveSoft));
    canvas.drawPath(give, _line(p.give));
    canvas.restore();

    canvas.save();
    canvas.translate(gap, 0);
    canvas.scale(-1, 1);
    canvas.translate(-2 * seam, 0);
    final take = _half(Offset(seam, y), radius, tab: false);
    canvas.drawPath(take, _fill(p.takeSoft));
    canvas.drawPath(take, _line(p.take));
    canvas.restore();

    // A tile star at the seam: the fit itself, and the app's own ornament.
    canvas.drawPath(
      eightPointStar(Offset(seam, y), 15 * unit, 6.5 * unit),
      _fill(p.money),
    );

    // Sparks, largest nearest the seam.
    for (final (angle, distance, r) in <(double, double, double)>[
      (-0.9, 78, 5),
      (-2.3, 70, 3.6),
      (0.85, 74, 4.2),
    ]) {
      canvas.drawCircle(
        Offset(
          seam + distance * unit * math.cos(angle),
          y + distance * unit * math.sin(angle),
        ),
        r * unit,
        _fill(p.moneyVivid.withValues(alpha: 0.55)),
      );
    }
  }

  @override
  bool shouldRepaint(_MatchPainter old) => old.p != p;
}

/// Two halves that lock together — the matcher's whole idea in one shape.
class MatchIllustration extends StatelessWidget {
  const MatchIllustration({super.key, this.size = const Size(260, 200)});

  final Size size;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _MatchPainter(palette(context)), size: size);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 3 · Trust
// ─────────────────────────────────────────────────────────────────────────────

class _TrustPainter extends CustomPainter {
  const _TrustPainter(this.p);
  final BarterPalette p;

  Path _shield(Offset centre, double width, double height) {
    final halfWidth = width / 2;
    final top = centre.dy - height / 2;
    final bottom = centre.dy + height / 2;
    final shoulder = top + height * 0.62;

    return Path()
      ..moveTo(centre.dx, top)
      ..lineTo(centre.dx + halfWidth, top + height * 0.14)
      ..lineTo(centre.dx + halfWidth, shoulder)
      ..quadraticBezierTo(
        centre.dx + halfWidth * 0.86,
        bottom - height * 0.06,
        centre.dx,
        bottom,
      )
      ..quadraticBezierTo(
        centre.dx - halfWidth * 0.86,
        bottom - height * 0.06,
        centre.dx - halfWidth,
        shoulder,
      )
      ..lineTo(centre.dx - halfWidth, top + height * 0.14)
      ..close();
  }

  @override
  void paint(Canvas canvas, Size size) {
    final unit = size.width / 260;
    final centre = Offset(size.width / 2, size.height * 0.48);
    final shield = _shield(centre, 108 * unit, 132 * unit);

    canvas.drawPath(shield, _fill(p.giveSoft));
    canvas.drawPath(shield, _line(p.give));

    // The tilework shows through the shield — trust here is the local kind:
    // the neighbour with a name, not a padlock badge.
    canvas.save();
    canvas.clipPath(shield);
    final faint = _line(p.give.withValues(alpha: 0.28), 1.1);
    for (var row = -1; row < 4; row++) {
      for (var column = -1; column < 4; column++) {
        final origin =
            centre + Offset((column - 1) * 34 * unit, (row - 1) * 34 * unit);
        canvas.drawPath(
          eightPointStar(origin, 15 * unit, 6 * unit),
          faint,
        );
      }
    }
    canvas.restore();

    // The check, drawn thick and short so it reads at a glance.
    final tick = Path()
      ..moveTo(centre.dx - 22 * unit, centre.dy + 2 * unit)
      ..lineTo(centre.dx - 6 * unit, centre.dy + 18 * unit)
      ..lineTo(centre.dx + 24 * unit, centre.dy - 18 * unit);
    canvas.drawPath(tick, _line(p.give, _Ink.stroke * 1.7));

    // Three stars for the reviews the shield is made of.
    for (final (index, angle) in <(int, double)>[
      (0, -2.55),
      (1, -0.6),
      (2, 1.57),
    ]) {
      final at = centre + Offset(
        92 * unit * math.cos(angle),
        86 * unit * math.sin(angle),
      );
      final r = (index == 1 ? 13.0 : 10.0) * unit;
      canvas.drawCircle(at, r, _fill(p.moneySoft));
      canvas.drawPath(
        eightPointStar(at, r * 0.72, r * 0.3),
        _fill(p.money),
      );
    }
  }

  @override
  bool shouldRepaint(_TrustPainter old) => old.p != p;
}

/// A shield of tilework, earned in stars.
class TrustIllustration extends StatelessWidget {
  const TrustIllustration({super.key, this.size = const Size(260, 200)});

  final Size size;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _TrustPainter(palette(context)), size: size);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 4 · Nothing here yet
// ─────────────────────────────────────────────────────────────────────────────

class _EmptyPainter extends CustomPainter {
  const _EmptyPainter(this.p);
  final BarterPalette p;

  @override
  void paint(Canvas canvas, Size size) {
    final unit = size.width / 160;
    final centre = Offset(size.width / 2, size.height * 0.54);

    // An open, empty crate: the lid tilted off, nothing inside. Reads the same
    // whether the feed found nothing or the inbox is quiet.
    final body = Rect.fromCenter(
      center: centre + Offset(0, 10 * unit),
      width: 96 * unit,
      height: 66 * unit,
    );
    final rounded = RRect.fromRectAndRadius(
      body,
      Radius.circular(_Ink.radius * unit * 0.9),
    );
    canvas.drawRRect(rounded, _fill(p.sunken));
    canvas.drawRRect(rounded, _line(p.inkFaint, 2.2 * unit));

    canvas.save();
    canvas.translate(centre.dx, body.top - 12 * unit);
    canvas.rotate(-0.22);
    final lid = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset.zero,
        width: 104 * unit,
        height: 20 * unit,
      ),
      Radius.circular(7 * unit),
    );
    canvas.drawRRect(lid, _fill(p.sunken));
    canvas.drawRRect(lid, _line(p.inkFaint, 2.2 * unit));
    canvas.restore();

    // A dotted floor line, so the crate is standing somewhere.
    final floor = _line(p.hair, 2 * unit);
    for (var x = -54.0; x < 54; x += 12) {
      canvas.drawLine(
        Offset(centre.dx + x * unit, body.bottom + 14 * unit),
        Offset(centre.dx + (x + 6) * unit, body.bottom + 14 * unit),
        floor,
      );
    }
  }

  @override
  bool shouldRepaint(_EmptyPainter old) => old.p != p;
}

/// An empty crate, for screens with nothing in them yet.
class EmptyIllustration extends StatelessWidget {
  const EmptyIllustration({super.key, this.size = const Size(160, 130)});

  final Size size;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _EmptyPainter(palette(context)), size: size);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 5 · Something went wrong
// ─────────────────────────────────────────────────────────────────────────────

class _BrokenPainter extends CustomPainter {
  const _BrokenPainter(this.p, this.accent);
  final BarterPalette p;
  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    final unit = size.width / 160;
    final centre = Offset(size.width / 2, size.height * 0.5);

    // Draw rays radiating from center
    final rayPaint = Paint()
      ..color = p.inkFaint.withValues(alpha: 0.3)
      ..strokeWidth = 2.0 * unit
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    for (int i = 0; i < 8; i++) {
      if (i == 2 || i == 6) continue; // Skip vertical rays to leave room for crack
      final angle = (i * 45) * 3.14159 / 180.0;
      final dx = math.cos(angle);
      final dy = math.sin(angle);
      canvas.drawLine(
        centre + Offset(dx * 40 * unit, dy * 40 * unit),
        centre + Offset(dx * 65 * unit, dy * 65 * unit),
        rayPaint,
      );
    }

    // The swap arrow, snapped in the middle.
    final gap = 13.0 * unit;

    _arrow(
      canvas,
      centre + Offset(-58 * unit, -14 * unit),
      centre + Offset(-gap, -14 * unit),
      color: accent,
      bow: -16 * unit,
    );
    _arrow(
      canvas,
      centre + Offset(58 * unit, 16 * unit),
      centre + Offset(gap, 16 * unit),
      color: accent,
      bow: -16 * unit,
    );

    // The break: two short strokes where the line gave way.
    final crack = _line(accent, 2.6 * unit);
    canvas.drawLine(
      centre + Offset(-4 * unit, -30 * unit),
      centre + Offset(4 * unit, -6 * unit),
      crack,
    );
    canvas.drawLine(
      centre + Offset(-4 * unit, 8 * unit),
      centre + Offset(4 * unit, 32 * unit),
      crack,
    );
  }

  @override
  bool shouldRepaint(_BrokenPainter old) => old.p != p || old.accent != accent;
}

/// A broken swap, for a screen that could not load.
class BrokenIllustration extends StatelessWidget {
  const BrokenIllustration({super.key, this.size = const Size(160, 130)});

  final Size size;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _BrokenPainter(
        palette(context),
        palette(context).give, // Use Teal instead of error red
      ),
      size: size,
    );
  }
}
