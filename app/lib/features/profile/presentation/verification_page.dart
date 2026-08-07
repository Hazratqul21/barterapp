import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/material_symbols_icons.dart';

import '../../../core/widgets/common.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/models/models.dart';
import '../../trade/data/trade_repository.dart';

final _verificationProvider = FutureProvider.autoDispose<({int trustScore, List<VerificationStep> steps})>((ref) {
  return ref.watch(tradeRepositoryProvider).verification();
});

class VerificationPage extends ConsumerStatefulWidget {
  const VerificationPage({super.key});

  @override
  ConsumerState<VerificationPage> createState() => _VerificationPageState();
}

class _VerificationPageState extends ConsumerState<VerificationPage> {
  bool _isSubmitting = false;

  Future<void> _submitStep(String step) async {
    if (_isSubmitting) return;
    setState(() => _isSubmitting = true);
    try {
      await ref.read(tradeRepositoryProvider).submitStep(step);
      ref.invalidate(_verificationProvider);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final colors = palette(context);

    return Scaffold(
      appBar: AppBar(title: Text(l.verifyTitle)),
      body: ref.watch(_verificationProvider).when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorState(
          message: e.toString(),
          retryLabel: l.retry,
          onRetry: () => ref.invalidate(_verificationProvider),
        ),
        data: (data) {
          if (data.steps.isEmpty) {
            return EmptyState(title: l.verifyTitle, hint: '');
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 32),
                Center(
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox(
                        width: 160,
                        height: 160,
                        child: CircularProgressIndicator(
                          value: data.trustScore / 100,
                          strokeWidth: 10,
                          color: scheme.tertiary,
                          backgroundColor: scheme.primaryContainer,
                        ),
                      ),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '${data.trustScore}',
                            style: theme.textTheme.displayMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: scheme.onSurface,
                            ),
                          ),
                          Text(
                            '/100',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: colors.inkSoft,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Center(
                  child: Text(
                    l.verifyLevel,
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                const SizedBox(height: 48),
                Text(
                  l.verifySteps,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: scheme.onSurface,
                  ),
                ),
                const SizedBox(height: 16),
                ...List.generate(data.steps.length, (index) {
                  final step = data.steps[index];
                  Widget leadingIcon;
                  String stateText;
                  Color cardColor;
                  
                  if (step.state == 'done') {
                    leadingIcon = Icon(Symbols.check_circle_rounded, color: colors.give);
                    stateText = l.verifyDone;
                    cardColor = scheme.surfaceContainerHighest;
                  } else if (step.state == 'pending') {
                    leadingIcon = Icon(Symbols.hourglass_bottom_rounded, color: colors.money);
                    stateText = l.verifyPending;
                    cardColor = scheme.surfaceContainerHigh;
                  } else {
                    leadingIcon = Icon(Symbols.radio_button_unchecked_rounded, color: colors.inkFaint);
                    stateText = l.verifyTodo;
                    cardColor = scheme.surfaceContainerLow;
                  }

                  return AnimatedListItem(
                    index: index,
                    child: Card(
                      color: cardColor,
                      margin: const EdgeInsets.only(bottom: 8),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            leadingIcon,
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          step.step.replaceFirst(step.step[0], step.step[0].toUpperCase()),
                                          style: theme.textTheme.titleMedium,
                                        ),
                                      ),
                                      Pill(
                                        label: '+${step.weight}',
                                        background: colors.moneySoft,
                                        foreground: colors.money,
                                      ),
                                    ],
                                  ),
                                  if (step.hint != null && step.hint!.isNotEmpty) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      step.hint!,
                                      style: theme.textTheme.bodyMedium?.copyWith(
                                        color: colors.inkSoft,
                                      ),
                                    ),
                                  ],
                                  const SizedBox(height: 8),
                                  Text(
                                    stateText,
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: step.state == 'done'
                                          ? colors.give
                                          : (step.state == 'pending' ? colors.money : colors.inkSoft),
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (step.state == 'todo') ...[
                              const SizedBox(width: 16),
                              if (_isSubmitting)
                                const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              else
                                FilledButton.tonal(
                                  onPressed: () => _submitStep(step.step),
                                  child: Text(l.verifySubmit),
                                ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  );
                }),
              ],
            ),
          );
        },
      ),
    );
  }
}
