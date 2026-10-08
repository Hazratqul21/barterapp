import 'package:flutter/material.dart';

import '../../shared/models/models.dart';
import '../art/category_marks.dart';
import '../theme/haptics.dart';
import '../theme/motion.dart';
import '../theme/tokens.dart';
import '../widgets/common.dart' show TraderAvatar, TrustLine, palette;

/// Every design token on one screen: colours, type, shapes, motion.
///
/// Debug builds only (`/dev/design`). It is the reference a designer reviews
/// and the surface the golden tests photograph, so a token change shows up
/// here before it surprises anyone on a real screen. Copy is not localised on
/// purpose — this is a tool, not product.
class DesignCatalogPage extends StatelessWidget {
  const DesignCatalogPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(title: const Text('Dizayn tizimi v2')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(Gap.x5, Gap.x2, Gap.x5, Gap.x10),
        children: const [
          _Section('Rang', _Colors()),
          _Section('Tipografiya', _Type()),
          _Section('Narx', _Prices()),
          _Section('Tugmalar', _Buttons()),
          _Section('Kartalar va kategoriyalar', _Cards()),
          _Section('Ishonch', _Trust()),
          _Section('Harakat (spring)', _MotionDemo()),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section(this.title, this.child);

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: Gap.x6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          Gap.h3,
          child,
        ],
      ),
    );
  }
}

class _Colors extends StatelessWidget {
  const _Colors();

  @override
  Widget build(BuildContext context) {
    final p = palette(context);
    final s = Theme.of(context).colorScheme;
    final swatches = <(String, Color, Color)>[
      ('give', p.give, s.onPrimary),
      ('giveSoft', p.giveSoft, p.give),
      ('take', p.take, Colors.white),
      ('takeSoft', p.takeSoft, p.take),
      ('money', p.money, Colors.white),
      ('moneySoft', p.moneySoft, p.money),
      ('canvas', p.canvas, p.inkSoft),
      ('sunken', p.sunken, p.inkSoft),
      ('container', s.surfaceContainer, p.inkSoft),
      ('containerHigh', s.surfaceContainerHigh, p.inkSoft),
    ];
    return Wrap(
      spacing: Gap.x2,
      runSpacing: Gap.x2,
      children: [
        for (final (name, bg, fg) in swatches)
          Container(
            width: 96,
            height: 64,
            padding: const EdgeInsets.all(Gap.x2),
            alignment: Alignment.bottomLeft,
            decoration: ShapeDecoration(
              color: bg,
              shape: RoundedSuperellipseBorder(
                borderRadius: Radii.rSm,
                side: BorderSide(color: p.hair),
              ),
            ),
            child: Text(
              name,
              style: Theme.of(
                context,
              ).textTheme.labelMedium?.copyWith(color: fg),
            ),
          ),
        Container(
          width: 200,
          height: 64,
          decoration: ShapeDecoration(
            gradient: p.swapGradient,
            shape: const RoundedSuperellipseBorder(borderRadius: Radii.rSm),
          ),
          alignment: Alignment.center,
          child: Text(
            'swapGradient — faqat almashuv lahzasi',
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.labelMedium?.copyWith(color: Colors.white),
          ),
        ),
      ],
    );
  }
}

class _Type extends StatelessWidget {
  const _Type();

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final rows = <(String, TextStyle?)>[
      ('headlineLarge', t.headlineLarge),
      ('headlineSmall', t.headlineSmall),
      ('titleLarge', t.titleLarge),
      ('titleMedium', t.titleMedium),
      ('bodyLarge', t.bodyLarge),
      ('bodyMedium', t.bodyMedium),
      ('labelLarge', t.labelLarge),
      ('labelSmall', t.labelSmall),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final (name, style) in rows)
          Padding(
            padding: const EdgeInsets.only(bottom: Gap.x2),
            child: Text(
              '$name · Noutbukni ta‘mirga almashaman · Ноутбук',
              style: style,
            ),
          ),
      ],
    );
  }
}

class _Prices extends StatelessWidget {
  const _Prices();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final amount in ['5 000 000', '12 450 000', '890 000'])
          Text.rich(
            TextSpan(
              children: [
                TextSpan(text: amount, style: AppText.price(context)),
                TextSpan(text: ' so‘m', style: AppText.currency(context)),
              ],
            ),
          ),
      ],
    );
  }
}

class _Buttons extends StatelessWidget {
  const _Buttons();

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: Gap.x2,
      runSpacing: Gap.x2,
      children: [
        FilledButton(onPressed: () {}, child: const Text('Taklif berish')),
        FilledButton.tonal(onPressed: () {}, child: const Text('Saqlash')),
        OutlinedButton(onPressed: () {}, child: const Text('Orqaga')),
        TextButton(onPressed: () {}, child: const Text('Bekor qilish')),
        const FilledButton(onPressed: null, child: Text('O‘chirilgan')),
      ],
    );
  }
}

class _Cards extends StatelessWidget {
  const _Cards();

  @override
  Widget build(BuildContext context) {
    final p = palette(context);
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(Gap.x4),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Karta — superellipse',
                        style: theme.textTheme.titleMedium,
                      ),
                      Gap.h1,
                      Text(
                        'Radius 20, ingichka chegara, soya yo‘q.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: p.inkSoft,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        Gap.h3,
        Wrap(
          spacing: Gap.x2,
          runSpacing: Gap.x2,
          children: [
            for (final tag in ListingTag.values)
              Builder(
                builder: (context) {
                  final base = CategoryStyle.of(tag);
                  final style = p.isDark ? base.dark : base;
                  return Container(
                    width: 52,
                    height: 52,
                    decoration: ShapeDecoration(
                      color: style.tint,
                      shape: const RoundedSuperellipseBorder(
                        borderRadius: Radii.rMd,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: CategoryMarkIcon(
                      mark: style.mark,
                      color: style.color,
                      size: 28,
                    ),
                  );
                },
              ),
          ],
        ),
      ],
    );
  }
}

class _Trust extends StatelessWidget {
  const _Trust();

  static const _traders = [
    TraderBrief(
      id: '1',
      name: 'Aziz Karimov',
      isVerified: true,
      rating: 4.8,
      deals: 12,
    ),
    TraderBrief(id: '2', name: 'Bekzod', isVerified: false),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final t in _traders)
          Padding(
            padding: const EdgeInsets.only(bottom: Gap.x3),
            child: Row(
              children: [
                TraderAvatar(
                  url: null,
                  name: t.name,
                  size: 48,
                  verified: t.isVerified,
                ),
                Gap.w3,
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        t.name,
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      Gap.h1,
                      TrustLine(trader: t),
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

class _MotionDemo extends StatefulWidget {
  const _MotionDemo();

  @override
  State<_MotionDemo> createState() => _MotionDemoState();
}

class _MotionDemoState extends State<_MotionDemo> {
  bool _end = false;

  @override
  Widget build(BuildContext context) {
    final p = palette(context);
    final specs = <(String, MotionSpec)>[
      ('fast', Motion.fast),
      ('standard', Motion.standard),
      ('slow', Motion.slow),
      ('bouncy', Motion.bouncy),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final (name, spec) in specs)
          Padding(
            padding: const EdgeInsets.only(bottom: Gap.x2),
            child: Row(
              children: [
                SizedBox(
                  width: 80,
                  child: Text(
                    name,
                    style: Theme.of(context).textTheme.labelMedium,
                  ),
                ),
                Expanded(
                  child: AnimatedAlign(
                    duration: spec.durationOf(context),
                    curve: spec.curve,
                    alignment: _end
                        ? Alignment.centerRight
                        : Alignment.centerLeft,
                    child: Container(
                      width: 28,
                      height: 28,
                      decoration: ShapeDecoration(
                        color: name == 'bouncy' ? p.take : p.give,
                        shape: const RoundedSuperellipseBorder(
                          borderRadius: Radii.rXs,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        Gap.h2,
        OutlinedButton(
          onPressed: () {
            Haptics.selection();
            setState(() => _end = !_end);
          },
          child: const Text('Harakatlantirish'),
        ),
      ],
    );
  }
}
