import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'tokens.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Brand Colours
// ─────────────────────────────────────────────────────────────────────────────
/// The product's two-sided idea shows up in the palette: green is what you
/// **give**, blue is what you **take**. Gold marks money and premium.
///
/// The `vivid` steps exist for one job — the gradient at the top of the feed
/// runs green into blue, so the header itself is a picture of a swap. Nothing
/// else in the app uses them at full strength.
abstract final class BrandColors {
  // Ink — a green-black, so text sits in the same family as the brand rather
  // than looking like it was pasted in from a different app.
  static const ink = Color(0xFF12211A);
  static const inkSoft = Color(0xFF5A6B62);
  static const inkFaint = Color(0xFF93A099);

  // Surfaces. Warm, not the cold blue-grey the first version used: this is a
  // marketplace for farms and workshops, and it should feel like daylight on
  // paper, not like a banking dashboard.
  static const canvas = Color(0xFFFAF8F4);
  static const surface = Color(0xFFFFFFFF);
  static const sunken = Color(0xFFF2EEE7);
  static const hair = Color(0xFFE7E2D9);

  // Give — green.
  static const brand50 = Color(0xFFE3F3EA);
  static const brand100 = Color(0xFFC6E7D4);
  static const brand300 = Color(0xFF6BC098);
  static const brand500 = Color(0xFF14A86B);
  static const brand600 = Color(0xFF0E7A52);
  static const brand900 = Color(0xFF06341F);

  // Money — gold.
  static const gold50 = Color(0xFFFDF2DC);
  static const gold500 = Color(0xFFF0A82A);
  static const gold600 = Color(0xFFB47714);

  // Take — blue.
  static const take50 = Color(0xFFE6EDFC);
  static const take500 = Color(0xFF3B76F0);
  static const take700 = Color(0xFF1D4FBF);
}

// ─────────────────────────────────────────────────────────────────────────────
// Barter Palette (Theme Extension)
// ─────────────────────────────────────────────────────────────────────────────
/// Colours the Material scheme has no slot for, reached through
/// `palette(context)`.
@immutable
class BarterPalette extends ThemeExtension<BarterPalette> {
  const BarterPalette({
    required this.give,
    required this.giveSoft,
    required this.giveVivid,
    required this.take,
    required this.takeSoft,
    required this.takeVivid,
    required this.money,
    required this.moneySoft,
    required this.moneyVivid,
    required this.canvas,
    required this.sunken,
    required this.hair,
    required this.inkSoft,
    required this.inkFaint,
    required this.isDark,
  });

  /// What is offered.
  final Color give;
  final Color giveSoft;
  final Color giveVivid;

  /// What is wanted.
  final Color take;
  final Color takeSoft;
  final Color takeVivid;

  /// Cash, premium, unread.
  final Color money;
  final Color moneySoft;
  final Color moneyVivid;

  /// The page behind the cards.
  final Color canvas;

  /// A well pressed into the page: search fields, inert tiles.
  final Color sunken;

  final Color hair;
  final Color inkSoft;
  final Color inkFaint;

  /// Widgets that pick an asset or a tint per brightness ask here rather than
  /// reaching for `Theme.of(context).brightness` a second time.
  final bool isDark;

  /// The header gradient: give flowing into take. The whole product in one
  /// shape, which is why it is defined once here and never re-mixed per screen.
  LinearGradient get swapGradient => LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [giveVivid, takeVivid],
  );

  @override
  BarterPalette copyWith({
    Color? give,
    Color? giveSoft,
    Color? giveVivid,
    Color? take,
    Color? takeSoft,
    Color? takeVivid,
    Color? money,
    Color? moneySoft,
    Color? moneyVivid,
    Color? canvas,
    Color? sunken,
    Color? hair,
    Color? inkSoft,
    Color? inkFaint,
    bool? isDark,
  }) {
    return BarterPalette(
      give: give ?? this.give,
      giveSoft: giveSoft ?? this.giveSoft,
      giveVivid: giveVivid ?? this.giveVivid,
      take: take ?? this.take,
      takeSoft: takeSoft ?? this.takeSoft,
      takeVivid: takeVivid ?? this.takeVivid,
      money: money ?? this.money,
      moneySoft: moneySoft ?? this.moneySoft,
      moneyVivid: moneyVivid ?? this.moneyVivid,
      canvas: canvas ?? this.canvas,
      sunken: sunken ?? this.sunken,
      hair: hair ?? this.hair,
      inkSoft: inkSoft ?? this.inkSoft,
      inkFaint: inkFaint ?? this.inkFaint,
      isDark: isDark ?? this.isDark,
    );
  }

  @override
  BarterPalette lerp(BarterPalette? other, double t) {
    if (other == null) return this;
    return BarterPalette(
      give: Color.lerp(give, other.give, t)!,
      giveSoft: Color.lerp(giveSoft, other.giveSoft, t)!,
      giveVivid: Color.lerp(giveVivid, other.giveVivid, t)!,
      take: Color.lerp(take, other.take, t)!,
      takeSoft: Color.lerp(takeSoft, other.takeSoft, t)!,
      takeVivid: Color.lerp(takeVivid, other.takeVivid, t)!,
      money: Color.lerp(money, other.money, t)!,
      moneySoft: Color.lerp(moneySoft, other.moneySoft, t)!,
      moneyVivid: Color.lerp(moneyVivid, other.moneyVivid, t)!,
      canvas: Color.lerp(canvas, other.canvas, t)!,
      sunken: Color.lerp(sunken, other.sunken, t)!,
      hair: Color.lerp(hair, other.hair, t)!,
      inkSoft: Color.lerp(inkSoft, other.inkSoft, t)!,
      inkFaint: Color.lerp(inkFaint, other.inkFaint, t)!,
      isDark: t < 0.5 ? isDark : other.isDark,
    );
  }

  static const light = BarterPalette(
    give: BrandColors.brand600,
    giveSoft: BrandColors.brand50,
    giveVivid: BrandColors.brand500,
    take: BrandColors.take700,
    takeSoft: BrandColors.take50,
    takeVivid: BrandColors.take500,
    money: BrandColors.gold600,
    moneySoft: BrandColors.gold50,
    moneyVivid: BrandColors.gold500,
    canvas: BrandColors.canvas,
    sunken: BrandColors.sunken,
    hair: BrandColors.hair,
    inkSoft: BrandColors.inkSoft,
    inkFaint: BrandColors.inkFaint,
    isDark: false,
  );

  static const dark = BarterPalette(
    give: Color(0xFF4FCB92),
    giveSoft: Color(0xFF11291F),
    giveVivid: Color(0xFF2FB87A),
    take: Color(0xFF8FB0F5),
    takeSoft: Color(0xFF141D33),
    takeVivid: Color(0xFF4C82F2),
    money: Color(0xFFE0B45A),
    moneySoft: Color(0xFF261E0E),
    moneyVivid: Color(0xFFD69A2C),
    canvas: Color(0xFF0B100D),
    sunken: Color(0xFF161D19),
    hair: Color(0xFF283330),
    inkSoft: Color(0xFF9CACA4),
    inkFaint: Color(0xFF6C7C75),
    isDark: true,
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// M3 Easing Curves & Durations
// ─────────────────────────────────────────────────────────────────────────────
/// Material 3 standard motion tokens.
abstract final class M3Motion {
  /// M3 "emphasized" easing (standard for most transitions).
  static const emphasized = Curves.easeInOutCubicEmphasized;

  /// M3 "emphasized decelerate" for elements entering the screen.
  static const emphasizedDecelerate = Cubic(0.05, 0.7, 0.1, 1.0);

  /// M3 "emphasized accelerate" for elements leaving the screen.
  static const emphasizedAccelerate = Cubic(0.3, 0.0, 0.8, 0.15);

  /// M3 "standard" easing for simple property changes.
  static const standard = Curves.easeInOutCubicEmphasized;

  /// Duration tokens
  static const short1 = Duration(milliseconds: 50);
  static const short2 = Duration(milliseconds: 100);
  static const short3 = Duration(milliseconds: 150);
  static const short4 = Duration(milliseconds: 200);
  static const medium1 = Duration(milliseconds: 250);
  static const medium2 = Duration(milliseconds: 300);
  static const medium3 = Duration(milliseconds: 350);
  static const medium4 = Duration(milliseconds: 400);
  static const long1 = Duration(milliseconds: 450);
  static const long2 = Duration(milliseconds: 500);
  static const long3 = Duration(milliseconds: 550);
  static const long4 = Duration(milliseconds: 600);
  static const extraLong1 = Duration(milliseconds: 700);
}

// ─────────────────────────────────────────────────────────────────────────────
// App Theme Builder
// ─────────────────────────────────────────────────────────────────────────────
abstract final class AppTheme {
  /// iOS gets its edge-swipe-back transition; Android and web get Material's.
  static const _transitions = PageTransitionsTheme(
    builders: {
      TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
      TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
      TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
    },
  );

  static ThemeData light() => _build(Brightness.light);
  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final palette = isDark ? BarterPalette.dark : BarterPalette.light;
    final textColor = isDark ? const Color(0xFFE9F0EB) : BrandColors.ink;

    // ── Color Scheme ──────────────────────────────────────────────────────
    final scheme =
        ColorScheme.fromSeed(
          seedColor: BrandColors.brand500,
          brightness: brightness,
        ).copyWith(
          primary: palette.give,
          secondary: palette.take,
          tertiary: palette.money,
          // The page is the canvas; cards are white on top of it. Reversing
          // these is what made every screen read as one flat sheet before.
          surface: palette.canvas,
          surfaceContainerLowest: isDark
              ? const Color(0xFF080C0A)
              : const Color(0xFFFFFFFF),
          surfaceContainerLow: isDark
              ? const Color(0xFF111713)
              : const Color(0xFFFFFFFF),
          surfaceContainer: isDark
              ? const Color(0xFF161D19)
              : const Color(0xFFF7F4EE),
          surfaceContainerHigh: isDark
              ? const Color(0xFF1C2420)
              : const Color(0xFFF2EEE7),
          surfaceContainerHighest: isDark
              ? const Color(0xFF232C27)
              : const Color(0xFFEBE6DD),
          outlineVariant: palette.hair,
        );

    // ── Typography ────────────────────────────────────────────────────────
    // Plus Jakarta Sans carries Cyrillic and Latin at the same weight, which
    // matters when the same screen is read in Uzbek and Russian.
    final baseTextTheme = GoogleFonts.plusJakartaSansTextTheme().apply(
      bodyColor: textColor,
      displayColor: textColor,
    );

    // A tighter scale than the default. The old one jumped from 22 to 28 to 32
    // with nothing usable in between, so screens borrowed `titleLarge` for
    // section headers and everything ended up shouting.
    final textTheme = baseTextTheme.copyWith(
      displayLarge: baseTextTheme.displayLarge?.copyWith(
        fontSize: 48,
        fontWeight: FontWeight.w700,
        letterSpacing: -1.2,
        height: 1.08,
      ),
      displayMedium: baseTextTheme.displayMedium?.copyWith(
        fontSize: 40,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.8,
        height: 1.1,
      ),
      displaySmall: baseTextTheme.displaySmall?.copyWith(
        fontSize: 32,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.6,
        height: 1.15,
      ),
      headlineLarge: baseTextTheme.headlineLarge?.copyWith(
        fontSize: 28,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.5,
        height: 1.2,
      ),
      headlineMedium: baseTextTheme.headlineMedium?.copyWith(
        fontSize: 24,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.4,
        height: 1.22,
      ),
      headlineSmall: baseTextTheme.headlineSmall?.copyWith(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.3,
        height: 1.25,
      ),
      // Section headers live here — the most-used style in the app.
      titleLarge: baseTextTheme.titleLarge?.copyWith(
        fontSize: 18,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.3,
        height: 1.3,
      ),
      titleMedium: baseTextTheme.titleMedium?.copyWith(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.1,
        height: 1.35,
      ),
      titleSmall: baseTextTheme.titleSmall?.copyWith(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        letterSpacing: 0,
        height: 1.4,
      ),
      bodyLarge: baseTextTheme.bodyLarge?.copyWith(
        fontSize: 15,
        fontWeight: FontWeight.w400,
        letterSpacing: 0,
        height: 1.5,
      ),
      bodyMedium: baseTextTheme.bodyMedium?.copyWith(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        letterSpacing: 0.05,
        height: 1.5,
      ),
      bodySmall: baseTextTheme.bodySmall?.copyWith(
        fontSize: 12.5,
        fontWeight: FontWeight.w400,
        letterSpacing: 0.1,
        height: 1.45,
      ),
      labelLarge: baseTextTheme.labelLarge?.copyWith(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.1,
      ),
      labelMedium: baseTextTheme.labelMedium?.copyWith(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.2,
      ),
      // Eyebrow labels: "BERAMAN", "OLAMAN", "ISHONCH DARAJASI".
      labelSmall: baseTextTheme.labelSmall?.copyWith(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.8,
      ),
    );

    // ── Base ThemeData ─────────────────────────────────────────────────────
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      textTheme: textTheme,
      scaffoldBackgroundColor: palette.canvas,
      pageTransitionsTheme: _transitions,
      extensions: [palette],
      splashFactory: InkSparkle.splashFactory,
    );

    // ── Component Themes ──────────────────────────────────────────────────
    return base.copyWith(
      appBarTheme: AppBarTheme(
        backgroundColor: palette.canvas,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleSpacing: Gap.x5,
        titleTextStyle: textTheme.titleLarge?.copyWith(color: textColor),
        iconTheme: IconThemeData(color: textColor, size: Sizes.iconLg),
      ),

      // Cards are white on a warm canvas, with a hairline instead of a shadow.
      // Elevation is reserved for things that genuinely float.
      cardTheme: CardThemeData(
        color: scheme.surfaceContainerLow,
        elevation: 0,
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: Radii.rLg,
          side: BorderSide(color: palette.hair),
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: palette.sunken,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: Gap.x4,
          vertical: Gap.x4,
        ),
        border: const OutlineInputBorder(
          borderRadius: Radii.rMd,
          borderSide: BorderSide.none,
        ),
        enabledBorder: const OutlineInputBorder(
          borderRadius: Radii.rMd,
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: Radii.rMd,
          borderSide: BorderSide(color: palette.give, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: Radii.rMd,
          borderSide: BorderSide(color: scheme.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: Radii.rMd,
          borderSide: BorderSide(color: scheme.error, width: 2),
        ),
        labelStyle: textTheme.bodyLarge?.copyWith(color: palette.inkSoft),
        hintStyle: textTheme.bodyLarge?.copyWith(color: palette.inkFaint),
        floatingLabelStyle: textTheme.titleSmall?.copyWith(color: palette.give),
        prefixIconColor: palette.inkFaint,
        suffixIconColor: palette.inkFaint,
      ),

      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(Sizes.buttonLg),
          padding: const EdgeInsets.symmetric(horizontal: Gap.x6),
          shape: const RoundedRectangleBorder(borderRadius: Radii.rMd),
          textStyle: textTheme.titleMedium,
          elevation: 0,
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(64, Sizes.buttonMd),
          padding: const EdgeInsets.symmetric(horizontal: Gap.x5),
          shape: const RoundedRectangleBorder(borderRadius: Radii.rMd),
          side: BorderSide(color: palette.hair, width: 1.5),
          foregroundColor: textColor,
          textStyle: textTheme.titleSmall,
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(48, Sizes.buttonSm),
          padding: const EdgeInsets.symmetric(horizontal: Gap.x3),
          shape: const RoundedRectangleBorder(borderRadius: Radii.rSm),
          textStyle: textTheme.titleSmall,
        ),
      ),

      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          shape: const RoundedRectangleBorder(borderRadius: Radii.rSm),
          foregroundColor: textColor,
        ),
      ),

      // The create button is the loudest thing in the app on purpose: posting
      // what you have spare is the one action the whole product depends on.
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: palette.give,
        foregroundColor: Colors.white,
        elevation: 6,
        highlightElevation: 2,
        extendedTextStyle: textTheme.titleMedium?.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.w700,
        ),
        shape: const RoundedRectangleBorder(borderRadius: Radii.rMd),
      ),

      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: scheme.surfaceContainerLowest,
        indicatorColor: palette.giveSoft,
        elevation: 0,
        height: 68,
        surfaceTintColor: Colors.transparent,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => textTheme.labelMedium?.copyWith(
            fontSize: 11,
            color: states.contains(WidgetState.selected)
                ? palette.give
                : palette.inkFaint,
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            color: states.contains(WidgetState.selected)
                ? palette.give
                : palette.inkFaint,
            size: Sizes.iconLg,
          ),
        ),
      ),

      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: scheme.surfaceContainerLowest,
        indicatorColor: palette.giveSoft,
        selectedIconTheme: IconThemeData(color: palette.give, size: Sizes.iconLg),
        unselectedIconTheme: IconThemeData(
          color: palette.inkFaint,
          size: Sizes.iconLg,
        ),
        selectedLabelTextStyle: textTheme.labelMedium?.copyWith(
          color: palette.give,
        ),
        unselectedLabelTextStyle: textTheme.labelMedium?.copyWith(
          color: palette.inkFaint,
        ),
      ),

      // Filter chips are pills — softer than the old 12px rectangles, and they
      // read as "tap me" rather than as a table cell.
      chipTheme: ChipThemeData(
        backgroundColor: scheme.surfaceContainerLowest,
        selectedColor: palette.give,
        checkmarkColor: Colors.white,
        labelStyle: textTheme.labelLarge,
        secondaryLabelStyle: textTheme.labelLarge?.copyWith(
          color: Colors.white,
        ),
        side: BorderSide(color: palette.hair),
        shape: const RoundedRectangleBorder(borderRadius: Radii.rFull),
        padding: const EdgeInsets.symmetric(
          horizontal: Gap.x3,
          vertical: Gap.x2,
        ),
      ),

      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: scheme.surfaceContainerLowest,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: const RoundedRectangleBorder(borderRadius: Radii.sheetTop),
        showDragHandle: true,
        dragHandleColor: palette.hair,
        dragHandleSize: const Size(40, 4),
      ),

      dialogTheme: DialogThemeData(
        backgroundColor: scheme.surfaceContainerLowest,
        elevation: 0,
        shape: const RoundedRectangleBorder(borderRadius: Radii.rXl),
        titleTextStyle: textTheme.headlineSmall?.copyWith(color: textColor),
        contentTextStyle: textTheme.bodyLarge?.copyWith(color: palette.inkSoft),
      ),

      snackBarTheme: SnackBarThemeData(
        backgroundColor: scheme.inverseSurface,
        contentTextStyle: textTheme.bodyMedium?.copyWith(
          color: scheme.onInverseSurface,
        ),
        actionTextColor: palette.giveVivid,
        shape: const RoundedRectangleBorder(borderRadius: Radii.rSm),
        behavior: SnackBarBehavior.floating,
        insetPadding: const EdgeInsets.all(Gap.x4),
      ),

      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: scheme.inverseSurface,
          borderRadius: Radii.rXs,
        ),
        textStyle: textTheme.bodySmall?.copyWith(
          color: scheme.onInverseSurface,
        ),
      ),

      listTileTheme: ListTileThemeData(
        contentPadding: const EdgeInsets.symmetric(horizontal: Gap.x4),
        shape: const RoundedRectangleBorder(borderRadius: Radii.rSm),
        iconColor: palette.inkSoft,
        titleTextStyle: textTheme.bodyLarge?.copyWith(
          color: textColor,
          fontWeight: FontWeight.w500,
        ),
        subtitleTextStyle: textTheme.bodyMedium?.copyWith(color: palette.inkSoft),
      ),

      dividerTheme: DividerThemeData(
        color: palette.hair,
        space: 1,
        thickness: 1,
      ),

      popupMenuTheme: PopupMenuThemeData(
        color: scheme.surfaceContainerLowest,
        elevation: 3,
        shape: const RoundedRectangleBorder(borderRadius: Radii.rSm),
        textStyle: textTheme.bodyMedium,
      ),

      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? Colors.white
              : scheme.outline,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? palette.give
              : palette.sunken,
        ),
        trackOutlineColor: WidgetStatePropertyAll(palette.hair),
      ),

      tabBarTheme: TabBarThemeData(
        labelStyle: textTheme.titleSmall,
        unselectedLabelStyle: textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.w500,
        ),
        indicatorColor: palette.give,
        indicatorSize: TabBarIndicatorSize.tab,
        labelColor: palette.give,
        unselectedLabelColor: palette.inkFaint,
        dividerColor: palette.hair,
      ),

      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: palette.give,
        linearTrackColor: palette.sunken,
        circularTrackColor: palette.sunken,
      ),

      segmentedButtonTheme: SegmentedButtonThemeData(
        style: SegmentedButton.styleFrom(
          selectedBackgroundColor: palette.give,
          selectedForegroundColor: Colors.white,
          foregroundColor: palette.inkSoft,
          side: BorderSide(color: palette.hair),
          shape: const RoundedRectangleBorder(borderRadius: Radii.rSm),
          textStyle: textTheme.labelLarge,
        ),
      ),
    );
  }
}
