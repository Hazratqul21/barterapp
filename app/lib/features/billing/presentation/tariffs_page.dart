import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:material_symbols_icons/material_symbols_icons.dart';

import '../../../core/network/api_client.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/common.dart';
import '../../../l10n/app_localizations.dart';
import '../../auth/data/auth_repository.dart';
import '../data/billing_repository.dart';
import 'payme_button.dart';

/// Plans: how many free listings are left, the packs on sale, and what was
/// paid before. Every price comes from the server — the admin sets them.
class TariffsPage extends ConsumerWidget {
  const TariffsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L.of(context);
    final theme = Theme.of(context);

    if (!ref.watch(authStateProvider)) {
      return Scaffold(
        appBar: AppBar(title: Text(l.billingTitle)),
        body: SignInPrompt(reason: l.accountSignIn),
      );
    }

    final status = ref.watch(billingStatusProvider);
    final packs = ref.watch(tariffsProvider(TariffKind.listingPack));
    final orders = ref.watch(myOrdersProvider);

    Future<void> refresh() async {
      ref.invalidate(billingStatusProvider);
      ref.invalidate(tariffsProvider(TariffKind.listingPack));
      ref.invalidate(myOrdersProvider);
      await ref.read(tariffsProvider(TariffKind.listingPack).future);
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          l.billingTitle,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: refresh,
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: Sizes.contentMax),
            child: ListView(
              padding: EdgeInsets.fromLTRB(
                Gap.x5,
                Gap.x4,
                Gap.x5,
                MediaQuery.paddingOf(context).bottom + Gap.x14,
              ),
              children: [
                status.maybeWhen(
                  data: (s) =>
                      s == null ? const SizedBox.shrink() : _QuotaCard(s),
                  orElse: () => const SizedBox.shrink(),
                ),
                Gap.h6,
                _Heading(l.billingPacks),
                Gap.h3,
                packs.fade(
                  loading: () => const _Skeleton(),
                  error: (e) => ErrorState(
                    message: errorMessage(context, e),
                    retryLabel: l.retry,
                    onRetry: refresh,
                  ),
                  data: (rows) => rows.isEmpty
                      ? EmptyState(
                          icon: Symbols.sell_rounded,
                          title: l.billingEmpty,
                          hint: l.billingEmptyHint,
                        )
                      : Column(
                          children: [
                            for (var i = 0; i < rows.length; i++)
                              AnimatedListItem(
                                index: i,
                                child: TariffCard(tariff: rows[i]),
                              ),
                          ],
                        ),
                ),
                Gap.h6,
                _Heading(l.billingBoostSection),
                Gap.h2,
                Text(
                  l.billingBoostHint,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: palette(context).inkSoft,
                  ),
                ),
                Gap.h4,
                const _SecureNote(),
                Gap.h8,
                _Heading(l.billingHistory),
                Gap.h3,
                orders.maybeWhen(
                  data: (rows) => rows.isEmpty
                      ? Text(
                          l.billingNoOrders,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: palette(context).inkFaint,
                          ),
                        )
                      : Column(
                          children: [for (final o in rows) OrderTile(order: o)],
                        ),
                  orElse: () => const SizedBox.shrink(),
                ),
              ],
            ),
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
  Widget build(BuildContext context) => Text(
    text,
    style: Theme.of(context).textTheme.labelSmall?.copyWith(
      color: palette(context).inkFaint,
      letterSpacing: 1.2,
    ),
  );
}

class _QuotaCard extends StatelessWidget {
  const _QuotaCard(this.status);
  final BillingStatus status;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final theme = Theme.of(context);
    final p = palette(context);
    final text = status.listingFeeEnabled
        ? l.billingFreeLeft(status.freeListingsLeft)
        : l.billingFreeUnlimited;
    return Container(
      padding: const EdgeInsets.all(Gap.x4),
      decoration: BoxDecoration(color: p.giveSoft, borderRadius: Radii.rLg),
      child: Row(
        children: [
          Icon(Symbols.campaign_rounded, color: p.give, size: Sizes.iconLg),
          Gap.w3,
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// One plan: what it gives, the price (struck through when discounted) and
/// the Payme button. Shared by the plans page and the boost sheet.
class TariffCard extends ConsumerStatefulWidget {
  const TariffCard({super.key, required this.tariff, this.listingId});

  final Tariff tariff;
  final String? listingId;

  @override
  ConsumerState<TariffCard> createState() => _TariffCardState();
}

class _TariffCardState extends ConsumerState<TariffCard> {
  bool _busy = false;

  Future<void> _pay() async {
    setState(() => _busy = true);
    try {
      await startPayment(
        context,
        ref,
        tariff: widget.tariff,
        listingId: widget.listingId,
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final theme = Theme.of(context);
    final p = palette(context);
    final locale = ref.watch(localeProvider);
    final t = widget.tariff;
    final what = t.kind == TariffKind.boost
        ? l.billingDays(t.durationDays ?? 1)
        : l.billingListings(t.quantity);

    return Container(
      margin: const EdgeInsets.only(bottom: Gap.x3),
      padding: const EdgeInsets.all(Gap.x4),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLowest,
        borderRadius: Radii.rLg,
        border: Border.all(color: p.hair),
        boxShadow: Shadows.clay,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      t.title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Gap.h1,
                    Text(
                      what,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: p.inkSoft,
                      ),
                    ),
                  ],
                ),
              ),
              if (t.discounted)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: Gap.x2,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: p.moneySoft,
                    borderRadius: Radii.rFull,
                  ),
                  child: Text(
                    '−${t.discountPercent}%',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: p.money,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
            ],
          ),
          Gap.h3,
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.end,
            spacing: Gap.x2,
            children: [
              Text(
                t.finalPrice.format(locale),
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: p.money,
                ),
              ),
              if (t.discounted)
                Text(
                  t.price.format(locale),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: p.inkFaint,
                    decoration: TextDecoration.lineThrough,
                  ),
                ),
            ],
          ),
          if (t.discounted && t.discountUntil != null)
            Padding(
              padding: const EdgeInsets.only(top: Gap.x1),
              child: Text(
                l.billingDiscountUntil(
                  DateFormat.yMMMd(locale).format(t.discountUntil!.toLocal()),
                ),
                style: theme.textTheme.bodySmall?.copyWith(color: p.inkFaint),
              ),
            ),
          Gap.h4,
          PaymeButton(onPressed: _pay, busy: _busy),
        ],
      ),
    );
  }
}

class _SecureNote extends StatelessWidget {
  const _SecureNote();

  @override
  Widget build(BuildContext context) {
    final p = palette(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Symbols.lock_rounded, size: Sizes.iconSm, color: p.inkFaint),
        Gap.w2,
        Expanded(
          child: Text(
            L.of(context).billingSecureNote,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: p.inkFaint),
          ),
        ),
      ],
    );
  }
}

class _Skeleton extends StatelessWidget {
  const _Skeleton();

  @override
  Widget build(BuildContext context) => Column(
    children: [
      for (var i = 0; i < 2; i++)
        Container(
          height: 150,
          margin: const EdgeInsets.only(bottom: Gap.x3),
          decoration: BoxDecoration(
            color: palette(context).sunken,
            borderRadius: Radii.rLg,
          ),
        ),
    ],
  );
}

/// A past payment, tappable while it is still waiting.
class OrderTile extends ConsumerWidget {
  const OrderTile({super.key, required this.order});
  final PaymentOrder order;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L.of(context);
    final p = palette(context);
    final locale = ref.watch(localeProvider);
    final (icon, color, label) = switch (order.status) {
      OrderStatus.paid => (Symbols.check_circle_rounded, p.give, l.orderPaid),
      OrderStatus.cancelled => (
        Symbols.cancel_rounded,
        p.inkFaint,
        l.orderCancelled,
      ),
      OrderStatus.pending => (
        Symbols.schedule_rounded,
        p.money,
        l.orderPending,
      ),
    };
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: color, fill: 1),
      title: Text(order.title),
      subtitle: Text(
        '$label · ${DateFormat.yMMMd(locale).add_Hm().format(order.createdAt.toLocal())}',
      ),
      trailing: Text(
        order.amount.format(locale),
        style: Theme.of(
          context,
        ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
      ),
      onTap: order.status == OrderStatus.pending
          ? () => context.push('/payments/order/${order.id}')
          : null,
    );
  }
}
