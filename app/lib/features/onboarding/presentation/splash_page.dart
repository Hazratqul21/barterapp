import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/common.dart';
import '../../../l10n/app_localizations.dart';

class SplashPage extends ConsumerStatefulWidget {
  const SplashPage({super.key});

  @override
  ConsumerState<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends ConsumerState<SplashPage> {
  // Prevent a one-frame flash while routing, but never keep someone here just
  // to finish decorative motion.
  static const _minimumDisplay = Duration(milliseconds: 900);
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer(_minimumDisplay, _leave);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // The splash shows for under a second: decode the mark now so it is on
    // the first frame rather than arriving halfway through.
    precacheImage(
      const AssetImage('assets/brand/mab-wordmark-gold.png'),
      context,
    );
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

    // Olive ground and gold letters, as on the logo and the native launch
    // screen before it, so opening the app is one continuous image.
    return Scaffold(
      backgroundColor: BrandColors.olive900,
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0, -0.15),
            radius: 0.9,
            colors: [BrandColors.olive600Glow, BrandColors.olive900],
          ),
        ),
        child: SizedBox.expand(
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Hero(
                  tag: BrandMark.heroTag,
                  child: BrandMark(size: 72, onDark: true, animate: true),
                ),
                Gap.h6,
                Text(
                  l.splashTagline,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: BrandColors.goldLight,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.6,
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
