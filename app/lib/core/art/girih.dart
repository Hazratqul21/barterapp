import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../widgets/common.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Girih
// ─────────────────────────────────────────────────────────────────────────────
// The eight-point star lattice — khatam — that covers the tilework of Samarkand
// and Bukhara. It is drawn here rather than photographed or downloaded, for the
// same reasons every other picture in this app is: it stays sharp at any size,
// re-tints itself for the dark theme, and adds nothing to the download.
//
// It is also the one ornament this product has any business wearing. A generic
// gradient could belong to any marketplace anywhere; this belongs to the market
// it was built for. Kept at a whisper — it should be felt before it is noticed,
// and never read as texture competing with a photograph.

/// One eight-point star, centred on [c].
///
/// Sixteen vertices alternating between [outer] and [inner] radius. The classic
/// construction is two squares laid over each other at 45°; going round the
/// alternating radii draws the same figure in one path.
Path eightPointStar(Offset c, double outer, double inner) {
  final path = Path();
  for (var i = 0; i < 16; i++) {
    final radius = i.isEven ? outer : inner;
    final angle = -math.pi / 2 + i * math.pi / 8;
    final point = Offset(
      c.dx + radius * math.cos(angle),
      c.dy + radius * math.sin(angle),
    );
    i == 0 ? path.moveTo(point.dx, point.dy) : path.lineTo(point.dx, point.dy);
  }
  return path..close();
}

/// A square standing on its corner — the tile that fills the gaps between the
/// stars and closes the lattice.
Path diamond(Offset c, double radius) => Path()
  ..moveTo(c.dx, c.dy - radius)
  ..lineTo(c.dx + radius, c.dy)
  ..lineTo(c.dx, c.dy + radius)
  ..lineTo(c.dx - radius, c.dy)
  ..close();

class _GirihPainter extends CustomPainter {
  const _GirihPainter({
    required this.color,
    required this.cell,
    required this.strokeWidth,
    required this.fade,
  });

  final Color color;

  /// Distance between star centres.
  final double cell;

  final double strokeWidth;

  /// Where the lattice dissolves, as a fraction of the height. 0 keeps it even;
  /// 1 fades it out completely by the bottom edge.
  final double fade;

  @override
  void paint(Canvas canvas, Size size) {
    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeJoin = StrokeJoin.round
      ..color = color;

    final outer = cell * 0.44;
    final inner = outer * 0.42;
    final gap = cell * 0.19;

    // One row past each edge, so the pattern runs off the sides rather than
    // stopping at a visible boundary.
    final columns = (size.width / cell).ceil() + 2;
    final rows = (size.height / cell).ceil() + 2;

    for (var row = -1; row < rows; row++) {
      for (var column = -1; column < columns; column++) {
        final origin = Offset(column * cell, row * cell);

        if (fade > 0) {
          final depth = (origin.dy / size.height).clamp(0.0, 1.0);
          final remaining = (1 - depth * fade).clamp(0.0, 1.0);
          if (remaining <= 0.02) continue;
          line.color = color.withValues(alpha: color.a * remaining);
        }

        canvas.drawPath(eightPointStar(origin, outer, inner), line);
        canvas.drawPath(
          diamond(origin + Offset(cell / 2, cell / 2), gap),
          line,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_GirihPainter old) =>
      old.color != color ||
      old.cell != cell ||
      old.strokeWidth != strokeWidth ||
      old.fade != fade;
}

/// The lattice as a widget, sized to whatever it is given.
class GirihField extends StatelessWidget {
  const GirihField({
    super.key,
    this.color,
    this.opacity = 0.06,
    this.cell = 76,
    this.strokeWidth = 1,
    this.fade = 0,
  });

  /// Defaults to the give-green, which is the app's own line colour.
  final Color? color;

  /// How present the pattern is. Above roughly 0.10 it starts to argue with
  /// body text sitting on top of it.
  final double opacity;

  final double cell;
  final double strokeWidth;
  final double fade;

  @override
  Widget build(BuildContext context) {
    final p = palette(context);
    final base = color ?? p.give;

    return IgnorePointer(
      child: CustomPaint(
        painter: _GirihPainter(
          // Dark surfaces swallow a line that a light one would show.
          color: base.withValues(alpha: opacity * (p.isDark ? 1.7 : 1.0)),
          cell: cell,
          strokeWidth: strokeWidth,
          fade: fade,
        ),
        size: Size.infinite,
      ),
    );
  }
}
