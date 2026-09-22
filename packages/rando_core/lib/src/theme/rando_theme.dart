import 'package:flutter/material.dart';

/// Rando Oise visual identity.
///
/// Warm cream "paper" background, near-black ink, deep green for actions and
/// positive states, big display headlines, very round cards and pill buttons.
/// Dark mode uses a true dark background with mint-green accents.
class RandoColors {
  RandoColors._();

  // Brand
  static const green = Color(0xFF1F6B4A);
  static const greenDeep = Color(0xFF15503A);
  static const greenBright = Color(0xFF2FA36B);
  static const mint = Color(0xFFDDEFE3);
  static const mintSoft = Color(0xFFEAF4EC);
  static const ochre = Color(0xFFB8781F);
  static const ochreSoft = Color(0xFFFBEFD9);
  static const blue = Color(0xFF3B6FD9);
  static const blueSoft = Color(0xFFE3EBFA);
  static const red = Color(0xFFD2452E);
  static const redSoft = Color(0xFFFBE4DF);

  // Light surfaces
  static const paper = Color(0xFFF5F0E8);
  static const paperDeep = Color(0xFFEDE6DA);
  static const card = Color(0xFFFFFFFF);
  static const cardTint = Color(0xFFFAF7F1);
  static const ink = Color(0xFF141414);
  static const inkSoft = Color(0xFF6B6B6B);
  static const line = Color(0xFFE6E0D5);

  // Dark surfaces
  static const night = Color(0xFF0C0C0C);
  static const nightCard = Color(0xFF1B1B1B);
  static const nightCardHigh = Color(0xFF262626);
  static const nightInk = Color(0xFFF3F1EC);
  static const nightInkSoft = Color(0xFFA3A3A3);
  static const nightLine = Color(0xFF2E2E2E);
  static const nightGreen = Color(0xFF79D9A3);
  static const nightGreenDeep = Color(0xFF1E5A40);
  static const nightMint = Color(0xFF17352A);

  // Map
  static const track = Color(0xFFE0521C);
  static const trackNight = Color(0xFFFF7A45);
  static const trackHalo = Color(0xB3FFFFFF);

  // Legacy aliases still used by some widgets.
  static const forest = green;
  static const forestDark = greenDeep;
  static const forestLight = mint;
  static const ochreLight = ochreSoft;
  static const surface = card;
  static const inkMuted = inkSoft;
  static const danger = red;
  static const water = blue;
}

/// Shared radii and spacing.
class RandoRadius {
  RandoRadius._();
  static const card = 24.0;
  static const tile = 20.0;
  static const chip = 999.0;
  static const button = 999.0;
  static const field = 16.0;
}

const String kRandoFont = 'packages/rando_core/Inter';
const String kRandoDisplayFont = 'packages/rando_core/InterDisplay';

ThemeData buildRandoTheme({Brightness brightness = Brightness.light}) {
  final dark = brightness == Brightness.dark;

  final scheme = ColorScheme(
    brightness: brightness,
    primary: dark ? RandoColors.nightGreen : RandoColors.green,
    onPrimary: dark ? RandoColors.night : Colors.white,
    primaryContainer: dark ? RandoColors.nightMint : RandoColors.mint,
    onPrimaryContainer: dark ? RandoColors.nightGreen : RandoColors.greenDeep,
    secondary: RandoColors.ochre,
    onSecondary: Colors.white,
    secondaryContainer: dark ? const Color(0xFF3A2A10) : RandoColors.ochreSoft,
    onSecondaryContainer: dark ? const Color(0xFFF2C77A) : const Color(0xFF6A4300),
    tertiary: dark ? const Color(0xFF8FB0FF) : RandoColors.blue,
    onTertiary: Colors.white,
    tertiaryContainer: dark ? const Color(0xFF1B2A4A) : RandoColors.blueSoft,
    onTertiaryContainer: dark ? const Color(0xFFC7D6FF) : const Color(0xFF1F3F86),
    error: dark ? const Color(0xFFFF8A75) : RandoColors.red,
    onError: dark ? RandoColors.night : Colors.white,
    errorContainer: dark ? const Color(0xFF4A1A12) : RandoColors.redSoft,
    onErrorContainer: dark ? const Color(0xFFFFC4B8) : const Color(0xFF7A1F12),
    surface: dark ? RandoColors.nightCard : RandoColors.card,
    onSurface: dark ? RandoColors.nightInk : RandoColors.ink,
    onSurfaceVariant: dark ? RandoColors.nightInkSoft : RandoColors.inkSoft,
    outline: dark ? RandoColors.nightLine : RandoColors.line,
    outlineVariant: dark ? RandoColors.nightLine : RandoColors.line,
    surfaceContainerLowest: dark ? RandoColors.night : Colors.white,
    surfaceContainerLow: dark ? RandoColors.night : RandoColors.paper,
    surfaceContainer: dark ? RandoColors.nightCard : RandoColors.paperDeep,
    surfaceContainerHigh: dark ? RandoColors.nightCardHigh : RandoColors.paperDeep,
    surfaceContainerHighest: dark ? RandoColors.nightCardHigh : RandoColors.line,
    inverseSurface: dark ? RandoColors.nightInk : RandoColors.ink,
    onInverseSurface: dark ? RandoColors.ink : RandoColors.paper,
    inversePrimary: dark ? RandoColors.green : RandoColors.nightGreen,
    shadow: Colors.black,
    scrim: Colors.black,
  );

  final base = ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    brightness: brightness,
    fontFamily: kRandoFont,
  );

  final ink = scheme.onSurface;
  final soft = scheme.onSurfaceVariant;
  final text = base.textTheme.apply(bodyColor: ink, displayColor: ink).copyWith(
        displayLarge: TextStyle(fontFamily: kRandoDisplayFont, fontSize: 40, fontWeight: FontWeight.w800, letterSpacing: -1.2, height: 1.05, color: ink),
        displayMedium: TextStyle(fontFamily: kRandoDisplayFont, fontSize: 34, fontWeight: FontWeight.w800, letterSpacing: -1.0, height: 1.08, color: ink),
        displaySmall: TextStyle(fontFamily: kRandoDisplayFont, fontSize: 28, fontWeight: FontWeight.w800, letterSpacing: -0.8, height: 1.1, color: ink),
        headlineLarge: TextStyle(fontFamily: kRandoDisplayFont, fontSize: 26, fontWeight: FontWeight.w800, letterSpacing: -0.6, height: 1.15, color: ink),
        headlineMedium: TextStyle(fontFamily: kRandoDisplayFont, fontSize: 22, fontWeight: FontWeight.w700, letterSpacing: -0.4, height: 1.2, color: ink),
        headlineSmall: TextStyle(fontFamily: kRandoDisplayFont, fontSize: 20, fontWeight: FontWeight.w700, letterSpacing: -0.3, height: 1.2, color: ink),
        titleLarge: TextStyle(fontSize: 19, fontWeight: FontWeight.w700, letterSpacing: -0.3, color: ink),
        titleMedium: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, letterSpacing: -0.2, color: ink),
        titleSmall: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: ink),
        bodyLarge: TextStyle(fontSize: 16, fontWeight: FontWeight.w400, height: 1.45, color: ink),
        bodyMedium: TextStyle(fontSize: 14, fontWeight: FontWeight.w400, height: 1.4, color: ink),
        bodySmall: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w500, height: 1.35, color: soft),
        labelLarge: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: ink),
        labelMedium: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: soft),
        labelSmall: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.2, color: soft),
      );

  final pill = RoundedRectangleBorder(borderRadius: BorderRadius.circular(RandoRadius.button));

  return base.copyWith(
    textTheme: text,
    scaffoldBackgroundColor: dark ? RandoColors.night : RandoColors.paper,
    canvasColor: dark ? RandoColors.night : RandoColors.paper,
    splashFactory: InkSparkle.splashFactory,
    appBarTheme: AppBarTheme(
      backgroundColor: dark ? RandoColors.night : RandoColors.paper,
      foregroundColor: ink,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleSpacing: 8,
      titleTextStyle: text.headlineMedium,
      iconTheme: IconThemeData(color: ink),
    ),
    cardTheme: CardThemeData(
      color: scheme.surface,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(RandoRadius.card)),
    ),
    chipTheme: base.chipTheme.copyWith(
      shape: pill,
      side: BorderSide(color: scheme.outline),
      backgroundColor: scheme.surface,
      selectedColor: ink,
      checkmarkColor: scheme.surface,
      secondarySelectedColor: ink,
      // Selected chips are dark pills: flip the label colour with the state.
      labelStyle: WidgetStateTextStyle.resolveWith((states) => text.labelLarge!.copyWith(
            color: states.contains(WidgetState.selected) ? scheme.surface : ink,
          )),
      secondaryLabelStyle: text.labelLarge?.copyWith(color: scheme.surface),
      iconTheme: IconThemeData(color: ink, size: 18),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      showCheckmark: false,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(56, 56),
        padding: const EdgeInsets.symmetric(horizontal: 22),
        shape: pill,
        backgroundColor: dark ? RandoColors.nightGreenDeep : RandoColors.green,
        foregroundColor: dark ? RandoColors.nightInk : Colors.white,
        textStyle: const TextStyle(fontFamily: kRandoFont, fontSize: 16, fontWeight: FontWeight.w700),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        minimumSize: const Size(56, 56),
        elevation: 0,
        shape: pill,
        backgroundColor: ink,
        foregroundColor: scheme.surface,
        textStyle: const TextStyle(fontFamily: kRandoFont, fontSize: 16, fontWeight: FontWeight.w700),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(56, 56),
        padding: const EdgeInsets.symmetric(horizontal: 22),
        shape: pill,
        side: BorderSide.none,
        backgroundColor: dark ? RandoColors.nightCardHigh : RandoColors.paperDeep,
        foregroundColor: ink,
        textStyle: const TextStyle(fontFamily: kRandoFont, fontSize: 16, fontWeight: FontWeight.w700),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        shape: pill,
        foregroundColor: ink,
        textStyle: const TextStyle(fontFamily: kRandoFont, fontSize: 15, fontWeight: FontWeight.w700),
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(minimumSize: const Size(48, 48)),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: SegmentedButton.styleFrom(
        shape: pill,
        side: BorderSide(color: scheme.outline),
        selectedBackgroundColor: ink,
        selectedForegroundColor: scheme.surface,
        backgroundColor: scheme.surface,
        foregroundColor: ink,
        textStyle: text.labelLarge,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: scheme.surface,
      hintStyle: text.bodyMedium?.copyWith(color: soft),
      labelStyle: text.labelLarge?.copyWith(color: soft),
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(RandoRadius.field), borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(RandoRadius.field), borderSide: BorderSide.none),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(RandoRadius.field), borderSide: BorderSide(color: scheme.primary, width: 2)),
      errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(RandoRadius.field), borderSide: BorderSide(color: scheme.error, width: 1.5)),
      focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(RandoRadius.field), borderSide: BorderSide(color: scheme.error, width: 2)),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: scheme.surface,
      indicatorColor: scheme.primaryContainer,
      height: 68,
      labelTextStyle: WidgetStatePropertyAll(text.labelMedium?.copyWith(color: ink)),
    ),
    navigationRailTheme: NavigationRailThemeData(
      backgroundColor: scheme.surface,
      indicatorColor: scheme.primaryContainer,
      selectedIconTheme: IconThemeData(color: scheme.onPrimaryContainer),
      selectedLabelTextStyle: text.labelMedium?.copyWith(color: ink, fontWeight: FontWeight.w700),
      unselectedLabelTextStyle: text.labelMedium,
    ),
    dividerTheme: DividerThemeData(color: scheme.outline, space: 1),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: ink,
      contentTextStyle: text.bodyMedium?.copyWith(color: scheme.surface, fontWeight: FontWeight.w600),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
    ),
    dialogTheme: DialogThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      backgroundColor: scheme.surface,
      titleTextStyle: text.headlineSmall,
      contentTextStyle: text.bodyLarge,
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: scheme.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      showDragHandle: true,
      dragHandleColor: scheme.outline,
    ),
    listTileTheme: ListTileThemeData(
      iconColor: soft,
      titleTextStyle: text.titleMedium,
      subtitleTextStyle: text.bodySmall,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(RandoRadius.tile)),
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: scheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      textStyle: text.bodyMedium,
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: scheme.primary,
      linearTrackColor: dark ? RandoColors.nightCardHigh : RandoColors.paperDeep,
      circularTrackColor: dark ? RandoColors.nightCardHigh : RandoColors.paperDeep,
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStatePropertyAll(scheme.surface),
      trackColor: WidgetStateProperty.resolveWith((s) =>
          s.contains(WidgetState.selected) ? scheme.primary : scheme.outline),
      trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
    ),
  );
}

/// Human labels / colors for route difficulty.
class DifficultyStyle {
  static Color color(String? difficulte) {
    final d = (difficulte ?? '').toLowerCase();
    if (d.contains('très') && d.contains('difficile')) return RandoColors.red;
    if (d.contains('difficile')) return const Color(0xFFC05621);
    if (d.contains('moyen')) return RandoColors.ochre;
    if (d.contains('facile')) return RandoColors.green;
    return RandoColors.inkSoft;
  }

  static String label(String? difficulte) =>
      (difficulte == null || difficulte.isEmpty) ? 'Non renseigné' : difficulte;
}
