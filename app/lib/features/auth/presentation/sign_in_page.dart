import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/material_symbols_icons.dart';

import '../../../core/theme/tokens.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/legal_links.dart';
import '../../../l10n/app_localizations.dart';
import '../data/auth_repository.dart';
import '../data/google_auth.dart';
import '../../../core/theme/haptics.dart';
import 'google_web_button_stub.dart'
    if (dart.library.js_interop) 'google_web_button_web.dart';

class _OtpInput extends StatefulWidget {
  const _OtpInput({
    required this.controller,
    required this.onSubmitted,
    required this.enabled,
  });
  final TextEditingController controller;
  final ValueChanged<String> onSubmitted;
  final bool enabled;

  @override
  State<_OtpInput> createState() => _OtpInputState();
}

class _OtpInputState extends State<_OtpInput> {
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_update);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    widget.controller.removeListener(_update);
    _focusNode.dispose();
    super.dispose();
  }

  void _update() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final text = widget.controller.text;

    return Stack(
      children: [
        Opacity(
          opacity: 0,
          alwaysIncludeSemantics: true,
          child: TextField(
            controller: widget.controller,
            focusNode: _focusNode,
            enabled: widget.enabled,
            keyboardType: TextInputType.number,
            autofillHints: const [AutofillHints.oneTimeCode],
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            maxLength: 6,
            onSubmitted: widget.onSubmitted,
            decoration: const InputDecoration(counterText: ''),
          ),
        ),
        GestureDetector(
          onTap: () => _focusNode.requestFocus(),
          child: LayoutBuilder(
            builder: (context, constraints) => Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: List.generate(6, (index) {
                final char = index < text.length ? text[index] : '';
                final isFocused = _focusNode.hasFocus && text.length == index;
                final isFilled = index < text.length;

                return AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: ((constraints.maxWidth - 30) / 6).clamp(24.0, 48.0),
                  height: 56,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isFocused
                          ? theme.colorScheme.primary
                          : (isFilled
                                ? theme.colorScheme.outlineVariant
                                : Colors.transparent),
                      width: 2,
                    ),
                  ),
                  child: Text(
                    char,
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                );
              }),
            ),
          ),
        ),
      ],
    );
  }
}

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

  /// Seconds until another code may be asked for. A wrong number or an SMS
  /// that never arrived used to leave only one way out: leaving the page.
  int _resendIn = 0;
  Timer? _resendTimer;
  static const _resendAfter = 60;

  @override
  void dispose() {
    _resendTimer?.cancel();
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
      // Only a development server returns the code; a release build never
      // types it in, even if a server is misconfigured to send it.
      if (code != null && !kReleaseMode) _code.text = code;
    });
    _startResendCountdown();
  });

  void _startResendCountdown() {
    _resendTimer?.cancel();
    setState(() => _resendIn = _resendAfter);
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return t.cancel();
      setState(() => _resendIn--);
      if (_resendIn <= 0) t.cancel();
    });
  }

  void _changePhone() {
    _resendTimer?.cancel();
    setState(() {
      _codeSent = false;
      _resendIn = 0;
      _error = null;
      _code.clear();
    });
  }

  Future<void> _verify() => _run(() async {
    final isNewUser = await ref
        .read(authRepositoryProvider)
        .verify(_cleanPhone, _code.text.trim());
    await _signedIn(isNewUser);
  });

  Future<void> _google(String idToken) => _run(() async {
    final isNewUser = await ref
        .read(authRepositoryProvider)
        .signInWithGoogle(idToken);
    await _signedIn(isNewUser);
  });

  Future<void> _signedIn(bool isNewUser) async {
    await ref.read(authStateProvider.notifier).signedIn();
    ref.invalidate(meProvider);
    if (!mounted) return;
    context.go(isNewUser ? '/onboarding' : '/home');
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
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
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
                  Gap.h6,

                  if (!_codeSent && googleSignInAvailable)
                    _GoogleSignIn(
                      enabled: !_busy,
                      onIdToken: _google,
                      onError: (e) =>
                          setState(() => _error = errorMessage(context, e)),
                    ),
                  TextField(
                    controller: _phone,
                    enabled: !_codeSent && !_busy,
                    keyboardType: TextInputType.phone,
                    textInputAction: TextInputAction.done,
                    autofillHints: const [AutofillHints.telephoneNumber],
                    onSubmitted: (_) {
                      if (!_busy && _phoneLooksValid) _sendCode();
                    },
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
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
                    _OtpInput(
                      controller: _code,
                      enabled: !_busy,
                      onSubmitted: (_) => _verify(),
                    ),
                    Gap.h2,
                    Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      children: [
                        TextButton(
                          onPressed: _busy ? null : _changePhone,
                          child: Text(l.authChangePhone),
                        ),
                        TextButton(
                          onPressed: _busy || _resendIn > 0 ? null : _sendCode,
                          child: Text(
                            _resendIn > 0
                                ? l.authResendIn(_resendIn)
                                : l.authResend,
                          ),
                        ),
                      ],
                    ),
                  ],

                  if (_error != null) ...[
                    Gap.h4,
                    _Notice(
                      icon: Symbols.error_rounded,
                      color: theme.colorScheme.error,
                      background: theme.colorScheme.errorContainer.withValues(
                        alpha: 0.5,
                      ),
                      text: _error!,
                    ),
                  ],

                  Gap.h6,
                  FilledButton(
                    onPressed: _busy || (!_codeSent && !_phoneLooksValid)
                        ? null
                        : () {
                            Haptics.success();
                            _codeSent ? _verify() : _sendCode();
                          },
                    child: _busy
                        ? SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: theme.colorScheme.onPrimary,
                            ),
                          )
                        : Text(_codeSent ? l.authVerify : l.authSendCode),
                  ),
                  Gap.h4,
                  const LegalLinks(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// "Continue with Google". On Android a button of our own opens the account
/// picker; on the web Google insists on drawing its button itself, and the
/// token arrives on a stream instead of as a return value.
class _GoogleSignIn extends StatefulWidget {
  const _GoogleSignIn({
    required this.enabled,
    required this.onIdToken,
    required this.onError,
  });
  final bool enabled;
  final Future<void> Function(String idToken) onIdToken;
  final void Function(Object error) onError;

  @override
  State<_GoogleSignIn> createState() => _GoogleSignInState();
}

class _GoogleSignInState extends State<_GoogleSignIn> {
  StreamSubscription<String>? _tokens;
  bool _ready = !kIsWeb;

  /// Google's script did not load (blocked network, ad blocker). The phone
  /// form still works, so the section quietly goes away rather than leaving
  /// an error above a perfectly good way in.
  bool _unavailable = false;

  @override
  void initState() {
    super.initState();
    if (kIsWeb) {
      GoogleAuth.ensureInitialized().then(
        (_) {
          if (!mounted) return;
          _tokens = GoogleAuth.idTokens().listen(
            widget.onIdToken,
            onError: widget.onError,
          );
          setState(() => _ready = true);
        },
        onError: (Object _) {
          if (mounted) setState(() => _unavailable = true);
        },
      );
    }
  }

  @override
  void dispose() {
    _tokens?.cancel();
    super.dispose();
  }

  Future<void> _tap() async {
    try {
      final token = await GoogleAuth.signIn();
      if (token != null) await widget.onIdToken(token);
    } catch (e) {
      widget.onError(e);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_unavailable) return const SizedBox.shrink();
    final l = L.of(context);
    final theme = Theme.of(context);
    final Widget button;
    if (kIsWeb) {
      button = _ready
          ? Center(
              child: googleWebButton(
                locale: Localizations.localeOf(context).languageCode,
              ),
            )
          : const SizedBox(height: 44);
    } else {
      button = OutlinedButton(
        onPressed: widget.enabled ? _tap : null,
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          shape: const StadiumBorder(),
          side: BorderSide(color: theme.colorScheme.outlineVariant),
          foregroundColor: theme.colorScheme.onSurface,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SvgPicture.asset(
              'assets/brand/google_g.svg',
              width: 20,
              height: 20,
            ),
            Gap.w3,
            Text(
              l.authWithGoogle,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        button,
        Gap.h6,
        Row(
          children: [
            const Expanded(child: Divider()),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: Gap.x4),
              child: Text(
                l.authOrPhone,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: palette(context).inkFaint,
                ),
              ),
            ),
            const Expanded(child: Divider()),
          ],
        ),
        Gap.h6,
      ],
    );
  }
}

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
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(Gap.x3),
    decoration: BoxDecoration(color: background, borderRadius: Radii.rMd),
    child: Row(
      children: [
        Icon(icon, size: 20, color: color),
        Gap.w2,
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              color: color,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    ),
  );
}
