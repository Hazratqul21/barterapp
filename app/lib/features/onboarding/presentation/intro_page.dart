import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/tokens.dart';
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

    final slides = <({String imagePath, String title, String body})>[
      (
        imagePath: 'assets/images/intro_swap.png',
        title: l.introTitle1,
        body: l.introBody1,
      ),
      (
        imagePath: 'assets/images/intro_match.png',
        title: l.introTitle2,
        body: l.introBody2,
      ),
      (
        imagePath: 'assets/images/intro_trust.png',
        title: l.introTitle3,
        body: l.introBody3,
      ),
    ];

    final last = _page == slides.length - 1;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.only(left: Gap.x5),
                  child: Row(
                    children: [
                      // The mark arrives here from the centre of the splash.
                      // It also gives these three screens a sender: without
                      // it the intro was an unbranded slideshow between the
                      // logo and the app.
                      const Hero(
                        tag: BrandMark.heroTag,
                        child: BrandMark(size: 36),
                      ),
                      const Spacer(),
                      AnimatedOpacity(
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
                    ],
                  ),
                ),
                Expanded(
                  child: PageView.builder(
                    controller: _controller,
                    onPageChanged: (i) => setState(() => _page = i),
                    itemCount: slides.length,
                    itemBuilder: (context, index) {
                      final slide = slides[index];
                      return LayoutBuilder(
                        builder: (context, constraints) {
                          final double vh = constraints.maxHeight;
                          final double vw = constraints.maxWidth;
                          final double targetHeight = (vh * 0.30).clamp(
                            210.0,
                            270.0,
                          );
                          final double targetWidth = vw < 300.0 ? vw : 300.0;

                          return SingleChildScrollView(
                            child: ConstrainedBox(
                              constraints: BoxConstraints(minHeight: vh),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: Gap.x6,
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Gap.h4,
                                    SizedBox(
                                      height: targetHeight,
                                      width: targetWidth,
                                      child: Image.asset(
                                        slide.imagePath,
                                        fit: BoxFit.contain,
                                        filterQuality: FilterQuality.high,
                                        semanticLabel: slide.title,
                                      ),
                                    ),
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
                                      style: theme.textTheme.bodyLarge
                                          ?.copyWith(color: p.inkSoft),
                                    ),
                                    const SizedBox(height: Gap.x8),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
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
                        margin: const EdgeInsets.symmetric(horizontal: Gap.x1),
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
    );
  }
}

// End of file
