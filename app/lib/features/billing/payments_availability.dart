import 'package:flutter/foundation.dart';

/// Whether this build sells anything itself.
///
/// Google Play and the App Store require their own billing for digital goods
/// sold inside a store app, and listing packs and boosts are digital. Until
/// that billing exists, the store builds sell nothing: plans, boosts and saved
/// cards stay on the web app at mab.uz, where Payme is allowed.
/// `--dart-define=IN_APP_PAYMENTS=true` turns them back on for a build that is
/// not going to a store.
const _inAppPaymentsOverride = bool.fromEnvironment('IN_APP_PAYMENTS');

bool get paymentsInApp => kIsWeb || _inAppPaymentsOverride;
