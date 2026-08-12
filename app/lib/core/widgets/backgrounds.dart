import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../art/girih.dart';
import '../theme/section_theme.dart';
import 'common.dart';

/// The app's wallpaper: a soft two-colour glow with the tile lattice over it.
///
/// Green bleeds in from one corner, blue from the other — the same give-to-take
/// idea the splash states outright, said quietly enough to read behind text.
/// Over that sits [GirihField], the eight-point star lattice of Samarkand
/// tilework, faded out toward the bottom so it never reaches the content.
///
/// Both halves are drawn, not downloaded: no asset, no blur pass per frame, and
/// both re-tint themselves for the dark theme.
///
/// Reserved for the screens with no pictures of their own — the intro, sign-in
/// and profile setup. A feed of photographs needs a plain page underneath, not
/// a second thing competing for attention.
class AuroraBackground extends ConsumerStatefulWidget {
  const AuroraBackground({
    super.key,
    required this.child,
    this.intensity = 1.0,
    this.pattern = true,
  });

  final Widget child;
  final double intensity;
  final bool pattern;

  @override
  ConsumerState<AuroraBackground> createState() => _AuroraBackgroundState();
}

class _AuroraBackgroundState extends ConsumerState<AuroraBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 15),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = palette(context);
    final alpha = (p.isDark ? 0.26 : 0.16) * widget.intensity;

    // The two glow colours follow the current tab and drift when it changes.
    final aura = sectionAura(p, ref.watch(sectionProvider));

    return LayoutBuilder(
      builder: (context, constraints) {
        final span = math.max(constraints.maxWidth, constraints.maxHeight);
        final diameter = span * 1.25;

        return DecoratedBox(
          decoration: BoxDecoration(color: p.canvas),
          child: Stack(
            children: [
              // Three layers, and the split between them is the whole point.
              //
              // The cost of a drifting wallpaper is paint, not build: the
              // stack used to have no repaint boundaries in it, so the blooms,
              // the lattice and the entire app shared one layer. A bloom
              // moving a pixel marked that layer dirty, and every frame
              // repainted the lattice's hundreds of stroked paths and the
              // app's own painting along with it — measured at one full
              // repaint per frame, which is what the jank was.
              //
              // Boundaries split them, and the drift now only transforms a
              // layer that was painted once. The blooms sit in their own
              // subtree so that recolouring them on a tab change cannot reach
              // the app below.
              Positioned.fill(
                child: _AnimatedBlooms(
                  controller: _controller,
                  diameter: diameter,
                  alpha: alpha,
                  aura: aura,
                ),
              ),

              // The lattice is hundreds of stroked star paths and never
              // changes. Its own boundary means it is rasterised once and
              // then only composited.
              if (widget.pattern)
                const Positioned.fill(
                  child: RepaintBoundary(
                    child: GirihField(opacity: 0.07, cell: 82, fade: 0.45),
                  ),
                ),

              // The app on its own layer, so a drifting bloom cannot dirty it
              // and a scrolling feed cannot dirty the wallpaper.
              Positioned.fill(child: RepaintBoundary(child: widget.child)),
            ],
          ),
        );
      },
    );
  }
}

/// The two drifting blooms, whose colours cross-fade when the section changes.
///
/// It is a separate widget for one reason: the colour animation must not reach
/// the app. The wallpaper's whole performance rests on the app sitting in a
/// sibling `RepaintBoundary`; if the tab-change colour tween lived up in
/// [AuroraBackground.build], the app would be inside its rebuild scope and every
/// section change would repaint every screen. Here the tween's scope is exactly
/// the two blooms and nothing else.
class _AnimatedBlooms extends StatelessWidget {
  const _AnimatedBlooms({
    required this.controller,
    required this.diameter,
    required this.alpha,
    required this.aura,
  });

  final Animation<double> controller;
  final double diameter;
  final double alpha;
  final ({Color a, Color b}) aura;

  @override
  Widget build(BuildContext context) {
    // `TweenAnimationBuilder` remembers the last value it built, so giving it a
    // new `end` when the tab changes animates from the colour already on
    // screen. Two are nested because there are two independent colours; the
    // duration is long enough to read as a drift, not a switch.
    const dur = Duration(milliseconds: 620);
    const curve = Curves.easeInOutCubic;

    return TweenAnimationBuilder<Color?>(
      tween: ColorTween(end: aura.a),
      duration: dur,
      curve: curve,
      builder: (context, colorA, _) => TweenAnimationBuilder<Color?>(
        tween: ColorTween(end: aura.b),
        duration: dur,
        curve: curve,
        builder: (context, colorB, _) => Stack(
          children: [
            _Drift(
              controller: controller,
              diameter: diameter,
              alignment: Alignment.topLeft,
              bloom: _Bloom(
                diameter: diameter,
                color: colorA ?? aura.a,
                alpha: alpha,
              ),
            ),
            _Drift(
              controller: controller,
              diameter: diameter,
              alignment: Alignment.bottomRight,
              bloom: _Bloom(
                diameter: diameter,
                color: colorB ?? aura.b,
                alpha: alpha * 0.85,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One bloom, drifting.
///
/// The bloom itself is passed in as `child` and therefore built once; the
/// builder only wraps it in a transform. A transform moves an existing layer
/// rather than repainting a full-screen gradient, which is the difference
/// between a wallpaper that costs nothing and one that costs a frame.
class _Drift extends StatelessWidget {
  const _Drift({
    required this.controller,
    required this.diameter,
    required this.alignment,
    required this.bloom,
  });

  final Animation<double> controller;
  final double diameter;

  /// Which corner this bloom is anchored to.
  final Alignment alignment;

  final Widget bloom;

  @override
  Widget build(BuildContext context) {
    final fromTop = alignment.y < 0;

    return Positioned(
      top: fromTop ? -diameter * 0.38 : null,
      left: fromTop ? -diameter * 0.30 : null,
      bottom: fromTop ? null : -diameter * 0.44,
      right: fromTop ? null : -diameter * 0.30,
      child: RepaintBoundary(
        child: AnimatedBuilder(
          animation: controller,
          child: bloom,
          builder: (context, child) {
            final t = math.sin(controller.value * math.pi);
            final shift = t * 30 * (fromTop ? 1 : -1);
            final scale = fromTop ? 1.0 + t * 0.1 : 1.1 - t * 0.1;

            return Transform.translate(
              offset: Offset(-shift, shift),
              child: Transform.scale(scale: scale, child: child),
            );
          },
        ),
      ),
    );
  }
}

/// One radial wash. The stops fall away early so the edge never draws a ring —
/// a linear falloff leaves a visible disc boundary at these sizes.
class _Bloom extends StatelessWidget {
  const _Bloom({
    required this.diameter,
    required this.color,
    required this.alpha,
  });

  final double diameter;
  final Color color;
  final double alpha;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: diameter,
        height: diameter,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [
              color.withValues(alpha: alpha),
              color.withValues(alpha: alpha * 0.55),
              color.withValues(alpha: 0),
            ],
            stops: const [0.0, 0.35, 1.0],
          ),
        ),
      ),
    );
  }
}

/// The gradient band at the top of the feed, with the lattice worked into it.
///
/// The same tilework as the wallpaper, but reversed out in white — on a strong
/// green-to-blue field a dark line would disappear, and the pattern is what
/// keeps the header from looking like every other app's gradient.
class SwapBanner extends StatelessWidget {
  const SwapBanner({
    super.key,
    required this.height,
    required this.borderRadius,
  });

  final double height;
  final BorderRadius borderRadius;

  @override
  Widget build(BuildContext context) {
    final p = palette(context);

    return SizedBox(
      height: height,
      child: ClipRRect(
        borderRadius: borderRadius,
        child: DecoratedBox(
          decoration: BoxDecoration(gradient: p.swapGradient),
          child: const GirihField(
            color: Colors.white,
            opacity: 0.14,
            cell: 64,
            strokeWidth: 1.1,
          ),
        ),
      ),
    );
  }
}
