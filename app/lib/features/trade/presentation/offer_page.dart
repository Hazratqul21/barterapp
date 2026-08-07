import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/material_symbols_icons.dart';

import '../../../core/widgets/common.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/models/models.dart';
import '../../feed/data/listing_repository.dart';
import '../data/trade_repository.dart';

class OfferPage extends ConsumerStatefulWidget {
  const OfferPage({super.key, required this.listingId});
  final String listingId;

  @override
  ConsumerState<OfferPage> createState() => _OfferPageState();
}

class _OfferPageState extends ConsumerState<OfferPage> {
  final _cashController = TextEditingController();
  final Set<String> _selectedItems = {};

  @override
  void dispose() {
    _cashController.dispose();
    super.dispose();
  }

  void _submit(WidgetRef ref, ListingDetail targetListing) async {
    final l = L.of(context);
    final cashText = _cashController.text.trim();
    final cashValue = int.tryParse(cashText) ?? 0;
    
    try {
      final offer = await ref.read(tradeRepositoryProvider).sendOffer(
        listingId: widget.listingId,
        offeredListingIds: _selectedItems.toList(),
        cashDeltaMinor: cashValue * 100,
      );
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l.offerSent)),
        );
        context.go('/chat/${offer.conversationId}');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final p = palette(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final targetState = ref.watch(listingDetailProvider(widget.listingId));
    final myListingsState = ref.watch(myListingsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l.offerTitle),
        leading: IconButton(
          icon: const Icon(Symbols.close_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: targetState.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorState(
          message: e.toString(),
          retryLabel: l.retry,
          onRetry: () => ref.invalidate(listingDetailProvider(widget.listingId)),
        ),
        data: (targetListing) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: SizedBox(
                            width: 60,
                            height: 60,
                            child: RemoteImage(
                              url: targetListing.imageUrl,
                              semanticLabel: targetListing.imageAlt,
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(l.offerYouWant, style: theme.textTheme.labelMedium?.copyWith(color: scheme.secondary)),
                              Text(targetListing.title, style: theme.textTheme.titleMedium),
                              Text(targetListing.owner.displayName, style: theme.textTheme.bodyMedium?.copyWith(color: p.inkSoft)),
                              Text(targetListing.value.format(l.localeName), style: theme.textTheme.labelLarge?.copyWith(color: scheme.tertiary)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Padding(
                  padding: const EdgeInsets.only(left: 4, bottom: 12),
                  child: Text(l.offerSelectItems, style: theme.textTheme.titleSmall),
                ),
                myListingsState.when(
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Text(e.toString()),
                  data: (myListings) {
                    if (myListings.isEmpty) {
                      return EmptyState(
                        title: l.offerNoItems,
                        hint: '',
                        actionLabel: l.navCreate,
                        onAction: () => context.push('/create'),
                      );
                    }
                    
                    return SizedBox(
                      height: 140,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: myListings.length,
                        separatorBuilder: (_, _) => const SizedBox(width: 12),
                        itemBuilder: (context, index) {
                          final item = myListings[index];
                          final isSelected = _selectedItems.contains(item.id);
                          
                          return AnimatedListItem(
                            index: index,
                            child: GestureDetector(
                              onTap: () {
                                setState(() {
                                  if (isSelected) {
                                    _selectedItems.remove(item.id);
                                  } else {
                                    _selectedItems.add(item.id);
                                  }
                                });
                              },
                              child: Card(
                                shape: isSelected ? RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                  side: BorderSide(color: scheme.primary, width: 2),
                                ) : null,
                                child: SizedBox(
                                  width: 120,
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.stretch,
                                    children: [
                                      Expanded(
                                        child: RemoteImage(
                                          url: item.imageUrl,
                                          semanticLabel: item.imageAlt,
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.all(8),
                                        color: isSelected ? scheme.primaryContainer : null,
                                        child: Text(
                                          item.title,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: theme.textTheme.labelMedium?.copyWith(
                                            color: isSelected ? scheme.onPrimaryContainer : scheme.onSurface,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    );
                  },
                ),
                const SizedBox(height: 24),
                TextFormField(
                  controller: _cashController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: l.offerAddCash,
                    hintText: l.offerAddCashHint,
                    prefixIcon: const Icon(Symbols.attach_money_rounded),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 24),
                Card(
                  color: scheme.surfaceContainerHighest,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        Text(
                          '${_selectedItems.length} items + ${int.tryParse(_cashController.text) ?? 0} cash',
                          style: theme.textTheme.titleSmall,
                        ),
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 8),
                          child: Icon(Symbols.swap_vert_rounded),
                        ),
                        Text(
                          targetListing.title,
                          style: theme.textTheme.titleSmall,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: _selectedItems.isEmpty ? null : () => _submit(ref, targetListing),
                  child: Text(l.offerSend),
                ),
                const SizedBox(height: 24),
              ],
            ),
          );
        },
      ),
    );
  }
}
