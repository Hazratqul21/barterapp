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
class AuroraBackground extends StatelessWidget {
  const AuroraBackground({
    super.key,
    required this.child,
    this.intensity = 1.0,
    this.pattern = true,
  });

  final Widget child;

  /// Scales both blooms. Below 1 for screens that already have colour of their
  /// own; the default is tuned to sit under body text without tinting it.
  final double intensity;

  /// The tile lattice. Off for screens where even a whisper of ornament would
  /// crowd the content.
  final bool pattern;

  @override
  Widget build(BuildContext context) {
    final p = palette(context);

    // Dark surfaces swallow a wash that light ones would show, so the same
    // apparent softness needs more of it.
    final alpha = (p.isDark ? 0.26 : 0.16) * intensity;

    return LayoutBuilder(
      builder: (context, constraints) {
        // Blooms scale with the viewport: a fixed radius that reads as a soft
        // corner glow on a phone becomes a hard disc on a desktop window.
        final span = math.max(constraints.maxWidth, constraints.maxHeight);
        final diameter = span * 0.95;

        return DecoratedBox(
          decoration: BoxDecoration(color: p.canvas),
          child: Stack(
            children: [
              Positioned(
                top: -diameter * 0.42,
                left: -diameter * 0.34,
                child: _Bloom(
                  diameter: diameter,
                  color: p.giveVivid,
                  alpha: alpha,
                ),
              ),
              Positioned(
                bottom: -diameter * 0.5,
                right: -diameter * 0.38,
                child: _Bloom(
                  diameter: diameter,
                  color: p.takeVivid,
                  alpha: alpha * 0.85,
                ),
              ),
              if (pattern)
                // Fades as it descends, so the lattice frames the top of the
                // screen and has let go by the time the reading starts.
                const Positioned.fill(
                  child: GirihField(opacity: 0.055, cell: 82, fade: 0.95),
                ),
              Positioned.fill(child: child),
            ],
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
      child: ClipPath(
        clipper: _SweptBottom(borderRadius.topLeft.x),
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

/// The band's lower edge: a single shallow curve rather than two corner radii.
///
/// A rounded rectangle is what every app's header does. One bezier sweeping
/// across the full width reads as hand-drawn — closer to the tilework above it
/// — and it costs nothing extra to paint.
///
/// The drop is deliberately small. The classified-app pattern this borrows from
/// dips 80 logical pixels, which swallows the first row of content and dates
/// the screen to about 2019; at [_drop] the curve is felt more than seen.
class _SweptBottom extends CustomClipper<Path> {
  const _SweptBottom(this.topRadius);

  /// Matches the radius the banner used before, so the top corners are
  /// unchanged and only the bottom edge is new.
  final double topRadius;

  @override
  Path getClip(Size size) {
    final r = topRadius.clamp(0.0, size.width / 2);

    // Proportional to the width, so the curvature is the same on a phone and
    // on a desktop pane. A fixed drop looked right at 375 logical pixels and
    // flattened into what read as a misaligned edge across a 900-pixel shell.
    final drop = (size.width * 0.055).clamp(18.0, 44.0);

    // Small radii where the curve meets the vertical sides. Without them the
    // sweep arrives at the edge on a slope and leaves a visible kink.
    const corner = 18.0;

    return Path()
      ..moveTo(0, r)
      ..arcToPoint(Offset(r, 0), radius: Radius.circular(r))
      ..lineTo(size.width - r, 0)
      ..arcToPoint(Offset(size.width, r), radius: Radius.circular(r))
      ..lineTo(size.width, size.height - drop - corner)
      ..arcToPoint(
        Offset(size.width - corner, size.height - drop),
        radius: const Radius.circular(corner),
        clockwise: true,
      )
      // One control point at the midpoint, so the curve is symmetric and its
      // deepest point sits under the search field rather than off to one side.
      ..quadraticBezierTo(
        size.width / 2,
        size.height + drop,
        corner,
        size.height - drop,
      )
      ..arcToPoint(
        Offset(0, size.height - drop - corner),
        radius: const Radius.circular(corner),
        clockwise: true,
      )
      ..close();
  }

  @override
  bool shouldReclip(_SweptBottom old) => old.topRadius != topRadius;
}
