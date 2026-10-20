import 'package:flutter/widgets.dart';
import 'package:google_sign_in_web/web_only.dart' as web;

/// On the web Google requires its own button (Identity Services); a custom
/// one cannot start the sign-in. The token comes back through
/// `GoogleAuth.idTokens()`.
Widget googleWebButton({required String locale}) => web.renderButton(
  configuration: web.GSIButtonConfiguration(
    type: web.GSIButtonType.standard,
    theme: web.GSIButtonTheme.outline,
    size: web.GSIButtonSize.large,
    text: web.GSIButtonText.continueWith,
    shape: web.GSIButtonShape.pill,
    logoAlignment: web.GSIButtonLogoAlignment.left,
    minimumWidth: 320,
    locale: locale,
  ),
);
