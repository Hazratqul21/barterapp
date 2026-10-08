import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/material.dart';

import 'tokens.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Brand Colours
// ─────────────────────────────────────────────────────────────────────────────
abstract final class BrandColors {
  static const ink = Color(0xFF12211A);
  static const inkSoft = Color(0xFF5A6B62);
  static const inkFaint = Color(0xFF93A099);

  // M3 Tonal Base
  static const canvas = Color(0xFFFAF8F4);
  static const surface = Color(0xFFFFFFFF);
  static const hair = Color(0xFFE7E2D9);

  static const brand500 = Color(
    0xFF007D73,
  ); // Accessible MAB teal for text/CTAs.
  static const take500 = Color(0xFF0D9488); // Secondary Seed (Darker Teal)
  static const gold500 = Color(0xFFF0A82A); // Tertiary Seed

  // Surfaces that used to be hard-coded at their call sites.
  static const glassDark = Color(0xFF141B18);
  static const glassDarkRaised = Color(0xFF1B2420);
  static const mist = Color(0xFFEAF7F7);

  /// Premium badge — the one place a non-brand hue is allowed.
  static const premiumStart = Color(0xFF5D3FD3);
  static const premiumEnd = Color(0xFF9D65FF);
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
  /// Give moves into take: a restrained green-to-blue sweep, not a generic
  /// teal wash. Keeping the end on [take] makes the barter relationship clear
  /// wherever this is used (the hero and the create action).
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

  static const light = BarterPalette(
    give: BrandColors.brand500, // Teal/Feruza
    giveSoft: Color(0xFFE0F2F1), // Light teal
    giveVivid: Color(0xFF1DE9B6),
    take: Color(0xFF1D4FBF),
    takeSoft: Color(0xFFE6EDFC),
    takeVivid: Color(0xFF3B76F0),
    money: Color(0xFFB47714),
    moneySoft: Color(0xFFFDF2DC),
    moneyVivid: Color(0xFFF0A82A),
    canvas: Color(0xFFFAF8F4),
    sunken: Color(0xFFF2EEE7),
    hair: Color(0xFFE7E2D9),
    inkSoft: Color(0xFF5A6B62),
    inkFaint: Color(0xFF62746A), // 4.69:1 on canvas — test/design_system_test
    isDark: false,
  );

  static const dark = BarterPalette(
    give: Color(0xFF1DE9B6), // Bright Teal for Dark mode
    giveSoft: Color(0xFF004D40), // Dark teal
    giveVivid: Color(0xFF64FFDA),
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
    inkFaint: Color(0xFF73837C), // 4.81:1 on canvas
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
      TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
      TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
      TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
    },
  );

  static ThemeData light() => _build(Brightness.light);
  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final p = isDark ? BarterPalette.dark : BarterPalette.light;
    final textColor = isDark ? const Color(0xFFE9F0EB) : BrandColors.ink;

    // ── M3 Color Scheme with Surface Container Logic ──────────────────────
    final scheme =
        ColorScheme.fromSeed(
          seedColor: BrandColors.brand500,
          brightness: brightness,
        ).copyWith(
          primary: p.give,
          primaryContainer: isDark
              ? const Color(0xFF163C35)
              : const Color(0xFFE6F3EF),
          onPrimaryContainer: isDark
              ? const Color(0xFFBCECDF)
              : const Color(0xFF164B40),
          onPrimary: isDark ? const Color(0xFF08251F) : Colors.white,
          secondary: p.take,
          tertiary: p.money,
          surface: p.canvas,
          // M3 Surface Containers (v1.2 standards)
          surfaceContainerLowest: isDark
              ? const Color(0xFF080C0A)
              : const Color(0xFFFFFFFF),
          surfaceContainerLow: isDark
              ? const Color(0xFF111713)
              : const Color(0xFFF7F4EE),
          surfaceContainer: isDark
              ? const Color(0xFF161D19)
              : const Color(0xFFF2EEE7),
          surfaceContainerHigh: isDark
              ? const Color(0xFF1C2420)
              : const Color(0xFFEBE6DD),
          surfaceContainerHighest: isDark
              ? const Color(0xFF232C27)
              : const Color(0xFFE2DCD3),
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
        fontSize: 15,
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
        style: FilledButton.styleFrom(
          minimumSize: const Size(64, 56),
          shape: const RoundedRectangleBorder(borderRadius: Radii.rFull),
          textStyle: textTheme.titleMedium?.copyWith(color: Colors.white),
        ),
      ),
    );
  }
}
