import 'package:flutter/material.dart';
import 'package:material_symbols_icons/material_symbols_icons.dart';

import '../../../core/theme/tokens.dart';
import '../../../core/widgets/common.dart';
import '../../../shared/models/models.dart';

class ListingCardTile extends StatelessWidget {
  const ListingCardTile({
    super.key,
    required this.listing,
    required this.onTap,
  });

  final ListingCard listing;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = palette(context);
    final theme = Theme.of(context);

    return Pressable(
      onTap: onTap,
      child: Card(
        clipBehavior: Clip.antiAlias,
        elevation: 0,
        // Premium: M3 surfaceContainerLow rangidan foydalanamiz
        color: theme.colorScheme.surfaceContainerLow,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: Radii.rLg,
          side: BorderSide(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
          ),
        ),
        // 80 / 10 / 10 — the photo does the selling. The card's whole job is
        // to catch the eye and answer "I have ↔ I want" in a second, so the
        // text below is only the name and that one barter line. Everything else
        // — price detail, distance, date, specs — waits on the detail page.
        child: InkWell(
          onTap: onTap,
          borderRadius: Radii.rLg,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Photo(listing: listing),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                Gap.x4,
                Gap.x3,
                Gap.x4,
                Gap.x3,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 10% — what it is.
                  Text(
                    listing.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      height: 1.15,
                    ),
                  ),
                  Gap.h1,
                  // 10% — the barter itself: what the owner wants back.
                  Row(
                    children: [
                      Icon(
                        Symbols.swap_horiz_rounded,
                        size: Sizes.iconMd,
                        color: p.take,
                      ),
                      Gap.w2,
                      Expanded(
                        child: Text(
                          listing.wantsSummary,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: p.take,
                            fontWeight: FontWeight.w700,
                          ),
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

class _Photo extends StatelessWidget {
  const _Photo({required this.listing});
  final ListingCard listing;

  @override
  Widget build(BuildContext context) {
    final p = palette(context);
    final theme = Theme.of(context);
    final locale = Localizations.localeOf(context).languageCode;

    return SizedBox(
      // Tall on purpose: the photo is ~80% of the card, the part that sells.
      height: 236,
      width: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Hero(
            tag: 'listing-image-${listing.id}',
            child: RemoteImage(
              url: listing.imageUrl,
              semanticLabel: listing.imageAlt,
            ),
          ),
          Positioned(
            top: Gap.x3,
            left: Gap.x3,
            child: CategoryBadge(tag: listing.tag, compact: true),
          ),
          // The value on the photo. It used to be a real BackdropFilter, but a
          // live blur on every card is one of the most expensive things to put
          // in a scrolling list — it was a real part of why the feed did not
          // feel smooth. This is a solid jewel-dark pill instead: legible over
          // any photo, premium to look at, and free to scroll. The thin lit rim
          // fakes the glass edge without a single pixel of blur.
          Positioned(
            top: Gap.x3,
            right: Gap.x3,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xF01A2C22), Color(0xF00E1A14)],
                ),
                borderRadius: Radii.rFull,
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.18),
                  width: 0.75,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.22),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (listing.isPremium) ...[
                    Icon(
                      Symbols.star_rounded,
                      size: 12,
                      color: p.moneyVivid,
                      fill: 1,
                    ),
                    Gap.w1,
                  ],
                  Text(
                    listing.value.format(locale),
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.fromLTRB(
                Gap.x4,
                Gap.x6,
                Gap.x4,
                Gap.x2,
              ),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [Color(0x99000000), Colors.transparent],
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      listing.owner.displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (listing.owner.rating != null) ...[
                    Gap.w1,
                    const Icon(
                      Symbols.star_rounded,
                      size: 12,
                      color: Colors.white,
                      fill: 1,
                    ),
                    Gap.w1,
                    Text(
                      listing.owner.rating!.toStringAsFixed(1),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
