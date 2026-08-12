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
    setState(() { _busy = true; _error = null; });
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
    final code = await ref.read(authRepositoryProvider).requestCode(_cleanPhone);
    if (!mounted) return;
    setState(() {
      _codeSent = true;
      _debugCode = code;
      if (code != null) _code.text = code;
    });
  });

  Future<void> _verify() => _run(() async {
    final isNewUser = await ref.read(authRepositoryProvider).verify(_cleanPhone, _code.text.trim());
    await ref.read(authStateProvider.notifier).signedIn();
    ref.invalidate(meProvider);
    if (!mounted) return;
    context.go(isNewUser ? '/onboarding' : '/home');
  });

  void _notYet(L l) {
    HapticFeedback.lightImpact();
    ScaffoldMessenger.of(context)..hideCurrentSnackBar()..showSnackBar(SnackBar(content: Text(l.comingSoon)));
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final p = palette(context);
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(Gap.x6, Gap.x4, Gap.x6, Gap.x8),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Center(child: BrandMark(size: 64)),
                  Gap.h8,
                  Text(
                    _codeSent ? l.authCodeTitle : l.authTitle,
                    style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w900),
                  ),
                  Gap.h2,
                  Text(
                    _codeSent ? l.authCodeSubtitle(_cleanPhone) : l.authSubtitle,
                    style: theme.textTheme.bodyLarge?.copyWith(color: p.inkSoft),
                  ),
                  Gap.h6,

                  if (!_codeSent) ...[
                    _SocialButton(icon: Icons.apple, label: l.authWithApple, backgroundColor: Colors.black, textColor: Colors.white, onPressed: () => _notYet(l)),
                    Gap.h3,
                    _SocialButton(icon: Icons.g_mobiledata, label: l.authWithGoogle, backgroundColor: Colors.white, textColor: Colors.black87, borderColor: theme.colorScheme.outlineVariant, iconSize: 32, onPressed: () => _notYet(l)),
                    Gap.h6,
                    Row(children: [const Expanded(child: Divider()), Padding(padding: const EdgeInsets.symmetric(horizontal: Gap.x4), child: Text(l.authOrPhone, style: theme.textTheme.bodySmall?.copyWith(color: p.inkFaint))), const Expanded(child: Divider())]),
                    Gap.h6,
                  ].animate(interval: 50.ms).fadeIn().slideY(begin: 0.1, end: 0),

                  TextField(
                    controller: _phone,
                    enabled: !_codeSent && !_busy,
                    keyboardType: TextInputType.phone,
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                    decoration: InputDecoration(
                      labelText: l.authPhoneLabel,
                      prefixIcon: const Icon(Symbols.call_rounded),
                      filled: true,
                      fillColor: theme.colorScheme.surfaceContainerLow,
                    ),
                    onChanged: (_) => setState(() {}),
                  ),

                  if (_codeSent) ...[
                    Gap.h4,
                    TextField(
                      controller: _code,
                      enabled: !_busy,
                      autofocus: true,
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.headlineMedium?.copyWith(letterSpacing: 12, fontWeight: FontWeight.w900),
                      decoration: InputDecoration(filled: true, fillColor: theme.colorScheme.surfaceContainerLow),
                      onSubmitted: (_) => _verify(),
                    ),
                  ],

                  if (_error != null) ...[Gap.h4, _Notice(icon: Symbols.error_rounded, color: theme.colorScheme.error, background: theme.colorScheme.errorContainer.withValues(alpha: 0.5), text: _error!)],

                  Gap.h6,
                  FilledButton(
                    onPressed: _busy || (!_codeSent && !_phoneLooksValid) ? null : () { HapticFeedback.mediumImpact(); _codeSent ? _verify() : _sendCode(); },
                    child: _busy ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white)) : Text(_codeSent ? l.authVerify : l.authSendCode),
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

class _Notice extends StatelessWidget {
  const _Notice({required this.icon, required this.color, required this.background, required this.text});
  final IconData icon; final Color color; final Color background; final String text;
  @override
  Widget build(BuildContext context) => Container(padding: const EdgeInsets.all(Gap.x3), decoration: BoxDecoration(color: background, borderRadius: Radii.rMd), child: Row(children: [Icon(icon, size: 20, color: color), Gap.w2, Expanded(child: Text(text, style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w600)))]));
}

class _SocialButton extends StatelessWidget {
  const _SocialButton({required this.icon, required this.label, required this.backgroundColor, required this.textColor, required this.onPressed, this.borderColor, this.iconSize = 24});
  final IconData icon; final String label; final Color backgroundColor; final Color textColor; final Color? borderColor; final double iconSize; final VoidCallback onPressed;
  @override
  Widget build(BuildContext context) => SizedBox(height: 56, child: OutlinedButton(style: OutlinedButton.styleFrom(backgroundColor: backgroundColor, foregroundColor: textColor, side: borderColor != null ? BorderSide(color: borderColor!) : BorderSide.none, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28))), onPressed: onPressed, child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(icon, size: iconSize), Gap.w3, Text(label, style: const TextStyle(fontWeight: FontWeight.w700))])));
}
