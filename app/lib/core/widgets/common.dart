import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:material_symbols_icons/material_symbols_icons.dart';

import '../../l10n/app_localizations.dart';
import '../../shared/models/models.dart';
import '../network/api_client.dart';
import '../theme/app_theme.dart';
import '../theme/tokens.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Helpers
// ─────────────────────────────────────────────────────────────────────────────

BarterPalette palette(BuildContext context) =>
    Theme.of(context).extension<BarterPalette>()!;

/// Turn any thrown object into a sentence worth showing someone.
///
/// The server already writes its refusals in plain Uzbek — "Faqat taklif kelgan
/// tomon bu amalni bajara oladi." — so those are passed through untouched.
/// Everything else falls back to a translated line, because half the screens
/// used to render `e.toString()` and hand the user a Dart exception.
String errorMessage(BuildContext context, Object error) {
  final l = L.of(context);
  if (error is ApiException) {
    return error.isNetworkFailure ? l.errorNetwork : error.message;
  }
  return l.errorGeneric;
}

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

/// The picture at the top of an empty or failed screen.
///
/// A tinted disc with a symbol in it. This replaced two `Lottie.network` calls
/// that fetched animations from a third-party CDN: on a slow connection they
/// left a blank square where the explanation should be, and with no connection
/// at all — exactly when the error state is on screen — they never arrived.
class StateArt extends StatelessWidget {
  const StateArt({super.key, required this.icon, this.tone});

  final IconData icon;

  /// Defaults to the neutral surface. Pass a palette colour to make the mood
  /// specific: give for something good, error for something broken.
  final Color? tone;

  @override
  Widget build(BuildContext context) {
    final p = palette(context);
    final scheme = Theme.of(context).colorScheme;
    final accent = tone ?? p.inkFaint;

    return Container(
      width: Sizes.avatarXl,
      height: Sizes.avatarXl,
      decoration: BoxDecoration(
        color: tone == null
            ? scheme.surfaceContainerHigh
            : accent.withValues(alpha: p.isDark ? 0.18 : 0.1),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, size: 40, color: accent),
    );
  }
}

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
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(
          horizontal: Gap.x8,
          vertical: Gap.x10,
        ),
        child:
            Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    StateArt(
                      icon: Symbols.cloud_off_rounded,
                      tone: theme.colorScheme.error,
                    ),
                    Gap.h5,
                    Text(
                      message,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: p.inkSoft,
                      ),
                    ),
                    Gap.h6,
                    OutlinedButton.icon(
                      onPressed: onRetry,
                      icon: const Icon(
                        Symbols.refresh_rounded,
                        size: Sizes.iconMd,
                      ),
                      label: Text(retryLabel),
                    ),
                  ],
                )
                .animate()
                .fadeIn(
                  duration: M3Motion.medium2,
                  curve: M3Motion.emphasizedDecelerate,
                )
                .slideY(
                  begin: 0.06,
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
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(
          horizontal: Gap.x8,
          vertical: Gap.x10,
        ),
        child:
            Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    StateArt(icon: icon ?? Symbols.inbox_rounded),
                    Gap.h5,
                    Text(
                      title,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.titleLarge,
                    ),
                    if (hint.isNotEmpty) ...[
                      Gap.h2,
                      Text(
                        hint,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: p.inkSoft,
                        ),
                      ),
                    ],
                    if (actionLabel != null && onAction != null) ...[
                      Gap.h6,
                      FilledButton(
                        onPressed: onAction,
                        style: FilledButton.styleFrom(
                          minimumSize: const Size(0, Sizes.buttonMd),
                          padding: const EdgeInsets.symmetric(
                            horizontal: Gap.x6,
                          ),
                        ),
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
                  begin: const Offset(0.96, 0.96),
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
// Categories
// ─────────────────────────────────────────────────────────────────────────────

/// The translated name of a category. One switch, so a new tag breaks the
/// build in exactly one place instead of appearing untranslated in four.
String categoryLabel(L l, ListingTag tag) => switch (tag) {
  ListingTag.agri => l.filterAgri,
  ListingTag.livestock => l.filterLivestock,
  ListingTag.machinery => l.filterMachinery,
  ListingTag.transport => l.filterTransport,
  ListingTag.electronics => l.filterElectronics,
  ListingTag.construction => l.filterConstruction,
};

/// A category as a picture first and a word second.
///
/// The feed used to filter through a row of grey text chips. Someone with a
/// spare laptop looking to get their flat painted scans for the thing that
/// looks like what they have; a colour and a symbol do that at a glance, and do
/// it identically in all three languages.
class CategoryTile extends StatelessWidget {
  const CategoryTile({
    super.key,
    required this.tag,
    required this.selected,
    required this.onTap,
  });

  final ListingTag tag;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final p = palette(context);
    final theme = Theme.of(context);
    final base = CategoryStyle.of(tag);
    final style = p.isDark ? base.dark : base;

    return Semantics(
      button: true,
      selected: selected,
      label: categoryLabel(l, tag),
      child: InkWell(
        onTap: onTap,
        borderRadius: Radii.rMd,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: Gap.x2),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedContainer(
                duration: M3Motion.short4,
                curve: M3Motion.standard,
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: selected ? style.color : style.tint,
                  shape: BoxShape.circle,
                  boxShadow: selected ? Shadows.raised : null,
                ),
                child: Icon(
                  style.icon,
                  size: 28,
                  color: selected ? Colors.white : style.color,
                ),
              ),
              Gap.h2,
              SizedBox(
                width: 74,
                child: Text(
                  categoryLabel(l, tag),
                  maxLines: 2,
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: selected ? style.color : p.inkSoft,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    height: 1.25,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The small tinted badge that marks which category a listing belongs to.
class CategoryBadge extends StatelessWidget {
  const CategoryBadge({super.key, required this.tag, this.compact = false});

  final ListingTag tag;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final p = palette(context);
    final base = CategoryStyle.of(tag);
    final style = p.isDark ? base.dark : base;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? Gap.x2 : Gap.x3,
        vertical: Gap.x1 + 2,
      ),
      decoration: BoxDecoration(
        color: style.tint,
        borderRadius: Radii.rFull,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(style.icon, size: Sizes.iconSm, color: style.color),
          if (!compact) ...[
            Gap.w1,
            Text(
              categoryLabel(l, tag),
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: style.color,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// The two sides of a trade
// ─────────────────────────────────────────────────────────────────────────────

/// «X ⇄ Y» — what is offered against what is wanted.
///
/// The single most repeated idea in the product, so it is drawn once. Green
/// leads, blue answers, and the arrow between them is the whole pitch: this is
/// not a price, it is a swap.
class TradeSides extends StatelessWidget {
  const TradeSides({
    super.key,
    required this.giveLabel,
    required this.takeLabel,
    this.giveCaption,
    this.takeCaption,
    this.dense = false,
  });

  /// What is being handed over.
  final String giveLabel;

  /// What is asked for in return.
  final String takeLabel;

  /// Optional eyebrows above each side ("BERAMAN" / "OLAMAN").
  final String? giveCaption;
  final String? takeCaption;

  final bool dense;

  @override
  Widget build(BuildContext context) {
    final p = palette(context);
    final theme = Theme.of(context);

    Widget side(String label, String? caption, Color color, Color tint) {
      return Expanded(
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: Gap.x3,
            vertical: dense ? Gap.x2 : Gap.x3,
          ),
          decoration: BoxDecoration(color: tint, borderRadius: Radii.rSm),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (caption != null) ...[
                Text(
                  caption.toUpperCase(),
                  style: theme.textTheme.labelSmall?.copyWith(color: color),
                ),
                Gap.h1,
              ],
              Text(
                label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleSmall?.copyWith(height: 1.3),
              ),
            ],
          ),
        ),
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        side(giveLabel, giveCaption, p.give, p.giveSoft),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: Gap.x2),
          child: Icon(
            Symbols.swap_horiz_rounded,
            size: Sizes.iconMd,
            color: p.inkFaint,
          ),
        ),
        side(takeLabel, takeCaption, p.take, p.takeSoft),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Skeletons
// ─────────────────────────────────────────────────────────────────────────────

/// A shimmering placeholder block.
///
/// Used while real content loads, so a screen shows its own shape immediately
/// instead of a spinner that says nothing about what is coming.
class SkeletonBox extends StatelessWidget {
  const SkeletonBox({
    super.key,
    this.width,
    this.height = 16,
    this.radius = Radii.rXs,
  });

  final double? width;
  final double height;
  final BorderRadius radius;

  @override
  Widget build(BuildContext context) {
    final p = palette(context);
    return Container(
          width: width,
          height: height,
          decoration: BoxDecoration(color: p.sunken, borderRadius: radius),
        )
        .animate(onPlay: (c) => c.repeat())
        .shimmer(
          duration: const Duration(milliseconds: 1200),
          color: p.hair.withValues(alpha: 0.6),
        );
  }
}
