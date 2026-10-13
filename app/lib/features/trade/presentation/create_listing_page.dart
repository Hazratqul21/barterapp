import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/material_symbols_icons.dart';

import '../../../core/theme/haptics.dart';
import '../../../core/theme/motion.dart';
import '../../feed/presentation/listing_card_tile.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/photo_picker.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/models/models.dart';
import '../../feed/data/listing_repository.dart';
import '../../auth/data/auth_repository.dart' show regionsProvider;
import '../data/listing_draft.dart';
import '../data/trade_repository.dart';

class CreateListingPage extends ConsumerStatefulWidget {
  const CreateListingPage({super.key, this.listingToEdit});

  final ListingDetail? listingToEdit;

  @override
  ConsumerState<CreateListingPage> createState() => _CreateListingPageState();
}

class _CreateListingPageState extends ConsumerState<CreateListingPage> {
  static const _steps = 4;
  static const _maxPhotos = 10;
  int _step = 0;
  bool _forward = true;
  bool _busy = false;

  final _photos = <_PhotoSlot>[];
  ListingTag? _tag;
  // One box per field, written in whatever language the person uses. Every
  // field used to have UZ/RU/EN tabs and "Next" stayed off until all
  // eighteen boxes were filled; people gave up at the second step. The
  // server shows the author's own words to readers of the other languages.
  final _title = _Text();
  final _description = _Text();
  final _condition = _Text();
  final _quantity = _Text();
  final _wants = _Text();
  final _value = TextEditingController();
  ListingTag? _wantTag;

  /// Where the goods are. Null sends nothing and the server uses the owner's
  /// region — the common case, one less question.
  String? _region;
  final _district = TextEditingController();
  bool _cashOk = false;
  bool _wantsCash = false;

  /// Read once: `ref` is not usable in [dispose], where the last save runs.
  late final ListingDraftStore _drafts = ref.read(listingDraftStoreProvider);
  Timer? _saveTimer;

  /// Drafts are for new listings only; an edit already lives on the server.
  bool get _drafting => widget.listingToEdit == null;

  /// False while the "continue your draft?" question is open, so autosave
  /// cannot overwrite the stored draft with this still-empty form.
  bool _draftSettled = true;

  /// Set once the listing is published; nothing may be saved after that.
  bool _done = false;

  /// Text fields as they were when an edit opened; empty for a new listing.
  Map<String, String> _original = const {};

  /// A new listing sends every field; an edit only the ones that changed.
  bool _send(String field, _Text text) =>
      !_original.containsKey(field) ||
      _original[field] != text.controller.text.trim();

  Map<String, _Text> get _fields => {
    'title': _title,
    'description': _description,
    'condition': _condition,
    'quantity': _quantity,
    'wants': _wants,
  };

  @override
  void initState() {
    super.initState();
    // "Next" depends on what is typed: rebuild the page, not just the box.
    // Only the field used to repaint, so the button could stay disabled
    // after the last box was filled until something else moved.
    for (final field in _fields.values) {
      field.controller.addListener(_refresh);
    }
    _value.addListener(_refresh);
    if (widget.listingToEdit != null) {
      final lst = widget.listingToEdit!;
      _photos.addAll(
        (lst.gallery.isEmpty && lst.imageUrl != null
                ? [lst.imageUrl!]
                : lst.gallery)
            .map(_PhotoSlot.uploaded),
      );
      _tag = lst.tag;
      // What the edit started from: only text that changes is sent, so
      // fixing the price does not overwrite the other languages' wording.
      _original = {
        'title': lst.title,
        'description': lst.description,
        'condition': lst.condition,
        'quantity': lst.quantity,
        'wants': lst.wants.join(', '),
      };
      _title.controller.text = lst.title;
      _description.controller.text = lst.description;
      _condition.controller.text = lst.condition;
      _quantity.controller.text = lst.quantity;
      _wants.controller.text = lst.wants.join(', ');

      _value.text = (lst.value.minor ~/ 100).toString();
      _cashOk = lst.cashOk;
      _region = lst.region;
      _district.text = lst.district ?? '';
      return;
    }

    for (final field in _fields.values) {
      field.controller.addListener(_changed);
    }
    _value.addListener(_changed);
    _district.addListener(_changed);

    final draft = _drafts.load();
    if (draft != null) {
      _draftSettled = false;
      WidgetsBinding.instance.addPostFrameCallback((_) => _offerDraft(draft));
    }
  }

  @override
  void dispose() {
    _saveTimer?.cancel();
    // Leaving the page is the moment most worth saving.
    if (_drafting && _draftSettled && !_done) _drafts.save(_snapshot());
    for (final f in _fields.values) {
      f.dispose();
    }
    _value.dispose();
    _district.dispose();
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  /// Any edit: save shortly after typing stops, not on every keystroke.
  void _changed() {
    if (!_drafting || !_draftSettled || _done) return;
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 600), () {
      if (!_done) _drafts.save(_snapshot());
    });
  }

  ListingDraft _snapshot() => ListingDraft(
    savedAt: DateTime.now(),
    step: _step,
    photos: [
      for (final slot in _photos)
        if (slot.url != null) slot.url!,
    ],
    tag: _tag?.name,
    fields: {for (final e in _fields.entries) e.key: e.value.toJson(_locale)},
    value: _value.text,
    wantTag: _wantTag?.name,
    cashOk: _cashOk,
    wantsCash: _wantsCash,
    region: _region,
    district: _district.text,
  );

  Future<void> _offerDraft(ListingDraft draft) async {
    if (!mounted) return;
    final l = L.of(context);
    final resume = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text(l.draftFoundTitle),
        content: Text(l.draftFoundBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l.draftDiscard),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l.draftContinue),
          ),
        ],
      ),
    );
    if (!mounted) return;
    if (resume != true) {
      await _drafts.clear();
      _draftSettled = true;
      return;
    }

    final expired = draft.photosExpired(DateTime.now());
    final usable = expired ? draft.withoutPhotos() : draft;
    final tags = ListingTag.values.asNameMap();
    setState(() {
      _photos
        ..clear()
        ..addAll(usable.photos.map(_PhotoSlot.uploaded));
      _tag = tags[usable.tag];
      _wantTag = tags[usable.wantTag];
      for (final e in _fields.entries) {
        // Drafts saved before this change hold three languages: take the
        // one the person reads, else whichever they wrote.
        final saved = usable.fields[e.key] ?? const {};
        e.value.controller.text =
            saved[_locale] ??
            saved.values.firstWhere(
              (t) => t.trim().isNotEmpty,
              orElse: () => '',
            );
      }
      _value.text = usable.value;
      _cashOk = usable.cashOk;
      _region = usable.region;
      _district.text = usable.district;
      _wantsCash = usable.wantsCash;
      _step = usable.step.clamp(0, _steps - 1);
      // Never land past a step whose requirements are no longer met (the
      // photos may have just been dropped).
      while (_step > 0 && !_stepDone(0)) {
        _step--;
      }
    });
    _draftSettled = true;
    if (expired) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l.draftPhotosExpired)));
    }
  }

  /// The language the text is written in: the one the app is shown in.
  /// Kept in a field because the last draft save runs in [dispose], where
  /// the context can no longer be asked.
  String _locale = 'uz';

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _locale = Localizations.localeOf(context).languageCode;
  }

  /// The category comes from the picker, already translated: no reason to
  /// make anyone type "Elektronika" after choosing Elektronika.
  Map<String, String> _categoryText(ListingTag tag) => {
    for (final code in const ['uz', 'ru', 'en'])
      code: categoryLabel(lookupL(Locale(code)), tag),
  };

  int get _valueSom => int.tryParse(_value.text.replaceAll(' ', '')) ?? 0;

  bool get _stepComplete => _stepDone(_step);

  bool _stepDone(int step) => switch (step) {
    0 => _photos.isNotEmpty && _photos.every((slot) => slot.url != null),
    1 =>
      _tag != null &&
          _title.complete &&
          _description.complete &&
          _condition.complete &&
          _quantity.complete,
    2 => _wants.complete,
    _ => _valueSom > 0,
  };

  Future<void> _addPhoto() async {
    final picked = await pickPhoto(context);
    if (picked == null || !mounted) return;
    final slot = _PhotoSlot.pending(picked);
    setState(() => _photos.add(slot));
    await _upload(slot);
  }

  /// Each photo uploads on its own: one slow or failed photo no longer
  /// blocks adding the next, and a failure is retried from the bytes in hand.
  Future<void> _upload(_PhotoSlot slot) async {
    final picked = slot.picked;
    if (picked == null) return;
    setState(() {
      slot.error = null;
      slot.progress = 0;
    });
    try {
      final url = await ref
          .read(tradeRepositoryProvider)
          .uploadPhoto(
            bytes: picked.bytes,
            filename: picked.filename,
            onProgress: (sent, total) {
              if (!mounted || total <= 0) return;
              setState(() => slot.progress = sent / total);
            },
          );
      if (!mounted) return;
      setState(() {
        slot.url = url;
        slot.picked = null;
      });
      _changed();
    } catch (e) {
      if (!mounted) return;
      setState(() => slot.error = e);
    }
  }

  void _removePhoto(_PhotoSlot slot) {
    setState(() => _photos.remove(slot));
    _changed();
  }

  void _reorderPhoto(int oldIndex, int newIndex) {
    // onReorderItem already adjusts newIndex for the removed item.
    setState(() {
      _photos.insert(newIndex, _photos.removeAt(oldIndex));
    });
    _changed();
  }

  /// setState that also counts as an edit worth saving.
  void _edit(VoidCallback change) {
    setState(change);
    _changed();
  }

  Future<void> _publish() async {
    setState(() => _busy = true);
    try {
      final lang = _locale;
      final body = {
        'tag': _tag!.name,
        if (_send('title', _title)) ...{
          'title': _title.toJson(lang),
          'image_alt': _title.toJson(lang),
        },
        if (_send('description', _description))
          'description': _description.toJson(lang),
        // An edit keeps a hand-written category unless the type changed.
        if (widget.listingToEdit?.tag != _tag) 'category': _categoryText(_tag!),
        if (_send('condition', _condition))
          'condition': _condition.toJson(lang),
        if (_send('quantity', _quantity)) 'quantity': _quantity.toJson(lang),
        if (_send('wants', _wants)) ...{
          'wants_summary': _wants.toJson(lang),
          'wants': [_wants.toJson(lang)],
        },
        'desires': [
          {
            'category': _wantTag?.name,
            'will_add_cash': _cashOk,
            'wants_cash': _wantsCash,
          },
        ],
        'photos': [for (final slot in _photos) slot.url!],
        'value': {'minor': _valueSom * 100, 'currency': 'UZS'},
        'cash_ok': _cashOk,
        'region': ?_region,
        if (_district.text.trim().isNotEmpty) 'district': _district.text.trim(),
      };

      if (widget.listingToEdit != null) {
        await ref
            .read(tradeRepositoryProvider)
            .editListing(widget.listingToEdit!.id, body);
        ref.invalidate(listingDetailProvider(widget.listingToEdit!.id));
      } else {
        await ref.read(tradeRepositoryProvider).createListing(body);
        _done = true;
        _saveTimer?.cancel();
        await _drafts.clear();
      }
      ref.invalidate(feedProvider);
      ref.invalidate(myListingsProvider);
      if (!mounted) return;
      context.pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(errorMessage(context, e))));
      }
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
        title: Text(
          l.createTitle,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(
            40 + MediaQuery.textScalerOf(context).scale(12),
          ),
          child: _StepIndicator(
            labels: [
              l.createShortPhotos,
              l.createShortGive,
              l.createShortTake,
              l.createShortValue,
            ],
            current: _step,
            // Only backwards: forward still goes through "Keyingi", which
            // checks the step is complete.
            onTap: _busy
                ? null
                : (i) {
                    if (i < _step) {
                      Haptics.selection();
                      _edit(() {
                        _forward = false;
                        _step = i;
                      });
                    }
                  },
          ),
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
                    duration: Motion.standard.durationOf(context),
                    switchInCurve: Motion.standard.curve,
                    switchOutCurve: Curves.easeOut,
                    // Slides the way the person is going: forward comes in
                    // from the right, back from the left.
                    transitionBuilder: (child, anim) {
                      final entering = child.key == ValueKey(_step);
                      final from =
                          (entering ? 1 : -1) * (_forward ? 0.08 : -0.08);
                      return FadeTransition(
                        opacity: anim,
                        child: SlideTransition(
                          position: anim.drive(
                            Tween(begin: Offset(from, 0), end: Offset.zero),
                          ),
                          child: child,
                        ),
                      );
                    },
                    child: ListView(
                      key: ValueKey(_step),
                      padding: const EdgeInsets.all(Gap.x5),
                      children: [
                        Text(
                          switch (_step) {
                            0 => l.createStepPhotos,
                            1 => l.createStepGive,
                            2 => l.createStepTake,
                            _ => l.createStepValue,
                          },
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        Gap.h2,
                        Text(
                          switch (_step) {
                            0 => l.createPhotosHint,
                            1 => l.createGiveHint,
                            2 => l.createTakeHint,
                            _ => l.createValueHint,
                          },
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: p.inkSoft,
                          ),
                        ),
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
                      if (_step > 0)
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _busy
                                ? null
                                : () => _edit(() {
                                    _forward = false;
                                    _step--;
                                  }),
                            child: Text(l.createBack),
                          ),
                        ),
                      if (_step > 0) Gap.w3,
                      Expanded(
                        flex: 2,
                        child: FilledButton(
                          onPressed: !_stepComplete || _busy
                              ? null
                              : () {
                                  Haptics.success();
                                  last
                                      ? _publish()
                                      : _edit(() {
                                          _forward = true;
                                          _step++;
                                        });
                                },
                          child: _busy
                              ? const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : Text(last ? l.createPublish : l.createNext),
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

  List<Widget> _photosStep(L l) => [
    Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_photos.length < _maxPhotos) ...[
          PhotoWell(url: null, onTap: _addPhoto),
          Gap.w3,
        ],
        Expanded(
          child: SizedBox(
            // Room for the remove badge that pokes out of each well.
            height: 96 + 12,
            child: ReorderableListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.only(top: 6, right: 6),
              itemCount: _photos.length,
              onReorderItem: _reorderPhoto,
              itemBuilder: (context, index) {
                final slot = _photos[index];
                return Padding(
                  key: slot.key,
                  padding: const EdgeInsets.only(right: Gap.x3),
                  child: _PhotoTile(
                    slot: slot,
                    cover: index == 0,
                    coverLabel: l.photoCover,
                    failedLabel: l.photoUploadFailed,
                    retryLabel: l.retry,
                    onRemove: () => _removePhoto(slot),
                    onRetry: () => _upload(slot),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    ),
    if (_photos.length > 1) ...[
      Gap.h3,
      Text(
        l.photoReorderHint,
        style: Theme.of(
          context,
        ).textTheme.bodySmall?.copyWith(color: palette(context).inkSoft),
      ),
    ],
  ];

  List<Widget> _giveStep(L l) => [
    DropdownButtonFormField<ListingTag>(
      initialValue: _tag,
      decoration: InputDecoration(
        labelText: l.createFieldTag,
        filled: true,
        fillColor: Theme.of(context).colorScheme.surfaceContainerLow,
      ),
      items: [
        for (final t in ListingTag.values)
          DropdownMenuItem(value: t, child: Text(categoryLabel(l, t))),
      ],
      onChanged: (v) => _edit(() => _tag = v),
    ),
    Gap.h4,
    _TextField(label: l.createFieldTitle, field: _title),
    Gap.h4,
    _TextField(
      label: l.createFieldDescription,
      field: _description,
      maxLines: 4,
    ),
    Gap.h4,
    _TextField(label: l.createFieldCondition, field: _condition),
    Gap.h4,
    _TextField(label: l.createFieldQuantity, field: _quantity),
    Gap.h4,
    // Where the goods are: per listing, so a trader with stock in two regions
    // can list both, and moving house does not move old listings.
    ref
        .watch(regionsProvider)
        .maybeWhen(
          data: (regions) => DropdownButtonFormField<String?>(
            initialValue: regions.contains(_region) ? _region : null,
            decoration: InputDecoration(
              labelText: l.filterRegion,
              filled: true,
              fillColor: Theme.of(context).colorScheme.surfaceContainerLow,
            ),
            items: [
              for (final r in regions)
                DropdownMenuItem(value: r, child: Text(r)),
            ],
            onChanged: (v) => _edit(() => _region = v),
          ),
          orElse: () => const SizedBox.shrink(),
        ),
    Gap.h3,
    TextField(
      controller: _district,
      maxLength: 120,
      decoration: InputDecoration(
        labelText: l.createFieldDistrict,
        counterText: '',
        filled: true,
        fillColor: Theme.of(context).colorScheme.surfaceContainerLow,
      ),
    ),
  ];

  List<Widget> _takeStep(L l) => [
    DropdownButtonFormField<ListingTag>(
      initialValue: _wantTag,
      decoration: InputDecoration(
        labelText: l.createPreferredCategory,
        filled: true,
        fillColor: Theme.of(context).colorScheme.surfaceContainerLow,
      ),
      items: [
        DropdownMenuItem(value: null, child: Text(l.createWantAny)),
        for (final t in ListingTag.values)
          DropdownMenuItem(value: t, child: Text(categoryLabel(l, t))),
      ],
      onChanged: (v) => _edit(() => _wantTag = v),
    ),
    Gap.h4,
    _TextField(label: l.createFieldWants, field: _wants, maxLines: 2),
    Gap.h4,
    SwitchListTile(
      value: _cashOk,
      onChanged: (v) => _edit(() {
        _cashOk = v;
        if (v) _wantsCash = false;
      }),
      title: Text(l.createCashAdd),
      contentPadding: EdgeInsets.zero,
      activeThumbColor: palette(context).give,
    ),
    SwitchListTile(
      value: _wantsCash,
      onChanged: (v) => _edit(() {
        _wantsCash = v;
        if (v) _cashOk = false;
      }),
      title: Text(l.createPreferCash),
      contentPadding: EdgeInsets.zero,
      activeThumbColor: palette(context).take,
    ),
  ];

  List<Widget> _valueStep(L l, ThemeData theme) => [
    TextField(
      controller: _value,
      keyboardType: TextInputType.number,
      onChanged: (_) => setState(() {}),
      style: theme.textTheme.headlineMedium?.copyWith(
        fontWeight: FontWeight.w900,
      ),
      decoration: InputDecoration(
        labelText: l.createFieldValue,
        suffixText: l.currencySom,
        filled: true,
        fillColor: theme.colorScheme.surfaceContainerLow,
      ),
    ),
    Gap.h6,
    Text(
      l.createPreviewTitle,
      style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
    ),
    Gap.h3,
    // The real feed card, built from what was typed: the last check before
    // publishing is seeing it the way a trader scrolling past will.
    Center(child: _preview(theme)),
  ];

  Widget _preview(ThemeData theme) {
    String pick(_Text f) => f.controller.text.trim();

    final card = ListingCard(
      id: 'preview',
      tag: _tag ?? ListingTag.values.first,
      title: pick(_title),
      imageUrl: _photos.isEmpty ? null : _photos.first.url,
      imageAlt: pick(_title),
      wantsSummary: pick(_wants),
      value: Money(minor: _valueSom * 100, currency: 'UZS'),
      cashOk: _cashOk,
      isPremium: false,
      postedAt: DateTime.now(),
      owner: const TraderBrief(id: 'me', name: '', isVerified: false),
    );
    const width = 200.0;
    final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
    return IgnorePointer(
      child: SizedBox(
        width: width,
        height: width + ListingCardTile.textBlockHeight(scale),
        child: ListingCardTile(listing: card, onTap: () {}),
      ),
    );
  }
}

/// Four labelled steps instead of a bare progress line: where you are, what
/// is done (a tick) and what is left. Finished steps can be tapped to go back.
class _StepIndicator extends StatelessWidget {
  const _StepIndicator({
    required this.labels,
    required this.current,
    required this.onTap,
  });

  final List<String> labels;
  final int current;
  final ValueChanged<int>? onTap;

  @override
  Widget build(BuildContext context) {
    final p = palette(context);
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(Gap.x4, 0, Gap.x4, Gap.x3),
      child: Row(
        children: [
          for (var i = 0; i < labels.length; i++)
            Expanded(
              child: Semantics(
                button: i < current,
                selected: i == current,
                label: '${i + 1}/${labels.length} ${labels[i]}',
                excludeSemantics: true,
                child: InkWell(
                  onTap: onTap == null || i >= current ? null : () => onTap!(i),
                  borderRadius: Radii.rXs,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        AnimatedContainer(
                          duration: Motion.standard.durationOf(context),
                          curve: Motion.standard.curve,
                          height: 4,
                          decoration: ShapeDecoration(
                            color: i <= current
                                ? p.give
                                : theme.colorScheme.surfaceContainerHighest,
                            shape: const StadiumBorder(),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            if (i < current) ...[
                              Icon(
                                Symbols.check_rounded,
                                size: 14,
                                color: p.give,
                              ),
                              const SizedBox(width: 2),
                            ],
                            Flexible(
                              child: Text(
                                labels[i],
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.labelMedium?.copyWith(
                                  color: i == current
                                      ? theme.colorScheme.onSurface
                                      : p.inkSoft,
                                  fontWeight: i == current
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Text {
  final controller = TextEditingController();
  bool get complete => controller.text.trim().isNotEmpty;

  /// Sent in the language it was written in; the server fills the others.
  Map<String, String> toJson(String locale) => {locale: controller.text.trim()};

  void dispose() => controller.dispose();
}

/// The page rebuilds on every keystroke (for "Next"), which also redraws the
/// tick here.
class _TextField extends StatelessWidget {
  const _TextField({
    required this.label,
    required this.field,
    this.maxLines = 1,
  });
  final String label;
  final _Text field;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    final p = palette(context);
    final theme = Theme.of(context);
    final multiline = maxLines > 1;
    return TextField(
      controller: field.controller,
      minLines: multiline ? 2 : 1,
      maxLines: maxLines,
      textCapitalization: TextCapitalization.sentences,
      textInputAction: multiline
          ? TextInputAction.newline
          : TextInputAction.next,
      decoration: InputDecoration(
        labelText: label,
        alignLabelWithHint: multiline,
        filled: true,
        fillColor: theme.colorScheme.surfaceContainerLow,
        suffixIcon: field.complete
            ? Icon(
                Symbols.check_circle_rounded,
                size: 20,
                color: p.give,
                fill: 1,
              )
            : null,
      ),
    );
  }
}

/// One photo on the first step: either uploaded (has a [url]) or still on
/// the device (has [picked]) — uploading, or failed with [error].
class _PhotoSlot {
  _PhotoSlot.uploaded(String this.url);
  _PhotoSlot.pending(PickedPhoto this.picked);

  final key = UniqueKey();
  String? url;
  PickedPhoto? picked;
  double progress = 0;
  Object? error;
}

class _PhotoTile extends StatelessWidget {
  const _PhotoTile({
    required this.slot,
    required this.cover,
    required this.coverLabel,
    required this.failedLabel,
    required this.retryLabel,
    required this.onRemove,
    required this.onRetry,
  });

  final _PhotoSlot slot;
  final bool cover;
  final String coverLabel;
  final String failedLabel;
  final String retryLabel;
  final VoidCallback onRemove;
  final VoidCallback onRetry;

  static const _size = 96.0;

  @override
  Widget build(BuildContext context) {
    final p = palette(context);
    final theme = Theme.of(context);
    final picked = slot.picked;

    final Widget well;
    if (slot.url != null || picked == null) {
      well = PhotoWell(url: slot.url, onTap: null, onRemove: onRemove);
    } else {
      final failed = slot.error != null;
      well = SizedBox.square(
        dimension: _size,
        child: Stack(
          clipBehavior: Clip.none,
          fit: StackFit.expand,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.memory(
                picked.bytes,
                fit: BoxFit.cover,
                color: Colors.black.withValues(alpha: 0.45),
                colorBlendMode: BlendMode.darken,
              ),
            ),
            Center(
              child: failed
                  ? Semantics(
                      button: true,
                      label: '$failedLabel. $retryLabel',
                      child: IconButton(
                        tooltip: retryLabel,
                        onPressed: onRetry,
                        icon: const Icon(
                          Symbols.refresh_rounded,
                          color: Colors.white,
                        ),
                      ),
                    )
                  : SizedBox.square(
                      dimension: 34,
                      child: CircularProgressIndicator(
                        value: slot.progress > 0 ? slot.progress : null,
                        strokeWidth: 3,
                        color: Colors.white,
                        backgroundColor: Colors.white24,
                      ),
                    ),
            ),
            if (failed)
              Positioned(
                left: 0,
                right: 0,
                bottom: 6,
                child: Text(
                  failedLabel,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: Colors.white,
                  ),
                ),
              ),
            if (failed)
              Positioned(
                top: -6,
                right: -6,
                child: Material(
                  color: theme.colorScheme.surfaceContainerLowest,
                  shape: const CircleBorder(),
                  elevation: 2,
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: onRemove,
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: Icon(
                        Symbols.close_rounded,
                        size: 16,
                        color: p.inkSoft,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      );
    }

    if (!cover) return well;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        well,
        Positioned(
          left: 6,
          bottom: 6,
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: p.give,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                child: Text(
                  coverLabel,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
