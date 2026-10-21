import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

/// The OAuth "Web application" client ID from Google Cloud. Not a secret —
/// it ships in every web page that shows the button. On the web it is the
/// client; on Android it is the `serverClientId`, which is what makes Google
/// hand back an ID token the API can verify.
///
/// Empty (the default) hides Google sign-in entirely.
const googleClientId = String.fromEnvironment('GOOGLE_CLIENT_ID');

/// iOS needs its own client ID and a URL scheme in Info.plist; until both are
/// set up there, the button stays hidden rather than crashing on tap.
bool get googleSignInAvailable =>
    googleClientId.isNotEmpty &&
    (kIsWeb || defaultTargetPlatform == TargetPlatform.android);

/// The Google side of sign-in: obtaining an ID token. Exchanging it for our
/// own session is `AuthRepository.signInWithGoogle`.
class GoogleAuth {
  GoogleAuth._();

  static Future<void>? _init;

  static Future<void> ensureInitialized() =>
      _init ??= GoogleSignIn.instance.initialize(
        clientId: kIsWeb ? googleClientId : null,
        serverClientId: kIsWeb ? null : googleClientId,
      );

  /// Android: opens the account picker. Null when the person backs out.
  static Future<String?> signIn() async {
    await ensureInitialized();
    try {
      final account = await GoogleSignIn.instance.authenticate();
      return account.authentication.idToken;
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) return null;
      rethrow;
    }
  }

  /// Web: Google's own button signs in, and the token arrives here.
  static Stream<String> idTokens() => GoogleSignIn.instance.authenticationEvents
      .where((e) => e is GoogleSignInAuthenticationEventSignIn)
      .map(
        (e) => (e as GoogleSignInAuthenticationEventSignIn)
            .user
            .authentication
            .idToken,
      )
      .where((token) => token != null)
      .cast<String>();

  /// So the next person on this device gets the account picker, not this
  /// account silently signed back in.
  static Future<void> signOut() async {
    if (!googleSignInAvailable || _init == null) return;
    try {
      await GoogleSignIn.instance.signOut();
    } catch (_) {
      // Our own session is already gone; Google's is best-effort.
    }
  }
}
