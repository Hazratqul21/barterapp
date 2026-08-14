import 'package:flutter/material.dart';

import '../art/category_marks.dart';

import '../../shared/models/models.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Design tokens
// ─────────────────────────────────────────────────────────────────────────────
// One scale per dimension, used everywhere. The first version of the theme gave
// cards, inputs, buttons and dialogs the same 24px radius and a 60px button
// height, which flattened the hierarchy: nothing looked more important than
// anything else. A person swapping a laptop for a repair reads shape before
// they read words, so shape has to carry rank.

/// Corner radii, smallest to largest. Rank reads off the curve: a chip is
/// tighter than a card, a card is tighter than the sheet it lives in.
abstract final class Radii {
  /// Chips, badges, small tags.
  static const xs = 8.0;

  /// Thumbnails, nested tiles, inline images.
  static const sm = 12.0;

  /// Inputs and buttons — the things a finger lands on.
  static const md = 16.0;

  /// Cards.
  static const lg = 24.0;

  /// Bottom sheets, dialogs, the hero's bottom edge.
  static const xl = 28.0;

  /// Pills and avatars.
  static const full = 999.0;

  static const rXs = BorderRadius.all(Radius.circular(xs));
  static const rSm = BorderRadius.all(Radius.circular(sm));
  static const rMd = BorderRadius.all(Radius.circular(md));
  static const rLg = BorderRadius.all(Radius.circular(lg));
  static const rXl = BorderRadius.all(Radius.circular(xl));
  static const rFull = BorderRadius.all(Radius.circular(full));

  /// Sheets and heroes curve on one edge only.
  static const sheetTop = BorderRadius.vertical(top: Radius.circular(xl));
  static const heroBottom = BorderRadius.vertical(bottom: Radius.circular(xl));
}

/// A 4px grid. Every gap in the app is one of these — no loose numbers.
abstract final class Gap {
  static const x1 = 4.0;
  static const x2 = 8.0;
  static const x3 = 12.0;
  static const x4 = 16.0;
  static const x5 = 20.0;
  static const x6 = 24.0;
  static const x8 = 32.0;
  static const x10 = 40.0;
  static const x14 = 56.0;

  // Vertical spacers, so a Column reads as a list of steps rather than a wall
  // of SizedBox constructors.
  static const h1 = SizedBox(height: x1);
  static const h2 = SizedBox(height: x2);
  static const h3 = SizedBox(height: x3);
  static const h4 = SizedBox(height: x4);
  static const h5 = SizedBox(height: x5);
  static const h6 = SizedBox(height: x6);
  static const h8 = SizedBox(height: x8);
  static const h10 = SizedBox(height: x10);

  static const w1 = SizedBox(width: x1);
  static const w2 = SizedBox(width: x2);
  static const w3 = SizedBox(width: x3);
  static const w4 = SizedBox(width: x4);
  static const w6 = SizedBox(width: x6);

  /// The horizontal margin every screen's content sits inside.
  static const screen = EdgeInsets.symmetric(horizontal: x5);
}

/// Touch target heights. All three clear the 44px minimum for a fingertip;
/// they differ in how much they ask for attention.
abstract final class Sizes {
  /// Secondary, inline. Text buttons and small chips. M3 minimum touch target.
  static const buttonSm = 48.0;

  /// The default: dialog actions, list actions, secondary CTAs.
  static const buttonMd = 48.0;

  /// The one thing on the screen you are meant to press.
  static const buttonLg = 56.0;

  static const iconSm = 16.0;
  static const iconMd = 20.0;
  static const iconLg = 24.0;

  static const avatarSm = 32.0;
  static const avatarMd = 44.0;
  static const avatarLg = 72.0;
  static const avatarXl = 96.0;

  /// Feed card photo.
  static const cardImage = 190.0;

  /// Reading width. Wider than this and a line of Cyrillic gets tiring.
  static const contentMax = 720.0;
}

/// Shadows are soft and green-tinted rather than grey, so a raised card reads
/// as lifted off a warm page instead of stamped onto a cold one.
abstract final class Shadows {
  static const _tint = Color(0xFF0E3A28);

  /// Resting cards.
  static List<BoxShadow> get card => [
    BoxShadow(
      color: _tint.withValues(alpha: 0.05),
      blurRadius: 12,
      offset: const Offset(0, 2),
    ),
  ];

  /// Things that float over content: the search field on the hero, chips.
  static List<BoxShadow> get raised => [
    BoxShadow(
      color: _tint.withValues(alpha: 0.09),
      blurRadius: 20,
      offset: const Offset(0, 6),
    ),
  ];

  /// The create button and bottom sheets.
  static List<BoxShadow> get lifted => [
    BoxShadow(
      color: _tint.withValues(alpha: 0.16),
      blurRadius: 28,
      offset: const Offset(0, 10),
    ),
  ];

  /// Neumorphic extruded (up) shadows for light background.
  /// Requires the surface color to be exactly the same as the background color (e.g. Canvas).
  static List<BoxShadow> neomorphicUp(Color surfaceColor) {
    // For light mode (e.g., BrandColors.canvas = 0xFFFAF8F4)
    // Dark shadow on bottom right, Light shadow on top left
    return [
      BoxShadow(
        color: Colors.black.withValues(alpha: 0.08),
        offset: const Offset(6, 6),
        blurRadius: 12,
      ),
      const BoxShadow(
        color: Colors.white,
        offset: Offset(-6, -6),
        blurRadius: 12,
      ),
    ];
  }

  /// Neumorphic pressed (inset) isn't natively supported by standard BoxShadow.
  /// We will handle inset shadows using standard containers and gradients inside the `NeoButton` widget.
}

// ─────────────────────────────────────────────────────────────────────────────
// Categories
// ─────────────────────────────────────────────────────────────────────────────

/// How a listing category looks: an icon and a colour, not a word.
///
/// The feed used to filter through six grey text chips. Someone who has a spare
/// laptop and wants their flat painted does not scan a row of words — they look
/// for the picture that matches what they have. Colour and icon do that job in
/// every language at once, which also spares three translations per category.
@immutable
class CategoryStyle {
  const CategoryStyle({
    required this.mark,
    required this.color,
    required this.tint,
  });

  /// Which of the six hand-drawn marks this category wears.
  final CategoryMark mark;

  /// Icon and label colour.
  final Color color;

  /// The circle behind the icon.
  final Color tint;

  static const _styles = <ListingTag, CategoryStyle>{
    ListingTag.agri: CategoryStyle(
      mark: CategoryMark.crops,
      color: Color(0xFF15803D),
      tint: Color(0xFFDCFCE7),
    ),
    ListingTag.livestock: CategoryStyle(
      mark: CategoryMark.livestock,
      color: Color(0xFFA16207),
      tint: Color(0xFFFEF3C7),
    ),
    ListingTag.machinery: CategoryStyle(
      mark: CategoryMark.tractor,
      color: Color(0xFFC2410C),
      tint: Color(0xFFFFEDD5),
    ),
    ListingTag.transport: CategoryStyle(
      mark: CategoryMark.truck,
      color: Color(0xFF1D4ED8),
      tint: Color(0xFFDBEAFE),
    ),
    ListingTag.electronics: CategoryStyle(
      mark: CategoryMark.chip,
      color: Color(0xFF6D28D9),
      tint: Color(0xFFEDE9FE),
    ),
    ListingTag.construction: CategoryStyle(
      mark: CategoryMark.bricks,
      color: Color(0xFFB91C1C),
      tint: Color(0xFFFEE2E2),
    ),
  };

  static CategoryStyle of(ListingTag tag) => _styles[tag]!;

  /// The dark-theme tint: the same hue, dropped to a depth that sits on a dark
  /// surface without glowing.
  CategoryStyle get dark => CategoryStyle(
    mark: mark,
    color: Color.lerp(color, Colors.white, 0.45)!,
    tint: Color.lerp(color, const Color(0xFF0B1014), 0.82)!,
  );
}
