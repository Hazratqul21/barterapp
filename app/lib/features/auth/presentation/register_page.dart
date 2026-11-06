import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/material_symbols_icons.dart';

import '../../../core/theme/tokens.dart';
import '../../../core/widgets/common.dart';
import '../../../l10n/app_localizations.dart';
import '../data/auth_repository.dart';
import 'google_login_button.dart';

/// Yangi hisob: Google, email (kod bilan) yoki telefon.
///
/// Ilgari alohida ro'yxatdan o'tish yo'q edi — hisob faqat telefon kodi yoki
/// Google orqali «kirish» paytida jimgina ochilardi. SMS hali ulanmagan va
/// Google sozlanmagan paytda yangi odam uchun hech qanday yo'l qolmasdi.
class RegisterPage extends ConsumerStatefulWidget {
  const RegisterPage({super.key});

  @override
  ConsumerState<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends ConsumerState<RegisterPage> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _code = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();

  bool _busy = false, _sent = false, _visible = false;
  String? _error;
  int _resendIn = 0;
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    for (final c in [_name, _email, _code, _password, _confirm]) {
      c.dispose();
    }
    super.dispose();
  }

  String get _cleanEmail => _email.text.trim().toLowerCase();
  bool get _emailLooksValid =>
      RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]{2,}$').hasMatch(_cleanEmail);

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
    } catch (e) {
      if (mounted) setState(() => _error = errorMessage(context, e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _sendCode() => _run(() async {
    final code = await ref
        .read(authRepositoryProvider)
        .requestEmailCode(_cleanEmail);
    if (!mounted) return;
    setState(() {
      _sent = true;
      if (code != null && !kReleaseMode) _code.text = code;
      _resendIn = 60;
    });
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return t.cancel();
      setState(() => _resendIn--);
      if (_resendIn <= 0) t.cancel();
    });
  });

  Future<void> _register() => _run(() async {
    final l = L.of(context);
    if (_password.text.length < 12 || _password.text != _confirm.text) {
      setState(() => _error = l.authPasswordMismatch);
      return;
    }
    final fresh = await ref
        .read(authRepositoryProvider)
        .registerEmail(
          _cleanEmail,
          _code.text.trim(),
          _password.text,
          firstName: _name.text.trim(),
        );
    await _signedIn(fresh);
  });

  Future<void> _signedIn(bool fresh) async {
    await ref.read(authStateProvider.notifier).signedIn();
    ref.invalidate(meProvider);
    if (mounted) context.go(fresh ? '/onboarding' : '/home');
  }

  Widget _field(
    TextEditingController controller,
    String label, {
    bool secret = false,
    bool enabled = true,
    TextInputType? keyboard,
    Iterable<String>? hints,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: Gap.x3),
    child: TextField(
      controller: controller,
      enabled: enabled && !_busy,
      obscureText: secret && !_visible,
      autocorrect: !secret,
      enableSuggestions: !secret,
      keyboardType: keyboard,
      autofillHints: hints,
      maxLength: secret ? 128 : null,
      onChanged: (_) => setState(() {}),
      decoration: InputDecoration(
        labelText: label,
        counterText: '',
        suffixIcon: secret
            ? IconButton(
                tooltip: L.of(context).authShowPassword,
                icon: Icon(_visible ? Icons.visibility_off : Icons.visibility),
                onPressed: () => setState(() => _visible = !_visible),
              )
            : null,
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final theme = Theme.of(context);
    final p = palette(context);
    final methods = ref.watch(loginMethodsProvider);
    final emailOpen = methods.value?['email'] == true;
    final googleOpen = methods.value?['google'] == true;
    final phoneOpen = methods.value?['phone'] == true;

    return Scaffold(
      appBar: AppBar(title: Text(l.authRegister)),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(Gap.x6, Gap.x2, Gap.x6, Gap.x8),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: AutofillGroup(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      l.authRegisterSubtitle,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: p.inkSoft,
                      ),
                    ),
                    Gap.h6,
                    if (methods.isLoading) const LinearProgressIndicator(),
                    if (methods.hasError) ...[
                      Text(l.authMethodsUnavailable),
                      TextButton(
                        onPressed: () => ref.invalidate(loginMethodsProvider),
                        child: Text(l.retry),
                      ),
                    ],

                    // ── Google ───────────────────────────────────────────
                    if (googleOpen) ...[
                      GoogleLoginButton(
                        clientId: methods.value!['google_client_id'] as String,
                        onToken: (token) => _run(() async {
                          final fresh = await ref
                              .read(authRepositoryProvider)
                              .google(token);
                          await _signedIn(fresh);
                        }),
                      ),
                      Gap.h6,
                    ],

                    // ── Email ────────────────────────────────────────────
                    Text(
                      l.authRegisterEmail,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Gap.h3,
                    if (methods.hasValue && !emailOpen)
                      Text(l.authEmailUnavailable)
                    else ...[
                      _field(
                        _name,
                        l.authNameLabel,
                        enabled: !_sent,
                        hints: const [AutofillHints.givenName],
                      ),
                      _field(
                        _email,
                        l.authEmailLabel,
                        enabled: !_sent,
                        keyboard: TextInputType.emailAddress,
                        hints: const [AutofillHints.email],
                      ),
                      if (!_sent)
                        FilledButton(
                          onPressed: _busy || !_emailLooksValid
                              ? null
                              : _sendCode,
                          child: Text(l.authSendCode),
                        )
                      else ...[
                        Text(
                          l.authEmailCodeSent(_cleanEmail),
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: p.inkSoft,
                          ),
                        ),
                        Gap.h3,
                        _field(
                          _code,
                          l.authCodeTitle,
                          keyboard: TextInputType.number,
                          hints: const [AutofillHints.oneTimeCode],
                        ),
                        _field(
                          _password,
                          l.authNewPassword,
                          secret: true,
                          hints: const [AutofillHints.newPassword],
                        ),
                        _field(_confirm, l.authConfirmPassword, secret: true),
                        FilledButton(
                          onPressed: _busy || _code.text.trim().length != 6
                              ? null
                              : _register,
                          child: _busy
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : Text(l.authCreateAccount),
                        ),
                        Wrap(
                          alignment: WrapAlignment.spaceBetween,
                          children: [
                            TextButton(
                              onPressed: _busy
                                  ? null
                                  : () => setState(() {
                                      _sent = false;
                                      _code.clear();
                                      _error = null;
                                    }),
                              child: Text(l.authChangeEmail),
                            ),
                            TextButton(
                              onPressed: _busy || _resendIn > 0
                                  ? null
                                  : _sendCode,
                              child: Text(
                                _resendIn > 0
                                    ? l.authResendIn(_resendIn)
                                    : l.authResend,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                    if (_error != null) ...[
                      Gap.h3,
                      Text(
                        _error!,
                        style: TextStyle(color: theme.colorScheme.error),
                      ),
                    ],

                    // ── Telefon ──────────────────────────────────────────
                    Gap.h6,
                    OutlinedButton.icon(
                      onPressed: _busy || !phoneOpen
                          ? null
                          : () => Navigator.of(context).maybePop(),
                      icon: const Icon(Symbols.call_rounded),
                      label: Text(l.authRegisterPhone),
                    ),
                    Gap.h2,
                    Text(
                      phoneOpen ? l.authRegisterPhoneHint : l.authPhoneUnavailable,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: p.inkSoft,
                      ),
                    ),
                    Gap.h6,
                    TextButton(
                      onPressed: _busy
                          ? null
                          : () => Navigator.of(context).maybePop(),
                      child: Text(l.authHaveAccount),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
