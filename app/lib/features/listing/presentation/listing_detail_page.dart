import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/common.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/models/models.dart';
import '../../feed/data/listing_repository.dart';
import '../../profile/presentation/favorites_page.dart';
import '../../trade/data/trade_repository.dart';
import '../../auth/data/auth_repository.dart';
import '../../../core/analytics/analytics_service.dart';
import '../../../core/theme/haptics.dart';

class ListingDetailPage extends ConsumerStatefulWidget {
  const ListingDetailPage({super.key, required this.listingId});

  final String listingId;

  @override
  ConsumerState<ListingDetailPage> createState() => _ListingDetailPageState();
}

class _ListingDetailPageState extends ConsumerState<ListingDetailPage> {
  int _shot = 0;
  bool? _saved;
  bool _saving = false;
  late final DateTime _enteredAt;
  late final AnalyticsService _analytics;

  @override
  void initState() {
    super.initState();
    _enteredAt = DateTime.now();
    _analytics = ref.read(analyticsServiceProvider);
  }

  @override
  void dispose() {
    final dwellMs = DateTime.now().difference(_enteredAt).inMilliseconds;
    _analytics.logEvent(
      'listing_dwell',
      targetType: 'listing',
      targetId: widget.listingId,
      payload: {'dwell_ms': dwellMs},
    );
    super.dispose();
  }

  Future<void> _toggleSave(ListingDetail listing) async {
    if (_saving) return;
    if (!ref.read(authStateProvider)) {
      context.push('/signin');
      return;
    }
    final previous = _saved ?? listing.isFavorite;
    setState(() {
      _saving = true;
      _saved = !previous;
    });
    try {
      await ref
          .read(tradeRepositoryProvider)
          .toggleFavorite(listing.id, !previous);
      if (!mounted) return;
      ref.invalidate(favoritesProvider);
      ref.invalidate(feedProvider);
      ref.invalidate(listingDetailProvider(listing.id));
    } catch (error) {
      if (!mounted) return;
      setState(() => _saved = previous);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(errorMessage(context, error))));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _moderate(ListingDetail listing, {required bool block}) async {
    if (!ref.read(authStateProvider)) {
      context.push('/signin');
      return;
    }
    final l = L.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(block ? l.actionBlockUser : l.actionReportUser),
        content: Text(
          block ? listing.owner.name : l.actionReportReasonInappropriate,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(block ? l.actionBlockUser : l.actionReportUser),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      final repository = ref.read(tradeRepositoryProvider);
      if (block) {
        await repository.blockUser(listing.owner.id);
      } else {
        await repository.reportUser(
          listing.owner.id,
          l.actionReportReasonInappropriate,
        );
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(block ? l.userBlocked : l.reportSent)),
      );
      if (block) {
        ref.invalidate(feedProvider);
        ref.invalidate(favoritesProvider);
        context.go('/home');
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(errorMessage(context, error))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final async = ref.watch(listingDetailProvider(widget.listingId));

    return Scaffold(
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: ErrorState(
            message: error is ApiException && error.isNetworkFailure
                ? l.errorNetwork
                : l.errorGeneric,
            retryLabel: l.retry,
            onRetry: () =>
                ref.invalidate(listingDetailProvider(widget.listingId)),
          ),
        ),
        data: (listing) => Container(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: Sizes.contentMax),
            child: _Content(
              listing: listing,
              isMine: ref.watch(meProvider).value?.id == listing.owner.id,
              shot: _shot,
              saved: _saved ?? listing.isFavorite,
              onShot: (i) => setState(() => _shot = i),
              onToggleSave: () => _toggleSave(listing),
              onReport: () => _moderate(listing, block: false),
              onBlock: () => _moderate(listing, block: true),
              onEdit: () => context.push('/create', extra: listing),
              onDelete: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (ctx) {
                    final tl = L.of(ctx);
                    return AlertDialog(
                      title: Text(tl.actionDeleteListing),
                      content: Text(tl.actionDeleteListingConfirm),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(ctx).pop(false),
                          child: Text(tl.actionCancel),
                        ),
                        TextButton(
                          onPressed: () => Navigator.of(ctx).pop(true),
                          child: Text(tl.actionDelete),
                        ),
                      ],
                    );
                  },
                );
                if (confirm == true) {
                  try {
                    await ref
                        .read(tradeRepositoryProvider)
                        .deleteListing(listing.id);
                    if (context.mounted) {
                      context.go('/home');
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(
                        context,
                      ).showSnackBar(SnackBar(content: Text(l.errorGeneric)));
                    }
                  }
                }
              },
            ),
          ),
        ),
      ),
      bottomNavigationBar: async.maybeWhen(
        data: (listing) {
          final isMine = ref.watch(meProvider).value?.id == listing.owner.id;
          return SafeArea(
            minimum: const EdgeInsets.fromLTRB(Gap.x5, Gap.x2, Gap.x5, Gap.x3),
            child: Center(
              heightFactor: 1,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: Sizes.contentMax),
                child: Row(
                  children: [
                    if (isMine)
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: () {
                            Haptics.light();
                            context.push('/create', extra: listing);
                          },
                          icon: const Icon(
                            Icons.edit_rounded,
                            size: Sizes.iconMd,
                          ),
                          label: Text(l.actionEdit),
                          style: FilledButton.styleFrom(
                            backgroundColor: Theme.of(
                              context,
                            ).colorScheme.secondary,
                            foregroundColor: Theme.of(
                              context,
                            ).colorScheme.onSecondary,
                          ),
                        ),
                      )
                    else
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: () {
                            Haptics.light();
                            context.push('/offer/${listing.id}');
                          },
                          icon: const Icon(
                            Icons.swap_horiz_rounded,
                            size: Sizes.iconMd,
                          ),
                          label: Text(l.listingOffer),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          );
        },
        orElse: () => const SizedBox.shrink(),
      ),
    );
  }
}

class _Content extends StatelessWidget {
  const _Content({
    required this.listing,
    required this.isMine,
    required this.shot,
    required this.saved,
    required this.onShot,
    required this.onToggleSave,
    required this.onReport,
    required this.onBlock,
    required this.onEdit,
    required this.onDelete,
  });

  final ListingDetail listing;
  final bool isMine;
  final int shot;
  final bool saved;
  final ValueChanged<int> onShot;
  final VoidCallback onToggleSave;
  final VoidCallback onReport;
  final VoidCallback onBlock;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final p = palette(context);
    final theme = Theme.of(context);
    final locale = Localizations.localeOf(context).languageCode;
    final gallery = listing.gallery.isEmpty
        ? [if (listing.imageUrl != null) listing.imageUrl!]
        : listing.gallery;

    // 50 / 50 — the photo owns the top half of the screen, the details the
    // bottom. The card sold the barter in a glance; the detail page is where
    // the picture is finally big enough to judge and the full description,
    // wanted items and specs have room. Clamped so it is neither a strip on a
    // short window nor a whole screen on a tall one.
    final heroHeight = (MediaQuery.sizeOf(context).height * 0.5).clamp(
      300.0,
      520.0,
    );

    return CustomScrollView(
      slivers: [
        SliverAppBar(
          pinned: true,
          expandedHeight: heroHeight,
          backgroundColor: BrandColors.brand500,
          foregroundColor: Colors.white,
          leading: IconButton(
            tooltip: context.canPop()
                ? MaterialLocalizations.of(context).backButtonTooltip
                : MaterialLocalizations.of(context).closeButtonTooltip,
            icon: Icon(
              context.canPop() ? Icons.arrow_back : Icons.close_rounded,
            ),
            onPressed: () {
              if (context.canPop()) {
                context.pop();
              } else {
                context.go('/home');
              }
            },
          ),
          actions: [
            if (isMine)
              PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'edit') {
                    onEdit();
                  } else if (value == 'delete') {
                    onDelete();
                  }
                },
                itemBuilder: (context) => [
                  PopupMenuItem(value: 'edit', child: Text(l.actionEdit)),
                  PopupMenuItem(value: 'delete', child: Text(l.actionDelete)),
                ],
              )
            else
              PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'report') {
                    onReport();
                  } else if (value == 'block') {
                    onBlock();
                  }
                },
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: 'report',
                    child: Text(l.actionReportUser),
                  ),
                  PopupMenuItem(value: 'block', child: Text(l.actionBlockUser)),
                ],
              ),
            if (!isMine)
              Padding(
                padding: const EdgeInsets.only(right: Gap.x2),
                child: TextButton(
                  onPressed: onToggleSave,
                  style: TextButton.styleFrom(
                    backgroundColor: saved
                        ? BrandColors.gold500
                        : Colors.black.withValues(alpha: 0.35),
                    foregroundColor: Colors.white,
                  ),
                  child: Text(saved ? l.listingSaved : l.listingSave),
                ),
              ),
          ],
          flexibleSpace: FlexibleSpaceBar(
            background: Hero(
              tag: 'listing-image-${listing.id}',
              child: AnimatedSwitcher(
                duration: M3Motion.short4,
                switchInCurve: M3Motion.standardDecelerate,
                switchOutCurve: M3Motion.standardAccelerate,
                transitionBuilder: (child, animation) =>
                    FadeTransition(opacity: animation, child: child),
                child: RemoteImage(
                  key: ValueKey(
                    gallery.isEmpty
                        ? ''
                        : gallery[shot.clamp(0, gallery.length - 1)],
                  ),
                  url: gallery.isEmpty
                      ? null
                      : gallery[shot.clamp(0, gallery.length - 1)],
                  semanticLabel: listing.imageAlt,
                ),
              ),
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(Gap.x5, Gap.x5, Gap.x5, Gap.x8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (gallery.length > 1) ...[
                  SizedBox(
                    height: 60,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: gallery.length,
                      separatorBuilder: (_, _) => Gap.w2,
                      itemBuilder: (context, i) => InkWell(
                        onTap: () => onShot(i),
                        borderRadius: Radii.rSm,
                        child: Container(
                          width: 60,
                          decoration: BoxDecoration(
                            borderRadius: Radii.rSm,
                            border: Border.all(
                              color: i == shot ? p.give : Colors.transparent,
                              width: 2,
                            ),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: RemoteImage(
                            url: gallery[i],
                            semanticLabel: '',
                          ),
                        ),
                      ),
                    ),
                  ),
                  Gap.h5,
                ],

                Text(listing.title, style: theme.textTheme.headlineMedium),
                Gap.h2,
                Wrap(
                  spacing: Gap.x3,
                  runSpacing: Gap.x2,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      listing.value.format(locale),
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                    Pill(
                      label: listing.cashOk ? l.listingCashOk : l.listingCashNo,
                      foreground: listing.cashOk ? p.money : p.inkSoft,
                      background: listing.cashOk
                          ? p.moneySoft
                          : theme.colorScheme.surfaceContainerHighest,
                    ),
                  ],
                ),

                Gap.h6,
                _GiveTakeCard(listing: listing),

                Gap.h6,
                _SectionLabel(l.listingAbout),
                BouncingClayCard(
                  clayMode: true,
                  borderRadius: Radii.rLg,
                  child: Container(
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerLow,
                      borderRadius: Radii.rLg,
                      border: Border.all(
                        color: theme.colorScheme.outlineVariant.withValues(
                          alpha: 0.5,
                        ),
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(Gap.x4),
                      child: Text(
                        listing.description,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: p.inkSoft,
                        ),
                      ),
                    ),
                  ),
                ),

                Gap.h6,
                BouncingClayCard(
                  clayMode: true,
                  borderRadius: Radii.rLg,
                  child: Container(
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerLow,
                      borderRadius: Radii.rLg,
                      border: Border.all(
                        color: theme.colorScheme.outlineVariant.withValues(
                          alpha: 0.5,
                        ),
                      ),
                    ),
                    child: ExpansionTile(
                      title: _SectionLabel(l.listingSpecs),
                      tilePadding: const EdgeInsets.symmetric(
                        horizontal: Gap.x4,
                      ),
                      initiallyExpanded: true,
                      shape: const Border(),
                      children: [
                        _SpecRow(l.specCategory, listing.category),
                        _SpecRow(l.specCondition, listing.condition),
                        _SpecRow(l.specQuantity, listing.quantity),
                        _SpecRow(
                          l.specPosted,
                          formatDate(context, listing.postedAt),
                        ),
                        _SpecRow(
                          l.specValue,
                          listing.value.format(locale),
                          last: true,
                        ),
                        Gap.h2,
                      ],
                    ),
                  ),
                ),

                Gap.h6,
                _SectionLabel(l.listingOwner),
                BouncingClayCard(
                  clayMode: true,
                  borderRadius: Radii.rLg,
                  child: Container(
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerLow,
                      borderRadius: Radii.rLg,
                      border: Border.all(
                        color: theme.colorScheme.outlineVariant.withValues(
                          alpha: 0.5,
                        ),
                      ),
                    ),
                    padding: const EdgeInsets.all(Gap.x4),
                    child: Row(
                      children: [
                        TraderAvatar(
                          url: listing.owner.avatarUrl,
                          name: listing.owner.name,
                          size: 48,
                          isOnline: listing.owner.isOnline,
                          showPresence: true,
                        ),
                        Gap.w3,
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      listing.owner.name,
                                      overflow: TextOverflow.ellipsis,
                                      style: theme.textTheme.titleSmall,
                                    ),
                                  ),
                                  if (listing.owner.isVerified) ...[
                                    Gap.w1,
                                    Icon(
                                      Icons.verified_user_outlined,
                                      size: Sizes.iconSm,
                                      color: p.give,
                                    ),
                                  ],
                                ],
                              ),
                              Gap.h1,
                              Row(
                                children: [
                                  Icon(
                                    Icons.star_rounded,
                                    size: Sizes.iconSm,
                                    color: BrandColors.gold500,
                                  ),
                                  Gap.w1,
                                  Text(
                                    listing.owner.rating?.toStringAsFixed(1) ??
                                        '—',
                                    style: theme.textTheme.bodySmall,
                                  ),
                                  Text(
                                    '  ·  ${l.listingTrades(listing.owner.deals)}',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: p.inkSoft,
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
                Gap.h4,
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.shield_outlined,
                      size: Sizes.iconSm,
                      color: p.give,
                    ),
                    Gap.w2,
                    Expanded(
                      child: Text(
                        l.listingSafety,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: p.inkFaint,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _GiveTakeCard extends StatelessWidget {
  const _GiveTakeCard({required this.listing});

  final ListingDetail listing;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final p = palette(context);
    final theme = Theme.of(context);

    return BouncingClayCard(
      clayMode: true,
      borderRadius: Radii.rLg,
      child: Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerLow,
          borderRadius: Radii.rLg,
          border: Border.all(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(
                Gap.x4,
                Gap.x4,
                Gap.x4,
                Gap.x4,
              ),
              decoration: BoxDecoration(
                border: BorderDirectional(
                  start: BorderSide(color: p.give, width: 3),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l.listingGives.toUpperCase(),
                    style: theme.textTheme.labelSmall?.copyWith(color: p.give),
                  ),
                  Gap.h1,
                  Text(listing.title, style: theme.textTheme.titleSmall),
                ],
              ),
            ),
            Container(
              color: theme.colorScheme.surfaceContainerHighest,
              padding: const EdgeInsets.symmetric(vertical: Gap.x2),
              child: Icon(
                Icons.swap_vert_rounded,
                size: Sizes.iconMd,
                color: p.give,
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(
                Gap.x4,
                Gap.x4,
                Gap.x4,
                Gap.x4,
              ),
              decoration: BoxDecoration(
                border: BorderDirectional(
                  start: BorderSide(color: p.take, width: 3),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l.listingWants.toUpperCase(),
                    style: theme.textTheme.labelSmall?.copyWith(color: p.take),
                  ),
                  Gap.h3,
                  Wrap(
                    spacing: Gap.x2,
                    runSpacing: Gap.x2,
                    children: [
                      for (final want in listing.wants)
                        Pill(
                          label: want,
                          foreground: p.take,
                          background: p.takeSoft,
                        ),
                    ],
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

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: Gap.x2),
      child: Text(
        text.toUpperCase(),
        style: Theme.of(
          context,
        ).textTheme.labelSmall?.copyWith(color: palette(context).inkFaint),
      ),
    );
  }
}

class _SpecRow extends StatelessWidget {
  const _SpecRow(this.label, this.value, {this.last = false});

  final String label;
  final String value;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final p = palette(context);
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: Gap.x4, vertical: Gap.x3),
      decoration: last
          ? null
          : BoxDecoration(
              border: Border(bottom: BorderSide(color: p.hair)),
            ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(color: p.inkSoft),
            ),
          ),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: theme.textTheme.titleSmall,
            ),
          ),
        ],
      ),
    );
  }
}
