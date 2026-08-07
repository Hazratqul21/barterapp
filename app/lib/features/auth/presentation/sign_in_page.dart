import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_client.dart';
import '../../../core/widgets/common.dart';
import '../../../l10n/app_localizations.dart';
import '../data/auth_repository.dart';

/// Phone, then code. Two steps in one screen so the number stays visible while
/// the user types the code that was sent to it.
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

  bool get _phoneLooksValid =>
      RegExp(r'^\+998\d{9}$').hasMatch(_phone.text.replaceAll(' ', ''));

  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.isNetworkFailure ? null : e.message);
      if (e.isNetworkFailure && mounted) {
        setState(() => _error = L.of(context).errorNetwork);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _sendCode() => _run(() async {
    final phone = _phone.text.replaceAll(' ', '');
    final code = await ref.read(authRepositoryProvider).requestCode(phone);
    if (!mounted) return;
    setState(() {
      _codeSent = true;
      _debugCode = code;
      if (code != null) _code.text = code;
    });
  });

  Future<void> _verify() => _run(() async {
    final phone = _phone.text.replaceAll(' ', '');
    final isNewUser = await ref.read(authRepositoryProvider).verify(phone, _code.text.trim());
    await ref.read(authStateProvider.notifier).signedIn();
    ref.invalidate(meProvider);
    if (mounted) {
      if (isNewUser) {
        context.go('/onboarding');
      } else {
        context.go('/home');
      }
    }
  });

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final p = palette(context);

    return Scaffold(
      appBar: AppBar(
        leading: context.canPop()
            ? IconButton(
                icon: const Icon(Icons.arrow_back_rounded),
                tooltip: l.back,
                onPressed: context.pop,
              )
            : null,
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    _codeSent ? l.authCodeTitle : l.authTitle,
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.6,
                      height: 1.15,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _codeSent
                        ? l.authCodeSubtitle(_phone.text)
                        : l.authSubtitle,
                    style: TextStyle(color: p.inkSoft, height: 1.5),
                  ),
                  const SizedBox(height: 28),

                  if (!_codeSent) ...[
                    _SocialButton(
                      text: 'Continue with Apple',
                      icon: const Icon(Icons.apple, size: 24, color: Colors.white),
                      backgroundColor: Colors.black,
                      textColor: Colors.white,
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l.comingSoon)));
                      },
                    ),
                    _SocialButton(
                      text: 'Continue with Google',
                      icon: const Text(
                        'G',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          color: Colors.black,
                        ),
                      ),
                      backgroundColor: Colors.white,
                      textColor: Colors.black,
                      borderColor: Colors.grey.shade300,
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l.comingSoon)));
                      },
                    ),
                    _SocialButton(
                      text: 'Continue with Facebook',
                      icon: const Icon(Icons.facebook, size: 24, color: Colors.white),
                      backgroundColor: const Color(0xFF1877F2),
                      textColor: Colors.white,
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l.comingSoon)));
                      },
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        const Expanded(child: Divider()),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Text(
                            'Yoki telefon orqali',
                            style: TextStyle(color: p.inkSoft, fontWeight: FontWeight.w500),
                          ),
                        ),
                        const Expanded(child: Divider()),
                      ],
                    ),
                    const SizedBox(height: 24),
                  ],

                  TextField(
                    controller: _phone,
                    enabled: !_codeSent && !_busy,
                    keyboardType: TextInputType.phone,
                    autofillHints: const [AutofillHints.telephoneNumber],
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[\d+]')),
                      LengthLimitingTextInputFormatter(13),
                    ],
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                    ),
                    decoration: InputDecoration(
                      labelText: l.authPhoneLabel,
                      labelStyle: TextStyle(color: p.inkSoft),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(color: Colors.black87),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),

                  if (_codeSent) ...[
                    const SizedBox(height: 14),
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
                      style: const TextStyle(
                        fontSize: 28,
                        letterSpacing: 12,
                        fontWeight: FontWeight.w700,
                      ),
                      decoration: InputDecoration(
                        counterText: '',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(color: Colors.black87),
                        ),
                        contentPadding: const EdgeInsets.symmetric(vertical: 20),
                      ),
                      onSubmitted: (_) {
                        HapticFeedback.lightImpact();
                        _verify();
                      },
                    ),
                    if (_debugCode != null) ...[
                      const SizedBox(height: 10),
                      // Development only: the backend has no SMS gateway yet, so
                      // it hands the code back instead of sending it.
                      Row(
                        children: [
                          Icon(Icons.info_outline, size: 15, color: p.money),
                          const SizedBox(width: 6),
                          Text(
                            'SMS hali ulanmagan — kod: $_debugCode',
                            style: TextStyle(fontSize: 12, color: p.money),
                          ),
                        ],
                      ),
                    ],
                  ],

                  if (_error != null) ...[
                    const SizedBox(height: 14),
                    Text(
                      _error!,
                      style: TextStyle(color: p.take, fontSize: 13),
                    ),
                  ],

                  const SizedBox(height: 24),
                  FilledButton(
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(double.infinity, 56),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 0,
                    ),
                    onPressed: _busy || (!_codeSent && !_phoneLooksValid)
                        ? null
                        : () {
                            HapticFeedback.lightImpact();
                            _codeSent ? _verify() : _sendCode();
                          },
                    child: _busy
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white),
                          )
                        : Text(
                            _codeSent ? l.authVerify : l.authSendCode,
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                          ),
                  ),
                  if (!_codeSent && !_phoneLooksValid && _phone.text.length > 4)
                    Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: Text(
                        l.authInvalidPhone,
                        style: TextStyle(fontSize: 12, color: p.inkFaint),
                      ),
                    ),
                  if (_codeSent)
                    TextButton(
                      onPressed: _busy
                          ? null
                          : () => setState(() {
                              _codeSent = false;
                              _code.clear();
                              _debugCode = null;
                            }),
                      child: Text(l.back),
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

class _SocialButton extends StatelessWidget {
  const _SocialButton({
    required this.text,
    required this.icon,
    required this.backgroundColor,
    required this.textColor,
    this.borderColor,
    required this.onPressed,
  });

  final String text;
  final Widget icon;
  final Color backgroundColor;
  final Color textColor;
  final Color? borderColor;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          backgroundColor: backgroundColor,
          foregroundColor: textColor,
          side: borderColor != null ? BorderSide(color: borderColor!) : BorderSide.none,
          minimumSize: const Size(double.infinity, 56),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 0,
        ),
        onPressed: () {
          HapticFeedback.lightImpact();
          onPressed();
        },
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            icon,
            const SizedBox(width: 12),
            Text(
              text,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: textColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
