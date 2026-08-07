import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/common.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/models/models.dart';
import '../data/trade_repository.dart';

class CreateOfferSheet extends ConsumerStatefulWidget {
  const CreateOfferSheet({super.key, required this.wantedListing});

  final ListingDetail wantedListing;

  @override
  ConsumerState<CreateOfferSheet> createState() => _CreateOfferSheetState();
}

class _CreateOfferSheetState extends ConsumerState<CreateOfferSheet> {
  final _selectedListingIds = <String>{};
  final _cashDeltaController = TextEditingController();
  final _messageController = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _cashDeltaController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_selectedListingIds.isEmpty && _cashDeltaController.text.isEmpty) {
      return;
    }

    HapticFeedback.lightImpact();
    setState(() => _submitting = true);

    try {
      final cash = int.tryParse(_cashDeltaController.text) ?? 0;
      final offer = await ref.read(tradeRepositoryProvider).sendOffer(
        listingId: widget.wantedListing.id,
        offeredListingIds: _selectedListingIds.toList(),
        cashDeltaMinor: cash * 100,
        message: _messageController.text,
      );

      if (!mounted) return;
      context.pop();
      context.push('/chat/${offer.conversationId}');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
      setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final p = palette(context);
    final theme = Theme.of(context);
    final myListingsAsync = ref.watch(myListingsProvider);

    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 12),
              Container(
                width: 32,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                l.listingOffer,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  children: [
                    Text(
                      'Your listings',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    myListingsAsync.when(
                      data: (listings) {
                        if (listings.isEmpty) {
                          return const Padding(
                            padding: EdgeInsets.all(16),
                            child: Text('No active listings found.'),
                          );
                        }
                        return Card(
                          margin: EdgeInsets.zero,
                          clipBehavior: Clip.antiAlias,
                          elevation: 0,
                          color: theme.colorScheme.surface,
                          child: Column(
                            children: listings.map((item) {
                              final selected = _selectedListingIds.contains(item.id);
                              return CheckboxListTile(
                                value: selected,
                                activeColor: p.give,
                                onChanged: (val) {
                                  setState(() {
                                    if (val == true) {
                                      _selectedListingIds.add(item.id);
                                    } else {
                                      _selectedListingIds.remove(item.id);
                                    }
                                  });
                                },
                                title: Text(
                                  item.title,
                                  style: const TextStyle(fontWeight: FontWeight.w500),
                                ),
                                secondary: ClipRRect(
                                  borderRadius: BorderRadius.circular(6),
                                  child: SizedBox(
                                    width: 44,
                                    height: 44,
                                    child: RemoteImage(url: item.imageUrl, semanticLabel: ''),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        );
                      },
                      loading: () => const Center(
                        child: Padding(
                          padding: EdgeInsets.all(24),
                          child: CircularProgressIndicator(),
                        ),
                      ),
                      error: (e, _) => Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(e.toString()),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Cash difference (optional)',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _cashDeltaController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        hintText: '0',
                        filled: true,
                        fillColor: theme.colorScheme.surface,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        prefixIcon: Icon(Icons.attach_money, color: p.inkSoft),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Message (optional)',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _messageController,
                      maxLines: 3,
                      decoration: InputDecoration(
                        hintText: 'Add a message to your offer...',
                        filled: true,
                        fillColor: theme.colorScheme.surface,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
              SafeArea(
                minimum: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                child: FilledButton(
                  onPressed: _submitting ? null : _submit,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                  ),
                  child: _submitting
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(l.listingOffer),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
