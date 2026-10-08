import 'package:flutter/services.dart';

/// Four kinds of touch feedback, named for what happened rather than how
/// hard the motor kicks.
///
/// Calls used to pick an impact strength at each site, so the same event
/// (saving, sending, deleting) felt different on different screens. Naming
/// the meaning keeps them consistent and gives one place to tune them.
abstract final class Haptics {
  /// Moving between options: a tab, a filter, a segmented control.
  static Future<void> selection() => HapticFeedback.selectionClick();

  /// A small, reversible action: like, copy, open.
  static Future<void> light() => HapticFeedback.lightImpact();

  /// Something went through: offer sent, profile saved, code requested.
  static Future<void> success() => HapticFeedback.mediumImpact();

  /// Something destructive or refused: delete, sign out, a failed step.
  static Future<void> warning() => HapticFeedback.heavyImpact();
}
