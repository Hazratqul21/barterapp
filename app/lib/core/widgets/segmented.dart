import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'common.dart';

/// A segmented control whose internal boundaries are smooth concave curves.
///
/// Material's `SegmentedButton` divides its segments with straight vertical
/// lines. This draws them as arcs instead: every boundary bows the same way,
/// so the selected fill reads as `[ ACTIVE ) [ INACTIVE ]` — a soft inward
/// curve rather than a hard edge or a plain rounded corner. The outer ends of
/// the bar stay fully rounded, so the whole thing is one continuous pill
/// pinched at its dividers.
///
/// Only the geometry of the boundaries is new; proportions, colours and type
/// are the ordinary segmented-control ones.
class ConcaveSegmentedControl<T> extends StatelessWidget {
  const ConcaveSegmentedControl({
    super.key,
    required this.segments,
    required this.selected,
    required this.onChanged,
    this.height = 40,
  });

  /// Value and label for each segment, in order.
  final List<({T value, String label})> segments;
  final T selected;
  final ValueChanged<T> onChanged;
  final double height;

  @override
  Widget build(BuildContext context) {
    final p = palette(context);
    final theme = Theme.of(context);

    final index = segments.indexWhere((s) => s.value == selected);
    final active = index < 0 ? 0.0 : index.toDouble();

    // The selected fill slides — and its curved edges travel with it — so a
    // change reads as one shape moving, not two shapes swapping colour.
    return TweenAnimationBuilder<double>(
      tween: Tween(end: active),
      duration: M3Motion.medium2,
      curve: M3Motion.emphasized,
      builder: (context, t, _) {
        return SizedBox(
          height: height,
          child: DecoratedBox(
            // The track: a faint pill the segments sit in.
            decoration: BoxDecoration(
              color: p.sunken,
              borderRadius: BorderRadius.circular(height / 2),
              border: Border.all(color: p.hair),
            ),
            child: Stack(
              children: [
                Positioned.fill(
                  child: CustomPaint(
                    painter: _ConcaveSegmentsPainter(
                      count: segments.length,
                      active: t,
                      fill: p.giveSoft,
                      divider: p.hair,
                      radius: height / 2,
                    ),
                  ),
                ),
                Row(
                  children: [
                    for (var i = 0; i < segments.length; i++)
                      Expanded(
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () => onChanged(segments[i].value),
                          child: Center(
                            // The label colour crossfades with the fill so text
                            // and background never disagree mid-slide.
                            child: AnimatedDefaultTextStyle(
                              duration: M3Motion.medium2,
                              curve: M3Motion.emphasized,
                              style: (theme.textTheme.labelLarge ??
                                      const TextStyle())
                                  .copyWith(
                                    color: i == index ? p.give : p.inkSoft,
                                    fontWeight: i == index
                                        ? FontWeight.w700
                                        : FontWeight.w600,
                                  ),
                              child: Text(segments[i].label),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ConcaveSegmentsPainter extends CustomPainter {
  const _ConcaveSegmentsPainter({
    required this.count,
    required this.active,
    required this.fill,
    required this.divider,
    required this.radius,
  });

  final int count;

  /// Selected index, fractional while the fill is sliding.
  final double active;

  final Color fill;
  final Color divider;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final segW = w / count;

    // How deep each boundary bows. Tied to height so the curve keeps its shape
    // whatever the bar's width — a fixed depth flattens on a wide bar.
    final depth = h * 0.42;

    // Everything is clipped to the pill so the outer ends stay rounded and the
    // fill can run right up to them without square corners poking out.
    final pill = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(radius),
    );
    canvas.save();
    canvas.clipRRect(pill);

    // The moving fill. Its internal edges are concave arcs; an edge that lands
    // on the very end of the bar is left straight, because the clip already
    // rounds it into the pill.
    final left = active * segW;
    final right = (active + 1) * segW;

    final path = Path()..moveTo(left, 0);
    if (left > 0.5) {
      // Left edge bows left — the fill bulges into the previous segment, the
      // convex half of the same curve the divider draws.
      path.quadraticBezierTo(left - depth, h / 2, left, h);
    } else {
      path.lineTo(left, h);
    }
    path.lineTo(right, h);
    if (right < w - 0.5) {
      // Right edge bows left — concave, the `)` the reference asks for.
      path.quadraticBezierTo(right - depth, h / 2, right, 0);
    } else {
      path.lineTo(right, 0);
    }
    path.close();
    canvas.drawPath(path, Paint()..color = fill..isAntiAlias = true);

    // Every internal boundary carries the same curve, faintly, so the dividers
    // read even where the fill is nowhere near.
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = divider
      ..isAntiAlias = true;
    for (var b = 1; b < count; b++) {
      final x = b * segW;
      canvas.drawPath(
        Path()
          ..moveTo(x, 4)
          ..quadraticBezierTo(x - depth, h / 2, x, h - 4),
        stroke,
      );
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(_ConcaveSegmentsPainter old) =>
      old.active != active ||
      old.count != count ||
      old.fill != fill ||
      old.divider != divider ||
      old.radius != radius;
}
