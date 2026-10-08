import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_client.dart';
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
      body: Container(
        width: double.infinity,
        height: double.infinity,
        color: p.canvas,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Hero(
                tag: BrandMark.heroTag,
                child: BrandMark(size: 100, animate: true),
              ),
              Gap.h6,
              Text(
                l.appName,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.8,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
