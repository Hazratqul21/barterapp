import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:material_symbols_icons/material_symbols_icons.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/common.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/models/models.dart';
import '../data/trade_repository.dart';

class ChatPage extends ConsumerStatefulWidget {
  const ChatPage({super.key, required this.conversationId});
  final String conversationId;

  @override
  ConsumerState<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends ConsumerState<ChatPage> {
  final _controller = TextEditingController();
  StreamSubscription? _socketSub;
  bool _peerTyping = false;
  Timer? _typingTimer;
  DateTime _lastTypingSent = DateTime.fromMillisecondsSinceEpoch(0);

  @override
  void initState() {
    super.initState();
    ref.read(liveChannelProvider).connect();
    
    _socketSub = ref.read(liveChannelProvider).events.listen((event) {
      if (event.conversationId != widget.conversationId) return;
      
      if (event is MessageArrived) {
        ref.invalidate(conversationProvider(widget.conversationId));
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
    _socketSub?.cancel();
    _typingTimer?.cancel();
    _controller.dispose();
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

  void _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    
    _controller.clear();
    try {
      await ref.read(tradeRepositoryProvider).send(widget.conversationId, text);
      ref.invalidate(conversationProvider(widget.conversationId));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final p = palette(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final state = ref.watch(conversationProvider(widget.conversationId));

    return Scaffold(
      appBar: AppBar(
        title: state.when(
          data: (detail) => GestureDetector(
            onTap: () => context.push('/trader/${detail.summary.peer.id}'),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                TraderAvatar(
                  url: detail.summary.peer.avatarUrl,
                  name: detail.summary.peer.name,
                  size: 32,
                  isOnline: detail.summary.peer.isOnline,
                  showPresence: true,
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Text(
                          detail.summary.peer.displayName,
                          style: theme.textTheme.titleMedium,
                        ),
                        if (detail.summary.peer.isVerified) ...[
                          const SizedBox(width: 4),
                          Icon(Symbols.verified_rounded, size: 16, color: scheme.primary),
                        ],
                      ],
                    ),
                    if (detail.summary.peer.isOnline)
                      Text(
                        l.traderOnline,
                        style: theme.textTheme.labelSmall?.copyWith(color: scheme.primary),
                      ),
                  ],
                ),
              ],
            ),
          ),
          loading: () => const SizedBox.shrink(),
          error: (error, stackTrace) => const SizedBox.shrink(),
        ),
      ),
      body: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 700), child: state.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorState(
          message: e.toString(),
          retryLabel: l.retry,
          onRetry: () => ref.invalidate(conversationProvider(widget.conversationId)),
        ),
        data: (detail) {
          final offer = detail.offer;
          
          return Column(
            children: [
              _DealPanel(
                offer: offer,
                onAccept: () async {
                  await ref.read(tradeRepositoryProvider).act(offer.id, 'accept');
                  ref.invalidate(conversationProvider(widget.conversationId));
                  ref.invalidate(conversationsProvider);
                },
                onDecline: () async {
                  await ref.read(tradeRepositoryProvider).act(offer.id, 'decline');
                  ref.invalidate(conversationProvider(widget.conversationId));
                  ref.invalidate(conversationsProvider);
                },
                onCounter: () => context.push('/offer/${offer.wanted.id}'),
                onComplete: () async {
                  await ref.read(tradeRepositoryProvider).act(offer.id, 'complete');
                  ref.invalidate(conversationProvider(widget.conversationId));
                  ref.invalidate(conversationsProvider);
                },
              ),
              Expanded(
                child: ListView.builder(
                  reverse: true,
                  padding: const EdgeInsets.all(16),
                  itemCount: detail.messages.length,
                  itemBuilder: (context, index) {
                    final msg = detail.messages[index];
                    final time = DateFormat.Hm(l.localeName).format(msg.createdAt);
                    
                    return Align(
                      alignment: msg.isMine ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        constraints: BoxConstraints(
                          maxWidth: MediaQuery.of(context).size.width * 0.75,
                        ),
                        decoration: BoxDecoration(
                          color: msg.isMine ? scheme.primaryContainer : scheme.surfaceContainerHigh,
                          borderRadius: BorderRadius.only(
                            topLeft: msg.isMine ? const Radius.circular(20) : const Radius.circular(4),
                            topRight: msg.isMine ? const Radius.circular(20) : const Radius.circular(20),
                            bottomLeft: const Radius.circular(20),
                            bottomRight: msg.isMine ? const Radius.circular(4) : const Radius.circular(20),
                          ),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        child: Column(
                          crossAxisAlignment: msg.isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                          children: [
                            if (msg.photoUrl != null) ...[
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: RemoteImage(
                                  url: msg.photoUrl,
                                  semanticLabel: 'Attachment',
                                ),
                              ),
                              const SizedBox(height: 8),
                            ],
                            Text(
                              msg.body,
                              style: theme.textTheme.bodyLarge?.copyWith(
                                color: msg.isMine ? scheme.onPrimaryContainer : scheme.onSurface,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              time,
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: msg.isMine ? scheme.onPrimaryContainer.withValues(alpha: 0.7) : p.inkFaint,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              if (_peerTyping)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      l.chatTyping, 
                      style: theme.textTheme.labelSmall?.copyWith(color: p.inkFaint),
                    ),
                  ),
                ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: scheme.surface,
                  boxShadow: [
                    BoxShadow(
                      color: scheme.shadow.withValues(alpha: 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, -2),
                    ),
                  ],
                ),
                child: SafeArea(
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _controller,
                          onChanged: _onTextChanged,
                          decoration: InputDecoration(
                            hintText: l.chatPlaceholder,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(24),
                              borderSide: BorderSide.none,
                            ),
                            filled: true,
                            fillColor: scheme.surfaceContainerHighest,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          ),
                          maxLines: null,
                          textInputAction: TextInputAction.send,
                          onSubmitted: (_) => _sendMessage(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        onPressed: _sendMessage,
                        icon: Icon(Symbols.send_rounded, color: scheme.primary),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ))),
    );
  }
}

class _DealPanel extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final l = L.of(context);
    final p = palette(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final offeredTitles = offer.offered.map((o) => o.title).join(', ');
    final cashText = offer.cashDeltaMinor != 0
        ? ' + ${offer.cash.format(l.localeName)}'
        : '';
        
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '$offeredTitles$cashText ⇄ ${offer.wanted.title}',
              style: theme.textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            if (offer.expiresAt != null && offer.status.isLive) ...[
              const SizedBox(height: 4),
              Text(
                'Expires in ${offer.expiresAt!.difference(DateTime.now()).inHours}h',
                textAlign: TextAlign.center,
                style: theme.textTheme.labelMedium?.copyWith(color: scheme.error),
              ),
            ],
            const SizedBox(height: 16),
            if ((offer.status == OfferStatus.pending || offer.status == OfferStatus.talking) && offer.isMine)
              Center(child: Text(l.dealPending, style: theme.textTheme.labelLarge?.copyWith(color: p.inkSoft)))
            else if ((offer.status == OfferStatus.pending || offer.status == OfferStatus.talking) && !offer.isMine)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: onDecline,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: scheme.error,
                        side: BorderSide(color: scheme.error),
                      ),
                      child: Text(l.dealDecline),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: onCounter,
                      child: Text(l.dealCounter),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton(
                      onPressed: onAccept,
                      child: Text(l.dealAccept),
                    ),
                  ),
                ],
              )
            else if (offer.status == OfferStatus.accepted)
              FilledButton(
                onPressed: onComplete,
                style: FilledButton.styleFrom(backgroundColor: p.give),
                child: Text(l.dealComplete),
              )
            else
              Center(
                child: Text(
                  offer.status == OfferStatus.completed ? l.dealCompleted :
                  offer.status == OfferStatus.declined ? l.dealDeclined :
                  offer.status == OfferStatus.expired ? l.dealExpired : '',
                  style: theme.textTheme.labelLarge?.copyWith(color: p.inkSoft),
                ),
              ),
          ],
        ),
      ),
    )
    .animate()
    .fadeIn(
      duration: M3Motion.medium2,
      curve: M3Motion.emphasizedDecelerate,
    )
    .slideY(
      begin: -0.1,
      end: 0,
      duration: M3Motion.medium2,
      curve: M3Motion.emphasizedDecelerate,
    );
  }
}
