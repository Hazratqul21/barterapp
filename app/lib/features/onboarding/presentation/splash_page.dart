import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/common.dart';
import '../../../l10n/app_localizations.dart';

/// The first frame of the app.
///
/// It exists to decide where to go, not to stall: a returning user is sent on
/// as soon as the mark lands, and only somebody who has never opened the app
/// sees the three intro screens. The wordmark is the product in one glyph —
/// two arrows swapping places over a green-to-blue field.
class SplashPage extends ConsumerStatefulWidget {
  const SplashPage({super.key});

  @override
  ConsumerState<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends ConsumerState<SplashPage> {
  /// Long enough for the mark to finish its entrance, short enough that nobody
  /// reads it as a loading screen.
  static const _hold = Duration(milliseconds: 1100);

  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer(_hold, _leave);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _leave() {
    if (!mounted) return;
    final seen = ref.read(sessionStoreProvider).introSeen;
    context.go(seen ? '/home' : '/intro');
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final p = palette(context);

    return Scaffold(
      body: DecoratedBox(
        decoration: BoxDecoration(gradient: p.swapGradient),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // The same mark the intro shows in its corner, so it flies
              // there rather than vanishing and being replaced.
              const Hero(
                tag: BrandMark.heroTag,
                child: BrandMark(size: 104, onDark: true, animate: true),
              ).animate().scale(
                begin: const Offset(0.8, 0.8),
                end: const Offset(1, 1),
                duration: M3Motion.long2,
                curve: M3Motion.emphasizedDecelerate,
              ),
              Gap.h6,
              Text(
                    l.appName,
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      color: Colors.white,
                      letterSpacing: -0.5,
                    ),
                  )
                  .animate()
                  .fadeIn(delay: M3Motion.medium2, duration: M3Motion.medium3)
                  .slideY(
                    begin: 0.4,
                    end: 0,
                    delay: M3Motion.medium2,
                    duration: M3Motion.medium3,
                    curve: M3Motion.emphasizedDecelerate,
                  ),
            ],
          ),
        ),
      ),
    );
  }
}
