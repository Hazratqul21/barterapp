import 'package:animations/animations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/material_symbols_icons.dart';

import '../../l10n/app_localizations.dart';
import '../theme/app_theme.dart';
import '../theme/section_theme.dart';
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
      floatingActionButton:
          FloatingActionButton(
                heroTag: 'create-fab',
                tooltip: l.navCreate,
                onPressed: () => context.push('/create'),
                child: const Icon(Symbols.add_rounded, size: 26, weight: 600),
              )
              .animate()
              .scale(
                begin: Offset.zero,
                end: const Offset(1, 1),
                duration: M3Motion.medium4,
                curve: M3Motion.emphasizedDecelerate,
              )
              .fadeIn(duration: M3Motion.medium2),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      bottomNavigationBar: GlassSurface(
        level: GlassLevel.chrome,
        borderRadius: BorderRadius.zero,
        shadow: false,
        child: NavigationBar(
          // Transparent so the glass beneath shows: `NavigationBar` paints its
          // own surface by default and would cover it completely.
          backgroundColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          selectedIndex: navigationShell.currentIndex,
          onDestinationSelected: _go,
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          destinations: [
            for (final d in destinations)
              NavigationDestination(
                icon: Icon(d.icon),
                selectedIcon: Icon(d.icon, fill: 1),
                label: d.label,
              ),
          ],
        ),
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
