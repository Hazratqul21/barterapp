import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:material_symbols_icons/material_symbols_icons.dart';

import '../../../core/theme/tokens.dart';
import '../../../core/widgets/common.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/models/models.dart';
import '../data/trade_repository.dart';

/// One trade, negotiated.
///
/// The deal panel is pinned above the messages because the offer is why the
/// thread exists — chat, reviews and settlement all hang off its status, not
/// the other way round.
class ChatPage extends ConsumerStatefulWidget {
  const ChatPage({
    super.key,
    required this.conversationId,
    this.embedded = false,
  });

  final String conversationId;

  /// True when the thread is the right-hand pane of the desktop inbox rather
  /// than a screen of its own. It then drops its own app bar and back button —
  /// the list beside it is already the way back.
  final bool embedded;

  @override
  ConsumerState<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends ConsumerState<ChatPage> {
  final _controller = TextEditingController();
  final _scroll = ScrollController();
  StreamSubscription<LiveEvent>? _live;
  Timer? _typingTimer;
  DateTime _lastTypingSent = DateTime.fromMillisecondsSinceEpoch(0);
  bool _peerTyping = false;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
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
      _controller.text = text; // do not lose what they wrote
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
      await ref
          .read(tradeRepositoryProvider)
          .act(offerId, action, cashDeltaMinor: cashDeltaMinor);
      // `counter` swaps the two sides, so `is_mine` flips and the buttons must
      // be rebuilt from the response rather than from what was on screen.
      ref.invalidate(conversationProvider(widget.conversationId));
      ref.invalidate(conversationsProvider);
      ref.invalidate(matchesProvider);
    } catch (e) {
      if (mounted) _complain(errorMessage(context, e));
    }
  }

  /// Ask for the new cash figure, then counter.
  ///
  /// This used to push `/offer/{wanted.id}` — a brand new offer against the
  /// listing the sender wanted. For the recipient that listing is their own, so
  /// the server refused it every time: "you cannot offer on your own listing".
  /// A counter is a state change on the offer that already exists.
  Future<void> _counter(Offer offer) async {
    final l = L.of(context);
    final controller = TextEditingController(
      text: offer.cashDeltaMinor == 0
          ? ''
          : (offer.cashDeltaMinor.abs() ~/ 100).toString(),
    );

    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (context) => Padding(
        padding: EdgeInsets.fromLTRB(
          Gap.x5,
          Gap.x4,
          Gap.x5,
          Gap.x5 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l.dealCounterTitle,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            Gap.h2,
            Text(
              l.dealCounterHint,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: palette(context).inkSoft,
              ),
            ),
            Gap.h5,
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
              onRetry: () =>
                  ref.invalidate(conversationProvider(widget.conversationId)),
            ),
            data: (detail) {
              final offer = detail.offer;
              return Column(
                children: [
                  if (widget.embedded)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: Gap.x4,
                        vertical: Gap.x3,
                      ),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surfaceContainerLowest,
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
                            // The server returns oldest first. `reverse` walks
                            // the list from the bottom of the screen upward, so
                            // it has to be read back to front — otherwise the
                            // newest message sits at the top and the whole
                            // conversation reads backwards.
                            reverse: true,
                            padding: const EdgeInsets.all(Gap.x4),
                            itemCount: detail.messages.length,
                            itemBuilder: (context, index) {
                              final message = detail
                                  .messages[detail.messages.length - 1 - index];
                              return _Bubble(message: message);
                            },
                          ),
                  ),
                  if (_peerTyping)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        Gap.x5,
                        0,
                        Gap.x5,
                        Gap.x2,
                      ),
                      child: Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: Text(
                          l.chatTyping,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: p.inkFaint,
                          ),
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

/// Who you are talking to, tappable through to their profile.
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
                        Icon(
                          Symbols.verified_rounded,
                          size: Sizes.iconSm,
                          color: p.give,
                          fill: 1,
                        ),
                      ],
                    ],
                  ),
                  if (peer.isOnline)
                    Text(
                      l.traderOnline,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: p.give,
                        letterSpacing: 0,
                      ),
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

/// What is on the table, and what this person can do about it.
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
    final cash = offer.cashDeltaMinor != 0
        ? ' + ${offer.cash.format(locale)}'
        : '';

    // `is_mine` says who sent it, which decides who may answer. It flips on
    // every counter, so it is read fresh from the response each time.
    final awaitingMe = !offer.isMine;
    final open =
        offer.status == OfferStatus.pending ||
        offer.status == OfferStatus.talking;

    return Container(
      margin: const EdgeInsets.fromLTRB(Gap.x4, Gap.x3, Gap.x4, 0),
      padding: const EdgeInsets.all(Gap.x4),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLowest,
        borderRadius: Radii.rLg,
        border: Border.all(color: p.hair),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: _StatusLine(status: offer.status)),
              if (open && offer.expiresAt != null)
                _Expiry(expiresAt: offer.expiresAt!),
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
                Expanded(
                  child: OutlinedButton(
                    onPressed: onCounter,
                    child: Text(l.dealCounter),
                  ),
                ),
                Gap.w2,
                Expanded(
                  child: FilledButton(
                    onPressed: onAccept,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(0, Sizes.buttonMd),
                      padding: EdgeInsets.zero,
                    ),
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

/// The offer's state, as a coloured word.
class _StatusLine extends StatelessWidget {
  const _StatusLine({required this.status});

  final OfferStatus status;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final p = palette(context);
    final scheme = Theme.of(context).colorScheme;

    final (label, color) = switch (status) {
      OfferStatus.pending => (l.dealPending, p.money),
      OfferStatus.talking => (l.dealTalking, p.take),
      OfferStatus.accepted => (l.dealAccepted, p.give),
      OfferStatus.completed => (l.dealCompleted, p.give),
      OfferStatus.declined => (l.dealDeclined, scheme.error),
      OfferStatus.expired => (l.dealExpired, p.inkFaint),
      _ => (l.dealExpired, p.inkFaint),
    };

    return Text(
      label.toUpperCase(),
      style: Theme.of(context).textTheme.labelSmall?.copyWith(color: color),
    );
  }
}

/// How long is left to answer. An offer lives 48 hours.
class _Expiry extends StatelessWidget {
  const _Expiry({required this.expiresAt});

  final DateTime expiresAt;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final p = palette(context);
    final hours = expiresAt.difference(DateTime.now()).inHours;

    return Text(
      hours < 1 ? l.chatExpiresSoon : l.chatExpiresIn(hours),
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
        color: hours < 6 ? Theme.of(context).colorScheme.error : p.inkFaint,
        letterSpacing: 0,
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.message});

  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final p = palette(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final mine = message.isMine;

    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: Gap.x2),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.78,
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: Gap.x3,
          vertical: Gap.x2 + 2,
        ),
        decoration: BoxDecoration(
          color: mine ? p.giveSoft : scheme.surfaceContainerLowest,
          border: mine ? null : Border.all(color: p.hair),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(Radii.md),
            topRight: const Radius.circular(Radii.md),
            bottomLeft: Radius.circular(mine ? Radii.md : Radii.xs),
            bottomRight: Radius.circular(mine ? Radii.xs : Radii.md),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
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
              style: theme.textTheme.bodyLarge,
              textAlign: TextAlign.start,
            ),
            Gap.h1,
            Text(
              DateFormat.Hm(l.localeName).format(message.createdAt.toLocal()),
              style: theme.textTheme.labelSmall?.copyWith(
                color: p.inkFaint,
                letterSpacing: 0,
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
    final p = palette(context);

    return Container(
      padding: const EdgeInsets.fromLTRB(Gap.x4, Gap.x2, Gap.x4, Gap.x2),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLowest,
        border: Border(top: BorderSide(color: p.hair)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                onChanged: onChanged,
                minLines: 1,
                maxLines: 5,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => onSend(),
                decoration: InputDecoration(
                  hintText: l.chatPlaceholder,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: Gap.x4,
                    vertical: Gap.x3,
                  ),
                ),
              ),
            ),
            Gap.w2,
            IconButton.filled(
              onPressed: sending ? null : onSend,
              icon: sending
                  ? const SizedBox(
                      width: Sizes.iconMd,
                      height: Sizes.iconMd,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Symbols.send_rounded),
              style: IconButton.styleFrom(
                backgroundColor: p.give,
                foregroundColor: Colors.white,
                minimumSize: const Size(Sizes.buttonMd, Sizes.buttonMd),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// After a completed trade: rate the other side, once.
///
/// It lives at the bottom of the deal panel because that is where the trade
/// ended. Asking on a separate screen means asking later, and later is never —
/// which is how the seed data ended up being the only reviews in the product.
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
    final l = L.of(context);
    try {
      await ref
          .read(tradeRepositoryProvider)
          .writeReview(
            offerId: widget.offer.id,
            rating: _rating,
            body: _body.text.trim(),
          );
      ref.invalidate(myReviewProvider(widget.offer.id));
      ref.invalidate(traderProvider(widget.offer.counterparty.id));
      ref.invalidate(traderReviewsProvider(widget.offer.counterparty.id));
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(l.reviewThanks)));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(errorMessage(context, e))));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final p = palette(context);
    final theme = Theme.of(context);
    final existing = ref.watch(myReviewProvider(widget.offer.id));

    return existing.when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
      data: (review) {
        if (review != null) {
          return Padding(
            padding: const EdgeInsets.only(top: Gap.x3),
            child: Row(
              children: [
                Icon(
                  Symbols.rate_review_rounded,
                  size: Sizes.iconMd,
                  color: p.give,
                ),
                Gap.w2,
                Text(
                  l.reviewDone,
                  style: theme.textTheme.bodyMedium?.copyWith(color: p.inkSoft),
                ),
                Gap.w2,
                _Stars(rating: review.rating, size: Sizes.iconSm),
              ],
            ),
          );
        }

        if (!_open) {
          return Padding(
            padding: const EdgeInsets.only(top: Gap.x3),
            child: OutlinedButton.icon(
              onPressed: () => setState(() => _open = true),
              icon: const Icon(Symbols.star_rounded, size: Sizes.iconMd),
              label: Text(l.reviewSend),
            ),
          );
        }

        return Padding(
          padding: const EdgeInsets.only(top: Gap.x4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(l.reviewTitle, style: theme.textTheme.titleMedium),
              Gap.h1,
              Text(
                l.reviewLede(widget.offer.counterparty.name),
                style: theme.textTheme.bodySmall?.copyWith(color: p.inkSoft),
              ),
              Gap.h3,
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var star = 1; star <= 5; star++)
                    IconButton(
                      onPressed: () => setState(() => _rating = star),
                      icon: Icon(
                        Symbols.star_rounded,
                        size: 32,
                        fill: star <= _rating ? 1 : 0,
                        color: star <= _rating ? p.money : p.inkFaint,
                      ),
                    ),
                ],
              ),
              Gap.h3,
              TextField(
                controller: _body,
                maxLines: 3,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(hintText: l.reviewBody),
              ),
              Gap.h3,
              Row(
                children: [
                  TextButton(
                    onPressed: () => setState(() => _open = false),
                    child: Text(l.reviewLater),
                  ),
                  Gap.w2,
                  Expanded(
                    child: FilledButton(
                      onPressed: _sending || _body.text.trim().isEmpty
                          ? null
                          : _send,
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(0, Sizes.buttonMd),
                      ),
                      child: _sending
                          ? const SizedBox(
                              width: Sizes.iconMd,
                              height: Sizes.iconMd,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.2,
                                color: Colors.white,
                              ),
                            )
                          : Text(l.reviewSend),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Five stars, filled to the rating.
class _Stars extends StatelessWidget {
  const _Stars({required this.rating, this.size = Sizes.iconMd});

  final int rating;
  final double size;

  @override
  Widget build(BuildContext context) {
    final p = palette(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var star = 1; star <= 5; star++)
          Icon(
            Symbols.star_rounded,
            size: size,
            fill: star <= rating ? 1 : 0,
            color: star <= rating ? p.money : p.inkFaint,
          ),
      ],
    );
  }
}
