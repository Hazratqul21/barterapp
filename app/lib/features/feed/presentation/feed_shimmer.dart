import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../core/theme/tokens.dart';
import '../../../core/widgets/common.dart';
import 'listing_card_tile.dart';

/// The feed while it loads: the same grid and card shape as the real thing,
/// so nothing jumps when the listings arrive.
class FeedShimmer extends StatelessWidget {
  const FeedShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    // Rows of plain widgets, not a GridView: this skeleton sits in the feed's
    // CustomScrollView through a SliverToBoxAdapter, which offers unbounded
    // height — a nested scrollable there throws. Two rows are enough to fill
    // the first screen.
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
          final columns = ListingGrid.columnsFor(width, scale);
          final cardWidth =
              (width - ListingGrid.spacing * (columns - 1)) / columns;
          final height = cardWidth + ListingCardTile.textBlockHeight(scale);
          Widget row() => Row(
            children: [
              for (var i = 0; i < columns; i++) ...[
                if (i > 0) const SizedBox(width: ListingGrid.spacing),
                SizedBox(
                  width: cardWidth,
                  height: height,
                  child: const _ShimmerCard(),
                ),
              ],
            ],
          );
          return Column(children: [row(), Gap.h4, row()]);
        },
      ),
    );
  }
}

class _ShimmerCard extends StatelessWidget {
  const _ShimmerCard();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final bone = colors.surfaceContainerHigh;

    Widget line(double widthFactor, double height) => FractionallySizedBox(
      widthFactor: widthFactor,
      child: Container(
        height: height,
        decoration: ShapeDecoration(
          color: bone,
          shape: const RoundedSuperellipseBorder(borderRadius: Radii.rXs),
        ),
      ),
    );

    final skeleton = Material(
      color: colors.surfaceContainerLowest,
      shape: RoundedSuperellipseBorder(
        borderRadius: Radii.rLg,
        side: BorderSide(color: colors.outlineVariant.withValues(alpha: 0.7)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: ColoredBox(color: bone)),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 12, 10, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                line(0.55, 16),
                Gap.h2,
                line(0.95, 12),
                Gap.h1,
                line(0.7, 12),
                Gap.h2,
                line(0.6, 16),
              ],
            ),
          ),
        ],
      ),
    );

    if (shouldReduceMotion(context)) return skeleton;

    return skeleton
        .animate(onPlay: (c) => c.repeat())
        .shimmer(duration: 1200.ms, color: Colors.white24);
  }
}
