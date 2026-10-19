import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/material.dart';

import 'tokens.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Brand Colours
// ─────────────────────────────────────────────────────────────────────────────
abstract final class BrandColors {
  // Brand v3 — taken from the MAB logo (olive tile, champagne-gold letters),
  // one step lighter for the app so it reads as warm rather than heavy.
  static const ink = Color(0xFF1E2112);

  // Payme's own colours, for the "pay with Payme" button only: it hands the
  // person to Payme, so it looks like Payme rather than like a MAB action.
  static const paymeTeal = Color(0xFF33CCCC);
  static const paymeInk = Color(0xFF16313A);
  static const inkSoft = Color(0xFF545A43);
  static const inkFaint = Color(0xFF62674F);

  static const canvas = Color(0xFFF7F4EB);
  static const surface = Color(0xFFFFFDF8);
  static const hair = Color(0xFFE3DECF);

  /// Olive — the logo tile at 600. Primary actions and "I give".
  static const brand500 = Color(0xFF5B6A3A);

  /// The logo tile itself and its deepest shade (splash, dark grounds).
  static const olive700 = Color(0xFF3E4228);
  static const olive900 = Color(0xFF252813);

  /// The lit centre of the logo tile (splash glow).
  static const olive600Glow = Color(0xFF4A5030);

  /// Petrol blue — "I want". Distinct from olive in hue and in lightness.
  static const take500 = Color(0xFF2C6E85);

  /// Champagne gold from the letters. A fill and an accent, never body text
  /// on a light ground (2.2:1); text in gold uses [BarterPalette.money].
  static const gold500 = Color(0xFFC9B07A);
  static const goldLight = Color(0xFFF0DFCB);
  static const goldDeep = Color(0xFF9C8250);

  // Surfaces that used to be hard-coded at their call sites.
  static const glassDark = Color(0xFF1B1E12);
  static const glassDarkRaised = Color(0xFF232717);
  static const mist = Color(0xFFF1F3E7);

  /// Premium is gold, the brand's own reward colour — the old violet sat
  /// outside the palette.
  static const premiumStart = Color(0xFFF0DFCB);
  static const premiumEnd = Color(0xFFC9B07A);
}

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

  final Color give;
  final Color giveSoft;
  final Color giveVivid;
  final Color take;
  final Color takeSoft;
  final Color takeVivid;
  final Color money;
  final Color moneySoft;
  final Color moneyVivid;
  final Color canvas;
  final Color sunken;
  final Color hair;
  final Color inkSoft;
  final Color inkFaint;
  final bool isDark;

  /// The brand gradient — the hero header, the create button, the splash.
  ///
  /// Give moves into take: olive into petrol blue. Reserved for the moments
  /// a trade moves (match found, agreed, done) — a reward, not a background.
  LinearGradient get swapGradient => LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [give, Color.lerp(give, take, 0.45)!, take],
    stops: const [0.0, 0.48, 1.0],
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

  // Contrast is checked in test/design_system_test.dart: every text colour
  // here is ≥ 4.5:1 on canvas, surface and sunken.
  static const light = BarterPalette(
    give: BrandColors.brand500,
    giveSoft: Color(0xFFECEFDF),
    giveVivid: Color(0xFF7A8C4C),
    take: BrandColors.take500,
    takeSoft: Color(0xFFE3EFF3),
    takeVivid: Color(0xFF3A8AA6),
    money: Color(0xFF7D6422),
    moneySoft: Color(0xFFFBF3E2),
    moneyVivid: BrandColors.gold500,
    canvas: BrandColors.canvas,
    sunken: Color(0xFFF1ECE1),
    hair: BrandColors.hair,
    inkSoft: BrandColors.inkSoft,
    inkFaint: BrandColors.inkFaint, // 5.35:1 on canvas
    isDark: false,
  );

  /// Olive-black rather than neon: the old #1DE9B6 glowed at night.
  static const dark = BarterPalette(
    give: Color(0xFFA9B97A),
    giveSoft: Color(0xFF2A3018),
    giveVivid: Color(0xFFC3D296),
    take: Color(0xFF7FB6C9),
    takeSoft: Color(0xFF13262D),
    takeVivid: Color(0xFF9DCADB),
    money: Color(0xFFD9C08A),
    moneySoft: Color(0xFF2A2414),
    moneyVivid: Color(0xFFE6CF9C),
    canvas: Color(0xFF12140C),
    sunken: Color(0xFF1B1E12),
    hair: Color(0xFF2E3320),
    inkSoft: Color(0xFFB9BDA6),
    inkFaint: Color(0xFF8E937C), // 5.85:1 on canvas
    isDark: true,
  );
}

abstract final class M3Motion {
  // ── Curves (M3 Easing) ───────────────────────────────────────────────────
  static const emphasized = Curves.easeInOutCubicEmphasized;
  static const emphasizedDecelerate = Cubic(0.05, 0.7, 0.1, 1.0);
  static const emphasizedAccelerate = Cubic(0.3, 0.0, 0.8, 0.15);
  static const standard = Curves.easeInOutCubicEmphasized;
  static const standardDecelerate = Cubic(0.0, 0.0, 0.0, 1.0);
  static const standardAccelerate = Cubic(0.3, 0.0, 1.0, 1.0);

  // ── Durations (M3 Motion Spec) ───────────────────────────────────────────
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

abstract final class AppTheme {
  static const _displayFamily = 'Manrope';
  static const _bodyFamily = 'Manrope';

  static const _transitions = PageTransitionsTheme(
    builders: {
      // The same push everywhere; see router/transitions.dart.
      TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
      TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
      TargetPlatform.android: CupertinoPageTransitionsBuilder(),
      TargetPlatform.windows: CupertinoPageTransitionsBuilder(),
      TargetPlatform.linux: CupertinoPageTransitionsBuilder(),
      TargetPlatform.fuchsia: CupertinoPageTransitionsBuilder(),
    },
  );

  static ThemeData light() => _build(Brightness.light);

  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final p = isDark ? BarterPalette.dark : BarterPalette.light;
    final textColor = isDark ? const Color(0xFFECEDE2) : BrandColors.ink;

    // ── M3 Color Scheme with Surface Container Logic ──────────────────────
    final scheme =
        ColorScheme.fromSeed(
          seedColor: BrandColors.brand500,
          brightness: brightness,
        ).copyWith(
          primary: p.give,
          primaryContainer: isDark
              ? const Color(0xFF2A3018)
              : const Color(0xFFECEFDF),
          onPrimaryContainer: isDark
              ? const Color(0xFFD5DEB4)
              : const Color(0xFF2F3519),
          onPrimary: isDark ? const Color(0xFF1B1E12) : Colors.white,
          secondary: p.take,
          tertiary: p.money,
          surface: p.canvas,
          // M3 Surface Containers (v1.2 standards)
          surfaceContainerLowest: isDark
              ? const Color(0xFF0D0F08)
              : BrandColors.surface,
          surfaceContainerLow: isDark
              ? const Color(0xFF171A0F)
              : const Color(0xFFFAF7EF),
          surfaceContainer: isDark
              ? const Color(0xFF1B1E12)
              : const Color(0xFFF1ECE1),
          surfaceContainerHigh: isDark
              ? const Color(0xFF222616)
              : const Color(0xFFEAE5D7),
          surfaceContainerHighest: isDark
              ? const Color(0xFF2A2F1C)
              : const Color(0xFFE1DBCB),
          outlineVariant: p.hair,
        );

    final typography = Typography.material2021();
    final baseTextTheme = (isDark ? typography.white : typography.black).apply(
      fontFamily: _bodyFamily,
      bodyColor: textColor,
      displayColor: textColor,
    );

    TextStyle head(
      double size,
      FontWeight weight, {
      double spacing = 0,
      double height = 1.2,
    }) => TextStyle(
      fontFamily: _displayFamily,
      fontSize: size,
      fontWeight: weight,
      letterSpacing: spacing,
      height: height,
      color: textColor,
    );

    final textTheme = baseTextTheme.copyWith(
      displayLarge: head(48, FontWeight.w800, spacing: -1.4, height: 1.05),
      displayMedium: head(40, FontWeight.w800, spacing: -1.0, height: 1.08),
      displaySmall: head(32, FontWeight.w700, spacing: -0.8, height: 1.12),
      headlineLarge: head(28, FontWeight.w700, spacing: -0.6, height: 1.18),
      headlineMedium: head(24, FontWeight.w700, spacing: -0.5, height: 1.22),
      headlineSmall: head(20, FontWeight.w700, spacing: -0.4, height: 1.25),
      titleLarge: head(18, FontWeight.w700, spacing: -0.3, height: 1.3),
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
        // 16, not 15: read outdoors and by older traders (design v3).
        fontSize: 16,
        fontWeight: FontWeight.w400,
        letterSpacing: 0,
        height: 1.5,
      ),
      // Proportional figures in running text; tabular only where numbers
      // stack in columns (prices, counters — see [AppText.price]).
      bodyMedium: baseTextTheme.bodyMedium?.copyWith(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        letterSpacing: 0,
        height: 1.5,
      ),
      bodySmall: baseTextTheme.bodySmall?.copyWith(
        fontSize: 12.5,
        fontWeight: FontWeight.w400,
        letterSpacing: 0,
        height: 1.45,
      ),
      labelLarge: baseTextTheme.labelLarge?.copyWith(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.1,
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
      labelMedium: baseTextTheme.labelMedium?.copyWith(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        letterSpacing: 0,
      ),
      // Nav and tag labels. Wide tracking belongs to SMALL CAPS only; on
      // mixed-case Uzbek/Cyrillic words it just looks loose.
      labelSmall: baseTextTheme.labelSmall?.copyWith(
        fontSize: 11.5,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.1,
      ),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      textTheme: textTheme,
      scaffoldBackgroundColor: Colors.transparent,
      pageTransitionsTheme: _transitions,
      extensions: [p],
      splashFactory: InkSparkle.splashFactory,

      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        scrolledUnderElevation: 0,
        titleTextStyle: textTheme.titleLarge?.copyWith(color: textColor),
      ),

      cardTheme: CardThemeData(
        color: scheme.surfaceContainerLow,
        elevation: 0,
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        shape: RoundedSuperellipseBorder(
          borderRadius: Radii.rLg,
          side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.5)),
        ),
      ),

      // Squircles: the continuous curve iOS uses. A plain rounded rectangle
      // shows a visible "corner join" at large radii; this does not.
      dialogTheme: const DialogThemeData(
        shape: RoundedSuperellipseBorder(borderRadius: Radii.rXl),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        shape: RoundedSuperellipseBorder(borderRadius: Radii.sheetTop),
      ),
      snackBarTheme: const SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedSuperellipseBorder(borderRadius: Radii.rMd),
      ),
      chipTheme: const ChipThemeData(
        shape: RoundedSuperellipseBorder(borderRadius: Radii.rSm),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(64, Sizes.buttonMd),
          shape: const StadiumBorder(),
          textStyle: textTheme.labelLarge,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(48, Sizes.buttonSm),
          textStyle: textTheme.labelLarge,
        ),
      ),

      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: p.give,
        foregroundColor: scheme.onPrimary,
        elevation: 3,
        highlightElevation: 0,
        shape: const CircleBorder(),
      ),

      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: scheme.surfaceContainerLowest,
        indicatorColor: p.giveSoft,
        height: 72,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => textTheme.labelSmall?.copyWith(
            color: states.contains(WidgetState.selected) ? p.give : p.inkSoft,
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            color: states.contains(WidgetState.selected) ? p.give : p.inkSoft,
            size: 26,
          ),
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainer,
        border: OutlineInputBorder(
          borderRadius: Radii.rMd,
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: Radii.rMd,
          borderSide: BorderSide(
            color: p.give.withValues(alpha: 0.5),
            width: 2,
          ),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: Gap.x5,
          vertical: Gap.x4,
        ),
        labelStyle: textTheme.bodyMedium?.copyWith(color: p.inkSoft),
        prefixIconColor: p.inkFaint,
      ),

      filledButtonTheme: FilledButtonThemeData(
        style:
            FilledButton.styleFrom(
              minimumSize: const Size(64, 56),
              shape: const RoundedRectangleBorder(borderRadius: Radii.rFull),
              textStyle: textTheme.titleMedium?.copyWith(color: Colors.white),
            ).copyWith(
              // Clay, lightly: the button stands a millimetre off the page on a
              // soft olive shadow and sinks when pressed. Material's own
              // elevation follows the button's shape exactly; a background
              // builder is laid out inside the padding and showed as a second
              // box within the button.
              elevation: WidgetStateProperty.resolveWith(
                (states) =>
                    states.contains(WidgetState.pressed) ||
                        states.contains(WidgetState.disabled)
                    ? 0
                    : 3,
              ),
              shadowColor: WidgetStatePropertyAll(
                BrandColors.olive900.withValues(alpha: 0.55),
              ),
            ),
      ),
    );
  }
}
