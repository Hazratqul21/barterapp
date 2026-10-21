import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../../../l10n/app_localizations.dart';
import 'google_web_button_stub.dart'
    if (dart.library.js_interop) 'google_web_button.dart';

Future<void>? _initialization;

class GoogleLoginButton extends StatefulWidget {
  const GoogleLoginButton({
    super.key,
    required this.clientId,
    required this.onToken,
  });
  final String clientId;
  final Future<void> Function(String) onToken;
  @override
  State<GoogleLoginButton> createState() => _GoogleLoginButtonState();
}

class _GoogleLoginButtonState extends State<GoogleLoginButton> {
  StreamSubscription<GoogleSignInAuthenticationEvent>? _events;
  bool _ready = false;
  bool _busy = false;
  bool _failed = false;
  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      const iosId = String.fromEnvironment('GOOGLE_IOS_CLIENT_ID');
      _initialization ??= GoogleSignIn.instance.initialize(
        clientId: kIsWeb ? widget.clientId : (iosId.isEmpty ? null : iosId),
        serverClientId: kIsWeb ? null : widget.clientId,
      );
      await _initialization;
      if (!mounted) return;
      _events = GoogleSignIn.instance.authenticationEvents.listen(
        (event) async {
          if (event is GoogleSignInAuthenticationEventSignIn && !_busy) {
            final token = event.user.authentication.idToken;
            if (token == null) {
              setState(() => _failed = true);
              return;
            }
            setState(() => _busy = true);
            try {
              await widget.onToken(token);
            } finally {
              if (mounted) setState(() => _busy = false);
            }
          }
        },
        onError: (Object e) {
          if (mounted) setState(() => _failed = true);
        },
      );
      setState(() => _ready = true);
    } catch (_) {
      _initialization = null;
      if (mounted) setState(() => _failed = true);
    }
  }

  @override
  void dispose() {
    _events?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    if (_failed) return Text(l.authMethodsUnavailable);
    if (!_ready) return const LinearProgressIndicator();
    if (kIsWeb) {
      return AbsorbPointer(absorbing: _busy, child: googleWebButton());
    }
    return OutlinedButton(
      onPressed: _busy
          ? null
          : () async {
              try {
                await GoogleSignIn.instance.authenticate();
              } on GoogleSignInException catch (e) {
                if (mounted && e.code != GoogleSignInExceptionCode.canceled) {
                  setState(() => _failed = true);
                }
              }
            },
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(52),
        shape: const StadiumBorder(),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SvgPicture.asset('assets/brand/google_g.svg', width: 20, height: 20),
          const SizedBox(width: 12),
          Text(l.authWithGoogle),
        ],
      ),
    );
  }
}
