import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/material_symbols_icons.dart';

import '../../l10n/app_localizations.dart';
import '../theme/tokens.dart';
import '../widgets/common.dart';
import '../widgets/glass.dart';

/// Above this the app lays itself out for a desk; below it, for a hand.
const kWebBreakpoint = 900.0;

/// The desktop chrome: a standing sidebar instead of a bar under the thumb.
///
/// A tab bar exists because a thumb reaches the bottom of a phone. On a laptop
/// nothing reaches the bottom of the window, the pointer is already at the
/// left, and there is room to show all four destinations with their names at
/// once. Same screens, same data, same design language — a different shape for
/// a different set of hands.
class WebShell extends StatelessWidget {
  const WebShell({
    super.key,
    required this.child,
    required this.currentIndex,
    required this.onDestination,
  });

  final Widget child;
  final int currentIndex;
  final ValueChanged<int> onDestination;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final p = palette(context);

    final destinations = <({IconData icon, String label})>[
      (icon: Symbols.home_rounded, label: l.navHome),
      (icon: Symbols.auto_awesome_rounded, label: l.navMatches),
      (icon: Symbols.forum_rounded, label: l.navChat),
      (icon: Symbols.person_rounded, label: l.navProfile),
    ];

    return Scaffold(
      body: Row(
        children: [
          // Glass, not an opaque panel. The rail is chrome sitting over the
          // page, and the wallpaper's green corner now shows through it —
          // which is the whole reason the wallpaper went behind the app
          // rather than onto four screens.
          GlassSurface(
            level: GlassLevel.chrome,
            borderRadius: BorderRadius.zero,
            // Pinned to the left edge: a shadow there would only draw a dark
            // seam against the window frame.
            shadow: false,
            // Liquid, not merely frosted. The rail is the tallest glass in the
            // app and a pane that tall with no light down its edge reads as a
            // grey strip.
            specular: true,
            child: Container(
              width: 68,
              decoration: BoxDecoration(
                border: Border(right: BorderSide(color: p.hair)),
              ),
              child: SafeArea(
                right: false,
                child: Column(
                  children: [
                    const _Brand(),
                    const _RailDivider(),
                    // Posting is not a destination — it is the one thing the
                    // rail asks you to do — so it keeps the brand colour while
                    // every navigation tile stays neutral clay.
                    _RailButton(
                      icon: Symbols.add_rounded,
                      label: l.navCreate,
                      tone: p.give,
                      foreground: Colors.white,
                      onTap: () => context.push('/create'),
                    ),
                    const _RailDivider(),
                    for (final (index, d) in destinations.indexed)
                      _RailButton(
                        icon: d.icon,
                        label: d.label,
                        selected: index == currentIndex,
                        onTap: () => onDestination(index),
                      ),
                    const Spacer(),
                    const _RailDivider(),
                    _RailButton(
                      icon: Symbols.settings_rounded,
                      label: l.navSettings,
                      onTap: () => context.push('/settings'),
                    ),
                    Gap.h4,
                  ],
                ),
              ),
            ),
          ),
          // No `ColoredBox` here. It used to paint the canvas colour over this
          // half of the window, which was harmless while the page had no
          // wallpaper and became the reason the wallpaper was invisible
          // everywhere except behind the rail.
          Expanded(child: child),
        ],
      ),
    );
  }
}

class _Brand extends StatelessWidget {
  const _Brand();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(Gap.x2, Gap.x5, Gap.x2, 0),
      child: Center(child: const BrandMark(size: 40)),
    );
  }
}

/// One tile in the rail.
///
/// Clay rather than a filled rectangle. The selected tile is pressed into the
/// pane instead of being painted a colour: on a rail this narrow a coloured
/// block is the loudest thing on the screen, and the thing it is competing
/// with is the listing photographs.
class _RailButton extends StatelessWidget {
  const _RailButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.selected = false,
    this.tone,
    this.foreground,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool selected;
  final Color? tone;
  final Color? foreground;

  @override
  Widget build(BuildContext context) {
    final p = palette(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Gap.x1),
      child: ClayTile(
        size: 46,
        radius: 15,
        pressed: selected,
        tone: tone,
        tooltip: label,
        onTap: onTap,
        child: Icon(
          icon,
          size: Sizes.iconLg,
          fill: selected ? 1 : 0,
          color: foreground ?? (selected ? p.give : p.inkSoft),
        ),
      ),
    );
  }
}

/// The hairline that groups the rail.
///
/// Four destinations, a create button and a settings tile in one unbroken
/// column read as six equal choices. The rules say which of them belong
/// together — the same job the separators in a desktop toolbar do.
class _RailDivider extends StatelessWidget {
  const _RailDivider();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Gap.x4, vertical: Gap.x3),
      child: Divider(height: 1, thickness: 1, color: palette(context).hair),
    );
  }
}
