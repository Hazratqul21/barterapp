import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../art/girih.dart';
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
class AuroraBackground extends StatefulWidget {
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
  State<AuroraBackground> createState() => _AuroraBackgroundState();
}

class _AuroraBackgroundState extends State<AuroraBackground>
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

    return LayoutBuilder(
      builder: (context, constraints) {
        final span = math.max(constraints.maxWidth, constraints.maxHeight);
        final diameter = span * 1.25;

        return DecoratedBox(
          decoration: BoxDecoration(color: p.canvas),
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              // Gentle breathing and shifting
              final shift = math.sin(_controller.value * math.pi) * 30;
              final scale = 1.0 + (_controller.value * 0.1);
              
              return Stack(
                children: [
                  Positioned(
                    top: -diameter * 0.38 + shift,
                    left: -diameter * 0.30 - shift,
                    child: Transform.scale(
                      scale: scale,
                      child: _Bloom(
                        diameter: diameter,
                        color: p.giveVivid,
                        alpha: alpha,
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: -diameter * 0.44 - shift,
                    right: -diameter * 0.30 + shift,
                    child: Transform.scale(
                      scale: 1.1 - (_controller.value * 0.1),
                      child: _Bloom(
                        diameter: diameter,
                        color: p.takeVivid,
                        alpha: alpha * 0.85,
                      ),
                    ),
                  ),
                  if (widget.pattern)
                    const Positioned.fill(
                      child: GirihField(opacity: 0.07, cell: 82, fade: 0.45),
                    ),
                  Positioned.fill(child: widget.child),
                ],
              );
            },
          ),
        );
      },
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
