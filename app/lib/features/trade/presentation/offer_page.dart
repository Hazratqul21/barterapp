import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/material_symbols_icons.dart';

import '../../../core/theme/tokens.dart';
import '../../../core/widgets/common.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/models/models.dart';
import '../../feed/data/listing_repository.dart';
import '../data/trade_repository.dart';
import 'package:intl/intl.dart';

/// Propose a swap: pick what you put up, add cash if the two sides are not
/// level, say something.
///
/// There used to be two of these — this route and a bottom sheet opened from
/// the listing page — with different fields, different bugs and different
/// untranslated strings. One screen now, reached by a real URL, so an offer can
/// be resumed from a link and there is one place to fix.
class OfferPage extends ConsumerStatefulWidget {
  const OfferPage({super.key, required this.listingId});

  final String listingId;

  @override
  ConsumerState<OfferPage> createState() => _OfferPageState();
}

class _OfferPageState extends ConsumerState<OfferPage> {
  final _selected = <String>{};
  final _cash = TextEditingController();
  final _message = TextEditingController();
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _cash.addListener(_formatCash);
  }

  void _formatCash() {
    final text = _cash.text.replaceAll(RegExp(r'\D'), '');
    if (text.isEmpty) {
      if (_cash.text.isNotEmpty) _cash.text = '';
      return;
    }
    final value = int.tryParse(text);
    if (value == null) return;
    final formatted = NumberFormat.decimalPattern('en_US').format(value).replaceAll(',', ' ');
    if (_cash.text != formatted) {
      _cash.value = TextEditingValue(
        text: formatted,
        selection: TextSelection.collapsed(offset: formatted.length),
      );
    }
  }

  @override
  void dispose() {
    _cash.removeListener(_formatCash);
    _cash.dispose();
    _message.dispose();
    super.dispose();
  }

  int get _cashSom => int.tryParse(_cash.text.replaceAll(' ', '')) ?? 0;

  Future<void> _send() async {
    setState(() => _sending = true);
    final l = L.of(context);
    try {
      final offer = await ref
          .read(tradeRepositoryProvider)
          .sendOffer(
            listingId: widget.listingId,
            offeredListingIds: _selected.toList(),
            cashDeltaMinor: _cashSom * 100,
            message: _message.text,
          );
      ref.invalidate(conversationsProvider);

      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(l.offerSent)));

      // Straight into the thread the offer just opened — that is where the
      // trade is negotiated from here on.
      final thread = offer.conversationId;
      thread == null ? context.pop() : context.pushReplacement('/chat/$thread');
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
    final theme = Theme.of(context);
    final target = ref.watch(listingDetailProvider(widget.listingId));
    final mine = ref.watch(myListingsProvider);
    final locale = l.localeName;

    return Scaffold(
      appBar: AppBar(
        title: Text(l.offerTitle),
        leading: IconButton(
          icon: const Icon(Symbols.close_rounded),
          tooltip: l.back,
          // pop, never go: this opens from the feed, a match card and a listing
          // page, and each of them expects to get the reader back.
          onPressed: context.pop,
        ),
      ),
      body: target.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorState(
          message: errorMessage(context, e),
          retryLabel: l.retry,
          onRetry: () =>
              ref.invalidate(listingDetailProvider(widget.listingId)),
        ),
        data: (listing) => Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Column(
              children: [
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(
                      Gap.x5,
                      Gap.x5,
                      Gap.x5,
                      Gap.x6,
                    ),
                    children: [
                      _WantedCard(listing: listing, locale: locale),
                      Gap.h6,

                      Text(l.offerSelectItems, style: theme.textTheme.titleLarge),
                      Gap.h3,
                      mine.when(
                        loading: () => const SkeletonBox(height: 140),
                        error: (e, _) => Text(
                          errorMessage(context, e),
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.error,
                          ),
                        ),
                        data: (listings) => listings.isEmpty
                            ? EmptyState(
                                icon: Symbols.inventory_2_rounded,
                                title: l.offerNoItems,
                                hint: '',
                                actionLabel: l.offerCreateFirst,
                                onAction: () => context.push('/create'),
                              )
                            : _MyListings(
                                listings: listings,
                                selected: _selected,
                                locale: locale,
                                onToggle: (id) => setState(() {
                                  _selected.contains(id)
                                      ? _selected.remove(id)
                                      : _selected.add(id);
                                }),
                              ),
                      ),

                      Gap.h6,
                      TextField(
                        controller: _cash,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        onChanged: (_) => setState(() {}),
                        decoration: InputDecoration(
                          labelText: l.offerAddCash,
                          helperText: l.offerAddCashHint,
                          suffixText: 'so‘m',
                          prefixIcon: const Icon(Symbols.payments_rounded),
                        ),
                      ),

                      Gap.h4,
                      TextField(
                        controller: _message,
                        maxLines: 3,
                        decoration: InputDecoration(
                          labelText: l.offerMessage,
                          hintText: l.offerMessageHint,
                        ),
                      ),

                      // The live summary of what is being proposed, in the
                      // product's own two-sided shape.
                      if (_selected.isNotEmpty) ...[
                        Gap.h6,
                        TradeSides(
                          giveCaption: l.offerYouGive,
                          giveLabel: _summary(mine.value ?? const []),
                          takeCaption: l.offerYouWant,
                          takeLabel: listing.title,
                        ),
                      ],
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    Gap.x5,
                    Gap.x2,
                    Gap.x5,
                    Gap.x4,
                  ),
                  child: SafeArea(
                    top: false,
                    child: FilledButton(
                      onPressed: _selected.isEmpty || _sending
                          ? null
                          : () {
                              HapticFeedback.lightImpact();
                              _send();
                            },
                      child: _sending
                          ? const SizedBox(
                              width: Sizes.iconLg,
                              height: Sizes.iconLg,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.4,
                                color: Colors.white,
                              ),
                            )
                          : Text(l.offerSend),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _summary(List<ListingCard> listings) {
    final titles = listings
        .where((x) => _selected.contains(x.id))
        .map((x) => x.title)
        .join(' + ');
    if (_cashSom <= 0) return titles;
    final cash = Money(minor: _cashSom * 100, currency: 'UZS');
    return '$titles + ${cash.format(L.of(context).localeName)}';
  }
}

/// What this offer is for.
class _WantedCard extends StatelessWidget {
  const _WantedCard({required this.listing, required this.locale});

  final ListingDetail listing;
  final String locale;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final p = palette(context);
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(Gap.x3),
      decoration: BoxDecoration(
        color: p.takeSoft,
        borderRadius: Radii.rLg,
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: Radii.rSm,
            child: SizedBox(
              width: 64,
              height: 64,
              child: RemoteImage(
                url: listing.imageUrl,
                semanticLabel: listing.imageAlt,
              ),
            ),
          ),
          Gap.w3,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l.offerYouWant.toUpperCase(),
                  style: theme.textTheme.labelSmall?.copyWith(color: p.take),
                ),
                Gap.h1,
                Text(
                  listing.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleMedium,
                ),
                Gap.h1,
                Text(
                  '${listing.owner.displayName} · ${listing.value.format(locale)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: p.inkSoft,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The listings you can put on your side, as a horizontal row of cards.
class _MyListings extends StatelessWidget {
  const _MyListings({
    required this.listings,
    required this.selected,
    required this.locale,
    required this.onToggle,
  });

  final List<ListingCard> listings;
  final Set<String> selected;
  final String locale;
  final ValueChanged<String> onToggle;

  @override
  Widget build(BuildContext context) {
    final p = palette(context);
    final theme = Theme.of(context);

    return SizedBox(
      height: 172,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: listings.length,
        separatorBuilder: (_, _) => Gap.w3,
        itemBuilder: (context, index) {
          final item = listings[index];
          final isSelected = selected.contains(item.id);

          return GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              onToggle(item.id);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 132,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerLowest,
                borderRadius: Radii.rLg,
                border: Border.all(
                  color: isSelected ? p.give : p.hair,
                  width: isSelected ? 2 : 1,
                ),
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        RemoteImage(
                          url: item.imageUrl,
                          semanticLabel: item.imageAlt,
                        ),
                        if (isSelected)
                          Container(
                            color: p.give.withValues(alpha: 0.25),
                            child: Center(
                              child: Container(
                                padding: const EdgeInsets.all(Gap.x1),
                                decoration: BoxDecoration(
                                  color: p.give,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Symbols.check_rounded,
                                  color: Colors.white,
                                  size: Sizes.iconMd,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(Gap.x2),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.labelLarge,
                        ),
                        Text(
                          item.value.format(locale),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: p.inkSoft,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
