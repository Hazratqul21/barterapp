import 'dart:async';

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
  bool _busy = false;

  final _photos = <_PhotoSlot>[];
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

  Map<String, _Trilingual> get _fields => {
    'title': _title,
    'description': _description,
    'category': _category,
    'condition': _condition,
    'quantity': _quantity,
    'wants': _wants,
  };

  @override
  void initState() {
    super.initState();
    if (widget.listingToEdit != null) {
      final lst = widget.listingToEdit!;
      _photos.addAll(
        (lst.gallery.isEmpty && lst.imageUrl != null
                ? [lst.imageUrl!]
                : lst.gallery)
            .map(_PhotoSlot.uploaded),
      );
      // listing tag is not in ListingDetail? wait, we don't have tag in ListingDetail.
      // We will leave _tag as null so user selects it.
      _title.controllers.forEach((k, v) => v.text = lst.title);
      _description.controllers.forEach((k, v) => v.text = lst.description);
      _category.controllers.forEach((k, v) => v.text = lst.category);
      _condition.controllers.forEach((k, v) => v.text = lst.condition);
      _quantity.controllers.forEach((k, v) => v.text = lst.quantity);
      _wants.controllers.forEach((k, v) => v.text = lst.wants.join(', '));

      _value.text = (lst.value.minor ~/ 100).toString();
      _cashOk = lst.cashOk;
      return;
    }

    for (final field in _fields.values) {
      for (final c in field.controllers.values) {
        c.addListener(_changed);
      }
    }
    _value.addListener(_changed);

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
    super.dispose();
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
    fields: {for (final e in _fields.entries) e.key: e.value.toJson()},
    value: _value.text,
    wantTag: _wantTag?.name,
    cashOk: _cashOk,
    wantsCash: _wantsCash,
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
        final saved = usable.fields[e.key] ?? const {};
        e.value.controllers.forEach(
          (locale, c) => c.text = saved[locale] ?? '',
        );
      }
      _value.text = usable.value;
      _cashOk = usable.cashOk;
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

  int get _valueSom => int.tryParse(_value.text.replaceAll(' ', '')) ?? 0;

  bool get _stepComplete => _stepDone(_step);

  bool _stepDone(int step) => switch (step) {
    0 => _photos.isNotEmpty && _photos.every((slot) => slot.url != null),
    1 =>
      _tag != null &&
          _title.complete &&
          _description.complete &&
          _category.complete &&
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
    setState(() {
      if (newIndex > oldIndex) newIndex--;
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
      final body = {
        'tag': _tag!.name,
        'title': _title.toJson(),
        'description': _description.toJson(),
        'image_alt': _title.toJson(),
        'category': _category.toJson(),
        'condition': _condition.toJson(),
        'quantity': _quantity.toJson(),
        'wants_summary': _wants.toJson(),
        'wants': [_wants.toJson()],
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
          preferredSize: const Size.fromHeight(4),
          child: LinearProgressIndicator(
            value: (_step + 1) / _steps,
            minHeight: 4,
            backgroundColor: theme.colorScheme.surfaceContainerHighest,
            color: p.give,
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
                    duration: 300.ms,
                    transitionBuilder: (child, anim) => FadeTransition(
                      opacity: anim,
                      child: SlideTransition(
                        position: anim.drive(
                          Tween(begin: const Offset(0.1, 0), end: Offset.zero),
                        ),
                        child: child,
                      ),
                    ),
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
                                : () => _edit(() => _step--),
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
                                  HapticFeedback.mediumImpact();
                                  last ? _publish() : _edit(() => _step++);
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
              onReorder: _reorderPhoto,
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
    _TrilingualField(label: l.createFieldTitle, field: _title),
    Gap.h4,
    _TrilingualField(
      label: l.createFieldDescription,
      field: _description,
      maxLines: 3,
    ),
    Gap.h4,
    _TrilingualField(label: l.createFieldCategory, field: _category),
    Gap.h4,
    _TrilingualField(label: l.createFieldCondition, field: _condition),
    Gap.h4,
    _TrilingualField(label: l.createFieldQuantity, field: _quantity),
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
    _TrilingualField(label: l.createFieldWants, field: _wants, maxLines: 2),
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
  ];
}

class _Trilingual {
  final controllers = {
    'uz': TextEditingController(),
    'ru': TextEditingController(),
    'en': TextEditingController(),
  };
  bool get complete =>
      controllers.values.every((c) => c.text.trim().isNotEmpty);
  Map<String, String> toJson() => {
    for (final e in controllers.entries) e.key: e.value.text.trim(),
  };
  void dispose() {
    for (final c in controllers.values) {
      c.dispose();
    }
  }
}

class _TrilingualField extends StatefulWidget {
  const _TrilingualField({
    required this.label,
    required this.field,
    this.maxLines = 1,
  });
  final String label;
  final _Trilingual field;
  final int maxLines;
  @override
  State<_TrilingualField> createState() => _TrilingualFieldState();
}

class _TrilingualFieldState extends State<_TrilingualField>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 3, vsync: this);
  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = palette(context);
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              widget.label,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            if (widget.field.complete)
              Icon(
                Symbols.check_circle_rounded,
                size: 16,
                color: p.give,
                fill: 1,
              ),
          ],
        ),
        Gap.h2,
        BouncingClayCard(
          clayMode: true,
          borderRadius: Radii.rMd,
          child: Container(
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerLow,
              borderRadius: Radii.rMd,
              border: Border.all(
                color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
              ),
            ),
            child: Column(
              children: [
                TabBar(
                  controller: _tabs,
                  indicatorColor: p.give,
                  labelColor: p.give,
                  tabs: const [
                    Tab(text: 'UZ'),
                    Tab(text: 'RU'),
                    Tab(text: 'EN'),
                  ],
                ),
                SizedBox(
                  height: widget.maxLines == 1 ? 60 : 100,
                  child: TabBarView(
                    controller: _tabs,
                    children: [
                      for (final code in ['uz', 'ru', 'en'])
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: Gap.x3,
                          ),
                          child: TextField(
                            controller: widget.field.controllers[code],
                            maxLines: widget.maxLines,
                            onChanged: (_) => setState(() {}),
                            decoration: const InputDecoration(
                              border: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                              filled: false,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
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
