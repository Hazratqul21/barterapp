import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/motion.dart';
import 'common.dart' show palette, shouldReduceMotion;

// ─────────────────────────────────────────────────────────────────────────────
// Moments
// ─────────────────────────────────────────────────────────────────────────────
// Small, one-shot effects for the few moments worth marking: something saved,
// a deal agreed, a payment through. Each plays once on its trigger and draws
// nothing under reduce-motion — the state change itself is always visible
// without them.

/// Pops its child (down, over, settle) each time [active] turns true.
///
/// A plain scale from 0.9 to 1 is a state, not an event: it looks the same
/// whether the heart was just tapped or has been filled for a week. The
/// overshoot is what says "that happened now".
class PopOnActivate extends StatefulWidget {
  const PopOnActivate({super.key, required this.active, required this.child});

  final bool active;
  final Widget child;

  @override
  State<PopOnActivate> createState() => _PopOnActivateState();
}

class _PopOnActivateState extends State<PopOnActivate>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: Motion.bouncy.duration,
  );

  static final _scale = TweenSequence<double>([
    TweenSequenceItem(tween: Tween<double>(begin: 1, end: 0.72), weight: 18),
    TweenSequenceItem(
      tween: Tween<double>(
        begin: 0.72,
        end: 1.22,
      ).chain(CurveTween(curve: Curves.easeOut)),
      weight: 32,
    ),
    TweenSequenceItem(
      tween: Tween<double>(
        begin: 1.22,
        end: 1,
      ).chain(CurveTween(curve: Curves.elasticOut)),
      weight: 50,
    ),
  ]);

  @override
  void didUpdateWidget(PopOnActivate old) {
    super.didUpdateWidget(old);
    if (widget.active && !old.active && !shouldReduceMotion(context)) {
      _c.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _c,
    builder: (context, child) => Transform.scale(
      scale: _c.isAnimating ? _scale.evaluate(_c) : 1,
      child: child,
    ),
    child: widget.child,
  );
}

/// A ring of sparks that bursts out of its child when [active] turns true.
class BurstOnActivate extends StatefulWidget {
  const BurstOnActivate({
    super.key,
    required this.active,
    required this.color,
    required this.child,
    this.radius = 22,
    this.sparks = 7,
  });

  final bool active;
  final Color color;
  final double radius;
  final int sparks;
  final Widget child;

  @override
  State<BurstOnActivate> createState() => _BurstOnActivateState();
}

class _BurstOnActivateState extends State<BurstOnActivate>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 520),
  );

  @override
  void didUpdateWidget(BurstOnActivate old) {
    super.didUpdateWidget(old);
    if (widget.active && !old.active && !shouldReduceMotion(context)) {
      _c.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Stack(
    clipBehavior: Clip.none,
    alignment: Alignment.center,
    children: [
      Positioned.fill(
        child: IgnorePointer(
          child: AnimatedBuilder(
            animation: _c,
            builder: (context, _) => _c.isAnimating
                ? CustomPaint(
                    painter: _BurstPainter(
                      t: Curves.easeOutCubic.transform(_c.value),
                      color: widget.color,
                      radius: widget.radius,
                      sparks: widget.sparks,
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ),
      ),
      widget.child,
    ],
  );
}

class _BurstPainter extends CustomPainter {
  _BurstPainter({
    required this.t,
    required this.color,
    required this.radius,
    required this.sparks,
  });

  final double t;
  final Color color;
  final double radius;
  final int sparks;

  @override
  void paint(Canvas canvas, Size size) {
    final centre = size.center(Offset.zero);
    final fade = (1 - t).clamp(0.0, 1.0);
    // A thin expanding ring under the sparks.
    canvas.drawCircle(
      centre,
      radius * (0.4 + 0.7 * t),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2 * fade
        ..color = color.withValues(alpha: 0.45 * fade),
    );
    final dot = Paint()..color = color.withValues(alpha: fade);
    for (var i = 0; i < sparks; i++) {
      final angle = -math.pi / 2 + i * 2 * math.pi / sparks;
      final distance = radius * (0.55 + 0.75 * t);
      final p = centre + Offset(math.cos(angle), math.sin(angle)) * distance;
      canvas.drawCircle(p, 2.6 * (1 - 0.6 * t), dot);
    }
  }

  @override
  bool shouldRepaint(_BurstPainter old) => old.t != t;
}

/// Confetti over the whole of its area, once, when it first appears.
///
/// For the swap moments only — a deal agreed, a payment through, a first
/// listing published — where the product wants to say well done. Brand
/// colours, no package, and nothing at all under reduce-motion.
class Celebration extends StatefulWidget {
  const Celebration({super.key, this.pieces = 70, this.seed = 7});

  final int pieces;
  final int seed;

  @override
  State<Celebration> createState() => _CelebrationState();
}

class _CelebrationState extends State<Celebration>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2200),
  );
  late List<_Piece> _pieces;

  @override
  void initState() {
    super.initState();
    final rnd = math.Random(widget.seed);
    _pieces = List.generate(widget.pieces, (i) {
      return _Piece(
        x: rnd.nextDouble(),
        vx: (rnd.nextDouble() - 0.5) * 0.5,
        vy: -(0.9 + rnd.nextDouble() * 0.7),
        spin: (rnd.nextDouble() - 0.5) * 14,
        size: 5 + rnd.nextDouble() * 6,
        colorIndex: i % 4,
        round: rnd.nextBool(),
      );
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!shouldReduceMotion(context) && !_c.isAnimating && _c.value == 0) {
      _c.forward();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (shouldReduceMotion(context)) return const SizedBox.shrink();
    final p = palette(context);
    final colors = [p.give, BrandColors.gold500, p.take, p.moneyVivid];
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) => _c.isCompleted
            ? const SizedBox.shrink()
            : CustomPaint(
                size: Size.infinite,
                painter: _ConfettiPainter(
                  t: _c.value,
                  pieces: _pieces,
                  colors: colors,
                ),
              ),
      ),
    );
  }
}

class _Piece {
  const _Piece({
    required this.x,
    required this.vx,
    required this.vy,
    required this.spin,
    required this.size,
    required this.colorIndex,
    required this.round,
  });

  /// Start across the width (0–1), launched from the bottom third.
  final double x;
  final double vx;
  final double vy;
  final double spin;
  final double size;
  final int colorIndex;
  final bool round;
}

class _ConfettiPainter extends CustomPainter {
  _ConfettiPainter({
    required this.t,
    required this.pieces,
    required this.colors,
  });

  final double t;
  final List<_Piece> pieces;
  final List<Color> colors;

  static const _gravity = 1.6;

  @override
  void paint(Canvas canvas, Size size) {
    final fade = t < 0.75 ? 1.0 : (1 - (t - 0.75) / 0.25).clamp(0.0, 1.0);
    for (final piece in pieces) {
      // Simple ballistic arc in "screen heights" per unit time.
      final dx = piece.x + piece.vx * t;
      final dy = 0.72 + piece.vy * t + 0.5 * _gravity * t * t;
      final pos = Offset(dx * size.width, dy * size.height);
      final paint = Paint()
        ..color = colors[piece.colorIndex].withValues(alpha: fade);
      canvas.save();
      canvas.translate(pos.dx, pos.dy);
      canvas.rotate(piece.spin * t);
      if (piece.round) {
        canvas.drawCircle(Offset.zero, piece.size / 2.4, paint);
      } else {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(
              center: Offset.zero,
              width: piece.size,
              height: piece.size * 0.45,
            ),
            const Radius.circular(1.5),
          ),
          paint,
        );
      }
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter old) => old.t != t;
}

/// A check mark that draws itself inside a filled circle — "done", said once.
class AnimatedCheck extends StatefulWidget {
  const AnimatedCheck({
    super.key,
    required this.color,
    required this.onColor,
    this.size = 72,
  });

  final Color color;
  final Color onColor;
  final double size;

  @override
  State<AnimatedCheck> createState() => _AnimatedCheckState();
}

class _AnimatedCheckState extends State<AnimatedCheck>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 760),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (shouldReduceMotion(context)) {
      _c.value = 1;
    } else if (_c.value == 0 && !_c.isAnimating) {
      _c.forward();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _c,
    builder: (context, _) {
      final circle = Curves.easeOutBack.transform(
        (_c.value / 0.5).clamp(0.0, 1.0),
      );
      final stroke = Curves.easeOutCubic.transform(
        ((_c.value - 0.35) / 0.65).clamp(0.0, 1.0),
      );
      return SizedBox.square(
        dimension: widget.size,
        child: CustomPaint(
          painter: _CheckPainter(
            circle: circle,
            stroke: stroke,
            color: widget.color,
            onColor: widget.onColor,
          ),
        ),
      );
    },
  );
}

class _CheckPainter extends CustomPainter {
  _CheckPainter({
    required this.circle,
    required this.stroke,
    required this.color,
    required this.onColor,
  });

  final double circle;
  final double stroke;
  final Color color;
  final Color onColor;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.shortestSide / 2;
    canvas.drawCircle(c, r * circle, Paint()..color = color);
    if (stroke <= 0) return;
    final path = Path()
      ..moveTo(size.width * 0.29, size.height * 0.52)
      ..lineTo(size.width * 0.44, size.height * 0.67)
      ..lineTo(size.width * 0.72, size.height * 0.37);
    final metric = path.computeMetrics().first;
    canvas.drawPath(
      metric.extractPath(0, metric.length * stroke),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = size.width * 0.085
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = onColor,
    );
  }

  @override
  bool shouldRepaint(_CheckPainter old) =>
      old.circle != circle || old.stroke != stroke;
}
