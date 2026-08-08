import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_client.dart';
import '../../../core/art/illustrations.dart';
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
// Three drawings from `core/art/illustrations.dart` — paths, not icons in
// boxes and not image files. They stay sharp at any size, follow the light and
// dark themes on their own, and add nothing to the download.

/// Slide 1 — two crates changing hands, with a coin for the difference.
class _SwapArt extends StatelessWidget {
  const _SwapArt();

  @override
  Widget build(BuildContext context) {
    return const SwapIllustration()
        .animate()
        .fadeIn(duration: M3Motion.long1)
        .scale(
          begin: const Offset(0.9, 0.9),
          end: const Offset(1, 1),
          duration: M3Motion.long2,
          curve: M3Motion.emphasizedDecelerate,
        );
  }
}

/// Slide 2 — two halves that lock together.
class _MatchArt extends StatelessWidget {
  const _MatchArt();

  @override
  Widget build(BuildContext context) {
    return const MatchIllustration()
        .animate()
        .fadeIn(duration: M3Motion.long1)
        .scale(
          begin: const Offset(0.9, 0.9),
          end: const Offset(1, 1),
          duration: M3Motion.long2,
          curve: M3Motion.emphasizedDecelerate,
        );
  }
}

/// Slide 3 — a shield of tilework, earned in stars.
class _TrustArt extends StatelessWidget {
  const _TrustArt();

  @override
  Widget build(BuildContext context) {
    return const TrustIllustration()
        .animate()
        .fadeIn(duration: M3Motion.long1)
        .scale(
          begin: const Offset(0.9, 0.9),
          end: const Offset(1, 1),
          duration: M3Motion.long2,
          curve: M3Motion.emphasizedDecelerate,
        );
  }
}
