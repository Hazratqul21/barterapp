import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/material_symbols_icons.dart';

import '../../l10n/app_localizations.dart';
import '../art/girih.dart';
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
            child: Container(
              width: 248,
              decoration: BoxDecoration(
                border: Border(right: BorderSide(color: p.hair)),
              ),
              child: SafeArea(
                right: false,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const _Brand(),
                    Gap.h5,
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: Gap.x4),
                      child: FilledButton.icon(
                        onPressed: () => context.push('/create'),
                        icon: const Icon(Symbols.add_rounded, size: 22),
                        label: Text(l.navCreate),
                        style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(Sizes.buttonMd),
                        ),
                      ),
                    ),
                    Gap.h6,
                    for (final (index, d) in destinations.indexed)
                      _NavItem(
                        icon: d.icon,
                        label: d.label,
                        selected: index == currentIndex,
                        onTap: () => onDestination(index),
                      ),
                    const Spacer(),
                    _NavItem(
                      icon: Symbols.settings_rounded,
                      label: l.navSettings,
                      selected: false,
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
    final l = L.of(context);
    final p = palette(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(Gap.x4, Gap.x6, Gap.x4, 0),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              gradient: p.swapGradient,
              borderRadius: Radii.rSm,
            ),
            clipBehavior: Clip.antiAlias,
            child: const Stack(
              alignment: Alignment.center,
              children: [
                GirihField(color: Colors.white, opacity: 0.2, cell: 26),
                Icon(
                  Symbols.swap_horiz_rounded,
                  color: Colors.white,
                  size: 22,
                  weight: 600,
                ),
              ],
            ),
          ),
          Gap.w3,
          Text(l.appName, style: Theme.of(context).textTheme.titleLarge),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = palette(context);
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: Gap.x3,
        vertical: Gap.x1 / 2,
      ),
      child: Material(
        color: selected ? p.giveSoft : Colors.transparent,
        borderRadius: Radii.rMd,
        child: InkWell(
          onTap: onTap,
          borderRadius: Radii.rMd,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: Gap.x3,
              vertical: Gap.x3,
            ),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: Sizes.iconLg,
                  fill: selected ? 1 : 0,
                  color: selected ? p.give : p.inkSoft,
                ),
                Gap.w3,
                Text(
                  label,
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: selected ? p.give : p.inkSoft,
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
