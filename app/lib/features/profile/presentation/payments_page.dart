import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:material_symbols_icons/material_symbols_icons.dart';

import '../../../core/widgets/common.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/models/models.dart';
import '../../trade/data/trade_repository.dart';

final _cardsProvider = FutureProvider.autoDispose<List<PaymentCard>>((ref) {
  return ref.watch(tradeRepositoryProvider).cards();
});

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
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Future<void> _removeCard(String cardId) async {
    final l = L.of(context);
    final materialL = MaterialLocalizations.of(context);
    
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l.paymentsRemove),
        content: const Text('Are you sure you want to remove this card?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(materialL.cancelButtonLabel),
          ),
          FilledButton(
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
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final colors = palette(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final cardsAsync = ref.watch(_cardsProvider);
    final settlementsAsync = ref.watch(settlementsProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l.paymentsTitle)),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
              child: Text(
                l.paymentsTitle,
                style: theme.textTheme.titleSmall?.copyWith(
                  color: colors.inkSoft,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ),
          cardsAsync.when(
            loading: () => const SliverToBoxAdapter(
              child: Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: CircularProgressIndicator(),
                ),
              ),
            ),
            error: (e, _) => SliverToBoxAdapter(
              child: ErrorState(
                message: e.toString(),
                retryLabel: l.retry,
                onRetry: () => ref.invalidate(_cardsProvider),
              ),
            ),
            data: (cards) {
              if (cards.isEmpty) {
                return SliverToBoxAdapter(
                  child: EmptyState(
                    title: l.paymentsEmpty,
                    hint: '',
                  ),
                );
              }
              return SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final card = cards[index];
                    Color brandColor;
                    if (card.brand.toLowerCase() == 'humo') {
                      brandColor = colors.give;
                    } else if (card.brand.toLowerCase() == 'uzcard') {
                      brandColor = colors.take;
                    } else if (card.brand.toLowerCase() == 'visa') {
                      brandColor = colors.money;
                    } else {
                      brandColor = colors.inkSoft;
                    }

                    return AnimatedListItem(
                      index: index,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        child: Card(
                          child: ListTile(
                            leading: Icon(Symbols.credit_card_rounded, color: brandColor, size: 32),
                            title: Text(card.label),
                            subtitle: Text('•••• ${card.last4} · ${card.expires}'),
                            trailing: card.isPrimary
                                ? Chip(
                                    label: Text(l.paymentsPrimary),
                                    backgroundColor: scheme.primaryContainer,
                                    labelStyle: theme.textTheme.labelMedium?.copyWith(
                                      color: scheme.onPrimaryContainer,
                                    ),
                                    side: BorderSide.none,
                                  )
                                : PopupMenuButton<String>(
                                    onSelected: (val) {
                                      if (val == 'primary') _makePrimary(card.id);
                                      if (val == 'remove') _removeCard(card.id);
                                    },
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
                          ),
                        ),
                      ),
                    );
                  },
                  childCount: cards.length,
                ),
              );
            },
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 32, 16, 8),
              child: Text(
                l.paymentsHistory,
                style: theme.textTheme.titleSmall?.copyWith(
                  color: colors.inkSoft,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ),
          
          settlementsAsync.when(
            loading: () => const SliverToBoxAdapter(
              child: Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: CircularProgressIndicator(),
                ),
              ),
            ),
            error: (e, _) => SliverToBoxAdapter(
              child: ErrorState(
                message: e.toString(),
                retryLabel: l.retry,
                onRetry: () => ref.invalidate(settlementsProvider),
              ),
            ),
            data: (settlements) {
              if (settlements.isEmpty) {
                return SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Center(
                      child: Text(
                        l.paymentsEmpty,
                        style: theme.textTheme.bodyLarge?.copyWith(color: colors.inkSoft),
                      ),
                    ),
                  ),
                );
              }
              
              final locale = Localizations.localeOf(context).toString();

              return SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final settlement = settlements[index];
                    final isOutgoing = settlement.outgoing;
                    
                    return AnimatedListItem(
                      index: index,
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: isOutgoing ? theme.colorScheme.errorContainer : colors.giveSoft,
                          child: Icon(
                            isOutgoing ? Symbols.arrow_upward_rounded : Symbols.arrow_downward_rounded,
                            color: isOutgoing ? theme.colorScheme.error : colors.give,
                          ),
                        ),
                        title: Text(settlement.counterpartyName),
                        subtitle: Text(DateFormat.yMMMd(locale).format(settlement.settledAt)),
                        trailing: Text(
                          '${isOutgoing ? '−' : '+'} ${settlement.amount.format(locale)}',
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: isOutgoing ? theme.colorScheme.error : colors.give,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    );
                  },
                  childCount: settlements.length,
                ),
              );
            },
          ),
          
          const SliverToBoxAdapter(child: SizedBox(height: 32)),
        ],
      ),
    );
  }
}
