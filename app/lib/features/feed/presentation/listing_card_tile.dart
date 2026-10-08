import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:material_symbols_icons/material_symbols_icons.dart';

import '../../../core/art/category_marks.dart';
import '../../../core/theme/motion.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/common.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/models/models.dart';

/// Grid geometry shared by every list of listing cards (feed, favorites,
/// profile, trader page), so a card never gets a height it was not drawn for.
abstract final class ListingGrid {
  static const spacing = Gap.x3;

  /// Two columns on a phone — four listings per screen instead of one —
  /// three on a tablet, four on a desktop. With large text a card needs more
  /// room, so the count drops (to one column on a phone at 160%) rather than
  /// cutting prices and titles short.
  static int columnsFor(double width, [double textScale = 1]) {
    final byBreakpoint = width >= 1000
        ? 4
        : width >= 600
        ? 3
        : 2;
    final byText = (width / (150 * textScale)).floor();
    return byText.clamp(1, byBreakpoint);
  }

  /// Square photo plus the text block, which grows with the text scale.
  static SliverGridDelegate delegate(double width, TextScaler scaler) {
    final scale = scaler.scale(14) / 14;
    final columns = columnsFor(width, scale);
    final cardWidth = (width - spacing * (columns - 1)) / columns;
    return SliverGridDelegateWithFixedCrossAxisCount(
      crossAxisCount: columns,
      crossAxisSpacing: spacing,
      mainAxisSpacing: Gap.x4,
      mainAxisExtent: cardWidth + ListingCardTile.textBlockHeight(scale),
    );
  }
}

/// A listing at a glance: photo, price, what it is, and — the barter part —
/// what the owner wants for it.
///
/// v1 led with the price in the biggest type and hid the wanted exchange in a
/// small teal line, which read like a classifieds site. Here the swap chip is
/// its own coloured element, so "what would they take?" is answered in the
/// same glance as "what is it?".
class ListingCardTile extends StatefulWidget {
  const ListingCardTile({
    super.key,
    required this.listing,
    required this.onTap,
    this.onFavorite,
  });

  final ListingCard listing;
  final VoidCallback onTap;

  /// Shows the heart for saving without opening the listing. Null hides it
  /// (the viewer's own listings, the saved list itself).
  final VoidCallback? onFavorite;

  /// Everything under the photo at text scale [scale]: paddings are fixed,
  /// text lines grow.
  static double textBlockHeight(double scale) =>
      10 + 10 + 4 + 6 + 8 + 4 + scale * (22 + 2 * 19 + 18 + 16) + 12;

  @override
  State<ListingCardTile> createState() => _ListingCardTileState();
}

class _ListingCardTileState extends State<ListingCardTile> {
  /// Pointer over the card (web/desktop): it lifts and the photo eases in,
  /// so the grid answers the cursor the way it answers a finger.
  bool _hovered = false;

  /// Keyboard focus gets a clear ring — on the web, Tab must show where it is.
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final listing = widget.listing;
    final onFavorite = widget.onFavorite;
    final theme = Theme.of(context);
    final l = L.of(context);
    final colors = theme.colorScheme;
    final p = palette(context);
    final locale = Localizations.localeOf(context).languageCode;
    final category = p.isDark
        ? CategoryStyle.of(listing.tag).dark
        : CategoryStyle.of(listing.tag);

    final meta = [
      if (listing.distanceKm != null)
        '${listing.distanceKm!.toStringAsFixed(listing.distanceKm! < 10 ? 1 : 0)} km',
      DateFormat.MMMd(locale).format(listing.postedAt.toLocal()),
    ].join(' · ');

    final motion = Motion.fast;
    final shape = RoundedSuperellipseBorder(
      borderRadius: Radii.rLg,
      side: _focused
          ? BorderSide(color: p.give, width: 2)
          : BorderSide(color: colors.outlineVariant.withValues(alpha: 0.7)),
    );
    return AnimatedContainer(
      duration: motion.durationOf(context),
      curve: motion.curve,
      transform: _hovered ? Matrix4.translationValues(0, -3, 0) : null,
      // Shadow only: the border is drawn once, by the Material below.
      decoration: ShapeDecoration(
        shape: RoundedSuperellipseBorder(borderRadius: Radii.rLg),
        shadows: _hovered ? Shadows.raised : const [],
      ),
      child: Material(
        color: colors.surfaceContainerLowest,
        shape: shape,
        clipBehavior: Clip.antiAlias,
        // A screen reader hears one sentence per card — what it is, what it
        // costs, what the owner wants — instead of a dozen fragments. The
        // heart stays a separate button.
        child: Semantics(
          button: true,
          label: [
            listing.title,
            listing.value.format(locale),
            '${l.listingWants}: ${listing.wantsSummary.trim().isEmpty ? l.createWantAny : listing.wantsSummary}',
            if (listing.owner.isVerified) l.traderVerified,
            meta,
          ].join('. '),
          child: InkWell(
            onTap: widget.onTap,
            onHover: (v) => setState(() => _hovered = v),
            onFocusChange: (v) => setState(() => _focused = v),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Square in every card of a row, whatever the title length.
                AspectRatio(
                  aspectRatio: 1,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      ExcludeSemantics(
                        child: Hero(
                          tag: 'listing-image-${listing.id}',
                          child: AnimatedScale(
                            scale: _hovered ? 1.04 : 1,
                            duration: Motion.standard.durationOf(context),
                            curve: Motion.standard.curve,
                            child: RemoteImage(
                              url: listing.imageUrl,
                              semanticLabel: listing.imageAlt,
                            ),
                          ),
                        ),
                      ),
                      // The category, as a mark rather than a word: readable in
                      // every language and at thumbnail size.
                      Positioned(
                        left: Gap.x2,
                        top: Gap.x2,
                        child: ExcludeSemantics(
                          child: Container(
                            width: 28,
                            height: 28,
                            decoration: ShapeDecoration(
                              color: category.tint,
                              shape: const RoundedSuperellipseBorder(
                                borderRadius: Radii.rXs,
                              ),
                            ),
                            alignment: Alignment.center,
                            child: CategoryMarkIcon(
                              mark: category.mark,
                              color: category.color,
                              size: 18,
                            ),
                          ),
                        ),
                      ),
                      if (listing.owner.isVerified)
                        Positioned(
                          left: Gap.x2 + 28 + Gap.x1,
                          top: Gap.x2,
                          child: ExcludeSemantics(
                            child: Container(
                              width: 28,
                              height: 28,
                              decoration: ShapeDecoration(
                                color: colors.surfaceContainerLowest,
                                shape: const RoundedSuperellipseBorder(
                                  borderRadius: Radii.rXs,
                                ),
                              ),
                              alignment: Alignment.center,
                              child: Icon(
                                Symbols.verified_rounded,
                                size: 18,
                                fill: 1,
                                color: p.give,
                              ),
                            ),
                          ),
                        ),
                      if (onFavorite != null)
                        Positioned(
                          right: Gap.x1,
                          top: Gap.x1,
                          child: _Heart(
                            saved: listing.isFavorite,
                            onTap: onFavorite,
                          ),
                        ),
                    ],
                  ),
                ),
                Expanded(
                  child: ExcludeSemantics(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(10, 10, 10, 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          PriceText(listing.value, size: 16),
                          const SizedBox(height: 4),
                          Text(
                            listing.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                              height: 1.35,
                            ),
                          ),
                          const SizedBox(height: 6),
                          SwapChip(wants: listing.wantsSummary),
                          // Date and distance sit on the card's bottom edge in
                          // every card, short title or long.
                          const Spacer(),
                          Text(
                            meta,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: p.inkSoft,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
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
}

/// The price with the number carrying the weight and the unit stepping back.
/// Shrinks rather than truncates: a cut-off price is wrong information.
class PriceText extends StatelessWidget {
  const PriceText(this.money, {super.key, this.size = 17});

  final Money money;
  final double size;

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context).languageCode;
    final formatted = money.format(locale);
    final split = formatted.lastIndexOf(' ');
    final number = split > 0 ? formatted.substring(0, split) : formatted;
    final unit = split > 0 ? formatted.substring(split) : '';
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerLeft,
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: number,
              style: AppText.price(context, size: size),
            ),
            TextSpan(
              text: unit,
              style: AppText.currency(context, size: size * 0.75),
            ),
          ],
        ),
        maxLines: 1,
      ),
    );
  }
}

/// "⇄ what they want" — the barter half of a listing, in the take colour.
///
/// The same chip belongs on the detail page, in chat and on matches, so the
/// exchange always looks like the same thing.
class SwapChip extends StatelessWidget {
  const SwapChip({super.key, required this.wants});

  final String wants;

  @override
  Widget build(BuildContext context) {
    final p = palette(context);
    final l = L.of(context);
    final text = wants.trim().isEmpty ? l.createWantAny : wants;
    return Semantics(
      label: '⇄ $text',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
        decoration: ShapeDecoration(
          color: p.takeSoft,
          shape: const RoundedSuperellipseBorder(borderRadius: Radii.rXs),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Symbols.swap_horiz_rounded, size: 14, color: p.take),
            const SizedBox(width: 3),
            Flexible(
              child: Text(
                text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(
                  context,
                ).textTheme.labelMedium?.copyWith(color: p.take, height: 1.35),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Save without leaving the feed. A 48px target around a small glyph, and a
/// short spring pop when it fills in.
class _Heart extends StatelessWidget {
  const _Heart({required this.saved, required this.onTap});

  final bool saved;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final colors = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      toggled: saved,
      label: saved ? l.listingSaved : l.listingSave,
      excludeSemantics: true,
      child: InkResponse(
        onTap: onTap,
        radius: 24,
        child: SizedBox.square(
          dimension: 48,
          child: Center(
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: colors.surfaceContainerLowest.withValues(alpha: 0.92),
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: AnimatedScale(
                scale: saved ? 1 : 0.9,
                duration: Motion.bouncy.durationOf(context),
                curve: Motion.bouncy.curve,
                child: Icon(
                  Symbols.favorite_rounded,
                  size: 18,
                  fill: saved ? 1 : 0,
                  color: saved ? colors.error : colors.onSurfaceVariant,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
