import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/widgets/common.dart';
import '../../../l10n/app_localizations.dart';
import '../data/auth_repository.dart';

class PasswordPage extends ConsumerStatefulWidget {
  const PasswordPage({super.key, this.manage = false});
  final bool manage;
  @override
  ConsumerState<PasswordPage> createState() => _PasswordPageState();
}

class _PasswordPageState extends ConsumerState<PasswordPage> {
  final _identifier = TextEditingController();
  final _password = TextEditingController();
  final _current = TextEditingController();
  final _confirm = TextEditingController();
  final _code = TextEditingController();
  bool _reset = false, _busy = false, _visible = false, _sent = false;
  String? _error;
  int _resendIn = 0;
  Timer? _resendTimer;
  @override
  void dispose() {
    _resendTimer?.cancel();
    for (final c in [_identifier, _password, _current, _confirm, _code]) {
      c.dispose();
    }
    super.dispose();
  }

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

  Future<void> _submit() => _run(() async {
    final l = L.of(context);
    if ((widget.manage || _reset) &&
        (_password.text.length < 12 || _password.text != _confirm.text)) {
      setState(() => _error = l.authPasswordMismatch);
      return;
    }
    final repo = ref.read(authRepositoryProvider);
    final fresh = widget.manage
        ? await repo.setPassword(_password.text, _current.text)
        : _reset
        ? await repo.resetPassword(
            _identifier.text.trim(),
            _code.text.trim(),
            _password.text,
          )
        : await repo.passwordLogin(_identifier.text.trim(), _password.text);
    await ref.read(authStateProvider.notifier).signedIn();
    ref.invalidate(meProvider);
    if (!mounted) return;
    if (widget.manage) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l.authPasswordSaved)));
      Navigator.pop(context);
    } else {
      context.go(fresh ? '/onboarding' : '/home');
    }
  });
  Widget _field(
    TextEditingController controller,
    String label, {
    bool secret = false,
    Iterable<String>? hints,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: TextField(
      controller: controller,
      enabled: !_busy,
      obscureText: secret && !_visible,
      autocorrect: !secret,
      enableSuggestions: !secret,
      autofillHints: hints,
      maxLength: secret ? 128 : null,
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
    final phoneEnabled =
        ref.watch(loginMethodsProvider).value?['phone'] == true;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.manage ? l.authManagePassword : l.authPassword),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: AutofillGroup(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(l.authPasswordHelp),
                  const SizedBox(height: 24),
                  if (!widget.manage)
                    _field(
                      _identifier,
                      _reset ? l.authPhoneLabel : l.authIdentifier,
                      hints: const [AutofillHints.username],
                    ),
                  if (widget.manage)
                    _field(
                      _current,
                      l.authCurrentPassword,
                      secret: true,
                      hints: const [AutofillHints.password],
                    ),
                  if (_reset) ...[
                    if (!phoneEnabled) Text(l.authPhoneUnavailable),
                    OutlinedButton(
                      onPressed: !phoneEnabled || _busy || _resendIn > 0
                          ? null
                          : () => _run(() async {
                              await ref
                                  .read(authRepositoryProvider)
                                  .requestCode(_identifier.text.trim());
                              if (mounted) {
                                setState(() {
                                  _sent = true;
                                  _resendIn = 60;
                                });
                                _resendTimer?.cancel();
                                _resendTimer = Timer.periodic(
                                  const Duration(seconds: 1),
                                  (timer) {
                                    if (!mounted) {
                                      timer.cancel();
                                      return;
                                    }
                                    setState(() => _resendIn--);
                                    if (_resendIn <= 0) timer.cancel();
                                  },
                                );
                              }
                            }),
                      child: Text(
                        _resendIn > 0
                            ? l.authResendIn(_resendIn)
                            : _sent
                            ? l.authResend
                            : l.authSendCode,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _field(
                      _code,
                      l.authCodeTitle,
                      hints: const [AutofillHints.oneTimeCode],
                    ),
                  ],
                  _field(
                    _password,
                    widget.manage || _reset
                        ? l.authNewPassword
                        : l.authPasswordLabel,
                    secret: true,
                    hints: [
                      widget.manage || _reset
                          ? AutofillHints.newPassword
                          : AutofillHints.password,
                    ],
                  ),
                  if (widget.manage || _reset)
                    _field(_confirm, l.authConfirmPassword, secret: true),
                  if (_error != null) ...[
                    Text(
                      _error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  FilledButton(
                    onPressed: _busy || (_reset && !phoneEnabled)
                        ? null
                        : _submit,
                    child: _busy
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(),
                          )
                        : Text(
                            widget.manage || _reset
                                ? l.authSavePassword
                                : l.authPassword,
                          ),
                  ),
                  if (!widget.manage)
                    TextButton(
                      onPressed: _busy
                          ? null
                          : () => setState(() {
                              _reset = !_reset;
                              _error = null;
                              _sent = false;
                            }),
                      child: Text(
                        _reset ? l.authPassword : l.authForgotPassword,
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
