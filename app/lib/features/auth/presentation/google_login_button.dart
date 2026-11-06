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
  /// Oxirgi xatoning sababi. Ilgari har qanday xato tugmani butunlay
  /// yo'qotib, «Kirish usullari yuklanmadi» deb qo'yardi — nima bo'lganini
  /// ham, qayta urinish yo'lini ham ko'rsatmasdi.
  String? _problem;
  bool _initFailed = false;
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
              setState(() => _problem = 'ID token yo‘q');
              return;
            }
            setState(() {
              _busy = true;
              _problem = null;
            });
            try {
              await widget.onToken(token);
            } finally {
              if (mounted) setState(() => _busy = false);
            }
          }
        },
        onError: (Object e) {
          if (mounted) setState(() => _problem = _describe(e));
        },
      );
      setState(() {
        _ready = true;
        _initFailed = false;
      });
    } catch (e) {
      _initialization = null;
      if (mounted) {
        setState(() {
          _initFailed = true;
          _problem = _describe(e);
        });
      }
    }
  }

  /// Odam o'qiy oladigan sabab. Kod qoldiriladi: «[28444]» kabi raqam
  /// Google Cloud'dagi qaysi sozlama noto'g'riligini aniq aytadi.
  String _describe(Object e) {
    if (e is GoogleSignInException) {
      final detail = e.description?.trim();
      return detail == null || detail.isEmpty
          ? e.code.name
          : '${e.code.name}: $detail';
    }
    return e.toString();
  }

  @override
  void dispose() {
    _events?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final problem = _problem == null
        ? null
        : Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              l.authGoogleFailed(_problem!),
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          );
    if (_initFailed) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          OutlinedButton(
            onPressed: () {
              setState(() => _problem = null);
              _init();
            },
            child: Text(l.retry),
          ),
          ?problem,
        ],
      );
    }
    if (!_ready) return const LinearProgressIndicator();
    if (kIsWeb) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AbsorbPointer(absorbing: _busy, child: googleWebButton()),
          ?problem,
        ],
      );
    }
    final button = OutlinedButton(
      onPressed: _busy
          ? null
          : () async {
              setState(() => _problem = null);
              try {
                await GoogleSignIn.instance.authenticate();
              } on GoogleSignInException catch (e) {
                if (mounted && e.code != GoogleSignInExceptionCode.canceled) {
                  setState(() => _problem = _describe(e));
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [button, ?problem],
    );
  }
}
