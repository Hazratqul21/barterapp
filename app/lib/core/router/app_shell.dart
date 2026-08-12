import 'package:animations/animations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/material_symbols_icons.dart';

import '../../l10n/app_localizations.dart';
import '../theme/app_theme.dart';
import '../theme/section_theme.dart';
import '../theme/tokens.dart';
import '../widgets/common.dart';
import '../widgets/glass.dart';
import 'web_shell.dart';

/// The four places this product is about, and the button that feeds it.
///
/// Two shapes for the same product. A tab bar exists because a thumb reaches
/// the bottom of a phone; on a laptop nothing reaches the bottom of the window,
/// so past [kWebBreakpoint] the destinations stand up the left-hand side
/// instead (`WebShell`). Same screens, same data, same design language.
///
/// Settings is absent from the phone bar: it is somewhere you go from your own
/// profile to change something, not a fifth destination. The desktop sidebar
/// has room for it at the foot, where it does not compete.
class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L.of(context);

    // Tell the wallpaper which section it is behind, after this frame so the
    // write never lands mid-build. Driven off `currentIndex` rather than the
    // tap handler so it stays in sync however navigation happened — a tab, a
    // deep link, or the back gesture.
    final section = AppSection.values[navigationShell.currentIndex];
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(sectionProvider.notifier).set(section);
    });

    final destinations = <({IconData icon, String label})>[
      (icon: Symbols.home_rounded, label: l.navHome),
      (icon: Symbols.auto_awesome_rounded, label: l.navMatches),
      (icon: Symbols.forum_rounded, label: l.navChat),
      (icon: Symbols.person_rounded, label: l.navProfile),
    ];

    // Destinations are peers, not steps: nothing slides sideways between them.
    // A fade-through says "a different place" without implying a direction.
    final body = PageTransitionSwitcher(
      duration: M3Motion.medium2,
      transitionBuilder: (child, animation, secondary) => FadeThroughTransition(
        animation: animation,
        secondaryAnimation: secondary,
        fillColor: Colors.transparent,
        child: child,
      ),
      child: KeyedSubtree(
        key: ValueKey(navigationShell.currentIndex),
        child: navigationShell,
      ),
    );

    if (MediaQuery.sizeOf(context).width >= kWebBreakpoint) {
      return WebShell(
        currentIndex: navigationShell.currentIndex,
        onDestination: _go,
        child: body,
      );
    }

    return Scaffold(
      // The body runs to the bottom of the screen so the list passes *behind*
      // the bar. Without this the bar has an opaque page under it and the
      // blur has nothing to work on — glass over nothing is just a tint.
      extendBody: true,
      body: body,
      // Creating a listing is the one thing the whole app is for, so it is the
      // centre of the bar — a raised green button, not a corner FAB — with two
      // destinations either side of it.
      bottomNavigationBar: _CreatorBar(
        destinations: destinations,
        currentIndex: navigationShell.currentIndex,
        onDestination: _go,
        onCreate: () {
          HapticFeedback.mediumImpact();
          context.push('/create');
        },
      ),
    );
  }

  void _go(int index) {
    // Tapping the active tab pops that branch back to its root, the way every
    // native tab bar behaves.
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }
}

/// The mobile bar: two destinations, the create button, two more destinations.
///
/// The create button is the centre of gravity because posting is the point of
/// the product. It is raised out of the bar so it reads as an action rather
/// than a fifth tab, and tapping it rises the create sheet up over the app —
/// the same vertical motion the route uses, so the button and the screen it
/// opens feel like one gesture.
class _CreatorBar extends StatelessWidget {
  const _CreatorBar({
    required this.destinations,
    required this.currentIndex,
    required this.onDestination,
    required this.onCreate,
  });

  final List<({IconData icon, String label})> destinations;
  final int currentIndex;
  final ValueChanged<int> onDestination;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);

    // Split the four destinations two and two around the centre button.
    return GlassSurface(
      level: GlassLevel.chrome,
      borderRadius: BorderRadius.zero,
      shadow: false,
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 64,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _Tab(
                icon: destinations[0].icon,
                label: destinations[0].label,
                selected: currentIndex == 0,
                onTap: () => onDestination(0),
              ),
              _Tab(
                icon: destinations[1].icon,
                label: destinations[1].label,
                selected: currentIndex == 1,
                onTap: () => onDestination(1),
              ),
              _CreateButton(label: l.navCreate, onTap: onCreate),
              _Tab(
                icon: destinations[2].icon,
                label: destinations[2].label,
                selected: currentIndex == 2,
                onTap: () => onDestination(2),
              ),
              _Tab(
                icon: destinations[3].icon,
                label: destinations[3].label,
                selected: currentIndex == 3,
                onTap: () => onDestination(3),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Tab extends StatelessWidget {
  const _Tab({
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
    final colour = selected ? p.give : p.inkFaint;

    return Expanded(
      child: InkResponse(
        onTap: onTap,
        radius: 36,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: Sizes.iconLg, fill: selected ? 1 : 0, color: colour),
            const SizedBox(height: 3),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelSmall?.copyWith(
                color: colour,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The raised centre button.
class _CreateButton extends StatefulWidget {
  const _CreateButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  State<_CreateButton> createState() => _CreateButtonState();
}

class _CreateButtonState extends State<_CreateButton> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final p = palette(context);

    return SizedBox(
      width: 76,
      child: Center(
        child: GestureDetector(
          onTapDown: (_) => setState(() => _down = true),
          onTapCancel: () => setState(() => _down = false),
          onTapUp: (_) {
            setState(() => _down = false);
            widget.onTap();
          },
          child: Tooltip(
            message: widget.label,
            // Lifts above the bar so it reads as an action, not a tab.
            child: AnimatedScale(
              scale: _down ? 0.9 : 1,
              duration: M3Motion.short3,
              curve: M3Motion.standard,
              child: Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  gradient: p.swapGradient,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: p.give.withValues(alpha: 0.4),
                      blurRadius: 16,
                      spreadRadius: -2,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: const Icon(
                  Symbols.add_rounded,
                  size: 30,
                  weight: 700,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
