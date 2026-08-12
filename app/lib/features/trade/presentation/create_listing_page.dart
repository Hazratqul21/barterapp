import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/material_symbols_icons.dart';
import 'package:flutter_animate/flutter_animate.dart';


import '../../../core/theme/tokens.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/photo_picker.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/models/models.dart';
import '../../feed/data/listing_repository.dart';
import '../data/trade_repository.dart';

class CreateListingPage extends ConsumerStatefulWidget {
  const CreateListingPage({super.key});

  @override
  ConsumerState<CreateListingPage> createState() => _CreateListingPageState();
}

class _CreateListingPageState extends ConsumerState<CreateListingPage> {
  static const _steps = 4;
  int _step = 0;
  bool _busy = false;
  bool _uploading = false;

  final _photos = <String>[];
  ListingTag? _tag;
  final _title = _Trilingual();
  final _description = _Trilingual();
  final _category = _Trilingual();
  final _condition = _Trilingual();
  final _quantity = _Trilingual();
  final _wants = _Trilingual();
  final _value = TextEditingController();
  ListingTag? _wantTag;
  bool _cashOk = false;
  bool _wantsCash = false;

  @override
  void dispose() {
    for (final f in [_title, _description, _category, _condition, _quantity, _wants]) { f.dispose(); }
    _value.dispose();
    super.dispose();
  }

  int get _valueSom => int.tryParse(_value.text.replaceAll(' ', '')) ?? 0;

  bool get _stepComplete => switch (_step) {
    0 => _photos.isNotEmpty,
    1 => _tag != null && _title.complete && _description.complete && _category.complete && _condition.complete && _quantity.complete,
    2 => _wants.complete,
    _ => _valueSom > 0,
  };

  Future<void> _addPhoto() async {
    setState(() => _uploading = true);
    try {
      final url = await pickAndUploadPhoto(context, ref);
      if (url != null) setState(() => _photos.add(url));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(errorMessage(context, e))));
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _publish() async {
    setState(() => _busy = true);
    try {
      await ref.read(tradeRepositoryProvider).createListing({
        'tag': _tag!.name,
        'title': _title.toJson(),
        'description': _description.toJson(),
        'image_alt': _title.toJson(),
        'category': _category.toJson(),
        'condition': _condition.toJson(),
        'quantity': _quantity.toJson(),
        'wants_summary': _wants.toJson(),
        'wants': [_wants.toJson()],
        'desires': [{'category': _wantTag?.name, 'will_add_cash': _cashOk, 'wants_cash': _wantsCash}],
        'photos': _photos,
        'value': {'minor': _valueSom * 100, 'currency': 'UZS'},
        'cash_ok': _cashOk,
      });
      ref.invalidate(feedProvider);
      ref.invalidate(myListingsProvider);
      if (!mounted) return;
      context.pop();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(errorMessage(context, e))));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final p = palette(context);
    final theme = Theme.of(context);
    final last = _step == _steps - 1;

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: Text(l.createTitle, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(4),
          child: LinearProgressIndicator(value: (_step + 1) / _steps, minHeight: 4, backgroundColor: theme.colorScheme.surfaceContainerHighest, color: p.give),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Column(
              children: [
                Expanded(
                  child: AnimatedSwitcher(
                    duration: 300.ms,
                    transitionBuilder: (child, anim) => FadeTransition(opacity: anim, child: SlideTransition(position: anim.drive(Tween(begin: const Offset(0.1, 0), end: Offset.zero)), child: child)),
                    child: ListView(
                      key: ValueKey(_step),
                      padding: const EdgeInsets.all(Gap.x5),
                      children: [
                        Text(switch(_step){0=>l.createStepPhotos, 1=>l.createStepGive, 2=>l.createStepTake, _=>l.createStepValue}, style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900)),
                        Gap.h2,
                        Text(switch(_step){0=>l.createPhotosHint, 1=>l.createGiveHint, 2=>l.createTakeHint, _=>l.createValueHint}, style: theme.textTheme.bodyMedium?.copyWith(color: p.inkSoft)),
                        Gap.h6,
                        ...switch (_step) {
                          0 => _photosStep(l),
                          1 => _giveStep(l),
                          2 => _takeStep(l),
                          _ => _valueStep(l, theme),
                        },
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(Gap.x5),
                  child: Row(
                    children: [
                      if (_step > 0) Expanded(child: OutlinedButton(onPressed: _busy ? null : () => setState(() => _step--), child: Text(l.createBack))),
                      if (_step > 0) Gap.w3,
                      Expanded(
                        flex: 2,
                        child: FilledButton(
                          onPressed: !_stepComplete || _busy || _uploading ? null : () { HapticFeedback.mediumImpact(); last ? _publish() : setState(() => _step++); },
                          child: _busy ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : Text(last ? l.createPublish : l.createNext),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _photosStep(L l) => [Wrap(spacing: Gap.x3, runSpacing: Gap.x3, children: [for (final (index, url) in _photos.indexed) PhotoWell(url: url, onTap: null, onRemove: () => setState(() => _photos.removeAt(index))), if (_photos.length < 10) PhotoWell(url: null, busy: _uploading, onTap: _addPhoto)])];

  List<Widget> _giveStep(L l) => [
    DropdownButtonFormField<ListingTag>(
      initialValue: _tag,
      decoration: InputDecoration(labelText: l.createFieldTag, filled: true, fillColor: Theme.of(context).colorScheme.surfaceContainerLow),
      items: [for (final t in ListingTag.values) DropdownMenuItem(value: t, child: Text(categoryLabel(l, t)))],
      onChanged: (v) => setState(() => _tag = v),
    ),
    Gap.h4,
    _TrilingualField(label: l.createFieldTitle, field: _title),
    Gap.h4,
    _TrilingualField(label: l.createFieldDescription, field: _description, maxLines: 3),
    Gap.h4,
    _TrilingualField(label: l.createFieldCategory, field: _category),
    Gap.h4,
    _TrilingualField(label: l.createFieldCondition, field: _condition),
    Gap.h4,
    _TrilingualField(label: l.createFieldQuantity, field: _quantity),
  ];

  List<Widget> _takeStep(L l) => [_TrilingualField(label: l.createFieldWants, field: _wants, maxLines: 2), Gap.h4, SwitchListTile(value: _cashOk, onChanged: (v) => setState(() { _cashOk = v; if (v) _wantsCash = false; }), title: Text(l.createCashAdd), contentPadding: EdgeInsets.zero, activeThumbColor: palette(context).give)];

  List<Widget> _valueStep(L l, ThemeData theme) => [TextField(controller: _value, keyboardType: TextInputType.number, style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w900), decoration: InputDecoration(labelText: l.createFieldValue, suffixText: 'so‘m', filled: true, fillColor: theme.colorScheme.surfaceContainerLow))];
}

class _Trilingual {
  final controllers = {'uz': TextEditingController(), 'ru': TextEditingController(), 'en': TextEditingController()};
  bool get complete => controllers.values.every((c) => c.text.trim().isNotEmpty);
  Map<String, String> toJson() => {for (final e in controllers.entries) e.key: e.value.text.trim()};
  void dispose() {
    for (final c in controllers.values) {
      c.dispose();
    }
  }
}

class _TrilingualField extends StatefulWidget {
  const _TrilingualField({required this.label, required this.field, this.maxLines = 1});
  final String label; final _Trilingual field; final int maxLines;
  @override
  State<_TrilingualField> createState() => _TrilingualFieldState();
}

class _TrilingualFieldState extends State<_TrilingualField> with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 3, vsync: this);
  @override
  void dispose() { _tabs.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    final p = palette(context); final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [Text(widget.label, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)), if (widget.field.complete) Icon(Symbols.check_circle_rounded, size: 16, color: p.give, fill: 1)]),
        Gap.h2,
        Container(
          decoration: BoxDecoration(color: theme.colorScheme.surfaceContainerLow, borderRadius: Radii.rMd),
          child: Column(
            children: [
              TabBar(controller: _tabs, indicatorColor: p.give, labelColor: p.give, tabs: const [Tab(text: 'UZ'), Tab(text: 'RU'), Tab(text: 'EN')]),
              SizedBox(height: widget.maxLines == 1 ? 60 : 100, child: TabBarView(controller: _tabs, children: [for (final code in ['uz', 'ru', 'en']) Padding(padding: const EdgeInsets.symmetric(horizontal: Gap.x3), child: TextField(controller: widget.field.controllers[code], maxLines: widget.maxLines, onChanged: (_) => setState(() {}), decoration: const InputDecoration(border: InputBorder.none, enabledBorder: InputBorder.none, focusedBorder: InputBorder.none, filled: false)))]))
            ],
          ),
        ),
      ],
    );
  }
}
