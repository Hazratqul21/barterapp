import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/material_symbols_icons.dart';

import '../../../core/theme/tokens.dart';
import '../../../core/widgets/common.dart';
import '../../../l10n/app_localizations.dart';
import '../../../core/analytics/analytics_service.dart';
import '../data/listing_repository.dart';
import '../../auth/data/auth_repository.dart';
import 'feed_banner.dart';
import 'feed_shimmer.dart';
import 'listing_card_tile.dart';

class FeedPage extends ConsumerStatefulWidget {
  const FeedPage({super.key});
  @override
  ConsumerState<FeedPage> createState() => _FeedPageState();
}

class _FeedPageState extends ConsumerState<FeedPage> {
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();
  Timer? _debounce;
  final _seen = <String>{};

  @override
  void initState() {
    super.initState();
    _searchController.text = ref.read(feedQueryProvider).search;
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    if (_scrollController.position.extentAfter < 600) {
      ref.read(feedProvider.notifier).loadMore();
    }
  }

  void _search(String value, {bool immediate = false}) {
    _debounce?.cancel();
    void apply() {
      ref.read(feedQueryProvider.notifier).search(value.trim());
      if (_scrollController.hasClients) _scrollController.jumpTo(0);
    }

    if (immediate) {
      apply();
    } else {
      _debounce = Timer(const Duration(milliseconds: 350), apply);
    }
    setState(() {});
  }

  void _clearSearch() {
    _searchController.clear();
    _search('', immediate: true);
  }

  void _filters() => showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    constraints: const BoxConstraints(maxWidth: 560),
    builder: (_) => const _FilterSheet(),
  );

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final theme = Theme.of(context);
    final query = ref.watch(feedQueryProvider);
    final feed = ref.watch(feedProvider);
    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: SafeArea(
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1200),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          const BrandMark(size: 32),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Align(
                              alignment: Alignment.centerRight,
                              child: TextButton.icon(
                                onPressed: _filters,
                                icon: const Icon(
                                  Symbols.location_on_rounded,
                                  size: 18,
                                ),
                                label: Text(
                                  query.region ?? l.feedRegionAny,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                          ),
                          IconButton(
                            tooltip: l.feedNotifications,
                            onPressed: () => context.push('/notifications'),
                            icon: const Icon(Symbols.notifications_rounded),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _searchController,
                              onChanged: _search,
                              onSubmitted: (value) {
                                _search(value, immediate: true);
                                FocusScope.of(context).unfocus();
                              },
                              textInputAction: TextInputAction.search,
                              maxLength: 120,
                              decoration: InputDecoration(
                                counterText: '',
                                hintText: l.feedSearchHint,
                                prefixIcon: const Icon(Symbols.search_rounded),
                                suffixIcon: _searchController.text.isEmpty
                                    ? null
                                    : IconButton(
                                        tooltip: l.clear,
                                        onPressed: _clearSearch,
                                        icon: const Icon(Symbols.close_rounded),
                                      ),
                                filled: true,
                                fillColor:
                                    theme.colorScheme.surfaceContainerLow,
                                border: OutlineInputBorder(
                                  borderRadius: Radii.rSm,
                                  borderSide: BorderSide.none,
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: Radii.rSm,
                                  borderSide: BorderSide.none,
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 14,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Badge(
                            isLabelVisible: query.isNarrowed,
                            child: IconButton.filledTonal(
                              tooltip: l.filterTitle,
                              onPressed: _filters,
                              style: IconButton.styleFrom(
                                minimumSize: const Size(52, 52),
                                shape: RoundedRectangleBorder(
                                  borderRadius: Radii.rSm,
                                ),
                              ),
                              icon: const Icon(Symbols.tune_rounded),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: () async {
                      HapticFeedback.lightImpact();
                      ref.invalidate(feedProvider);
                      try {
                        await ref.read(feedProvider.future);
                      } catch (_) {
                        // The feed displays the error and its retry action.
                      }
                    },
                    child: CustomScrollView(
                      controller: _scrollController,
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      physics: const AlwaysScrollableScrollPhysics(),
                      slivers: [
                        SliverToBoxAdapter(
                          child: _Categories(
                            selected: query.categoryId,
                            onSelect: (id) => ref
                                .read(feedQueryProvider.notifier)
                                .toggleCategory(id),
                          ),
                        ),
                        const SliverToBoxAdapter(child: FeedBanner()),
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    l.feedHeading,
                                    style: theme.textTheme.titleLarge?.copyWith(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                if (query.isNarrowed)
                                  TextButton(
                                    onPressed: () {
                                      _clearSearch();
                                      ref
                                          .read(feedQueryProvider.notifier)
                                          .reset();
                                    },
                                    child: Text(l.filterClear),
                                  ),
                              ],
                            ),
                          ),
                        ),
                        ...switch (feed) {
                          AsyncLoading() => [
                            const SliverToBoxAdapter(child: FeedShimmer()),
                          ],
                          AsyncError(:final error) => [
                            SliverFillRemaining(
                              hasScrollBody: false,
                              child: ErrorState(
                                message: errorMessage(context, error),
                                retryLabel: l.retry,
                                onRetry: () => ref.invalidate(feedProvider),
                              ),
                            ),
                          ],
                          AsyncData(:final value) when value.items.isEmpty => [
                            SliverFillRemaining(
                              hasScrollBody: false,
                              child: EmptyState(
                                icon: Symbols.search_off_rounded,
                                title: l.feedEmpty,
                                hint: l.feedEmptyHint,
                              ),
                            ),
                          ],
                          AsyncData(:final value) => [
                            SliverPadding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                              ),
                              sliver: SliverLayoutBuilder(
                                builder: (context, constraints) {
                                  final columns =
                                      constraints.crossAxisExtent >= 960
                                      ? 3
                                      : constraints.crossAxisExtent >= 580
                                      ? 2
                                      : 1;
                                  final cardWidth =
                                      (constraints.crossAxisExtent -
                                          16 * (columns - 1)) /
                                      columns;
                                  final textScale =
                                      MediaQuery.textScalerOf(
                                        context,
                                      ).scale(14) /
                                      14;
                                  return SliverGrid.builder(
                                    gridDelegate:
                                        SliverGridDelegateWithFixedCrossAxisCount(
                                          crossAxisCount: columns,
                                          crossAxisSpacing: 16,
                                          mainAxisSpacing: 16,
                                          mainAxisExtent:
                                              cardWidth * 0.62 +
                                              156 * textScale,
                                        ),
                                    itemCount: value.items.length,
                                    itemBuilder: (context, index) {
                                      final listing = value.items[index];
                                      if (_seen.add(listing.id)) {
                                        Future.microtask(() {
                                          if (!mounted) return;
                                          ref
                                              .read(analyticsServiceProvider)
                                              .logEvent(
                                                'listing_impression',
                                                targetType: 'listing',
                                                targetId: listing.id,
                                              );
                                        });
                                      }
                                      return ListingCardTile(
                                        listing: listing,
                                        onTap: () => context.push(
                                          '/listing/${listing.id}',
                                        ),
                                      );
                                    },
                                  );
                                },
                              ),
                            ),
                            SliverToBoxAdapter(
                              child: Padding(
                                padding: const EdgeInsets.all(24),
                                child: Center(
                                  child: value.loadingMore
                                      ? const CircularProgressIndicator()
                                      : value.hasMore
                                      ? OutlinedButton(
                                          onPressed: () => ref
                                              .read(feedProvider.notifier)
                                              .loadMore(retry: true),
                                          child: Text(
                                            value.loadMoreError != null
                                                ? l.retry
                                                : l.feedLoadMore,
                                          ),
                                        )
                                      : Text(
                                          l.feedEnd,
                                          style: theme.textTheme.bodySmall,
                                        ),
                                ),
                              ),
                            ),
                          ],
                        },
                        SliverToBoxAdapter(
                          child: SizedBox(
                            height: 16 + MediaQuery.paddingOf(context).bottom,
                          ),
                        ),
                      ],
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

class _Categories extends ConsumerWidget {
  const _Categories({required this.selected, required this.onSelect});
  final String? selected;
  final ValueChanged<String?> onSelect;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L.of(context);
    final categories = ref.watch(categoriesProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  l.feedCategories,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (selected != null)
                TextButton(
                  onPressed: () => onSelect(null),
                  child: Text(l.filterAll),
                ),
            ],
          ),
        ),
        SizedBox(
          height: 78 + MediaQuery.textScalerOf(context).scale(14) * 3,
          child: categories.when(
            data: (items) => ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: items.length,
              separatorBuilder: (_, _) => const SizedBox(width: 10),
              itemBuilder: (_, index) => CategoryCard(
                category: items[index],
                selected: selected == items[index].id,
                onTap: () => onSelect(items[index].id),
              ),
            ),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, _) => Center(
              child: TextButton.icon(
                onPressed: () => ref.invalidate(categoriesProvider),
                icon: const Icon(Icons.refresh),
                label: Text(l.errorCategoryLoad),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _FilterSheet extends ConsumerStatefulWidget {
  const _FilterSheet();
  @override
  ConsumerState<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends ConsumerState<_FilterSheet> {
  final _minController = TextEditingController();
  final _maxController = TextEditingController();
  final _regionController = TextEditingController();
  String _sortBy = 'new';
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    final query = ref.read(feedQueryProvider);
    _minController.text = query.minPrice?.toString() ?? '';
    _maxController.text = query.maxPrice?.toString() ?? '';
    _regionController.text = query.region ?? '';
    _sortBy = query.sortBy;
  }

  @override
  void dispose() {
    _minController.dispose();
    _maxController.dispose();
    _regionController.dispose();
    super.dispose();
  }

  double? _price(String value) =>
      double.tryParse(value.trim().replaceAll(',', '.'));

  String? _validatePrice(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    final value = _price(raw);
    return value == null ||
            !value.isFinite ||
            value < 0 ||
            value > 90000000000000
        ? L.of(context).filterInvalidPrice
        : null;
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final theme = Theme.of(context);

    return SafeArea(
      child: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            Gap.x5,
            Gap.x5,
            Gap.x5,
            Gap.x5 + MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      l.filterTitle,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Symbols.close_rounded),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: Gap.x4),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        validator: _validatePrice,
                        controller: _minController,
                        decoration: InputDecoration(
                          labelText: l.filterMinPrice,
                          errorMaxLines: 3,
                        ),
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                      ),
                    ),
                    const SizedBox(width: Gap.x3),
                    Expanded(
                      child: TextFormField(
                        validator: (raw) {
                          final error = _validatePrice(raw);
                          if (error != null) return error;
                          final min = _price(_minController.text);
                          final max = _price(raw ?? '');
                          return min != null && max != null && min > max
                              ? l.filterInvalidRange
                              : null;
                        },
                        controller: _maxController,
                        decoration: InputDecoration(
                          labelText: l.filterMaxPrice,
                          errorMaxLines: 3,
                        ),
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: Gap.x3),
                ref
                    .watch(regionsProvider)
                    .when(
                      data: (regions) => DropdownButtonFormField<String>(
                        key: ValueKey(_regionController.text),
                        initialValue: regions.contains(_regionController.text)
                            ? _regionController.text
                            : '',
                        isExpanded: true,
                        decoration: InputDecoration(labelText: l.filterRegion),
                        items: [
                          DropdownMenuItem(
                            value: '',
                            child: Text(l.feedRegionAny),
                          ),
                          for (final region in regions)
                            DropdownMenuItem(
                              value: region,
                              child: Text(
                                region,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                        ],
                        onChanged: (value) => setState(
                          () => _regionController.text = value ?? '',
                        ),
                      ),
                      loading: () => const LinearProgressIndicator(),
                      error: (_, _) => TextButton.icon(
                        onPressed: () => ref.invalidate(regionsProvider),
                        icon: const Icon(Icons.refresh),
                        label: Text(l.retry),
                      ),
                    ),
                const SizedBox(height: Gap.x3),
                DropdownButtonFormField<String>(
                  key: ValueKey(_sortBy),
                  initialValue: _sortBy,
                  isExpanded: true,
                  decoration: InputDecoration(labelText: l.filterSort),
                  items: [
                    DropdownMenuItem(value: 'new', child: Text(l.sortNewest)),
                    DropdownMenuItem(
                      value: 'cheap',
                      child: Text(l.sortCheapest),
                    ),
                    DropdownMenuItem(
                      value: 'expensive',
                      child: Text(l.sortExpensive),
                    ),
                  ],
                  onChanged: (v) => setState(() => _sortBy = v ?? 'new'),
                ),
                const SizedBox(height: Gap.x6),
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        style: TextButton.styleFrom(
                          minimumSize: const Size(0, 48),
                        ),
                        onPressed: () {
                          _minController.clear();
                          _maxController.clear();
                          _regionController.clear();
                          setState(() => _sortBy = 'new');
                        },
                        child: Text(l.filterClear),
                      ),
                    ),
                    const SizedBox(width: Gap.x3),
                    Expanded(
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          minimumSize: const Size(0, 48),
                        ),
                        onPressed: () {
                          if (!_formKey.currentState!.validate()) return;
                          final min = _price(_minController.text);
                          final max = _price(_maxController.text);
                          if (min != null && max != null && min > max) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(l.filterInvalidRange)),
                            );
                            return;
                          }
                          ref
                              .read(feedQueryProvider.notifier)
                              .setFilters(
                                minPrice: min,
                                maxPrice: max,
                                region: _regionController.text.trim().isEmpty
                                    ? null
                                    : _regionController.text.trim(),
                                sortBy: _sortBy,
                              );
                          ref
                              .read(analyticsServiceProvider)
                              .logEvent(
                                'filter_applied',
                                payload: {
                                  'min_price': _minController.text,
                                  'max_price': _maxController.text,
                                  'region': _regionController.text.trim(),
                                },
                              );
                          Navigator.pop(context);
                        },
                        child: Text(l.filterApply),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
