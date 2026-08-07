import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Brand Colours
// ─────────────────────────────────────────────────────────────────────────────
/// The product's two-sided idea shows up in the palette: green is what you
/// **give**, blue is what you **take**. Gold marks money and premium.
abstract final class BrandColors {
  static const ink = Color(0xFF0D1A15);
  static const inkSoft = Color(0xFF5B6B64);
  static const inkFaint = Color(0xFF8D9A94);
  static const ground = Color(0xFFF1F4F2);
  static const surface = Color(0xFFFFFFFF);
  static const hair = Color(0xFFE3E8E5);

  static const brand50 = Color(0xFFEEF6F1);
  static const brand100 = Color(0xFFD7EBE0);
  static const brand300 = Color(0xFF7DB79B);
  static const brand500 = Color(0xFF127A52);
  static const brand600 = Color(0xFF0E6444);
  static const brand900 = Color(0xFF06291D);

  static const gold50 = Color(0xFFFDF6E6);
  static const gold500 = Color(0xFFC08A1E);
  static const gold600 = Color(0xFF9A6D13);

  static const take50 = Color(0xFFEEF2FB);
  static const take500 = Color(0xFF2B5BD7);
  static const take700 = Color(0xFF1D3F9C);
}

// ─────────────────────────────────────────────────────────────────────────────
// Barter Palette (Theme Extension)
// ─────────────────────────────────────────────────────────────────────────────
/// Colours the Material scheme has no slot for, reached through
/// `Theme.of(context).extension<BarterPalette>()!`.
@immutable
class BarterPalette extends ThemeExtension<BarterPalette> {
  const BarterPalette({
    required this.give,
    required this.giveSoft,
    required this.take,
    required this.takeSoft,
    required this.money,
    required this.moneySoft,
    required this.hair,
    required this.inkSoft,
    required this.inkFaint,
  });

  final Color give;
  final Color giveSoft;
  final Color take;
  final Color takeSoft;
  final Color money;
  final Color moneySoft;
  final Color hair;
  final Color inkSoft;
  final Color inkFaint;

  @override
  BarterPalette copyWith({
    Color? give,
    Color? giveSoft,
    Color? take,
    Color? takeSoft,
    Color? money,
    Color? moneySoft,
    Color? hair,
    Color? inkSoft,
    Color? inkFaint,
  }) {
    return BarterPalette(
      give: give ?? this.give,
      giveSoft: giveSoft ?? this.giveSoft,
      take: take ?? this.take,
      takeSoft: takeSoft ?? this.takeSoft,
      money: money ?? this.money,
      moneySoft: moneySoft ?? this.moneySoft,
      hair: hair ?? this.hair,
      inkSoft: inkSoft ?? this.inkSoft,
      inkFaint: inkFaint ?? this.inkFaint,
    );
  }

  @override
  BarterPalette lerp(BarterPalette? other, double t) {
    if (other == null) return this;
    return BarterPalette(
      give: Color.lerp(give, other.give, t)!,
      giveSoft: Color.lerp(giveSoft, other.giveSoft, t)!,
      take: Color.lerp(take, other.take, t)!,
      takeSoft: Color.lerp(takeSoft, other.takeSoft, t)!,
      money: Color.lerp(money, other.money, t)!,
      moneySoft: Color.lerp(moneySoft, other.moneySoft, t)!,
      hair: Color.lerp(hair, other.hair, t)!,
      inkSoft: Color.lerp(inkSoft, other.inkSoft, t)!,
      inkFaint: Color.lerp(inkFaint, other.inkFaint, t)!,
    );
  }

  static const light = BarterPalette(
    give: BrandColors.brand600,
    giveSoft: BrandColors.brand50,
    take: BrandColors.take700,
    takeSoft: BrandColors.take50,
    money: BrandColors.gold600,
    moneySoft: BrandColors.gold50,
    hair: BrandColors.hair,
    inkSoft: BrandColors.inkSoft,
    inkFaint: BrandColors.inkFaint,
  );

  static const dark = BarterPalette(
    give: Color(0xFF57B98C),
    giveSoft: Color(0xFF12241C),
    take: Color(0xFF8AA6EE),
    takeSoft: Color(0xFF151C30),
    money: Color(0xFFD5A743),
    moneySoft: Color(0xFF241D0D),
    hair: Color(0xFF26332D),
    inkSoft: Color(0xFF9DADA5),
    inkFaint: Color(0xFF6D7D76),
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
    final textColor = isDark ? const Color(0xFFE8EFEA) : BrandColors.ink;

    // ── Color Scheme ──────────────────────────────────────────────────────
    final scheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF00C853), // Emerald Green
      brightness: brightness,
    ).copyWith(
      primary: palette.give,
      secondary: palette.take,
      tertiary: palette.money,
      surface: isDark ? const Color(0xFF0B1014) : const Color(0xFFFDFDFD),
      surfaceContainerLowest:
          isDark ? const Color(0xFF070B0E) : const Color(0xFFFFFFFF),
      surfaceContainerLow:
          isDark ? const Color(0xFF10161A) : const Color(0xFFF7F8FA),
      surfaceContainer:
          isDark ? const Color(0xFF151D22) : const Color(0xFFF1F3F6),
      surfaceContainerHigh:
          isDark ? const Color(0xFF1B242B) : const Color(0xFFE9ECF1),
      surfaceContainerHighest:
          isDark ? const Color(0xFF222C34) : const Color(0xFFE2E6EC),
    );

    // ── Typography ────────────────────────────────────────────────────────
    final baseTextTheme =
        GoogleFonts.plusJakartaSansTextTheme().apply(
      bodyColor: textColor,
      displayColor: textColor,
    );
    // M3 type scale refinements
    final textTheme = baseTextTheme.copyWith(
      displayLarge: baseTextTheme.displayLarge?.copyWith(
        fontSize: 64, fontWeight: FontWeight.w300, letterSpacing: -1.0,
      ),
      displayMedium: baseTextTheme.displayMedium?.copyWith(
        fontSize: 52, fontWeight: FontWeight.w400, letterSpacing: -0.5,
      ),
      displaySmall: baseTextTheme.displaySmall?.copyWith(
        fontSize: 44, fontWeight: FontWeight.w400, letterSpacing: -0.5,
      ),
      headlineLarge: baseTextTheme.headlineLarge?.copyWith(
        fontSize: 36, fontWeight: FontWeight.w600, letterSpacing: -0.5,
      ),
      headlineMedium: baseTextTheme.headlineMedium?.copyWith(
        fontSize: 32, fontWeight: FontWeight.w600, letterSpacing: -0.25,
      ),
      headlineSmall: baseTextTheme.headlineSmall?.copyWith(
        fontSize: 28, fontWeight: FontWeight.w600,
      ),
      titleLarge: baseTextTheme.titleLarge?.copyWith(
        fontSize: 22, fontWeight: FontWeight.w700, letterSpacing: -0.2,
      ),
      titleMedium: baseTextTheme.titleMedium?.copyWith(
        fontSize: 16, fontWeight: FontWeight.w600, letterSpacing: 0.15,
      ),
      titleSmall: baseTextTheme.titleSmall?.copyWith(
        fontSize: 14, fontWeight: FontWeight.w600, letterSpacing: 0.1,
      ),
      bodyLarge: baseTextTheme.bodyLarge?.copyWith(
        fontSize: 16, fontWeight: FontWeight.w400, letterSpacing: 0.15,
      ),
      bodyMedium: baseTextTheme.bodyMedium?.copyWith(
        fontSize: 14, fontWeight: FontWeight.w400, letterSpacing: 0.25,
      ),
      bodySmall: baseTextTheme.bodySmall?.copyWith(
        fontSize: 12, fontWeight: FontWeight.w400, letterSpacing: 0.4,
      ),
      labelLarge: baseTextTheme.labelLarge?.copyWith(
        fontSize: 14, fontWeight: FontWeight.w600, letterSpacing: 0.1,
      ),
      labelMedium: baseTextTheme.labelMedium?.copyWith(
        fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 0.5,
      ),
      labelSmall: baseTextTheme.labelSmall?.copyWith(
        fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.5,
      ),
    );

    // ── Base ThemeData ─────────────────────────────────────────────────────
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      textTheme: textTheme,
      scaffoldBackgroundColor: scheme.surfaceContainerLowest,
      pageTransitionsTheme: _transitions,
      extensions: [palette],
      splashFactory: InkSparkle.splashFactory, // M3 ripple
    );

    // ── Component Themes ──────────────────────────────────────────────────
    return base.copyWith(
      // AppBar
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 1,
        centerTitle: false,
        titleTextStyle: textTheme.titleLarge?.copyWith(
          fontSize: 20,
          color: textColor,
        ),
        iconTheme: IconThemeData(color: scheme.onSurface, size: 24),
      ),
      // Cards — M3 Filled style with subtle outline
      cardTheme: CardThemeData(
        color: scheme.surfaceContainerLow,
        elevation: 0,
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(
            color: scheme.outlineVariant.withValues(alpha: 0.3),
          ),
        ),
      ),
      // Input fields — M3 Filled style
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerHighest.withValues(alpha: 0.4),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(24),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(24),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(24),
          borderSide: BorderSide(color: palette.give, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(24),
          borderSide: BorderSide(color: scheme.error, width: 1),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(24),
          borderSide: BorderSide(color: scheme.error, width: 2),
        ),
        labelStyle: textTheme.bodyLarge?.copyWith(color: palette.inkSoft),
        hintStyle: textTheme.bodyLarge?.copyWith(color: palette.inkFaint),
        floatingLabelStyle:
            textTheme.titleSmall?.copyWith(color: palette.give),
      ),
      // Filled Buttons — M3 rounded rectangle
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(60),
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 18),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          textStyle: textTheme.titleMedium,
          elevation: 0,
        ),
      ),
      // Outlined Buttons
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(64, 52),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          side: BorderSide(color: scheme.outline.withValues(alpha: 0.5), width: 1.5),
          textStyle: textTheme.titleMedium,
        ),
      ),
      // Text Buttons
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          textStyle: textTheme.titleMedium,
        ),
      ),
      // IconButton
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
      // FAB — M3 large shape
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: scheme.primaryContainer,
        foregroundColor: scheme.onPrimaryContainer,
        elevation: 4,
        highlightElevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
      ),
      // NavigationBar — M3 pill indicator
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: scheme.surface,
        indicatorColor: scheme.primaryContainer,
        elevation: 2,
        height: 80,
        labelTextStyle: WidgetStatePropertyAll(
          textTheme.labelMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return IconThemeData(color: scheme.onPrimaryContainer, size: 24);
          }
          return IconThemeData(color: scheme.onSurfaceVariant, size: 24);
        }),
      ),
      // NavigationRail
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: scheme.surface,
        indicatorColor: scheme.primaryContainer,
        selectedIconTheme:
            IconThemeData(color: scheme.onPrimaryContainer, size: 24),
        unselectedIconTheme:
            IconThemeData(color: scheme.onSurfaceVariant, size: 24),
        selectedLabelTextStyle: textTheme.labelMedium?.copyWith(
          color: scheme.onSurface,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelTextStyle: textTheme.labelMedium?.copyWith(
          color: scheme.onSurfaceVariant,
        ),
      ),
      // Chips
      chipTheme: ChipThemeData(
        backgroundColor: scheme.surfaceContainerLow,
        selectedColor: palette.giveSoft,
        labelStyle: textTheme.labelLarge,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: scheme.outlineVariant),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),
      // Bottom Sheet
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: scheme.surfaceContainerLow,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
        showDragHandle: true,
        dragHandleColor: scheme.onSurfaceVariant.withValues(alpha: 0.4),
      ),
      // Dialog
      dialogTheme: DialogThemeData(
        backgroundColor: scheme.surfaceContainerHigh,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(32),
        ),
        titleTextStyle: textTheme.headlineMedium?.copyWith(color: textColor),
        contentTextStyle: textTheme.bodyLarge?.copyWith(color: textColor),
      ),
      // SnackBar
      snackBarTheme: SnackBarThemeData(
        backgroundColor: isDark
            ? scheme.inverseSurface
            : scheme.inverseSurface,
        contentTextStyle: textTheme.bodyMedium?.copyWith(
          color: scheme.onInverseSurface,
        ),
        actionTextColor: scheme.inversePrimary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        behavior: SnackBarBehavior.floating,
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
      // Tooltip
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: scheme.inverseSurface,
          borderRadius: BorderRadius.circular(8),
        ),
        textStyle: textTheme.bodySmall?.copyWith(
          color: scheme.onInverseSurface,
        ),
      ),
      // ListTile
      listTileTheme: ListTileThemeData(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        titleTextStyle: textTheme.bodyLarge?.copyWith(color: textColor),
        subtitleTextStyle:
            textTheme.bodyMedium?.copyWith(color: palette.inkSoft),
      ),
      // Divider
      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant.withValues(alpha: 0.5),
        space: 1,
        thickness: 1,
      ),
      // PopupMenu
      popupMenuTheme: PopupMenuThemeData(
        color: scheme.surfaceContainer,
        elevation: 3,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        textStyle: textTheme.bodyMedium,
      ),
      // Switch
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return scheme.onPrimary;
          }
          return scheme.outline;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return scheme.primary;
          }
          return scheme.surfaceContainerHighest;
        }),
      ),
      // TabBar
      tabBarTheme: TabBarThemeData(
        labelStyle: textTheme.titleSmall,
        unselectedLabelStyle: textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.w400,
        ),
        indicatorColor: scheme.primary,
        labelColor: scheme.primary,
        unselectedLabelColor: scheme.onSurfaceVariant,
      ),
    );
  }
}
