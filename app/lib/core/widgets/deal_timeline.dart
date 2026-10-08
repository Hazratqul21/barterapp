import 'package:flutter/material.dart';
import 'package:material_symbols_icons/material_symbols_icons.dart';

import '../../l10n/app_localizations.dart';
import '../../shared/models/models.dart';
import '../theme/motion.dart';
import '../theme/tokens.dart';
import 'common.dart' show palette;

/// Where a deal stands, as four steps: offered → agreed (goods held) →
/// handed over (both sides confirm) → done.
///
/// A single status word ("Qabul qilingan") said nothing about what comes
/// next. The timeline shows the path, the step each side is on, and — when a
/// deal leaves the path (dispute, cancel, expiry) — that it left and why.
class DealTimeline extends StatelessWidget {
  const DealTimeline({super.key, required this.offer});

  final Offer offer;

  /// 0 offered · 1 agreed · 2 handed over (at least one confirmation) · 3 done
  int get _reached => switch (offer.status) {
    OfferStatus.completed => 3,
    OfferStatus.accepted when offer.confirmedByMe || offer.confirmedByPeer => 2,
    OfferStatus.accepted || OfferStatus.disputed || OfferStatus.refunded => 1,
    _ => 0,
  };

  /// The deal left the happy path at the step after [_reached].
  bool get _derailed =>
      offer.status == OfferStatus.disputed ||
      offer.status == OfferStatus.refunded ||
      offer.status == OfferStatus.declined ||
      offer.status == OfferStatus.expired;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final labels = [
      l.timelineOffered,
      l.timelineAgreed,
      l.timelineHandedOver,
      l.timelineDone,
    ];
    final reached = _reached;
    final stopAt = _derailed ? reached + 1 : -1;
    final step = (reached + 1).clamp(1, labels.length);

    return Semantics(
      label: l.timelineSemantics(step, labels.length, labels[reached]),
      excludeSemantics: true,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < labels.length; i++) ...[
            Expanded(
              child: _Step(
                label: labels[i],
                state: i == stopAt
                    ? _StepState.stopped
                    : i <= reached
                    ? _StepState.done
                    : i == reached + 1 && !_derailed
                    ? _StepState.next
                    : _StepState.todo,
                first: i == 0,
                last: i == labels.length - 1,
                linkDone: i <= reached,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

enum _StepState { done, next, todo, stopped }

class _Step extends StatelessWidget {
  const _Step({
    required this.label,
    required this.state,
    required this.first,
    required this.last,
    required this.linkDone,
  });

  final String label;
  final _StepState state;
  final bool first;
  final bool last;

  /// Whether the line into this step is filled.
  final bool linkDone;

  @override
  Widget build(BuildContext context) {
    final p = palette(context);
    final scheme = Theme.of(context).colorScheme;
    final (fill, border, icon, iconColor) = switch (state) {
      _StepState.done => (
        p.give,
        p.give,
        Symbols.check_rounded,
        scheme.onPrimary,
      ),
      _StepState.next => (scheme.surface, p.give, null, null),
      _StepState.stopped => (
        scheme.errorContainer,
        scheme.error,
        Symbols.priority_high_rounded,
        scheme.onErrorContainer,
      ),
      _StepState.todo => (scheme.surface, p.hair, null, null),
    };
    final line = p.hair;

    return Column(
      children: [
        SizedBox(
          height: 22,
          child: Row(
            children: [
              Expanded(
                child: first
                    ? const SizedBox()
                    : Container(height: 2, color: linkDone ? p.give : line),
              ),
              AnimatedContainer(
                duration: Motion.standard.durationOf(context),
                curve: Motion.standard.curve,
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: fill,
                  shape: BoxShape.circle,
                  border: Border.all(color: border, width: 2),
                ),
                child: icon == null
                    ? null
                    : Icon(icon, size: 14, color: iconColor, weight: 700),
              ),
              Expanded(
                child: last
                    ? const SizedBox()
                    : Container(
                        height: 2,
                        color: state == _StepState.done ? p.give : line,
                      ),
              ),
            ],
          ),
        ),
        const SizedBox(height: Gap.x1),
        Text(
          label,
          textAlign: TextAlign.center,
          maxLines: 2,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: switch (state) {
              _StepState.done || _StepState.next => scheme.onSurface,
              _StepState.stopped => scheme.error,
              _StepState.todo => p.inkSoft,
            },
            fontWeight: state == _StepState.next ? FontWeight.w800 : null,
          ),
        ),
      ],
    );
  }
}
