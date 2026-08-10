import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:material_symbols_icons/material_symbols_icons.dart';

import '../../../core/art/girih.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/common.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/models/models.dart';
import '../../auth/data/auth_repository.dart';
import '../../trade/data/trade_repository.dart';

final _cardsProvider = FutureProvider.autoDispose<List<PaymentCard>>(
  (ref) => ref.watch(tradeRepositoryProvider).cards(),
);

/// Cards and the money that has actually moved.
///
/// Barter is the product; cash is the remainder that settles a trade the goods
/// could not balance. So this screen is small on purpose, and the history is
/// the part worth reading.
class PaymentsPage extends ConsumerStatefulWidget {
  const PaymentsPage({super.key});

  @override
  ConsumerState<PaymentsPage> createState() => _PaymentsPageState();
}

class _PaymentsPageState extends ConsumerState<PaymentsPage> {
  Future<void> _makePrimary(String cardId) async {
    try {
      await ref.read(tradeRepositoryProvider).makePrimary(cardId);
      ref.invalidate(_cardsProvider);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(errorMessage(context, e))));
    }
  }

  Future<void> _removeCard(String cardId) async {
    final l = L.of(context);
    final materialL = MaterialLocalizations.of(context);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l.paymentsRemove),
        content: Text(l.confirmRemoveCard),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(materialL.cancelButtonLabel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: Text(l.paymentsRemove),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await ref.read(tradeRepositoryProvider).removeCard(cardId);
      ref.invalidate(_cardsProvider);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(errorMessage(context, e))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    if (!ref.watch(authStateProvider)) {
      return Scaffold(
        appBar: AppBar(title: Text(l.paymentsTitle)),
        body: SignInPrompt(reason: l.accountSignIn),
      );
    }

    final cards = ref.watch(_cardsProvider);
    final settlements = ref.watch(settlementsProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l.paymentsTitle)),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: Sizes.contentMax),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              Gap.x5,
              Gap.x5,
              Gap.x5,
              Gap.x14,
            ),
            children: [
              _Heading(l.paymentsCards),
              cards.when(
                loading: () => const _CardSkeleton(),
                error: (e, _) => ErrorState(
                  message: errorMessage(context, e),
                  retryLabel: l.retry,
                  onRetry: () => ref.invalidate(_cardsProvider),
                ),
                data: (rows) => rows.isEmpty
                    ? EmptyState(
                        icon: Symbols.credit_card_off_rounded,
                        title: l.paymentsNoCards,
                        hint: l.paymentsNoCardsHint,
                      )
                    : Column(
                        children: [
                          for (var i = 0; i < rows.length; i++)
                            AnimatedListItem(
                              index: i,
                              child: _CardTile(
                                card: rows[i],
                                onPrimary: () => _makePrimary(rows[i].id),
                                onRemove: () => _removeCard(rows[i].id),
                              ),
                            ),
                        ],
                      ),
              ),
              Gap.h6,
              _Heading(l.paymentsHistory),
              settlements.when(
                loading: () => const _CardSkeleton(),
                error: (e, _) => ErrorState(
                  message: errorMessage(context, e),
                  retryLabel: l.retry,
                  onRetry: () => ref.invalidate(settlementsProvider),
                ),
                // The old screen showed the cards' empty message here, so an
                // account with no history was told it had no payment methods.
                data: (rows) => rows.isEmpty
                    ? EmptyState(
                        icon: Symbols.receipt_long_rounded,
                        title: l.paymentsEmpty,
                        hint: l.paymentsEmptyHint,
                      )
                    : Column(
                        children: [
                          for (var i = 0; i < rows.length; i++)
                            AnimatedListItem(
                              index: i,
                              child: _SettlementTile(settlement: rows[i]),
                            ),
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

class _Heading extends StatelessWidget {
  const _Heading(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: Gap.x3),
      child: Text(text, style: Theme.of(context).textTheme.titleLarge),
    );
  }
}

/// A card drawn as a card.
///
/// The list used to be `ListTile`s with a grey credit-card glyph — correct and
/// forgettable. Uzbek payment brands have their own colours, and a person
/// picking between two of theirs recognises the band of colour before the
/// digits.
class _CardTile extends StatelessWidget {
  const _CardTile({
    required this.card,
    required this.onPrimary,
    required this.onRemove,
  });

  final PaymentCard card;
  final VoidCallback onPrimary;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final p = palette(context);
    final theme = Theme.of(context);

    // Two colours per brand, not one with an alpha applied: `Pill` sets its own
    // opacity, so handing it a translucent brand colour produced solid green
    // behind green text.
    final (brand, brandSoft) = switch (card.brand.toLowerCase()) {
      'humo' => (p.give, p.giveSoft),
      'uzcard' => (p.take, p.takeSoft),
      'visa' => (p.money, p.moneySoft),
      _ => (p.inkSoft, p.sunken),
    };

    return Padding(
      padding: const EdgeInsets.only(bottom: Gap.x2),
      child: ClipRRect(
        borderRadius: Radii.rLg,
        child: Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerLowest,
            border: Border.all(color: card.isPrimary ? brand : p.hair),
            borderRadius: Radii.rLg,
          ),
          child: Stack(
            children: [
              // The tilework, faint, only on the primary card — it marks the
              // one that will be charged without needing a second badge.
              if (card.isPrimary)
                Positioned.fill(
                  child: GirihField(color: brand, opacity: 0.05, cell: 52),
                ),
              Padding(
                padding: const EdgeInsets.all(Gap.x4),
                child: Row(
                  children: [
                    Container(
                      width: 52,
                      height: 34,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: brand,
                        borderRadius: Radii.rXs,
                      ),
                      child: Text(
                        card.brand.toUpperCase(),
                        maxLines: 1,
                        overflow: TextOverflow.clip,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    Gap.w3,
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            card.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleSmall,
                          ),
                          Gap.h1,
                          Text(
                            '•••• ${card.last4} · ${card.expires}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: p.inkSoft,
                              fontFeatures: const [
                                FontFeature.tabularFigures(),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Gap.w2,
                    if (card.isPrimary)
                      Pill(
                        label: l.paymentsPrimary,
                        foreground: brand,
                        background: brandSoft,
                      )
                    else
                      PopupMenuButton<String>(
                        icon: const Icon(Symbols.more_vert_rounded),
                        onSelected: (value) => value == 'primary'
                            ? onPrimary()
                            : onRemove(),
                        itemBuilder: (context) => [
                          PopupMenuItem(
                            value: 'primary',
                            child: Text(l.paymentsMakePrimary),
                          ),
                          PopupMenuItem(
                            value: 'remove',
                            child: Text(
                              l.paymentsRemove,
                              style: TextStyle(color: theme.colorScheme.error),
                            ),
                          ),
                        ],
                      ),
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

class _SettlementTile extends StatelessWidget {
  const _SettlementTile({required this.settlement});

  final Settlement settlement;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final p = palette(context);
    final theme = Theme.of(context);
    final locale = Localizations.localeOf(context).languageCode;
    final out = settlement.outgoing;
    final tone = out ? theme.colorScheme.error : p.give;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Gap.x2),
      child: Row(
        children: [
          Container(
            width: Sizes.avatarMd,
            height: Sizes.avatarMd,
            decoration: BoxDecoration(
              color: out ? theme.colorScheme.errorContainer : p.giveSoft,
              shape: BoxShape.circle,
            ),
            child: Icon(
              out
                  ? Symbols.arrow_upward_rounded
                  : Symbols.arrow_downward_rounded,
              size: Sizes.iconMd,
              color: tone,
            ),
          ),
          Gap.w3,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  settlement.counterpartyName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall,
                ),
                Gap.h1,
                Text(
                  '${out ? l.paymentsOut : l.paymentsIn} · '
                  '${DateFormat.yMMMd(locale).format(settlement.settledAt)}',
                  style: theme.textTheme.bodySmall?.copyWith(color: p.inkFaint),
                ),
              ],
            ),
          ),
          Gap.w2,
          Text(
            // The minus is U+2212, not a hyphen: it aligns with the digits.
            '${out ? '−' : '+'}${settlement.amount.format(locale)}',
            style: theme.textTheme.titleMedium?.copyWith(
              color: tone,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

class _CardSkeleton extends StatelessWidget {
  const _CardSkeleton();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < 2; i++)
          const Padding(
            padding: EdgeInsets.only(bottom: Gap.x2),
            child: SkeletonBox(height: 66, radius: Radii.rLg),
          ),
      ],
    );
  }
}
