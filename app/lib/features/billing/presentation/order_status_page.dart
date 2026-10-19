import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/material_symbols_icons.dart';

import '../../../core/network/api_client.dart';
import '../../../core/theme/haptics.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/common.dart';
import '../../../l10n/app_localizations.dart';
import '../../auth/data/auth_repository.dart';
import '../../feed/data/listing_repository.dart';
import '../../trade/data/trade_repository.dart';
import '../data/billing_repository.dart';
import 'payme_button.dart';

/// Waits for Payme. The person pays in the browser; Payme tells the server;
/// this screen asks the server until the order is paid or cancelled.
///
/// Also the target of `https://mab.uz/payments/return?order=…`, where Payme
/// sends people back after paying on the web.
class OrderStatusPage extends ConsumerStatefulWidget {
  const OrderStatusPage({super.key, required this.orderId});

  final String orderId;

  @override
  ConsumerState<OrderStatusPage> createState() => _OrderStatusPageState();
}

class _OrderStatusPageState extends ConsumerState<OrderStatusPage>
    with WidgetsBindingObserver {
  /// How often to ask while waiting. Payme confirms within seconds.
  static const _interval = Duration(seconds: 3);

  /// Stop asking after this; the person can still refresh by hand.
  static const _giveUpAfter = Duration(minutes: 15);

  PaymentOrder? _order;
  Object? _error;
  Timer? _timer;
  late final DateTime _started = DateTime.now();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Coming back from the browser is the most likely moment the order paid.
    if (state == AppLifecycleState.resumed) _load();
  }

  Future<void> _load() async {
    _timer?.cancel();
    try {
      final order = await ref
          .read(billingRepositoryProvider)
          .order(widget.orderId);
      if (!mounted) return;
      setState(() {
        _order = order;
        _error = null;
      });
      if (order.status == OrderStatus.pending) {
        if (DateTime.now().difference(_started) < _giveUpAfter) {
          _timer = Timer(_interval, _load);
        }
      } else {
        _onSettled(order);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e);
      _timer = Timer(_interval * 2, _load);
    }
  }

  bool _settledOnce = false;

  void _onSettled(PaymentOrder order) {
    if (_settledOnce) return;
    _settledOnce = true;
    if (order.status == OrderStatus.paid) {
      Haptics.success();
      // What was bought shows up everywhere it matters.
      ref.invalidate(billingStatusProvider);
      ref.invalidate(myOrdersProvider);
      ref.invalidate(meProvider);
      if (order.listingId != null) {
        ref.invalidate(listingDetailProvider(order.listingId!));
        ref.invalidate(myListingsProvider);
      }
    }
  }

  void _close() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/profile');
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final order = _order;

    return Scaffold(
      appBar: AppBar(title: Text(l.orderTitle)),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Padding(
            padding: const EdgeInsets.all(Gap.x6),
            child: order == null
                ? (_error != null
                      ? ErrorState(
                          message: errorMessage(context, _error!),
                          retryLabel: l.retry,
                          onRetry: _load,
                        )
                      : const CircularProgressIndicator())
                : _Body(order: order, onRefresh: _load, onDone: _close),
          ),
        ),
      ),
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body({
    required this.order,
    required this.onRefresh,
    required this.onDone,
  });

  final PaymentOrder order;
  final VoidCallback onRefresh;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L.of(context);
    final theme = Theme.of(context);
    final p = palette(context);
    final locale = ref.watch(localeProvider);

    final (
      IconData icon,
      Color color,
      String title,
      String hint,
    ) = switch (order.status) {
      OrderStatus.paid => (
        Symbols.check_circle_rounded,
        p.give,
        l.orderPaid,
        order.kind == TariffKind.boost
            ? l.orderPaidBoost(order.durationDays ?? 1)
            : l.orderPaidPack(order.quantity),
      ),
      OrderStatus.cancelled => (
        Symbols.cancel_rounded,
        p.inkFaint,
        l.orderCancelled,
        l.orderCancelledHint,
      ),
      OrderStatus.pending => (
        Symbols.schedule_rounded,
        p.money,
        l.orderPending,
        l.orderPendingHint,
      ),
    };

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: Icon(
            icon,
            key: ValueKey(order.status),
            size: 72,
            color: color,
            fill: 1,
          ),
        ),
        Gap.h4,
        Text(
          title,
          textAlign: TextAlign.center,
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        Gap.h2,
        Text(
          hint,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyLarge?.copyWith(color: p.inkSoft),
        ),
        Gap.h6,
        Text(order.title, style: theme.textTheme.titleSmall),
        Text(
          order.amount.format(locale),
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w800,
            color: p.money,
          ),
        ),
        Gap.h8,
        if (order.status == OrderStatus.pending) ...[
          if (order.checkoutUrl != null)
            PaymeButton(
              onPressed: () =>
                  ref.read(checkoutLauncherProvider)(order.checkoutUrl!),
            ),
          Gap.h3,
          TextButton.icon(
            onPressed: onRefresh,
            icon: const Icon(Symbols.refresh_rounded),
            label: Text(l.retry),
          ),
        ] else
          FilledButton(
            onPressed: onDone,
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(Sizes.buttonLg),
            ),
            child: Text(l.orderDone),
          ),
      ],
    );
  }
}
