import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/material_symbols_icons.dart';

import '../../../core/network/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/backgrounds.dart';
import '../../../core/widgets/common.dart';
import '../../../l10n/app_localizations.dart';

/// Three screens that answer one question: why is this not OLX?
///
/// Someone arriving from a classifieds app expects to type a price. The whole
/// product depends on them arriving at "I have spare X, I need Y" instead, so
/// that sentence is the first screen and everything after it follows from that.
/// Shown once ever — the flag survives signing out.
class IntroPage extends ConsumerStatefulWidget {
  const IntroPage({super.key});

  @override
  ConsumerState<IntroPage> createState() => _IntroPageState();
}

class _IntroPageState extends ConsumerState<IntroPage> {
  final _controller = PageController();
  int _page = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    await ref.read(sessionStoreProvider).markIntroSeen();
    if (mounted) context.go('/home');
  }

  void _next(int total) {
    if (_page >= total - 1) {
      _finish();
      return;
    }
    _controller.nextPage(
      duration: M3Motion.medium3,
      curve: M3Motion.emphasized,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final p = palette(context);
    final theme = Theme.of(context);

    final slides = <({Widget art, String title, String body})>[
      (art: const _SwapArt(), title: l.introTitle1, body: l.introBody1),
      (art: const _MatchArt(), title: l.introTitle2, body: l.introBody2),
      (art: const _TrustArt(), title: l.introTitle3, body: l.introBody3),
    ];

    final last = _page == slides.length - 1;

    return Scaffold(
      body: AuroraBackground(
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Column(
                children: [
                  Align(
                    alignment: AlignmentDirectional.centerEnd,
                    child: AnimatedOpacity(
                      duration: M3Motion.short4,
                      opacity: last ? 0 : 1,
                      child: TextButton(
                        onPressed: last ? null : _finish,
                        child: Text(
                          l.introSkip,
                          style: theme.textTheme.titleSmall?.copyWith(
                            color: p.inkSoft,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: PageView.builder(
                      controller: _controller,
                      onPageChanged: (i) => setState(() => _page = i),
                      itemCount: slides.length,
                      itemBuilder: (context, index) {
                        final slide = slides[index];
                        return Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: Gap.x6,
                          ),
                          // Drawing and sentence read as one block, sitting a
                          // little above centre. Splitting them with an Expanded
                          // pushed the picture to the top of the screen and left
                          // a gap in the middle that looked like missing content.
                          child: Column(
                            children: [
                              const Spacer(flex: 3),
                              slide.art,
                              Gap.h8,
                              Text(
                                slide.title,
                                textAlign: TextAlign.center,
                                style: theme.textTheme.headlineMedium,
                              ),
                              Gap.h3,
                              Text(
                                slide.body,
                                textAlign: TextAlign.center,
                                style: theme.textTheme.bodyLarge?.copyWith(
                                  color: p.inkSoft,
                                ),
                              ),
                              const Spacer(flex: 4),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      for (var i = 0; i < slides.length; i++)
                        AnimatedContainer(
                          duration: M3Motion.short4,
                          curve: M3Motion.standard,
                          margin: const EdgeInsets.symmetric(
                            horizontal: Gap.x1,
                          ),
                          width: i == _page ? 22 : 7,
                          height: 7,
                          decoration: BoxDecoration(
                            color: i == _page ? p.give : p.hair,
                            borderRadius: Radii.rFull,
                          ),
                        ),
                    ],
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      Gap.x6,
                      Gap.x6,
                      Gap.x6,
                      Gap.x5,
                    ),
                    child: FilledButton(
                      onPressed: () => _next(slides.length),
                      child: Text(last ? l.introStart : l.introNext),
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
}

// ─────────────────────────────────────────────────────────────────────────────
// Slide art
// ─────────────────────────────────────────────────────────────────────────────
// Built from the design system rather than shipped as images: three drawings
// that stay sharp at any size, follow the light and dark themes on their own,
// and add nothing to the download.

/// Slide 1 — two goods changing hands.
class _SwapArt extends StatelessWidget {
  const _SwapArt();

  @override
  Widget build(BuildContext context) {
    final p = palette(context);

    // Sized on both axes: a Stack inside a Center collapses to the width of its
    // unpositioned child, which put both tiles underneath the arrow badge.
    return SizedBox(
      width: 260,
      height: 200,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            left: 0,
            child:
                _GoodsTile(
                      icon: Symbols.laptop_mac_rounded,
                      color: p.give,
                      tint: p.giveSoft,
                    )
                    .animate()
                    .fadeIn(duration: M3Motion.long1)
                    .slideX(
                      begin: -0.35,
                      end: 0,
                      duration: M3Motion.long2,
                      curve: M3Motion.emphasizedDecelerate,
                    ),
          ),
          Positioned(
            right: 0,
            child:
                _GoodsTile(
                      icon: Symbols.handyman_rounded,
                      color: p.take,
                      tint: p.takeSoft,
                    )
                    .animate()
                    .fadeIn(delay: M3Motion.short3, duration: M3Motion.long1)
                    .slideX(
                      begin: 0.35,
                      end: 0,
                      delay: M3Motion.short3,
                      duration: M3Motion.long2,
                      curve: M3Motion.emphasizedDecelerate,
                    ),
          ),
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              gradient: p.swapGradient,
              shape: BoxShape.circle,
              boxShadow: Shadows.lifted,
            ),
            child: const Icon(
              Symbols.swap_horiz_rounded,
              color: Colors.white,
              size: 30,
              weight: 600,
            ),
          ).animate().scale(
            delay: M3Motion.medium2,
            begin: const Offset(0.4, 0.4),
            end: const Offset(1, 1),
            duration: M3Motion.long2,
            curve: M3Motion.emphasizedDecelerate,
          ),
        ],
      ),
    );
  }
}

/// Slide 2 — the matcher pairing two listings and scoring the fit.
class _MatchArt extends StatelessWidget {
  const _MatchArt();

  @override
  Widget build(BuildContext context) {
    final p = palette(context);
    final theme = Theme.of(context);

    return SizedBox(
      height: 200,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Grain for a tractor — the worked example the matcher was built
              // around, and the one a farmer recognises without reading.
              _GoodsTile(
                icon: Symbols.grass_rounded,
                color: p.give,
                tint: p.giveSoft,
                size: 84,
              ),
              Gap.w4,
              _GoodsTile(
                icon: Symbols.agriculture_rounded,
                color: p.take,
                tint: p.takeSoft,
                size: 84,
              ),
            ],
          ),
          Gap.h5,
          Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: Gap.x4,
                  vertical: Gap.x2,
                ),
                decoration: BoxDecoration(
                  color: p.moneySoft,
                  borderRadius: Radii.rFull,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Symbols.auto_awesome_rounded,
                      size: Sizes.iconMd,
                      color: p.money,
                    ),
                    Gap.w2,
                    Text(
                      '86%',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: p.money,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              )
              .animate()
              .fadeIn(delay: M3Motion.medium2, duration: M3Motion.medium3)
              .scale(
                delay: M3Motion.medium2,
                begin: const Offset(0.7, 0.7),
                end: const Offset(1, 1),
                duration: M3Motion.long1,
                curve: M3Motion.emphasizedDecelerate,
              ),
        ],
      ),
    );
  }
}

/// Slide 3 — the trust that makes a stranger's offer worth taking.
class _TrustArt extends StatelessWidget {
  const _TrustArt();

  @override
  Widget build(BuildContext context) {
    final p = palette(context);

    return SizedBox(
      width: 260,
      height: 200,
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 148,
            height: 148,
            decoration: BoxDecoration(
              color: p.giveSoft,
              shape: BoxShape.circle,
            ),
          ),
          Icon(
                Symbols.verified_user_rounded,
                size: 76,
                color: p.give,
                weight: 500,
              )
              .animate()
              .scale(
                begin: const Offset(0.6, 0.6),
                end: const Offset(1, 1),
                duration: M3Motion.long2,
                curve: M3Motion.emphasizedDecelerate,
              )
              .fadeIn(duration: M3Motion.medium3),
          for (final (index, angle) in <(int, Offset)>[
            (0, Offset(-1, -0.72)),
            (1, Offset(1, -0.72)),
            (2, Offset(0, 1)),
          ])
            Transform.translate(
              offset: Offset(angle.dx * 86, angle.dy * 86),
              child:
                  Container(
                        padding: const EdgeInsets.all(Gap.x2),
                        decoration: BoxDecoration(
                          color: p.moneySoft,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Symbols.star_rounded,
                          size: Sizes.iconMd,
                          color: p.money,
                          fill: 1,
                        ),
                      )
                      .animate()
                      .fadeIn(
                        delay: Duration(milliseconds: 250 + index * 110),
                        duration: M3Motion.medium2,
                      )
                      .scale(
                        delay: Duration(milliseconds: 250 + index * 110),
                        begin: const Offset(0.4, 0.4),
                        end: const Offset(1, 1),
                        duration: M3Motion.medium4,
                        curve: M3Motion.emphasizedDecelerate,
                      ),
            ),
        ],
      ),
    );
  }
}

/// One piece of goods: a rounded tile with the thing's symbol in it.
class _GoodsTile extends StatelessWidget {
  const _GoodsTile({
    required this.icon,
    required this.color,
    required this.tint,
    this.size = 104,
  });

  final IconData icon;
  final Color color;
  final Color tint;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: tint,
        borderRadius: Radii.rLg,
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Icon(icon, size: size * 0.42, color: color),
    );
  }
}
