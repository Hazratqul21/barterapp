import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/material_symbols_icons.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/common.dart';
import '../../../l10n/app_localizations.dart';
import '../data/auth_repository.dart';

/// Phone, then code. Two steps on one screen so the number stays visible while
/// the code that was sent to it is typed.
///
/// There is no "continue with Google / Apple / Facebook". Those three buttons
/// used to sit at the top and every one of them answered with "coming soon" —
/// the server has no such flow and never had one. A button that cannot do its
/// job costs more than the space it takes: it teaches people that this app's
/// buttons are decorative. Phone and SMS is also simply how this market signs
/// in.
class SignInPage extends ConsumerStatefulWidget {
  const SignInPage({super.key});

  @override
  ConsumerState<SignInPage> createState() => _SignInPageState();
}

class _SignInPageState extends ConsumerState<SignInPage> {
  final _phone = TextEditingController(text: '+998');
  final _code = TextEditingController();

  bool _codeSent = false;
  bool _busy = false;
  String? _error;

  /// Only ever set while the backend runs with `OTP_DEBUG` on, which is where
  /// it hands the code back instead of sending an SMS.
  String? _debugCode;

  @override
  void dispose() {
    _phone.dispose();
    _code.dispose();
    super.dispose();
  }

  String get _cleanPhone => _phone.text.replaceAll(' ', '');

  bool get _phoneLooksValid => RegExp(r'^\+998\d{9}$').hasMatch(_cleanPhone);

  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = errorMessage(context, e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _sendCode() => _run(() async {
    final code = await ref
        .read(authRepositoryProvider)
        .requestCode(_cleanPhone);
    if (!mounted) return;
    setState(() {
      _codeSent = true;
      _debugCode = code;
      // Filling it in is the point of the debug code: it lets the whole trade
      // loop be walked end to end without an SMS gateway.
      if (code != null) _code.text = code;
    });
  });

  Future<void> _verify() => _run(() async {
    final isNewUser = await ref
        .read(authRepositoryProvider)
        .verify(_cleanPhone, _code.text.trim());
    await ref.read(authStateProvider.notifier).signedIn();
    ref.invalidate(meProvider);
    if (!mounted) return;
    // A new account has no name yet, and a nameless trader is invisible on
    // every card in the app — so that is the next screen, not the feed.
    context.go(isNewUser ? '/onboarding' : '/home');
  });

  void _backToPhone() => setState(() {
    _codeSent = false;
    _code.clear();
    _debugCode = null;
    _error = null;
  });

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final p = palette(context);
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(Gap.x6, Gap.x4, Gap.x6, Gap.x8),
            child:
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (context.canPop())
                        Align(
                          alignment: AlignmentDirectional.centerStart,
                          child: IconButton(
                            tooltip: l.back,
                            onPressed: context.pop,
                            icon: const Icon(Symbols.arrow_back_rounded),
                          ),
                        ),
                      Gap.h6,
                      const _BrandMark(),
                      Gap.h8,
                      Text(
                        _codeSent ? l.authCodeTitle : l.authTitle,
                        style: theme.textTheme.headlineMedium,
                      ),
                      Gap.h2,
                      Text(
                        _codeSent
                            ? l.authCodeSubtitle(_cleanPhone)
                            : l.authSubtitle,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: p.inkSoft,
                        ),
                      ),
                      Gap.h8,

                      TextField(
                        controller: _phone,
                        enabled: !_codeSent && !_busy,
                        keyboardType: TextInputType.phone,
                        autofillHints: const [AutofillHints.telephoneNumber],
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'[\d+]')),
                          LengthLimitingTextInputFormatter(13),
                        ],
                        style: theme.textTheme.titleMedium,
                        decoration: InputDecoration(
                          labelText: l.authPhoneLabel,
                          prefixIcon: const Icon(Symbols.call_rounded),
                        ),
                        onChanged: (_) => setState(() {}),
                        onSubmitted: (_) =>
                            _phoneLooksValid && !_busy ? _sendCode() : null,
                      ),

                      if (!_codeSent &&
                          !_phoneLooksValid &&
                          _phone.text.length > 4) ...[
                        Gap.h2,
                        Text(
                          l.authInvalidPhone,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: p.inkFaint,
                          ),
                        ),
                      ],

                      if (_codeSent) ...[
                        Gap.h3,
                        TextField(
                          controller: _code,
                          enabled: !_busy,
                          autofocus: true,
                          keyboardType: TextInputType.number,
                          autofillHints: const [AutofillHints.oneTimeCode],
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(6),
                          ],
                          textAlign: TextAlign.center,
                          style: theme.textTheme.headlineMedium?.copyWith(
                            letterSpacing: 10,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                          decoration: const InputDecoration(counterText: ''),
                          onSubmitted: (_) {
                            HapticFeedback.lightImpact();
                            _verify();
                          },
                        ),
                        if (_debugCode != null) ...[
                          Gap.h3,
                          _Notice(
                            icon: Symbols.info_rounded,
                            color: p.money,
                            background: p.moneySoft,
                            text: l.authOtpDebug(_debugCode!),
                          ),
                        ],
                      ],

                      if (_error != null) ...[
                        Gap.h3,
                        _Notice(
                          icon: Symbols.error_rounded,
                          color: theme.colorScheme.error,
                          background: theme.colorScheme.errorContainer,
                          text: _error!,
                        ),
                      ],

                      Gap.h6,
                      FilledButton(
                        onPressed: _busy || (!_codeSent && !_phoneLooksValid)
                            ? null
                            : () {
                                HapticFeedback.lightImpact();
                                _codeSent ? _verify() : _sendCode();
                              },
                        child: _busy
                            ? const SizedBox(
                                width: Sizes.iconLg,
                                height: Sizes.iconLg,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.4,
                                  color: Colors.white,
                                ),
                              )
                            : Text(_codeSent ? l.authVerify : l.authSendCode),
                      ),

                      if (_codeSent) ...[
                        Gap.h2,
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            TextButton(
                              onPressed: _busy ? null : _backToPhone,
                              child: Text(l.authChangeNumber),
                            ),
                            TextButton(
                              onPressed: _busy ? null : _sendCode,
                              child: Text(l.authResend),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ).animate().fadeIn(
                  duration: M3Motion.medium3,
                  curve: M3Motion.emphasizedDecelerate,
                ),
          ),
        ),
      ),
    );
  }
}

/// The swap mark, small. Signing in is the first screen most people reach after
/// the intro, and it should still look like the same app.
class _BrandMark extends StatelessWidget {
  const _BrandMark();

  @override
  Widget build(BuildContext context) {
    final p = palette(context);
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          gradient: p.swapGradient,
          borderRadius: Radii.rMd,
          boxShadow: Shadows.raised,
        ),
        child: const Icon(
          Symbols.swap_horiz_rounded,
          color: Colors.white,
          size: 30,
          weight: 600,
        ),
      ),
    );
  }
}

/// A tinted line of explanation under a field — an error, or the development
/// notice that carries the OTP while there is no SMS gateway.
class _Notice extends StatelessWidget {
  const _Notice({
    required this.icon,
    required this.color,
    required this.background,
    required this.text,
  });

  final IconData icon;
  final Color color;
  final Color background;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: Gap.x3, vertical: Gap.x3),
      decoration: BoxDecoration(color: background, borderRadius: Radii.rSm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: Sizes.iconMd, color: color),
          Gap.w2,
          Expanded(
            child: Text(
              text,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: color),
            ),
          ),
        ],
      ),
    );
  }
}
