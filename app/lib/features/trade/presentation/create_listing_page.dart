import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../core/network/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/common.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/models/models.dart';
import '../data/trade_repository.dart';

class CreateListingPage extends ConsumerStatefulWidget {
  const CreateListingPage({super.key});

  @override
  ConsumerState<CreateListingPage> createState() => _CreateListingPageState();
}

class _CreateListingPageState extends ConsumerState<CreateListingPage> {
  final _formKey = GlobalKey<FormState>();
  
  final _photosController = TextEditingController();
  ListingTag? _selectedTag;
  
  final _titleMap = {'uz': '', 'ru': '', 'en': ''};
  final _descMap = {'uz': '', 'ru': '', 'en': ''};
  final _categoryMap = {'uz': '', 'ru': '', 'en': ''};
  final _conditionMap = {'uz': '', 'ru': '', 'en': ''};
  final _quantityMap = {'uz': '', 'ru': '', 'en': ''};
  final _wantsMap = {'uz': '', 'ru': '', 'en': ''};
  
  final _valueController = TextEditingController();
  bool _cashOk = false;
  bool _isSubmitting = false;

  String _getTagName(L l, ListingTag tag) {
    switch (tag) {
      case ListingTag.agri: return l.filterAgri;
      case ListingTag.livestock: return l.filterLivestock;
      case ListingTag.machinery: return l.filterMachinery;
      case ListingTag.transport: return l.filterTransport;
      case ListingTag.electronics: return l.filterElectronics;
      case ListingTag.construction: return l.filterConstruction;
    }
  }

  void _submit() async {
    if (!_formKey.currentState!.validate()) return;
    
    final l = L.of(context);
    
    // Validate trilingual fields are non-empty
    bool isValidTrilingual(Map<String, String> map) {
      return map.values.every((v) => v.trim().isNotEmpty);
    }
    
    if (!isValidTrilingual(_titleMap) ||
        !isValidTrilingual(_descMap) ||
        !isValidTrilingual(_categoryMap) ||
        !isValidTrilingual(_conditionMap) ||
        !isValidTrilingual(_quantityMap) ||
        !isValidTrilingual(_wantsMap)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l.createLangHint)),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    
    try {
      final valueMinor = (double.tryParse(_valueController.text) ?? 0) * 100;
      
      final body = {
        'tag': _selectedTag!.name,
        'photos': _photosController.text.split('\n').map((s) => s.trim()).where((s) => s.isNotEmpty).toList(),
        'title': _titleMap,
        'description': _descMap,
        'category': _categoryMap,
        'condition': _conditionMap,
        'quantity': _quantityMap,
        'wants_summary': _wantsMap,
        'value_minor': valueMinor.toInt(),
        'cash_ok': _cashOk,
      };

      await ref.read(tradeRepositoryProvider).createListing(body);
      
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l.createPublished)),
      );
      context.pop();
    } on ApiException catch (e) {
      if (e.statusCode == 402) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Quota Exceeded'),
            content: const Text('You have reached your listing limit.'),
            actions: [
              TextButton(
                onPressed: () => context.pop(),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message)),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final p = palette(context);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(l.createTitle),
      ),
      body: Form(
        key: _formKey,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Card(
                  clipBehavior: Clip.antiAlias,
                  margin: EdgeInsets.zero,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // GIVE BLOCK
                      Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l.createGive,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: p.give,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Card(
                              margin: EdgeInsets.zero,
                              color: theme.colorScheme.surfaceContainer,
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  children: [
                                    TextFormField(
                                      controller: _photosController,
                                      maxLines: 3,
                                      decoration: InputDecoration(
                                        labelText: l.createPhotos,
                                        hintText: 'https://...',
                                        border: const OutlineInputBorder(),
                                      ),
                                      validator: (val) => val == null || val.trim().isEmpty ? l.createRequired : null,
                                    ),
                                    const SizedBox(height: 16),
                                    
                                    DropdownButtonFormField<ListingTag>(
                                      initialValue: _selectedTag,
                                      decoration: const InputDecoration(
                                        border: OutlineInputBorder(),
                                        labelText: 'Tag',
                                      ),
                                      items: ListingTag.values.map((t) {
                                        return DropdownMenuItem(
                                          value: t,
                                          child: Text(_getTagName(l, t)),
                                        );
                                      }).toList(),
                                      onChanged: (val) => setState(() => _selectedTag = val),
                                      validator: (val) => val == null ? l.createRequired : null,
                                    ),
                                    const SizedBox(height: 16),
                                    
                                    _TrilingualField(
                                      label: l.createFieldTitle,
                                      values: _titleMap,
                                      requiredMessage: l.createRequired,
                                    ),
                                    const SizedBox(height: 16),
                                    _TrilingualField(
                                      label: 'Description', // fallback if missing
                                      values: _descMap,
                                      requiredMessage: l.createRequired,
                                      maxLines: 3,
                                    ),
                                    const SizedBox(height: 16),
                                    _TrilingualField(
                                      label: 'Category', // fallback
                                      values: _categoryMap,
                                      requiredMessage: l.createRequired,
                                    ),
                                    const SizedBox(height: 16),
                                    _TrilingualField(
                                      label: 'Condition', // fallback
                                      values: _conditionMap,
                                      requiredMessage: l.createRequired,
                                    ),
                                    const SizedBox(height: 16),
                                    _TrilingualField(
                                      label: 'Quantity', // fallback
                                      values: _quantityMap,
                                      requiredMessage: l.createRequired,
                                    ),
                                    const SizedBox(height: 16),
                                    
                                    TextFormField(
                                      controller: _valueController,
                                      keyboardType: TextInputType.number,
                                      decoration: InputDecoration(
                                        labelText: l.createFieldValue,
                                        suffixText: 'UZS',
                                        border: const OutlineInputBorder(),
                                      ),
                                      validator: (val) => val == null || val.trim().isEmpty ? l.createRequired : null,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
        
                      const Divider(),
                      
                      // TAKE BLOCK
                      Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l.createTake,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: p.take,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Card(
                              margin: EdgeInsets.zero,
                              color: theme.colorScheme.surfaceContainer,
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  children: [
                                    _TrilingualField(
                                      label: l.createFieldWants,
                                      values: _wantsMap,
                                      requiredMessage: l.createRequired,
                                      maxLines: 2,
                                    ),
                                    const SizedBox(height: 16),
                                    
                                    SwitchListTile(
                                      title: Text(l.listingCashOk, style: theme.textTheme.bodyLarge),
                                      value: _cashOk,
                                      onChanged: (val) => setState(() => _cashOk = val),
                                      activeThumbColor: p.take,
                                      contentPadding: EdgeInsets.zero,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      
                      const SizedBox(height: 16),
                      
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surface,
                          boxShadow: [
                            BoxShadow(
                              color: theme.colorScheme.shadow.withValues(alpha: 0.1),
                              blurRadius: 10,
                              offset: const Offset(0, -5),
                            )
                          ],
                        ),
                        child: SafeArea(
                          child: FilledButton(
                            onPressed: _isSubmitting ? null : () {
                              HapticFeedback.lightImpact();
                              _submit();
                            },
                            style: FilledButton.styleFrom(
                              minimumSize: const Size.fromHeight(56),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            child: _isSubmitting
                                ? const SizedBox(
                                    height: 24, width: 24,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                  )
                                : Text(
                                    l.createPublish,
                                    style: theme.textTheme.titleSmall?.copyWith(
                                      color: theme.colorScheme.onPrimary,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ).animate().fadeIn(duration: M3Motion.medium2, curve: M3Motion.standard),
            ),
          ),
        ),
      ),
    );
  }
}

class _TrilingualField extends StatefulWidget {
  const _TrilingualField({
    required this.label,
    required this.values,
    required this.requiredMessage,
    this.maxLines = 1,
  });

  final String label;
  final Map<String, String> values;
  final String requiredMessage;
  final int maxLines;

  @override
  State<_TrilingualField> createState() => _TrilingualFieldState();
}

class _TrilingualFieldState extends State<_TrilingualField> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }
  
  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(widget.label, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: theme.dividerColor),
            borderRadius: BorderRadius.circular(8),
            color: theme.colorScheme.surface,
          ),
          child: Column(
            children: [
              TabBar(
                controller: _tabController,
                labelStyle: theme.textTheme.labelLarge,
                unselectedLabelStyle: theme.textTheme.labelLarge,
                tabs: const [
                  Tab(text: 'UZ'),
                  Tab(text: 'RU'),
                  Tab(text: 'EN'),
                ],
              ),
              SizedBox(
                height: widget.maxLines == 1 ? 64 : 100,
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildInput('uz', theme),
                    _buildInput('ru', theme),
                    _buildInput('en', theme),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInput(String lang, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: TextFormField(
        initialValue: widget.values[lang],
        maxLines: widget.maxLines,
        onChanged: (val) => widget.values[lang] = val,
        style: theme.textTheme.bodyMedium,
        decoration: InputDecoration(
          border: InputBorder.none,
          hintText: '${widget.label} ($lang)',
          hintStyle: theme.textTheme.bodyMedium?.copyWith(color: theme.hintColor),
        ),
      ),
    );
  }
}
