import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/material_symbols_icons.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/backgrounds.dart';
import '../../../core/widgets/common.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/models/models.dart';
import '../../auth/data/auth_repository.dart';
import '../../trade/data/trade_repository.dart';

final _verificationProvider =
    FutureProvider.autoDispose<({int trustScore, List<VerificationStep> steps})>(
      (ref) => ref.watch(tradeRepositoryProvider).verification(),
    );

/// How much of a stranger you still are.
///
/// The steps are a fixed set — phone, passport, business, bank, video — so both
/// their names and their explanations live here, in all three languages. The
/// server used to send the explanation as free text, which meant a Russian
/// interface read its instructions in Uzbek.
({String label, String hint, IconData icon}) _describe(L l, String step) =>
    switch (step) {
      'phone' => (
        label: l.verifyStepPhone,
        hint: l.verifyStepPhoneHint,
        icon: Symbols.smartphone_rounded,
      ),
      'passport' => (
        label: l.verifyStepPassport,
        hint: l.verifyStepPassportHint,
        icon: Symbols.id_card_rounded,
      ),
      'business' => (
        label: l.verifyStepBusiness,
        hint: l.verifyStepBusinessHint,
        icon: Symbols.storefront_rounded,
      ),
      'bank' => (
        label: l.verifyStepBank,
        hint: l.verifyStepBankHint,
        icon: Symbols.account_balance_rounded,
      ),
      'video' => (
        label: l.verifyStepVideo,
        hint: l.verifyStepVideoHint,
        icon: Symbols.videocam_rounded,
      ),
      // A step added by the server after this build shipped: show what it sent
      // rather than nothing at all.
      _ => (label: step, hint: '', icon: Symbols.shield_rounded),
    };

class VerificationPage extends ConsumerStatefulWidget {
  const VerificationPage({super.key});

  @override
  ConsumerState<VerificationPage> createState() => _VerificationPageState();
}

class _VerificationPageState extends ConsumerState<VerificationPage> {
  /// Which step is being submitted — not a bare bool. With one flag shared
  /// across the list, tapping "send" on the passport put a spinner on every
  /// unfinished row at once.
  String? _submitting;

  Future<void> _submitStep(String step) async {
    if (_submitting != null) return;
    setState(() => _submitting = step);
    try {
      await ref.read(tradeRepositoryProvider).submitStep(step);
      ref.invalidate(_verificationProvider);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(errorMessage(context, e))));
    } finally {
      if (mounted) setState(() => _submitting = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);

    // Ask before fetching. Without this the page fired `/me/verification`
    // with no token, sat on a spinner that never resolved, and retried the
    // 401 every time the auth state settled.
    if (!ref.watch(authStateProvider)) {
      return Scaffold(
        appBar: AppBar(title: Text(l.verifyTitle)),
        body: SignInPrompt(reason: l.accountSignIn),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(l.verifyTitle)),
      body: AuroraBackground(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: Sizes.contentMax),
            child: ref
                .watch(_verificationProvider)
                .fade(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (e) => ErrorState(
                    message: errorMessage(context, e),
                    retryLabel: l.retry,
                    onRetry: () => ref.invalidate(_verificationProvider),
                  ),
                  data: (data) => ListView(
                    padding: const EdgeInsets.fromLTRB(
                      Gap.x5,
                      Gap.x6,
                      Gap.x5,
                      Gap.x14,
                    ),
                    children: [
                      _TrustDial(score: data.trustScore),
                      Gap.h6,
                      Text(
                        l.verifyIntro,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: palette(context).inkSoft,
                        ),
                      ),
                      Gap.h8,
                      Text(
                        l.verifySteps,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      Gap.h3,
                      for (var i = 0; i < data.steps.length; i++)
                        AnimatedListItem(
                          index: i,
                          child: _StepCard(
                            step: data.steps[i],
                            busy: _submitting == data.steps[i].step,
                            locked: _submitting != null,
                            onSubmit: () => _submitStep(data.steps[i].step),
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

/// The score, as a ring that fills.
///
/// It animates from zero on arrival rather than snapping to its value — the
/// number is the point of the screen, and motion is what makes someone read it.
class _TrustDial extends StatelessWidget {
  const _TrustDial({required this.score});

  final int score;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final p = palette(context);

    // Colour states the verdict before the number is read.
    final tone = score >= 75
        ? p.give
        : score >= 40
        ? p.money
        : p.inkSoft;

    return Center(
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: score / 100),
        duration: M3Motion.extraLong2,
        curve: M3Motion.emphasized,
        builder: (context, value, _) => SizedBox(
          width: 168,
          height: 168,
          child: Stack(
            alignment: Alignment.center,
            children: [
              SizedBox.expand(
                child: CircularProgressIndicator(
                  value: value,
                  strokeWidth: 12,
                  strokeCap: StrokeCap.round,
                  color: tone,
                  backgroundColor: p.sunken,
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${(value * 100).round()}',
                    style: theme.textTheme.displaySmall?.copyWith(
                      color: tone,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                  Text(
                    L.of(context).verifyHeadline,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: p.inkFaint,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StepCard extends StatelessWidget {
  const _StepCard({
    required this.step,
    required this.busy,
    required this.locked,
    required this.onSubmit,
  });

  final VerificationStep step;
  final bool busy;
  final bool locked;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final p = palette(context);
    final theme = Theme.of(context);
    final about = _describe(l, step.step);

    final (stateLabel, tone, mark) = switch (step.state) {
      'done' => (l.verifyDone, p.give, Symbols.check_circle_rounded),
      'pending' => (l.verifyPending, p.money, Symbols.hourglass_bottom_rounded),
      _ => (l.verifyTodo, p.inkFaint, Symbols.radio_button_unchecked_rounded),
    };
    final isDone = step.state == 'done';

    return Padding(
      padding: const EdgeInsets.only(bottom: Gap.x2),
      child: AnimatedContainer(
        duration: M3Motion.medium2,
        padding: const EdgeInsets.all(Gap.x4),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerLowest,
          borderRadius: Radii.rLg,
          // A finished step is outlined in its own colour; the rest keep the
          // hairline, so the list reads as a checklist at a glance.
          border: Border.all(color: isDone ? p.give : p.hair),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: Sizes.avatarMd,
              height: Sizes.avatarMd,
              decoration: BoxDecoration(
                color: isDone ? p.giveSoft : p.sunken,
                borderRadius: Radii.rSm,
              ),
              child: Icon(about.icon, size: Sizes.iconMd, color: tone),
            ),
            Gap.w3,
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          about.label,
                          style: theme.textTheme.titleMedium,
                        ),
                      ),
                      Gap.w2,
                      Pill(
                        label: '+${step.weight}',
                        background: p.moneySoft,
                        foreground: p.money,
                      ),
                    ],
                  ),
                  if (about.hint.isNotEmpty) ...[
                    Gap.h1,
                    Text(
                      about.hint,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: p.inkSoft,
                      ),
                    ),
                  ],
                  Gap.h2,
                  Row(
                    children: [
                      Icon(mark, size: Sizes.iconSm, color: tone),
                      Gap.w1,
                      Text(
                        stateLabel,
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: tone,
                        ),
                      ),
                      if (step.state == 'todo') ...[
                        const Spacer(),
                        if (busy)
                          const SizedBox(
                            width: Sizes.iconLg,
                            height: Sizes.iconLg,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        else
                          FilledButton.tonal(
                            onPressed: locked ? null : onSubmit,
                            style: FilledButton.styleFrom(
                              minimumSize: const Size(0, Sizes.buttonSm),
                              // Without this the theme's wide button padding
                              // made "send" the widest thing on the card,
                              // outweighing the step it belongs to.
                              padding: const EdgeInsets.symmetric(
                                horizontal: Gap.x4,
                              ),
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: Text(l.verifySubmit),
                          ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
