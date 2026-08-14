import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '../router/web_shell.dart' show kWebBreakpoint;
import '../theme/tokens.dart';
import 'backgrounds.dart';
import 'common.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Neo-glassmorphism
// ─────────────────────────────────────────────────────────────────────────────
// Frosted glass only works when there is something behind it worth blurring.
// That is why this arrives after the wallpaper and not before: the app now
// paints one aurora and one tile lattice beneath every route, so a panel that
// blurs its backdrop picks up the green and blue of the page it is floating
// over instead of turning into flat grey.
//
// Four things, and all four have to be present or it reads as "a translucent
// box" rather than as glass:
//
//   1. **Backdrop blur.** What makes it glass rather than a tint.
//   2. **A graded fill.** Brighter at the top-left, thinner at the
//      bottom-right, so the pane has an implied light source.
//   3. **A lit rim.** One hairline whose brightness runs the same diagonal.
//      This is the detail people read as "expensive"; a uniform border does
//      not do it.
//   4. **A wide, weak shadow.** Glass floats. A tight dark drop shadow makes
//      it look stuck on.
//
// Used for chrome only — sheets, the web sidebar, bars that content scrolls
// under. Never for a card carrying text someone has to read: a listing card
// stays opaque, because legibility beats atmosphere every time.

/// How hard the frost is. Kept as named steps so the whole app agrees.
enum GlassLevel {
  /// Bars and rails that content passes behind.
  chrome,

  /// Sheets and dialogs that sit over a dimmed page.
  panel,
}

/// A pane of frosted glass.
class GlassSurface extends StatelessWidget {
  const GlassSurface({
    super.key,
    required this.child,
    this.borderRadius = const BorderRadius.all(Radius.circular(Radii.lg)),
    this.level = GlassLevel.panel,
    this.shadow = true,
    this.specular = false,
  });

  final Widget child;
  final BorderRadius borderRadius;
  final GlassLevel level;

  /// Off for a pane pinned to an edge, where a shadow on the pinned side has
  /// nothing to fall on and only shows up as a dark seam.
  final bool shadow;

  /// The band of light that runs down a pane of real glass.
  ///
  /// This is the difference between frosted glass and *liquid* glass. Frost is
  /// a uniform blur; liquid glass has a thickness, and thickness catches the
  /// light along one edge and lets it go along the other. One soft diagonal
  /// sweep is enough — a second one reads as a smudge.
  final bool specular;

  /// Blur radius per level.
  ///
  /// Lower on the web on purpose. `BackdropFilter` is the single most
  /// expensive thing in this app to paint, and on the web every blurred pixel
  /// is a saved layer the browser composites each frame; at desktop window
  /// sizes a phone-strength blur is what turns scrolling gritty.
  double get _blur => switch (level) {
    GlassLevel.chrome => kIsWeb ? 16 : 26,
    GlassLevel.panel => kIsWeb ? 24 : 36,
  };

  @override
  Widget build(BuildContext context) {
    final p = palette(context);

    // Dark glass is a smoked pane, not a white one dimmed: tinting a dark
    // surface with white washes the colour out of everything behind it.
    final base = p.isDark ? const Color(0xFF141B18) : Colors.white;
    final (nearAlpha, farAlpha) = p.isDark
        ? (0.62, 0.44)
        : (0.72, 0.52);

    final rimNear = p.isDark ? 0.20 : 0.85;
    final rimFar = p.isDark ? 0.05 : 0.22;

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        boxShadow: shadow
            ? [
                BoxShadow(
                  color: p.isDark
                      ? Colors.black.withValues(alpha: 0.42)
                      : const Color(0xFF12211A).withValues(alpha: 0.13),
                  blurRadius: 36,
                  spreadRadius: -6,
                  offset: const Offset(0, 14),
                ),
              ]
            : null,
      ),
      child: ClipRRect(
        borderRadius: borderRadius,
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: _blur, sigmaY: _blur),
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: borderRadius,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  base.withValues(alpha: nearAlpha),
                  base.withValues(alpha: farAlpha),
                ],
              ),
            ),
            child: Stack(
              children: [
                if (specular)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: borderRadius,
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Colors.white.withValues(
                                alpha: p.isDark ? 0.10 : 0.55,
                              ),
                              Colors.white.withValues(alpha: 0),
                              Colors.white.withValues(alpha: 0),
                              Colors.white.withValues(
                                alpha: p.isDark ? 0.04 : 0.18,
                              ),
                            ],
                            // The band sits in the upper third and fades out
                            // well before the middle, so it lights the edge
                            // rather than washing the whole pane.
                            stops: const [0.0, 0.28, 0.72, 1.0],
                          ),
                        ),
                      ),
                    ),
                  ),
                child,
                // The rim goes last so it is never covered by content, and
                // takes no hits so it cannot swallow a tap.
                Positioned.fill(
                  child: IgnorePointer(
                    child: CustomPaint(
                      painter: _RimPainter(
                        borderRadius: borderRadius,
                        near: Colors.white.withValues(alpha: rimNear),
                        far: Colors.white.withValues(alpha: rimFar),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The hairline around a pane, lit along one diagonal.
class _RimPainter extends CustomPainter {
  const _RimPainter({
    required this.borderRadius,
    required this.near,
    required this.far,
  });

  final BorderRadius borderRadius;
  final Color near;
  final Color far;

  @override
  void paint(Canvas canvas, Size size) {
    // Inset by half the stroke so the line lands inside the clip instead of
    // being shaved in half by it.
    final rect = Offset.zero & size;
    final rrect = borderRadius.toRRect(rect).deflate(0.5);

    canvas.drawRRect(
      rrect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [near, far],
          // The light falls off early, so most of the rim is quiet and only
          // the top-left corner reads as catching it.
          stops: const [0.0, 0.55],
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(_RimPainter old) =>
      old.near != near || old.far != far || old.borderRadius != borderRadius;
}

// ─────────────────────────────────────────────────────────────────────────────
// Sheet skins
// ─────────────────────────────────────────────────────────────────────────────

/// What a sheet is made of.
///
/// The default is glass, and glass is right for most of them: a sheet is
/// chrome over a page, and letting the page show through is what tells someone
/// they have not left it. But a sheet is also the app's most ceremonial
/// surface — the counter-offer, the review, the thing that closes a deal — and
/// those earn a treatment of their own.
///
/// So the skin is a parameter rather than a constant, and [SheetSkin.custom]
/// takes any widget at all: a photograph, a gradient, one of the drawn
/// illustrations. Whatever it is gets clipped to the sheet's corners and put
/// under the content, and the glass keeps its rim and its shadow on top.
sealed class SheetSkin {
  const SheetSkin();

  /// Frosted, showing the page behind it. The default.
  const factory SheetSkin.glass() = GlassSkin;

  /// The app's own wallpaper, carried into the sheet: the two blooms and the
  /// tile lattice, so the panel looks cut from the same cloth as the page
  /// rather than laid on top of it.
  const factory SheetSkin.wallpaper({double intensity}) = WallpaperSkin;

  /// Anything you like behind the content.
  const factory SheetSkin.custom(Widget background) = CustomSkin;
}

final class GlassSkin extends SheetSkin {
  const GlassSkin();
}

final class WallpaperSkin extends SheetSkin {
  const WallpaperSkin({this.intensity = 1.0});

  final double intensity;
}

final class CustomSkin extends SheetSkin {
  const CustomSkin(this.background);

  final Widget background;
}

/// A sheet's shell: the skin, then the content, in that order.
class _Skinned extends StatelessWidget {
  const _Skinned({
    required this.skin,
    required this.borderRadius,
    required this.child,
  });

  final SheetSkin skin;
  final BorderRadius borderRadius;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return switch (skin) {
      GlassSkin() => GlassSurface(
        borderRadius: borderRadius,
        specular: true,
        child: child,
      ),
      // The wallpaper is opaque, so the glass above it would have nothing left
      // to blur. It keeps the rim and the shadow — the parts that make the
      // panel float — and drops the frost.
      WallpaperSkin(:final intensity) => _Framed(
        borderRadius: borderRadius,
        background: AuroraBackground(
          intensity: intensity,
          child: const SizedBox.expand(),
        ),
        child: child,
      ),
      CustomSkin(:final background) => _Framed(
        borderRadius: borderRadius,
        background: background,
        child: child,
      ),
    };
  }
}

/// An opaque skin, given the same rim and shadow the glass has.
class _Framed extends StatelessWidget {
  const _Framed({
    required this.borderRadius,
    required this.background,
    required this.child,
  });

  final BorderRadius borderRadius;
  final Widget background;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final p = palette(context);

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        boxShadow: [
          BoxShadow(
            color: p.isDark
                ? Colors.black.withValues(alpha: 0.42)
                : const Color(0xFF12211A).withValues(alpha: 0.13),
            blurRadius: 36,
            spreadRadius: -6,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: borderRadius,
        child: Stack(
          children: [
            Positioned.fill(child: IgnorePointer(child: background)),
            child,
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                  painter: _RimPainter(
                    borderRadius: borderRadius,
                    near: Colors.white.withValues(
                      alpha: p.isDark ? 0.20 : 0.85,
                    ),
                    far: Colors.white.withValues(alpha: p.isDark ? 0.05 : 0.22),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Sheets
// ─────────────────────────────────────────────────────────────────────────────

/// Open a sheet, and let the platform decide what a sheet is.
///
/// On a phone it is a bottom sheet you drag: it starts part-height, stretches
/// to [maxSize] when pulled up, and closes when flung down. The list inside it
/// is handed the sheet's own `ScrollController`, which is what joins the two
/// gestures — without that wiring, dragging the list scrolls it and dragging
/// the sheet moves it, and the seam between the two is exactly where a sheet
/// feels cheap.
///
/// On a wide window it is a centred panel instead. Drag-to-dismiss is a thumb
/// gesture; asking someone to fling a panel down with a mouse is a phone
/// interaction wearing a desktop costume. The [builder] is unchanged either
/// way, so call sites never branch on width.
Future<T?> showBarterSheet<T>({
  required BuildContext context,
  required String title,
  required Widget Function(BuildContext context, ScrollController controller)
  builder,
  double initialSize = 0.58,
  double minSize = 0.28,
  double maxSize = 0.92,
  Widget? action,
  SheetSkin skin = const SheetSkin.glass(),
}) {
  final wide = MediaQuery.sizeOf(context).width >= kWebBreakpoint;
  final barrier = Colors.black.withValues(alpha: wide ? 0.42 : 0.34);

  if (wide) {
    return showDialog<T>(
      context: context,
      barrierColor: barrier,
      builder: (context) => _WidePanel(
        title: title,
        action: action,
        builder: builder,
        skin: skin,
      ),
    );
  }

  return showModalBottomSheet<T>(
    context: context,
    // Both required for a draggable sheet: the height has to be ours to set,
    // and the default sheet background would paint an opaque rectangle over
    // the glass and its rounded corners.
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: barrier,
    useSafeArea: true,
    // The theme turns Material's own handle on for every sheet in the app.
    // Ours lives inside the glass, where it belongs; leaving both on drew two
    // bars, one floating above the pane on nothing.
    showDragHandle: false,
    builder: (context) => _DragSheet(
      title: title,
      action: action,
      builder: builder,
      skin: skin,
      initialSize: initialSize,
      minSize: minSize,
      maxSize: maxSize,
    ),
  );
}

class _DragSheet extends StatelessWidget {
  const _DragSheet({
    required this.title,
    required this.action,
    required this.builder,
    required this.initialSize,
    required this.minSize,
    required this.maxSize,
    required this.skin,
  });

  final String title;
  final Widget? action;
  final Widget Function(BuildContext, ScrollController) builder;
  final double initialSize;
  final double minSize;
  final double maxSize;
  final SheetSkin skin;

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: initialSize,
      minChildSize: minSize,
      maxChildSize: maxSize,
      // Snapping is what separates a sheet that feels engineered from one that
      // stops wherever the finger left it. Released between two stops, it
      // settles onto the nearer one.
      snap: true,
      snapSizes: [initialSize, maxSize],
      expand: false,
      builder: (context, controller) => _Skinned(
        skin: skin,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(Radii.xl),
        ),
        child: Column(
          children: [
            const _DragHandle(),
            _SheetHeader(title: title, action: action),
            Expanded(child: builder(context, controller)),
          ],
        ),
      ),
    );
  }
}

/// The bar at the top of a sheet.
///
/// It is not decoration: it is the only thing telling someone the panel can be
/// moved at all. A sheet without one gets treated as a fixed dialog, and the
/// drag gesture goes undiscovered.
class _DragHandle extends StatelessWidget {
  const _DragHandle();

  @override
  Widget build(BuildContext context) {
    final p = palette(context);
    return Padding(
      padding: const EdgeInsets.only(top: Gap.x3, bottom: Gap.x1),
      child: Center(
        child: Container(
          width: 40,
          height: 5,
          decoration: BoxDecoration(
            color: p.inkFaint.withValues(alpha: 0.55),
            borderRadius: Radii.rFull,
          ),
        ),
      ),
    );
  }
}

class _SheetHeader extends StatelessWidget {
  const _SheetHeader({required this.title, this.action, this.onClose});

  final String title;
  final Widget? action;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(
        Gap.x5,
        onClose == null ? Gap.x3 : Gap.x5,
        onClose == null ? Gap.x5 : Gap.x3,
        Gap.x3,
      ),
      child: Row(
        children: [
          Expanded(child: Text(title, style: theme.textTheme.titleLarge)),
          ?action,
          if (onClose != null)
            IconButton(
              onPressed: onClose,
              icon: const Icon(Icons.close_rounded),
              tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
            ),
        ],
      ),
    );
  }
}

/// The wide-window shape: a panel in the middle of the screen.
class _WidePanel extends StatefulWidget {
  const _WidePanel({
    required this.title,
    required this.action,
    required this.builder,
    required this.skin,
  });

  final String title;
  final Widget? action;
  final Widget Function(BuildContext, ScrollController) builder;
  final SheetSkin skin;

  @override
  State<_WidePanel> createState() => _WidePanelState();
}

class _WidePanelState extends State<_WidePanel> {
  /// The same contract the drag sheet gives the builder, so one [builder]
  /// works in both shapes.
  final _controller = ScrollController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.sizeOf(context).height;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(Gap.x6),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 560,
            // Never taller than most of the window, and never so short that a
            // list inside it shows two rows and a scrollbar.
            maxHeight: (height * 0.82).clamp(320.0, 720.0),
          ),
          child: _Skinned(
            skin: widget.skin,
            borderRadius: const BorderRadius.all(Radius.circular(Radii.xl)),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _SheetHeader(
                  title: widget.title,
                  action: widget.action,
                  onClose: () => Navigator.of(context).pop(),
                ),
                Flexible(child: widget.builder(context, _controller)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A short sheet: a form, or a handful of choices.
///
/// Separate from [showBarterSheet] because a draggable sheet is the wrong
/// shape for content that has a natural height. Asking someone to drag a
/// two-line menu open, or leaving it stretched to 58% of the screen with
/// nothing in the lower half, is the mistake that makes an app feel like it
/// reached for the same component twice.
///
/// It still carries the handle and still closes on a downward fling — those
/// are the gestures people arrive expecting — but it is only ever as tall as
/// what is inside it, and it lifts clear of the keyboard when a field in it
/// takes focus.
Future<T?> showBarterPanel<T>({
  required BuildContext context,
  required String title,
  required WidgetBuilder builder,
  String? subtitle,
  SheetSkin skin = const SheetSkin.glass(),
}) {
  final wide = MediaQuery.sizeOf(context).width >= kWebBreakpoint;
  final barrier = Colors.black.withValues(alpha: wide ? 0.42 : 0.34);

  if (wide) {
    return showDialog<T>(
      context: context,
      barrierColor: barrier,
      builder: (context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(Gap.x6),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: _Skinned(
              skin: skin,
              borderRadius: const BorderRadius.all(Radius.circular(Radii.xl)),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _SheetHeader(
                    title: title,
                    onClose: () => Navigator.of(context).pop(),
                  ),
                  Flexible(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(
                        Gap.x5,
                        0,
                        Gap.x5,
                        Gap.x5,
                      ),
                      child: _PanelBody(subtitle: subtitle, builder: builder),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: barrier,
    useSafeArea: true,
    // The theme turns Material's own handle on for every sheet in the app.
    // Ours lives inside the glass, where it belongs; leaving both on drew two
    // bars, one floating above the pane on nothing.
    showDragHandle: false,
    builder: (context) => _Skinned(
      skin: skin,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(Radii.xl)),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const _DragHandle(),
            _SheetHeader(title: title),
            Padding(
              // `viewInsets` is the keyboard. Without it the field a panel
              // exists to hold ends up behind the keys that are filling it.
              padding: EdgeInsets.fromLTRB(
                Gap.x5,
                0,
                Gap.x5,
                Gap.x5 + MediaQuery.viewInsetsOf(context).bottom,
              ),
              child: _PanelBody(subtitle: subtitle, builder: builder),
            ),
          ],
        ),
      ),
    ),
  );
}

class _PanelBody extends StatelessWidget {
  const _PanelBody({required this.subtitle, required this.builder});

  final String? subtitle;
  final WidgetBuilder builder;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (subtitle != null) ...[
          Text(
            subtitle!,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: palette(context).inkSoft),
          ),
          Gap.h4,
        ],
        builder(context),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Clay
// ─────────────────────────────────────────────────────────────────────────────

/// A soft, moulded tile — the thing you actually press.
///
/// Glass and clay do different jobs and the difference is the point. Glass is
/// the pane a panel is made of: transparent, cool, and it belongs to the
/// window. Clay is the object sitting on that pane: opaque, warm, and it
/// belongs to the hand. Putting both on the same surface is what makes these
/// styles look like a mood board rather than a product, so the rail is glass
/// and only the tiles inside it are clay.
///
/// Two states, and they are opposites on purpose:
///
/// * **Raised** — light from the top-left, shadow to the bottom-right, and a
///   fill that runs pale to deep the same way. The tile stands off the pane.
/// * **Pressed** — every one of those reversed, plus a real inner shadow
///   painted inside the clip. This is the neumorphic half: the tile is not
///   highlighted, it is *pushed into* the surface, which reads as "you are
///   here" without needing a colour to say so.
class ClayTile extends StatelessWidget {
  const ClayTile({
    super.key,
    required this.child,
    this.pressed = false,
    this.size = 48,
    this.radius = 16,
    this.tone,
    this.onTap,
    this.tooltip,
  });

  final Widget child;

  /// Pushed into the surface rather than standing on it.
  final bool pressed;

  final double size;
  final double radius;

  /// Tints the clay. Left null it takes the page's own surface, which is what
  /// keeps a row of tiles quiet enough to read as one control.
  final Color? tone;

  final VoidCallback? onTap;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final p = palette(context);
    final base = tone ?? (p.isDark ? const Color(0xFF1B2420) : p.canvas);

    // The two lights. On a dark theme the "light" is a lifted grey rather than
    // white — white on near-black reads as a scratch, not as a highlight.
    final lit = p.isDark
        ? Colors.white.withValues(alpha: 0.06)
        : Colors.white.withValues(alpha: 0.95);
    final shade = p.isDark
        ? Colors.black.withValues(alpha: 0.55)
        : const Color(0xFF12211A).withValues(alpha: 0.13);

    final shape = BorderRadius.circular(radius);

    final surface = DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: shape,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: pressed
              ? [
                  Color.lerp(base, Colors.black, p.isDark ? 0.18 : 0.06)!,
                  base,
                ]
              : [Color.lerp(base, Colors.white, p.isDark ? 0.06 : 0.65)!, base],
        ),
        boxShadow: pressed
            ? null
            : [
                BoxShadow(color: shade, blurRadius: 10, offset: const Offset(3, 4)),
                BoxShadow(color: lit, blurRadius: 10, offset: const Offset(-3, -4)),
              ],
      ),
      child: SizedBox(
        width: size,
        height: size,
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (pressed)
              Positioned.fill(
                child: IgnorePointer(
                  child: ClipRRect(
                    borderRadius: shape,
                    child: CustomPaint(
                      painter: _InsetShadowPainter(
                        radius: radius,
                        shade: shade,
                        lit: lit,
                      ),
                    ),
                  ),
                ),
              ),
            child,
          ],
        ),
      ),
    );

    final tappable = onTap == null
        ? surface
        : Material(
            color: Colors.transparent,
            borderRadius: shape,
            clipBehavior: Clip.antiAlias,
            child: InkWell(onTap: onTap, borderRadius: shape, child: surface),
          );

    return tooltip == null
        ? tappable
        : Tooltip(message: tooltip!, preferBelow: false, child: tappable);
  }
}

/// The inner shadow of a pressed tile.
///
/// Flutter has no inner shadow, so this strokes the tile's own outline with a
/// blurred brush from inside the clip: the dark half offset down-right, the
/// light half up-left. Two strokes, and the tile reads as a dent.
class _InsetShadowPainter extends CustomPainter {
  const _InsetShadowPainter({
    required this.radius,
    required this.shade,
    required this.lit,
  });

  final double radius;
  final Color shade;
  final Color lit;

  @override
  void paint(Canvas canvas, Size size) {
    final rrect = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(radius),
    );

    void stroke(Color color, Offset shift) {
      canvas.save();
      canvas.translate(shift.dx, shift.dy);
      canvas.drawRRect(
        rrect,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 5
          ..color = color
          ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 4),
      );
      canvas.restore();
    }

    stroke(shade, const Offset(2, 2.5));
    stroke(lit, const Offset(-2, -2.5));
  }

  @override
  bool shouldRepaint(_InsetShadowPainter old) =>
      old.shade != shade || old.lit != lit || old.radius != radius;
}
