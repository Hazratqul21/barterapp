import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

class FeedShimmer extends StatelessWidget {
  const FeedShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    // A Column, not a ListView: this skeleton is dropped into the feed's
    // CustomScrollView through a SliverToBoxAdapter, which offers its child
    // unbounded height. A ListView there asks a scrollable to live inside an
    // unbounded scrollable and throws "viewport was given unbounded height".
    // The count is fixed at four, so nothing here needs to scroll on its own —
    // the outer scroll view already does.
    return const Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, 28),
      child: Column(
        children: [
          _ShimmerCard(),
          SizedBox(height: 16),
          _ShimmerCard(),
          SizedBox(height: 16),
          _ShimmerCard(),
          SizedBox(height: 16),
          _ShimmerCard(),
        ],
      ),
    );
  }
}

class _ShimmerCard extends StatelessWidget {
  const _ShimmerCard();

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.surfaceContainerHighest;

    return Card(
      clipBehavior: Clip.antiAlias,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            height: 186,
            width: double.infinity,
            color: color,
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  height: 20,
                  width: 200,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  height: 24,
                  width: 140,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                const SizedBox(height: 14),
                Divider(color: color, height: 1),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Container(
                      height: 16,
                      width: 60,
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      height: 12,
                      width: 40,
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const Spacer(),
                    Container(
                      height: 12,
                      width: 80,
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    ).animate(onPlay: (c) => c.repeat()).shimmer(
          duration: 1200.ms,
          color: Colors.white24,
        );
  }
}
