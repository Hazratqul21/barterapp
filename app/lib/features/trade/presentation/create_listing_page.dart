import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/material_symbols_icons.dart';

import 'dart:convert';
import 'package:http/http.dart' as http;

import '../../../core/network/api_client.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/photo_picker.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/models/models.dart';
import '../../feed/data/listing_repository.dart';
import '../data/trade_repository.dart';

/// Publishing a listing, in four steps.
///
/// It was one long form with seven trilingual fields visible at once, which is
/// where somebody with a spare laptop gives up. Four steps ask one question at
/// a time and never show the finish line as impossibly far away.
///
/// The old form also could not publish at all. It sent `value_minor` as a bare
/// integer where the server wants a `{minor, currency}` object, and omitted
/// `image_alt` and `wants` entirely — so every attempt came back 422. Nobody
/// could post anything.
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
    for (final f in [
      _title,
      _description,
      _category,
      _condition,
      _quantity,
      _wants,
    ]) {
      f.dispose();
    }
    _value.dispose();
    super.dispose();
  }

  int get _valueSom => int.tryParse(_value.text.replaceAll(' ', '')) ?? 0;

  /// Whether the step on screen has everything it needs. Checked per step so
  /// the "next" button is honest rather than failing at the end.
  bool get _stepComplete => switch (_step) {
    0 => _photos.isNotEmpty,
    1 => _tag != null && _title.complete && _description.complete &&
        _category.complete && _condition.complete && _quantity.complete,
    2 => _wants.complete,
    _ => _valueSom > 0,
  };

  Future<void> _addPhoto() async {
    setState(() => _uploading = true);
    try {
      final url = await pickAndUploadPhoto(context, ref);
      if (!mounted) return;
      if (url != null) setState(() => _photos.add(url));
    } catch (e) {
      if (mounted) _complain(errorMessage(context, e));
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  void _complain(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _publish() async {
    setState(() => _busy = true);
    final l = L.of(context);
    try {
      await ref.read(tradeRepositoryProvider).createListing({
        'tag': _tag!.name,
        'title': _title.toJson(),
        'description': _description.toJson(),
        // Alt text was never sent and the server requires it. The title says
        // what the photograph is of, which is what a screen reader needs.
        'image_alt': _title.toJson(),
        'category': _category.toJson(),
        'condition': _condition.toJson(),
        'quantity': _quantity.toJson(),
        'wants_summary': _wants.toJson(),
        'wants': [_wants.toJson()],
        // The structured half of the same wish — this is what the matcher
        // reads. Without it a listing is invisible to `wanted()` forever.
        'desires': [
          {
            'category': _wantTag?.name,
            'will_add_cash': _cashOk,
            'wants_cash': _wantsCash,
          },
        ],
        'photos': _photos,
        'value': {'minor': _valueSom * 100, 'currency': 'UZS'},
        'cash_ok': _cashOk,
      });

      ref.invalidate(feedProvider);
      ref.invalidate(myListingsProvider);
      ref.invalidate(matchesProvider);

      if (!mounted) return;
      _complain(l.createPublished);
      context.pop();
    } on ApiException catch (e) {
      if (!mounted) return;
      // Not a failure — the free quota ran out, and the answer is a plan.
      if (e.statusCode == 402) {
        _showQuotaDialog(e.message);
      } else {
        _complain(e.message);
      }
    } catch (e) {
      if (mounted) _complain(errorMessage(context, e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _showQuotaDialog(String serverMessage) {
    final l = L.of(context);
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Symbols.workspace_premium_rounded, size: 32),
        title: Text(l.createQuotaTitle),
        content: Text(serverMessage.isEmpty ? l.createQuotaBody : serverMessage),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l.createQuotaOk),
          ),
        ],
      ),
    );
  }

  void _showAiMagicDialog() {
    final aiController = TextEditingController();
    bool isLoading = false;
    
    showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            icon: const Icon(Symbols.auto_awesome_rounded, size: 32, color: Colors.purple),
            title: const Text('AI E\'lon Yozuvchi'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Qanday narsani barter qilmoqchisiz? Qisqacha yozing, AI uni mukammal e\'longa aylantiradi.'),
                Gap.h4,
                TextField(
                  controller: aiController,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    hintText: "Masalan: Menda iPhone 13 Pro bor, holati yangi. 200\$ farqi bilan velosipedga almashaman.",
                    border: OutlineInputBorder(),
                  ),
                ),
                if (isLoading)
                  const Padding(
                    padding: EdgeInsets.only(top: Gap.x4),
                    child: CircularProgressIndicator(),
                  ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: isLoading ? null : () => Navigator.pop(context),
                child: const Text('Bekor qilish'),
              ),
              FilledButton.icon(
                icon: const Icon(Symbols.auto_awesome_rounded, size: 18),
                onPressed: isLoading ? null : () async {
                  if (aiController.text.trim().isEmpty) return;
                  
                  setDialogState(() => isLoading = true);
                  
                  try {
                    final response = await http.post(
                      Uri.parse('http://127.0.0.1:8081/api/generateListing'),
                      headers: {'Content-Type': 'application/json'},
                      body: jsonEncode({'data': aiController.text.trim()}),
                    );
                    
                    if (response.statusCode == 200) {
                      final body = jsonDecode(response.body);
                      final result = body['result'] as Map<String, dynamic>;
                      
                      setState(() {
                        if (result['title'] != null) {
                          _title.controllers['uz']!.text = result['title'];
                        }
                        if (result['description'] != null) {
                          _description.controllers['uz']!.text = result['description'];
                        }
                        if (result['suggested_value'] != null) {
                          _value.text = result['suggested_value'].toString();
                        }
                        // Move to Step 2 so user can see it!
                        if (_step == 0 && _photos.isNotEmpty) {
                          _step = 1;
                        } else {
                          _step = 1; // Just jump to 1 so they see the form
                        }
                      });
                      
                      if (context.mounted) {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('AI e\'lon matnini yozib tugatdi!')),
                        );
                      }
                    } else {
                      throw Exception('Failed to generate');
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('AI xatoga yo\'liqdi')),
                      );
                    }
                  } finally {
                    setDialogState(() => isLoading = false);
                  }
                },
                label: const Text('Sehrlash'),
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.purple,
                ),
              ),
            ],
          );
        },
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final p = palette(context);
    final theme = Theme.of(context);
    final last = _step == _steps - 1;

    final titles = [
      l.createStepPhotos,
      l.createStepGive,
      l.createStepTake,
      l.createStepValue,
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(l.createTitle),
        leading: IconButton(
          icon: Icon(context.canPop() ? Icons.arrow_back : Icons.close_rounded),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/home');
            }
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Symbols.auto_awesome_rounded, color: Colors.purple),
            tooltip: 'AI E\'lon yozuvchi',
            onPressed: _showAiMagicDialog,
          ),
          Gap.w2,
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(3),
          child: LinearProgressIndicator(
            value: (_step + 1) / _steps,
            minHeight: 3,
            backgroundColor: p.hair,
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
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(
                      Gap.x5,
                      Gap.x5,
                      Gap.x5,
                      Gap.x6,
                    ),
                    children: [
                      Text(titles[_step], style: theme.textTheme.headlineSmall),
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
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    Gap.x5,
                    Gap.x2,
                    Gap.x5,
                    Gap.x4,
                  ),
                  child: Row(
                    children: [
                      if (_step > 0) ...[
                        OutlinedButton(
                          onPressed: _busy
                              ? null
                              : () => setState(() => _step -= 1),
                          child: Text(l.createBack),
                        ),
                        Gap.w3,
                      ],
                      Expanded(
                        child: FilledButton(
                          onPressed: !_stepComplete || _busy || _uploading
                              ? null
                              : () {
                                  HapticFeedback.lightImpact();
                                  last
                                      ? _publish()
                                      : setState(() => _step += 1);
                                },
                          child: _busy
                              ? const SizedBox(
                                  width: Sizes.iconLg,
                                  height: Sizes.iconLg,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.4,
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

  // ── Step 1 · photos ────────────────────────────────────────────────────

  List<Widget> _photosStep(L l) => [
    Wrap(
      spacing: Gap.x3,
      runSpacing: Gap.x3,
      children: [
        for (final (index, url) in _photos.indexed)
          PhotoWell(
            url: url,
            onTap: null,
            onRemove: () => setState(() => _photos.removeAt(index)),
          ),
        if (_photos.length < 10)
          PhotoWell(url: null, busy: _uploading, onTap: _addPhoto),
      ],
    ),
  ];

  // ── Step 2 · what is offered ───────────────────────────────────────────

  List<Widget> _giveStep(L l) => [
    DropdownButtonFormField<ListingTag>(
      initialValue: _tag,
      isExpanded: true,
      decoration: InputDecoration(labelText: l.createFieldTag),
      items: [
        for (final t in ListingTag.values)
          DropdownMenuItem(value: t, child: Text(categoryLabel(l, t))),
      ],
      onChanged: (v) => setState(() => _tag = v),
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

  // ── Step 3 · what is wanted ────────────────────────────────────────────

  List<Widget> _takeStep(L l) => [
    _TrilingualField(label: l.createFieldWants, field: _wants, maxLines: 2),
    Gap.h4,
    DropdownButtonFormField<ListingTag?>(
      initialValue: _wantTag,
      isExpanded: true,
      decoration: InputDecoration(labelText: l.createWantCategory),
      items: [
        DropdownMenuItem(value: null, child: Text(l.createWantAny)),
        for (final t in ListingTag.values)
          DropdownMenuItem(value: t, child: Text(categoryLabel(l, t))),
      ],
      onChanged: (v) => setState(() => _wantTag = v),
    ),
    Gap.h4,
    SwitchListTile(
      value: _cashOk,
      onChanged: (v) => setState(() {
        _cashOk = v;
        if (v) _wantsCash = false;
      }),
      title: Text(l.createCashAdd),
      contentPadding: EdgeInsets.zero,
    ),
    SwitchListTile(
      value: _wantsCash,
      onChanged: (v) => setState(() {
        _wantsCash = v;
        if (v) _cashOk = false;
      }),
      title: Text(l.createCashWant),
      contentPadding: EdgeInsets.zero,
    ),
  ];

  // ── Step 4 · what it is worth ──────────────────────────────────────────

  List<Widget> _valueStep(L l, ThemeData theme) => [
    TextField(
      controller: _value,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      style: theme.textTheme.headlineSmall,
      onChanged: (_) => setState(() {}),
      decoration: InputDecoration(
        labelText: l.createFieldValue,
        suffixText: 'so‘m',
      ),
    ),
    Gap.h6,
    if (_title.complete && _wants.complete)
      TradeSides(
        giveCaption: l.createGive,
        giveLabel: _title.text('uz'),
        takeCaption: l.createTake,
        takeLabel: _wants.text('uz'),
      ),
  ];
}

/// One field in three languages.
///
/// The server rejects a listing missing any locale, so this holds all three and
/// reports whether it is complete — rather than letting the form reach the end
/// and come back with a 422 nobody can act on.
class _Trilingual {
  final controllers = {
    'uz': TextEditingController(),
    'ru': TextEditingController(),
    'en': TextEditingController(),
  };

  bool get complete =>
      controllers.values.every((c) => c.text.trim().isNotEmpty);

  String text(String locale) => controllers[locale]!.text.trim();

  Map<String, String> toJson() => {
    for (final e in controllers.entries) e.key: e.value.text.trim(),
  };

  void dispose() {
    for (final c in controllers.values) {
      c.dispose();
    }
  }
}

/// UZ / RU / EN tabs over one input, with a tick once all three are filled.
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
    final locales = ['uz', 'ru', 'en'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(widget.label, style: theme.textTheme.titleSmall),
            Gap.w2,
            if (widget.field.complete)
              Icon(
                Symbols.check_circle_rounded,
                size: Sizes.iconSm,
                color: p.give,
                fill: 1,
              ),
          ],
        ),
        Gap.h2,
        Container(
          decoration: BoxDecoration(
            color: p.sunken,
            borderRadius: Radii.rMd,
          ),
          child: Column(
            children: [
              TabBar(
                controller: _tabs,
                dividerColor: Colors.transparent,
                tabs: [
                  for (final code in locales)
                    Tab(
                      height: 40,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(code.toUpperCase()),
                          if (widget
                              .field
                              .controllers[code]!
                              .text
                              .trim()
                              .isNotEmpty) ...[
                            Gap.w1,
                            Icon(
                              Symbols.check_rounded,
                              size: 14,
                              color: p.give,
                            ),
                          ],
                        ],
                      ),
                    ),
                ],
              ),
              SizedBox(
                height: widget.maxLines == 1 ? 60 : 92,
                child: TabBarView(
                  controller: _tabs,
                  children: [
                    for (final code in locales)
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: Gap.x3,
                        ),
                        child: TextField(
                          controller: widget.field.controllers[code],
                          maxLines: widget.maxLines,
                          // Rebuilds the ticks — and the parent's "next"
                          // button, which is disabled until all three are in.
                          onChanged: (_) {
                            setState(() {});
                            context
                                .findAncestorStateOfType<
                                  _CreateListingPageState
                                >()
                                ?.setState(() {});
                          },
                          decoration: const InputDecoration(
                            filled: false,
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(
                              vertical: Gap.x3,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
