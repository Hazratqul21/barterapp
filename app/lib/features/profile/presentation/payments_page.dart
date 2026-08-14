import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/material_symbols_icons.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../core/art/girih.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/common.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/models/models.dart';
import '../../auth/data/auth_repository.dart';
import '../../trade/data/trade_repository.dart';

final _cardsProvider = FutureProvider.autoDispose<List<PaymentCard>>(
  (ref) => ref.watch(tradeRepositoryProvider).cards(),
);

class PaymentsPage extends ConsumerStatefulWidget {
  const PaymentsPage({super.key});

  @override
  ConsumerState<PaymentsPage> createState() => _PaymentsPageState();
}

class _PaymentsPageState extends ConsumerState<PaymentsPage> {
  Future<void> _makePrimary(String cardId) async {
    HapticFeedback.mediumImpact();
    try {
      await ref.read(tradeRepositoryProvider).makePrimary(cardId);
      ref.invalidate(_cardsProvider);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(errorMessage(context, e))));
    }
  }

  Future<void> _removeCard(String cardId) async {
    final l = L.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l.paymentsRemove),
        content: Text(l.confirmRemoveCard),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(l.cancel)),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error),
            onPressed: () => Navigator.pop(context, true),
            child: Text(l.paymentsRemove),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      HapticFeedback.heavyImpact();
      try {
        await ref.read(tradeRepositoryProvider).removeCard(cardId);
        ref.invalidate(_cardsProvider);
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(errorMessage(context, e))));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final theme = Theme.of(context);
    final p = palette(context);

    if (!ref.watch(authStateProvider)) {
      return Scaffold(appBar: AppBar(title: Text(l.paymentsTitle)), body: SignInPrompt(reason: l.accountSignIn));
    }

    final cards = ref.watch(_cardsProvider);
    final settlements = ref.watch(settlementsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l.paymentsTitle, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: Sizes.contentMax),
          child: ListView(
            physics: const BouncingScrollPhysics(),
            padding: EdgeInsets.fromLTRB(Gap.x5, Gap.x4, Gap.x5, MediaQuery.paddingOf(context).bottom + Gap.x14),
            children: [
              Text(l.paymentsCards, style: theme.textTheme.labelSmall?.copyWith(color: p.inkFaint, letterSpacing: 1.2)),
              Gap.h3,
              cards.fade(
                loading: () => const _CardSkeleton(),
                error: (e) => ErrorState(message: errorMessage(context, e), retryLabel: l.retry, onRetry: () => ref.invalidate(_cardsProvider)),
                data: (rows) => rows.isEmpty
                    ? EmptyState(icon: Symbols.credit_card_off_rounded, title: l.paymentsNoCards, hint: l.paymentsNoCardsHint)
                    : Column(
                        children: [
                          for (var i = 0; i < rows.length; i++)
                            _CardTile(card: rows[i], onPrimary: () => _makePrimary(rows[i].id), onRemove: () => _removeCard(rows[i].id))
                                .animate()
                                .fadeIn(delay: (100 * i).ms)
                                .slideX(begin: 0.1, end: 0, curve: M3Motion.emphasizedDecelerate),
                        ],
                      ),
              ),
              Gap.h8,
              Text(l.paymentsHistory, style: theme.textTheme.labelSmall?.copyWith(color: p.inkFaint, letterSpacing: 1.2)),
              Gap.h3,
              settlements.fade(
                loading: () => const _CardSkeleton(),
                error: (e) => ErrorState(message: errorMessage(context, e), retryLabel: l.retry, onRetry: () => ref.invalidate(settlementsProvider)),
                data: (rows) => rows.isEmpty
                    ? EmptyState(icon: Symbols.receipt_long_rounded, title: l.paymentsEmpty, hint: l.paymentsEmptyHint)
                    : Column(
                        children: [
                          for (var i = 0; i < rows.length; i++)
                            _SettlementTile(settlement: rows[i]).animate().fadeIn(delay: (50 * i).ms),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CardTile extends StatelessWidget {
  const _CardTile({required this.card, required this.onPrimary, required this.onRemove});
  final PaymentCard card; final VoidCallback onPrimary; final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context); final p = palette(context); final theme = Theme.of(context);
    final (brandColor, softColor) = switch (card.brand.toLowerCase()) {
      'humo' => (p.give, p.giveSoft),
      'uzcard' => (p.take, p.takeSoft),
      'visa' => (p.money, p.moneySoft),
      _ => (p.inkSoft, theme.colorScheme.surfaceContainerHigh),
    };

    return Container(
      margin: const EdgeInsets.only(bottom: Gap.x3),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: Radii.rLg,
        border: Border.all(color: card.isPrimary ? brandColor : theme.colorScheme.outlineVariant.withValues(alpha: 0.4), width: card.isPrimary ? 2 : 1),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          if (card.isPrimary) Positioned.fill(child: GirihField(color: brandColor, opacity: 0.04, cell: 48)),
          Padding(
            padding: const EdgeInsets.all(Gap.x4),
            child: Row(
              children: [
                Container(
                  width: 56, height: 36,
                  decoration: BoxDecoration(color: brandColor, borderRadius: Radii.rXs),
                  child: Center(child: Text(card.brand.toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.black))),
                ),
                Gap.w4,
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(card.label, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                      Text('•••• ${card.last4}', style: theme.textTheme.bodySmall?.copyWith(color: p.inkSoft, fontFeatures: const [FontFeature.tabularFigures()])),
                    ],
                  ),
                ),
                if (card.isPrimary)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(color: softColor, borderRadius: Radii.rFull),
                    child: Text(l.paymentsPrimary, style: theme.textTheme.labelSmall?.copyWith(color: brandColor, fontSize: 9, fontWeight: FontWeight.black)),
                  )
                else
                  PopupMenuButton(
                    icon: const Icon(Symbols.more_vert_rounded),
                    onSelected: (v) => v == 'p' ? onPrimary() : onRemove(),
                    itemBuilder: (c) => [
                      PopupMenuItem(value: 'p', child: Text(l.paymentsMakePrimary)),
                      PopupMenuItem(value: 'r', child: Text(l.paymentsRemove, style: TextStyle(color: theme.colorScheme.error))),
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

class _SettlementTile extends StatelessWidget {
  const _SettlementTile({required this.settlement});
  final Settlement settlement;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context); final p = palette(context);
    final out = settlement.outgoing; final color = out ? theme.colorScheme.error : p.give;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Gap.x2),
      child: Row(
        children: [
          Container(width: 44, height: 44, decoration: BoxDecoration(color: out ? theme.colorScheme.errorContainer.withValues(alpha: 0.3) : p.giveSoft, shape: BoxShape.circle), child: Icon(out ? Symbols.arrow_upward_rounded : Symbols.arrow_downward_rounded, size: 20, color: color)),
          Gap.w3,
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(settlement.counterpartyName, style: theme.textTheme.titleSmall), Text(formatDate(context, settlement.settledAt), style: theme.textTheme.bodySmall?.copyWith(color: p.inkFaint))])),
          Text('${out ? '−' : '+'}${settlement.amount.format(L.of(context).localeName)}', style: theme.textTheme.titleMedium?.copyWith(color: color, fontWeight: FontWeight.w800, fontFeatures: const [FontFeature.tabularFigures()])),
        ],
      ),
    );
  }
}

class _CardSkeleton extends StatelessWidget {
  const _CardSkeleton();
  @override
  Widget build(BuildContext context) => Column(children: [for (var i = 0; i < 2; i++) const Padding(padding: EdgeInsets.only(bottom: Gap.x3), child: SkeletonBox(height: 80, radius: Radii.rLg))]);
}
