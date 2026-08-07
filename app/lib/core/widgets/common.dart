import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:lottie/lottie.dart';
import 'package:material_symbols_icons/material_symbols_icons.dart';

import '../theme/app_theme.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Helpers
// ─────────────────────────────────────────────────────────────────────────────

BarterPalette palette(BuildContext context) =>
    Theme.of(context).extension<BarterPalette>()!;

// ─────────────────────────────────────────────────────────────────────────────
// Remote Image
// ─────────────────────────────────────────────────────────────────────────────

/// One image widget for the whole app, so every photo gets the same cache,
/// placeholder and failure treatment.
class RemoteImage extends StatelessWidget {
  const RemoteImage({
    super.key,
    required this.url,
    required this.semanticLabel,
    this.fit = BoxFit.cover,
  });

  final String? url;
  final String semanticLabel;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    final p = palette(context);
    final scheme = Theme.of(context).colorScheme;
    final placeholder = Container(
      color: scheme.surfaceContainerHigh,
      child: Center(
        child: Icon(
          Symbols.image_rounded,
          color: p.inkFaint,
          size: 28,
        ),
      ),
    );
    if (url == null || url!.isEmpty) return placeholder;

    return CachedNetworkImage(
      imageUrl: url!,
      fit: fit,
      placeholder: (_, _) => placeholder,
      errorWidget: (_, _, _) => Container(
        color: scheme.surfaceContainerHigh,
        child: Center(
          child: Icon(
            Symbols.broken_image_rounded,
            color: p.inkFaint,
            size: 28,
          ),
        ),
      ),
      imageBuilder: (_, provider) => Semantics(
        label: semanticLabel,
        image: true,
        child: Image(image: provider, fit: fit),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Pill — semantic status chip
// ─────────────────────────────────────────────────────────────────────────────

/// A pill that carries meaning, not decoration: give / take / money / neutral.
class Pill extends StatelessWidget {
  const Pill({
    super.key,
    required this.label,
    required this.foreground,
    required this.background,
    this.icon,
  });

  final String label;
  final Color foreground;
  final Color background;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        left: icon == null ? 14 : 10,
        right: 14,
        top: 8,
        bottom: 8,
      ),
      decoration: BoxDecoration(
        color: background.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: background.withValues(alpha: 0.2),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: foreground),
            const SizedBox(width: 5),
          ],
          Flexible(
            child: Text(
              label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: foreground,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Error State
// ─────────────────────────────────────────────────────────────────────────────

/// Every failure the user can actually act on: a sentence and a way forward.
class ErrorState extends StatelessWidget {
  const ErrorState({
    super.key,
    required this.message,
    required this.retryLabel,
    required this.onRetry,
  });

  final String message;
  final String retryLabel;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final p = palette(context);
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 120,
              height: 120,
              child: Lottie.network(
                'https://assets10.lottiefiles.com/packages/lf20_a3keqsn0.json',
                fit: BoxFit.contain,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: p.inkSoft,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 24),
            FilledButton.tonal(
              onPressed: onRetry,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Symbols.refresh_rounded, size: 18),
                  const SizedBox(width: 8),
                  Text(retryLabel),
                ],
              ),
            ),
          ],
        )
            .animate()
            .fadeIn(
              duration: M3Motion.medium2,
              curve: M3Motion.emphasizedDecelerate,
            )
            .slideY(
              begin: 0.1,
              end: 0,
              duration: M3Motion.medium2,
              curve: M3Motion.emphasizedDecelerate,
            ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Empty State
// ─────────────────────────────────────────────────────────────────────────────

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.title,
    required this.hint,
    this.actionLabel,
    this.onAction,
    this.icon,
  });

  final String title;
  final String hint;
  final String? actionLabel;
  final VoidCallback? onAction;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final p = palette(context);
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 56),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null)
              Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(28),
                ),
                child: Icon(
                  icon,
                  size: 36,
                  color: p.inkFaint,
                ),
              )
            else
              SizedBox(
                width: 150,
                height: 150,
                child: Lottie.network(
                  'https://assets3.lottiefiles.com/packages/lf20_0s6tfbuc.json',
                  fit: BoxFit.contain,
                ),
              ),
            const SizedBox(height: 20),
            Text(
              title,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            if (hint.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                hint,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: p.inkSoft,
                  height: 1.5,
                ),
              ),
            ],
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 24),
              FilledButton.tonal(
                onPressed: onAction,
                child: Text(actionLabel!),
              ),
            ],
          ],
        )
            .animate()
            .fadeIn(
              duration: M3Motion.medium2,
              curve: M3Motion.emphasizedDecelerate,
            )
            .scale(
              begin: const Offset(0.95, 0.95),
              end: const Offset(1, 1),
              duration: M3Motion.medium2,
              curve: M3Motion.emphasizedDecelerate,
            ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Trader Avatar
// ─────────────────────────────────────────────────────────────────────────────

/// Avatar with the verification shield and presence dot the product relies on.
class TraderAvatar extends StatelessWidget {
  const TraderAvatar({
    super.key,
    required this.url,
    required this.name,
    this.size = 40,
    this.isOnline = false,
    this.showPresence = false,
  });

  final String? url;
  final String name;
  final double size;
  final bool isOnline;
  final bool showPresence;

  @override
  Widget build(BuildContext context) {
    final dot = size * 0.28;
    final scheme = Theme.of(context).colorScheme;
    final p = palette(context);

    // Generate initials for fallback
    final initials = name.isNotEmpty
        ? name
            .split(' ')
            .where((w) => w.isNotEmpty)
            .take(2)
            .map((w) => w[0].toUpperCase())
            .join()
        : '?';

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Avatar circle
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: scheme.surfaceContainerHigh,
              border: Border.all(
                color: scheme.outlineVariant.withValues(alpha: 0.3),
                width: 1,
              ),
            ),
            child: ClipOval(
              child: url != null && url!.isNotEmpty
                  ? RemoteImage(url: url, semanticLabel: name)
                  : Center(
                      child: Text(
                        initials,
                        style: TextStyle(
                          fontSize: size * 0.36,
                          fontWeight: FontWeight.w600,
                          color: p.give,
                        ),
                      ),
                    ),
            ),
          ),
          // Presence dot
          if (showPresence)
            Positioned(
              right: -1,
              bottom: -1,
              child: Container(
                width: dot,
                height: dot,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isOnline
                      ? BrandColors.brand500
                      : p.inkFaint,
                  border: Border.all(
                    color: scheme.surface,
                    width: 2.5,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Animated List Item — staggered entrance helper
// ─────────────────────────────────────────────────────────────────────────────

/// Wraps a child with a staggered slide+fade entrance animation.
/// Use in ListViews: `AnimatedListItem(index: index, child: yourWidget)`
class AnimatedListItem extends StatelessWidget {
  const AnimatedListItem({
    super.key,
    required this.index,
    required this.child,
  });

  final int index;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return child
        .animate()
        .fadeIn(
          delay: Duration(milliseconds: 40 * index),
          duration: M3Motion.medium2,
          curve: M3Motion.emphasizedDecelerate,
        )
        .slideY(
          begin: 0.06,
          end: 0,
          delay: Duration(milliseconds: 40 * index),
          duration: M3Motion.medium2,
          curve: M3Motion.emphasizedDecelerate,
        );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Listing Card Tile (used in feed, trader profile, etc.)
// ─────────────────────────────────────────────────────────────────────────────
// Note: This relies on the ListingCardTile from feed/presentation if it exists.
// The widget below is a re-export helper if needed.
