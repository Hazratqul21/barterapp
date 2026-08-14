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

class SplashPage extends ConsumerStatefulWidget {
  const SplashPage({super.key});

  @override
  ConsumerState<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends ConsumerState<SplashPage> {
  static const _hold = Duration(milliseconds: 1500);
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
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(gradient: p.swapGradient),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Hero(
                tag: BrandMark.heroTag,
                child: BrandMark(size: 112, onDark: true, animate: true),
              ).animate().scale(
                begin: const Offset(0.7, 0.7),
                end: const Offset(1, 1),
                duration: 600.ms,
                curve: M3Motion.emphasizedDecelerate,
              ),
              Gap.h6,
              Text(
                l.appName,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.8,
                ),
              ).animate().fadeIn(delay: 300.ms).slideY(begin: 0.3, end: 0, curve: M3Motion.emphasizedDecelerate),
            ],
          ),
        ),
      ),
    );
  }
}
