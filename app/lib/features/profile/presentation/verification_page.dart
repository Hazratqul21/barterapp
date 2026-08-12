import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/material_symbols_icons.dart';

import '../../../core/theme/tokens.dart';
import '../../../core/widgets/common.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/models/models.dart';
import '../../auth/data/auth_repository.dart';
import '../../trade/data/trade_repository.dart';

final _verificationProvider = FutureProvider.autoDispose<({int trustScore, List<VerificationStep> steps})>((ref) => ref.watch(tradeRepositoryProvider).verification());

({String label, String hint, IconData icon}) _describe(L l, String step) => switch (step) {
      'phone' => (label: l.verifyStepPhone, hint: l.verifyStepPhoneHint, icon: Symbols.smartphone_rounded),
      'passport' => (label: l.verifyStepPassport, hint: l.verifyStepPassportHint, icon: Symbols.id_card_rounded),
      'business' => (label: l.verifyStepBusiness, hint: l.verifyStepBusinessHint, icon: Symbols.storefront_rounded),
      'bank' => (label: l.verifyStepBank, hint: l.verifyStepBankHint, icon: Symbols.account_balance_rounded),
      'video' => (label: l.verifyStepVideo, hint: l.verifyStepVideoHint, icon: Symbols.videocam_rounded),
      _ => (label: step, hint: '', icon: Symbols.shield_rounded),
    };

class VerificationPage extends ConsumerStatefulWidget {
  const VerificationPage({super.key});
  @override
  ConsumerState<VerificationPage> createState() => _VerificationPageState();
}

class _VerificationPageState extends ConsumerState<VerificationPage> {
  String? _submitting;

  Future<void> _submitStep(String step) async {
    if (_submitting != null) return;
    HapticFeedback.mediumImpact();
    setState(() => _submitting = step);
    try {
      await ref.read(tradeRepositoryProvider).submitStep(step);
      ref.invalidate(_verificationProvider);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(errorMessage(context, e))));
    } finally {
      if (mounted) setState(() => _submitting = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    if (!ref.watch(authStateProvider)) return Scaffold(appBar: AppBar(title: Text(l.verifyTitle)), body: SignInPrompt(reason: l.accountSignIn));

    return Scaffold(
      appBar: AppBar(title: Text(l.verifyTitle, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800))),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: Sizes.contentMax),
          child: ref.watch(_verificationProvider).fade(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e) => ErrorState(message: errorMessage(context, e), retryLabel: l.retry, onRetry: () => ref.invalidate(_verificationProvider)),
                data: (data) => ListView(
                  padding: EdgeInsets.fromLTRB(Gap.x5, Gap.x6, Gap.x5, MediaQuery.paddingOf(context).bottom + Gap.x10),
                  children: [
                    _TrustDial(score: data.trustScore),
                    Gap.h6,
                    Text(l.verifyIntro, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: palette(context).inkSoft)),
                    Gap.h8,
                    Text(l.verifySteps, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                    Gap.h3,
                    for (var i = 0; i < data.steps.length; i++)
                      AnimatedListItem(index: i, child: _StepCard(step: data.steps[i], busy: _submitting == data.steps[i].step, locked: _submitting != null, onSubmit: () => _submitStep(data.steps[i].step))),
                  ],
                ),
              ),
        ),
      ),
    );
  }
}

class _TrustDial extends StatelessWidget {
  const _TrustDial({required this.score});
  final int score;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final p = palette(context);
    final tone = score >= 75 ? p.give : score >= 40 ? p.money : p.inkSoft;

    return Center(
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: score / 100),
        duration: const Duration(milliseconds: 1500),
        curve: Curves.elasticOut,
        builder: (context, value, _) => SizedBox(
          width: 180,
          height: 180,
          child: Stack(
            alignment: Alignment.center,
            children: [
              SizedBox.expand(child: CircularProgressIndicator(value: value, strokeWidth: 12, strokeCap: StrokeCap.round, color: tone, backgroundColor: theme.colorScheme.surfaceContainerHighest)),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('${(value * 100).round()}', style: theme.textTheme.displayMedium?.copyWith(color: tone, fontWeight: FontWeight.w900, fontFeatures: const [FontFeature.tabularFigures()])),
                  Text(L.of(context).verifyHeadline.toUpperCase(), style: theme.textTheme.labelSmall?.copyWith(color: p.inkFaint, fontSize: 9, letterSpacing: 1.0)),
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
  const _StepCard({required this.step, required this.busy, required this.locked, required this.onSubmit});
  final VerificationStep step; final bool busy; final bool locked; final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context); final p = palette(context); final theme = Theme.of(context); final about = _describe(l, step.step);
    final isDone = step.state == 'done'; final isPending = step.state == 'pending';
    final (stateLabel, tone, mark) = isDone ? (l.verifyDone, p.give, Symbols.check_circle_rounded) : isPending ? (l.verifyPending, p.money, Symbols.hourglass_bottom_rounded) : (l.verifyTodo, p.inkFaint, Symbols.radio_button_unchecked_rounded);

    return Container(
      margin: const EdgeInsets.only(bottom: Gap.x2),
      padding: const EdgeInsets.all(Gap.x4),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: Radii.rLg,
        border: Border.all(color: isDone ? p.give.withValues(alpha: 0.3) : theme.colorScheme.outlineVariant.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(width: 48, height: 48, decoration: BoxDecoration(color: isDone ? p.giveSoft : theme.colorScheme.surfaceContainerHighest, borderRadius: Radii.rSm), child: Icon(about.icon, size: 24, color: tone)),
          Gap.w3,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [Expanded(child: Text(about.label, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700))), Gap.w2, Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: p.moneySoft, borderRadius: Radii.rFull), child: Text('+${step.weight}', style: TextStyle(color: p.money, fontSize: 10, fontWeight: FontWeight.w900)))]),
                if (about.hint.isNotEmpty) Text(about.hint, style: theme.textTheme.bodySmall?.copyWith(color: p.inkSoft)),
                Gap.h2,
                Row(
                  children: [
                    Icon(mark, size: 14, color: tone, fill: isDone ? 1 : 0), Gap.w1, Text(stateLabel, style: theme.textTheme.labelMedium?.copyWith(color: tone, fontWeight: FontWeight.bold)),
                    if (step.state == 'todo') ...[const Spacer(), busy ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : FilledButton.tonal(onPressed: locked ? null : onSubmit, style: FilledButton.styleFrom(minimumSize: const Size(0, 32), padding: const EdgeInsets.symmetric(horizontal: 16)), child: Text(l.verifySubmit))]
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
