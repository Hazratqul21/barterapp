import 'package:flutter/material.dart';

/// The six category symbols, drawn rather than borrowed.
///
/// Material Symbols got the app this far, but they are a general-purpose set:
/// the nearest thing to "chorva" in it is a paw print, and the nearest thing to
/// "texnika" is a factory robot. A marketplace whose whole subject is grain,
/// livestock and tractors deserves marks that name those things exactly.
///
/// Every mark is drawn on the same 24-unit square with the same rules, which is
/// what makes six separate drawings read as one set:
///
/// * **One optical weight.** Solid masses about 2 units thick; nothing thinner
///   than 1.4, because at the badge size of 16 pixels that is already under a
///   single physical pixel.
/// * **Holes, not detail.** Wheel hubs and eyes are punched out of the fill.
///   A solid silhouette turns into a blob at small sizes; a hole survives the
///   shrink and is what keeps the shape nameable.
/// * **Room at the edges.** Nothing touches the 24-unit bounds, so the marks
///   sit at the same apparent size inside the medallion.
enum CategoryMark { crops, livestock, tractor, truck, chip, bricks }

/// One category mark at [size], in [color].
class CategoryMarkIcon extends StatelessWidget {
  const CategoryMarkIcon({
    super.key,
    required this.mark,
    required this.color,
    this.size = 30,
  });

  final CategoryMark mark;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _MarkPainter(mark: mark, color: color),
      ),
    );
  }
}

class _MarkPainter extends CustomPainter {
  const _MarkPainter({required this.mark, required this.color});

  final CategoryMark mark;
  final Color color;

  /// The grid every mark is drawn on.
  static const _grid = 24.0;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / _grid, size.height / _grid);

    final fill = Paint()
      ..color = color
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..isAntiAlias = true;

    switch (mark) {
      case CategoryMark.crops:
        _crops(canvas, fill);
      case CategoryMark.livestock:
        _livestock(canvas, fill, stroke);
      case CategoryMark.tractor:
        _tractor(canvas, fill);
      case CategoryMark.truck:
        _truck(canvas, fill);
      case CategoryMark.chip:
        _chip(canvas, fill);
      case CategoryMark.bricks:
        _bricks(canvas, fill);
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(_MarkPainter old) =>
      old.mark != mark || old.color != color;
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared shapes
// ─────────────────────────────────────────────────────────────────────────────

/// A grain, a leaf, an ear — a pointed oval from [base] to [tip].
///
/// Two mirrored quadratics rather than a rotated ellipse: the control points
/// sit at 38% of the length, which puts the widest part nearer the base and
/// gives the shape a direction. A true ellipse reads as a seed lying down.
Path _petal(Offset base, Offset tip, double halfWidth) {
  final d = tip - base;
  final len = d.distance;
  if (len == 0) return Path();
  final n = Offset(-d.dy / len, d.dx / len) * halfWidth;
  final mid = base + d * 0.38;

  return Path()
    ..moveTo(base.dx, base.dy)
    ..quadraticBezierTo(mid.dx + n.dx, mid.dy + n.dy, tip.dx, tip.dy)
    ..quadraticBezierTo(mid.dx - n.dx, mid.dy - n.dy, base.dx, base.dy)
    ..close();
}

/// A disc with a hole through it — a wheel, an eye.
Path _ring(Offset centre, double outer, double inner) => Path()
  ..fillType = PathFillType.evenOdd
  ..addOval(Rect.fromCircle(center: centre, radius: outer))
  ..addOval(Rect.fromCircle(center: centre, radius: inner));

Path _bar(double l, double t, double r, double b, double radius) =>
    Path()..addRRect(RRect.fromLTRBR(l, t, r, b, Radius.circular(radius)));

// ─────────────────────────────────────────────────────────────────────────────
// The marks
// ─────────────────────────────────────────────────────────────────────────────

/// Qishloq xo'jaligi — an ear of wheat.
///
/// Not a tractor: the tractor belongs to `texnika`, and what this category
/// actually holds is what the land produces.
void _crops(Canvas canvas, Paint fill) {
  canvas.drawPath(_bar(11.15, 10.0, 12.85, 21.6, 0.85), fill);

  // The crown, then three pairs stepping down the stalk. Each pair sits a
  // little lower than the grain above it and reaches a little further out, so
  // the silhouette widens toward the bottom the way a real ear does.
  canvas.drawPath(
    _petal(const Offset(12, 11.4), const Offset(12, 3.1), 2.05),
    fill,
  );

  const rows = [
    (base: 12.2, tip: 7.4, reach: 5.9),
    (base: 15.3, tip: 10.6, reach: 6.4),
    (base: 18.3, tip: 13.8, reach: 6.6),
  ];
  for (final row in rows) {
    canvas.drawPath(
      _petal(Offset(11.6, row.base), Offset(12 - row.reach, row.tip), 1.75),
      fill,
    );
    canvas.drawPath(
      _petal(Offset(12.4, row.base), Offset(12 + row.reach, row.tip), 1.75),
      fill,
    );
  }
}

/// Chorva — a ram's head, horns and all.
///
/// The horns are what make this nameable at 16 pixels: they break the outline
/// and put daylight between themselves and the head, so the eye reads a
/// creature rather than a lump.
void _livestock(Canvas canvas, Paint fill, Paint stroke) {
  // Horns first, so the head sits over their inner ends.
  stroke.strokeWidth = 2.0;
  for (final side in [-1.0, 1.0]) {
    final path = Path()
      ..moveTo(12 + side * 2.8, 8.4)
      ..cubicTo(
        12 + side * 6.4,
        6.2,
        12 + side * 9.4,
        9.4,
        12 + side * 7.8,
        12.6,
      );
    canvas.drawPath(path, stroke);
  }

  // Ears, low and wide, angled down so they do not read as more horns.
  canvas.drawPath(
    _petal(const Offset(9.4, 13.4), const Offset(4.6, 15.6), 1.35),
    fill,
  );
  canvas.drawPath(
    _petal(const Offset(14.6, 13.4), const Offset(19.4, 15.6), 1.35),
    fill,
  );

  // The head: wide at the brow, tapering to a muzzle.
  final head = Path()
    ..fillType = PathFillType.evenOdd
    ..moveTo(12, 8.0)
    ..cubicTo(15.9, 8.0, 16.7, 10.6, 16.5, 13.6)
    ..cubicTo(16.3, 17.2, 14.6, 20.6, 12, 20.6)
    ..cubicTo(9.4, 20.6, 7.7, 17.2, 7.5, 13.6)
    ..cubicTo(7.3, 10.6, 8.1, 8.0, 12, 8.0)
    ..close()
    // Eyes, punched through.
    ..addOval(Rect.fromCircle(center: const Offset(10.2, 13.3), radius: 1.0))
    ..addOval(Rect.fromCircle(center: const Offset(13.8, 13.3), radius: 1.0));
  canvas.drawPath(head, fill);
}

/// Texnika — a tractor in profile.
///
/// The two unequal wheels are the whole recognition: a big driven wheel behind,
/// a small steering wheel in front. Nothing else about the silhouette matters
/// as much, so both hubs stay generously open.
void _tractor(Canvas canvas, Paint fill) {
  // Cab and bonnet as one body, cut off above the axles.
  final body = Path()
    ..moveTo(4.6, 14.6)
    ..lineTo(4.6, 9.0)
    ..quadraticBezierTo(4.6, 8.1, 5.5, 8.1)
    ..lineTo(10.0, 8.1)
    ..quadraticBezierTo(10.9, 8.1, 10.9, 9.0)
    ..lineTo(10.9, 11.0)
    ..lineTo(19.0, 11.0)
    ..quadraticBezierTo(19.9, 11.0, 19.9, 11.9)
    ..lineTo(19.9, 14.6)
    ..close();
  canvas.drawPath(body, fill);

  canvas.drawPath(_ring(const Offset(7.9, 16.4), 4.7, 1.9), fill);
  canvas.drawPath(_ring(const Offset(17.6, 17.6), 3.3, 1.3), fill);
}

/// Transport — a lorry in profile.
void _truck(Canvas canvas, Paint fill) {
  canvas.drawPath(_bar(2.6, 7.4, 13.6, 16.2, 1.5), fill);

  // The cab: a bonnet stepping down from the box.
  final cab = Path()
    ..moveTo(13.6, 10.4)
    ..lineTo(17.2, 10.4)
    ..quadraticBezierTo(17.8, 10.4, 18.2, 10.9)
    ..lineTo(20.9, 14.3)
    ..quadraticBezierTo(21.3, 14.8, 21.3, 15.4)
    ..lineTo(21.3, 16.2)
    ..lineTo(13.6, 16.2)
    ..close();
  canvas.drawPath(cab, fill);

  canvas.drawPath(_ring(const Offset(7.0, 17.4), 3.1, 1.25), fill);
  canvas.drawPath(_ring(const Offset(17.4, 17.4), 3.1, 1.25), fill);
}

/// Elektronika — a chip with its legs out.
///
/// `devices` filled in was a plain rectangle, which is to say nothing at all.
/// The legs are what carry the meaning here, so they are drawn long enough to
/// survive the shrink to badge size.
void _chip(Canvas canvas, Paint fill) {
  final body = Path()
    ..fillType = PathFillType.evenOdd
    ..addRRect(
      RRect.fromLTRBR(6.4, 6.4, 17.6, 17.6, const Radius.circular(2.2)),
    )
    ..addRRect(
      RRect.fromLTRBR(10.0, 10.0, 14.0, 14.0, const Radius.circular(1.1)),
    );
  canvas.drawPath(body, fill);

  // Three legs to a side, on the same 3-unit pitch all the way round.
  const offsets = [-3.1, 0.0, 3.1];
  for (final o in offsets) {
    canvas.drawPath(_bar(12 + o - 0.85, 2.9, 12 + o + 0.85, 6.6, 0.75), fill);
    canvas.drawPath(_bar(12 + o - 0.85, 17.4, 12 + o + 0.85, 21.1, 0.75), fill);
    canvas.drawPath(_bar(2.9, 12 + o - 0.85, 6.6, 12 + o + 0.85, 0.75), fill);
    canvas.drawPath(_bar(17.4, 12 + o - 0.85, 21.1, 12 + o + 0.85, 0.75), fill);
  }
}

/// Qurilish — coursed brickwork.
///
/// Crossed hammer and spanner, which this category used to carry, says repairs.
/// What the category actually holds is building material, and three courses of
/// staggered brick say that in any language.
void _bricks(Canvas canvas, Paint fill) {
  const left = 3.4;
  const right = 20.6;
  const rows = [6.2, 11.1, 16.0];
  const height = 3.9;
  const joint = 1.0;
  const radius = 0.75;

  for (var i = 0; i < rows.length; i++) {
    final top = rows[i];
    final bottom = top + height;

    if (i.isEven) {
      // Two full bricks, the joint on the centre line.
      const mid = (left + right) / 2;
      canvas.drawPath(_bar(left, top, mid - joint / 2, bottom, radius), fill);
      canvas.drawPath(_bar(mid + joint / 2, top, right, bottom, radius), fill);
    } else {
      // Staggered: two half bricks at the ends, one full in the middle.
      const quarter = left + (right - left) / 4;
      const threeQuarter = left + 3 * (right - left) / 4;
      canvas.drawPath(
        _bar(left, top, quarter - joint / 2, bottom, radius),
        fill,
      );
      canvas.drawPath(
        _bar(
          quarter + joint / 2,
          top,
          threeQuarter - joint / 2,
          bottom,
          radius,
        ),
        fill,
      );
      canvas.drawPath(
        _bar(threeQuarter + joint / 2, top, right, bottom, radius),
        fill,
      );
    }
  }
}
