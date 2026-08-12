import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:material_symbols_icons/material_symbols_icons.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/glass.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/models/models.dart';
import '../data/trade_repository.dart';

class ChatPage extends ConsumerStatefulWidget {
  const ChatPage({
    super.key,
    required this.conversationId,
    this.embedded = false,
  });

  final String conversationId;
  final bool embedded;

  @override
  ConsumerState<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends ConsumerState<ChatPage> with WidgetsBindingObserver {
  final _controller = TextEditingController();
  final _scroll = ScrollController();
  StreamSubscription<LiveEvent>? _live;
  Timer? _typingTimer;
  DateTime _lastTypingSent = DateTime.fromMillisecondsSinceEpoch(0);
  bool _peerTyping = false;
  bool _sending = false;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    ref.read(liveChannelProvider).resume();
    ref.invalidate(conversationProvider(widget.conversationId));
    ref.invalidate(conversationsProvider);
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final channel = ref.read(liveChannelProvider)..connect();
    _live = channel.events.listen((event) {
      if (event.conversationId != widget.conversationId) return;
      if (event is MessageArrived) {
        ref.invalidate(conversationProvider(widget.conversationId));
        ref.invalidate(conversationsProvider);
      } else if (event is PeerTyping) {
        setState(() => _peerTyping = true);
        _typingTimer?.cancel();
        _typingTimer = Timer(const Duration(seconds: 3), () {
          if (mounted) setState(() => _peerTyping = false);
        });
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _live?.cancel();
    _typingTimer?.cancel();
    _controller.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _onTextChanged(String text) {
    if (text.isEmpty) return;
    final now = DateTime.now();
    if (now.difference(_lastTypingSent).inSeconds >= 2) {
      _lastTypingSent = now;
      ref.read(liveChannelProvider).typing(widget.conversationId);
    }
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _sending) return;

    _controller.clear();
    setState(() => _sending = true);
    try {
      await ref.read(tradeRepositoryProvider).send(widget.conversationId, text);
      ref.invalidate(conversationProvider(widget.conversationId));
      ref.invalidate(conversationsProvider);
    } catch (e) {
      if (!mounted) return;
      _controller.text = text;
      _complain(errorMessage(context, e));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _complain(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _act(String offerId, String action, {int? cashDeltaMinor}) async {
    try {
      await ref.read(tradeRepositoryProvider).act(offerId, action, cashDeltaMinor: cashDeltaMinor);
      ref.invalidate(conversationProvider(widget.conversationId));
      ref.invalidate(conversationsProvider);
      ref.invalidate(matchesProvider);
    } catch (e) {
      if (mounted) _complain(errorMessage(context, e));
    }
  }

  Future<void> _counter(Offer offer) async {
    final l = L.of(context);
    final controller = TextEditingController(
      text: offer.cashDeltaMinor == 0 ? '' : (offer.cashDeltaMinor.abs() ~/ 100).toString(),
    );

    final confirmed = await showBarterPanel<bool>(
      context: context,
      title: l.dealCounterTitle,
      subtitle: l.dealCounterHint,
      skin: const SheetSkin.wallpaper(intensity: 1.4),
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            autofocus: true,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: InputDecoration(
              labelText: l.dealCounterCash,
              suffixText: 'so‘m',
              prefixIcon: const Icon(Symbols.payments_rounded),
            ),
          ),
          Gap.h5,
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l.dealCounterSend),
          ),
        ],
      ),
    );

    final som = int.tryParse(controller.text.trim()) ?? 0;
    controller.dispose();
    if (confirmed == true) {
      await _act(offer.id, 'counter', cashDeltaMinor: som * 100);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final p = palette(context);
    final theme = Theme.of(context);
    final state = ref.watch(conversationProvider(widget.conversationId));

    return Scaffold(
      appBar: widget.embedded
          ? null
          : AppBar(
              titleSpacing: 0,
              title: state.when(
                data: (detail) => _PeerHeader(peer: detail.summary.peer),
                loading: () => const SizedBox.shrink(),
                error: (_, _) => const SizedBox.shrink(),
              ),
            ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: Sizes.contentMax),
          child: state.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => ErrorState(
              message: errorMessage(context, e),
              retryLabel: l.retry,
              onRetry: () => ref.invalidate(conversationProvider(widget.conversationId)),
            ),
            data: (detail) {
              final offer = detail.offer;
              return Column(
                children: [
                  if (widget.embedded)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: Gap.x4, vertical: Gap.x3),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerLowest,
                        border: Border(bottom: BorderSide(color: p.hair)),
                      ),
                      child: Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: _PeerHeader(peer: detail.summary.peer),
                      ),
                    ),
                  _DealPanel(
                    offer: offer,
                    onAccept: () => _act(offer.id, 'accept'),
                    onDecline: () => _act(offer.id, 'decline'),
                    onCounter: () => _counter(offer),
                    onComplete: () => _act(offer.id, 'complete'),
                  ),
                  Expanded(
                    child: detail.messages.isEmpty
                        ? EmptyState(
                            icon: Symbols.forum_rounded,
                            title: l.chatPlaceholder,
                            hint: '',
                          )
                        : ListView.builder(
                            controller: _scroll,
                            reverse: true,
                            padding: const EdgeInsets.symmetric(horizontal: Gap.x4, vertical: Gap.x4),
                            itemCount: detail.messages.length,
                            itemBuilder: (context, index) {
                              final message = detail.messages[detail.messages.length - 1 - index];
                              return _Bubble(message: message)
                                  .animate()
                                  .fadeIn(duration: 200.ms)
                                  .slideY(begin: 0.05, end: 0, curve: M3Motion.emphasizedDecelerate);
                            },
                          ),
                  ),
                  if (_peerTyping)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(Gap.x5, 0, Gap.x5, Gap.x2),
                      child: Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: Text(
                          l.chatTyping,
                          style: theme.textTheme.labelSmall?.copyWith(color: p.give, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                  _Composer(
                    controller: _controller,
                    sending: _sending,
                    onChanged: _onTextChanged,
                    onSend: _send,
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _PeerHeader extends StatelessWidget {
  const _PeerHeader({required this.peer});
  final TraderBrief peer;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final p = palette(context);
    final theme = Theme.of(context);

    return InkWell(
      onTap: () => context.push('/trader/${peer.id}'),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: Gap.x2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            TraderAvatar(
              url: peer.avatarUrl,
              name: peer.name,
              size: Sizes.avatarSm,
              isOnline: peer.isOnline,
              showPresence: true,
            ),
            Gap.w2,
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(
                          peer.displayName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleSmall,
                        ),
                      ),
                      if (peer.isVerified) ...[
                        Gap.w1,
                        Icon(Symbols.verified_rounded, size: Sizes.iconSm, color: p.give, fill: 1),
                      ],
                    ],
                  ),
                  if (peer.isOnline)
                    Text(
                      l.traderOnline,
                      style: theme.textTheme.labelSmall?.copyWith(color: p.give, letterSpacing: 0),
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

class _DealPanel extends ConsumerWidget {
  const _DealPanel({
    required this.offer,
    required this.onAccept,
    required this.onDecline,
    required this.onCounter,
    required this.onComplete,
  });

  final Offer offer;
  final VoidCallback onAccept;
  final VoidCallback onDecline;
  final VoidCallback onCounter;
  final VoidCallback onComplete;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L.of(context);
    final p = palette(context);
    final theme = Theme.of(context);
    final locale = l.localeName;

    final mine = offer.offered.map((o) => o.title).join(' + ');
    final cash = offer.cashDeltaMinor != 0 ? ' + ${offer.cash.format(locale)}' : '';
    final awaitingMe = !offer.isMine;
    final open = offer.status == OfferStatus.pending || offer.status == OfferStatus.talking;

    return AnimatedContainer(
      duration: M3Motion.medium3,
      curve: M3Motion.emphasized,
      margin: const EdgeInsets.fromLTRB(Gap.x4, Gap.x3, Gap.x4, 0),
      padding: const EdgeInsets.all(Gap.x4),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: Radii.rLg,
        border: Border.all(
          color: switch (offer.status) {
            OfferStatus.accepted || OfferStatus.completed => p.give,
            OfferStatus.declined => theme.colorScheme.error,
            _ => theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
          },
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: _StatusLine(status: offer.status)),
              if (open && offer.expiresAt != null) _Expiry(expiresAt: offer.expiresAt!),
            ],
          ),
          Gap.h3,
          TradeSides(
            dense: true,
            giveCaption: offer.isMine ? l.dealYouGive : l.dealYouGet,
            giveLabel: '$mine$cash',
            takeCaption: offer.isMine ? l.dealYouGet : l.dealYouGive,
            takeLabel: offer.wanted.title,
          ),
          if (open && awaitingMe) ...[
            Gap.h4,
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: onDecline,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: theme.colorScheme.error,
                      side: BorderSide(color: theme.colorScheme.error),
                    ),
                    child: Text(l.dealDecline),
                  ),
                ),
                Gap.w2,
                Expanded(child: OutlinedButton(onPressed: onCounter, child: Text(l.dealCounter))),
                Gap.w2,
                Expanded(
                  child: FilledButton(
                    onPressed: onAccept,
                    style: FilledButton.styleFrom(minimumSize: const Size(0, Sizes.buttonMd), padding: EdgeInsets.zero),
                    child: Text(l.dealAccept),
                  ),
                ),
              ],
            ),
          ] else if (offer.status == OfferStatus.accepted) ...[
            Gap.h4,
            FilledButton.icon(
              onPressed: onComplete,
              icon: const Icon(Symbols.check_circle_rounded),
              label: Text(l.dealComplete),
            ),
          ] else if (offer.status == OfferStatus.completed)
            _ReviewPrompt(offer: offer),
        ],
      ),
    );
  }
}

class _StatusLine extends StatelessWidget {
  const _StatusLine({required this.status});
  final OfferStatus status;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final p = palette(context);
    final (label, color) = switch (status) {
      OfferStatus.pending => (l.dealPending, p.money),
      OfferStatus.talking => (l.dealTalking, p.take),
      OfferStatus.accepted => (l.dealAccepted, p.give),
      OfferStatus.completed => (l.dealCompleted, p.give),
      OfferStatus.declined => (l.dealDeclined, Theme.of(context).colorScheme.error),
      _ => (l.dealExpired, p.inkFaint),
    };
    return Text(label.toUpperCase(), style: Theme.of(context).textTheme.labelSmall?.copyWith(color: color));
  }
}

class _Expiry extends StatelessWidget {
  const _Expiry({required this.expiresAt});
  final DateTime expiresAt;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final p = palette(context);
    final theme = Theme.of(context);
    final left = expiresAt.difference(DateTime.now());
    final (label, colour) = switch (left) {
      _ when left.isNegative => (l.dealExpired, p.inkFaint),
      _ when left.inHours < 1 => (l.chatExpiresSoon, theme.colorScheme.error),
      _ when left.inHours < 6 => (l.chatExpiresIn(left.inHours), theme.colorScheme.error),
      _ => (l.chatExpiresIn(left.inHours), p.inkFaint),
    };
    return Text(label, style: theme.textTheme.labelSmall?.copyWith(color: colour, letterSpacing: 0));
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.message});
  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final theme = Theme.of(context);
    final mine = message.isMine;
    final p = palette(context);

    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: Gap.x2),
        constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.78),
        padding: const EdgeInsets.symmetric(horizontal: Gap.x4, vertical: Gap.x3),
        decoration: BoxDecoration(
          color: mine ? theme.colorScheme.primaryContainer : theme.colorScheme.surfaceContainerHigh,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(22),
            topRight: const Radius.circular(22),
            bottomLeft: Radius.circular(mine ? 22 : 4),
            bottomRight: Radius.circular(mine ? 4 : 22),
          ),
        ),
        child: Column(
          crossAxisAlignment: mine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            if (message.photoUrl != null) ...[
              ClipRRect(
                borderRadius: Radii.rSm,
                child: RemoteImage(url: message.photoUrl, semanticLabel: ''),
              ),
              Gap.h2,
            ],
            Text(
              message.body,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: mine ? theme.colorScheme.onPrimaryContainer : theme.colorScheme.onSurfaceVariant,
              ),
            ),
            Gap.h1,
            Text(
              DateFormat.Hm(l.localeName).format(message.createdAt.toLocal()),
              style: theme.textTheme.labelSmall?.copyWith(
                color: mine ? theme.colorScheme.onPrimaryContainer.withValues(alpha: 0.6) : p.inkFaint,
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  const _Composer({
    required this.controller,
    required this.sending,
    required this.onChanged,
    required this.onSend,
  });

  final TextEditingController controller;
  final bool sending;
  final ValueChanged<String> onChanged;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(Gap.x4, Gap.x2, Gap.x4, Gap.x4),
      child: SafeArea(
        top: false,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(28),
                ),
                padding: const EdgeInsets.symmetric(horizontal: Gap.x2),
                child: TextField(
                  controller: controller,
                  onChanged: onChanged,
                  minLines: 1,
                  maxLines: 5,
                  decoration: InputDecoration(
                    hintText: l.chatPlaceholder,
                    filled: false,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: Gap.x3, vertical: Gap.x3),
                  ),
                ),
              ),
            ),
            Gap.w2,
            IconButton.filled(
              onPressed: sending ? null : onSend,
              icon: sending
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Symbols.send_rounded),
              style: IconButton.styleFrom(
                backgroundColor: theme.colorScheme.primary,
                foregroundColor: theme.colorScheme.onPrimary,
                minimumSize: const Size(52, 52),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReviewPrompt extends ConsumerStatefulWidget {
  const _ReviewPrompt({required this.offer});
  final Offer offer;
  @override
  ConsumerState<_ReviewPrompt> createState() => _ReviewPromptState();
}

class _ReviewPromptState extends ConsumerState<_ReviewPrompt> {
  final _body = TextEditingController();
  int _rating = 5;
  bool _sending = false;
  bool _open = false;

  @override
  void dispose() {
    _body.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (_body.text.trim().isEmpty) return;
    setState(() => _sending = true);
    try {
      await ref.read(tradeRepositoryProvider).writeReview(offerId: widget.offer.id, rating: _rating, body: _body.text.trim());
      ref.invalidate(myReviewProvider(widget.offer.id));
      ref.invalidate(traderProvider(widget.offer.counterparty.id));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(L.of(context).reviewThanks)));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(errorMessage(context, e))));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final theme = Theme.of(context);
    final existing = ref.watch(myReviewProvider(widget.offer.id));

    return existing.when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
      data: (review) {
        if (review != null) return Padding(padding: const EdgeInsets.only(top: Gap.x3), child: Text(l.reviewDone, style: theme.textTheme.bodySmall));
        if (!_open) return Padding(padding: const EdgeInsets.only(top: Gap.x3), child: OutlinedButton.icon(onPressed: () => setState(() => _open = true), icon: const Icon(Symbols.star_rounded), label: Text(l.reviewSend)));
        return Padding(
          padding: const EdgeInsets.only(top: Gap.x4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(l.reviewTitle, style: theme.textTheme.titleMedium),
              Gap.h3,
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var star = 1; star <= 5; star++)
                    IconButton(onPressed: () => setState(() => _rating = star), icon: Icon(Symbols.star_rounded, size: 32, fill: star <= _rating ? 1 : 0, color: star <= _rating ? palette(context).money : palette(context).inkFaint)),
                ],
              ),
              Gap.h3,
              TextField(controller: _body, maxLines: 3, decoration: InputDecoration(hintText: l.reviewBody)),
              Gap.h3,
              Row(
                children: [
                  TextButton(onPressed: () => setState(() => _open = false), child: Text(l.reviewLater)),
                  Gap.w2,
                  Expanded(child: FilledButton(onPressed: _sending ? null : _send, child: Text(l.reviewSend))),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
