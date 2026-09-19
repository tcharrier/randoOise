import 'package:flutter/material.dart';

/// Rando Oise visual identity: forest green, warm off-white paper, ochre
/// accent for actions and status.
class RandoColors {
  RandoColors._();

  static const forest = Color(0xFF2F6B45);
  static const forestDark = Color(0xFF1F4A2F);
  static const forestLight = Color(0xFFDCEBDF);
  static const ochre = Color(0xFFD98E04);
  static const ochreLight = Color(0xFFFFF1D6);
  static const paper = Color(0xFFF6F4EE);
  static const surface = Color(0xFFFFFFFF);
  static const ink = Color(0xFF1F2A22);
  static const inkMuted = Color(0xFF5F6B63);
  static const line = Color(0xFFE2E0D8);
  static const danger = Color(0xFFC0392B);
  static const track = Color(0xFFE0521C);
  static const trackHalo = Color(0x66FFFFFF);
  static const water = Color(0xFF2B6CB0);

  /// Dark mode counterparts.
  static const paperDark = Color(0xFF121A15);
  static const surfaceDark = Color(0xFF1B251E);
  static const inkDark = Color(0xFFECEBE4);
  static const inkMutedDark = Color(0xFFA5AFA8);
  static const lineDark = Color(0xFF2E3A32);
}

ThemeData buildRandoTheme({Brightness brightness = Brightness.light}) {
  final dark = brightness == Brightness.dark;
  final scheme = ColorScheme(
    brightness: brightness,
    primary: dark ? const Color(0xFF7FC08F) : RandoColors.forest,
    onPrimary: dark ? RandoColors.forestDark : Colors.white,
    primaryContainer: dark ? RandoColors.forestDark : RandoColors.forestLight,
    onPrimaryContainer: dark ? RandoColors.inkDark : RandoColors.forestDark,
    secondary: RandoColors.ochre,
    onSecondary: Colors.white,
    secondaryContainer: dark ? const Color(0xFF4A3406) : RandoColors.ochreLight,
    onSecondaryContainer: dark ? RandoColors.inkDark : const Color(0xFF5A3B00),
    tertiary: RandoColors.water,
    onTertiary: Colors.white,
    error: RandoColors.danger,
    onError: Colors.white,
    surface: dark ? RandoColors.surfaceDark : RandoColors.surface,
    onSurface: dark ? RandoColors.inkDark : RandoColors.ink,
    onSurfaceVariant: dark ? RandoColors.inkMutedDark : RandoColors.inkMuted,
    outline: dark ? RandoColors.lineDark : RandoColors.line,
    outlineVariant: dark ? RandoColors.lineDark : RandoColors.line,
    surfaceContainerHighest: dark ? const Color(0xFF243128) : const Color(0xFFEEECE4),
    surfaceContainer: dark ? const Color(0xFF1F2A23) : const Color(0xFFF1EFE8),
    surfaceContainerLow: dark ? RandoColors.paperDark : RandoColors.paper,
    inverseSurface: dark ? RandoColors.inkDark : RandoColors.ink,
    onInverseSurface: dark ? RandoColors.ink : RandoColors.paper,
    shadow: Colors.black,
    scrim: Colors.black,
  );

  final base = ThemeData(useMaterial3: true, colorScheme: scheme, brightness: brightness);
  const radius = 16.0;
  return base.copyWith(
    scaffoldBackgroundColor: dark ? RandoColors.paperDark : RandoColors.paper,
    appBarTheme: AppBarTheme(
      backgroundColor: dark ? RandoColors.paperDark : RandoColors.paper,
      foregroundColor: scheme.onSurface,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: base.textTheme.titleLarge?.copyWith(
        color: scheme.onSurface,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.2,
      ),
    ),
    cardTheme: CardThemeData(
      color: scheme.surface,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radius),
        side: BorderSide(color: scheme.outline),
      ),
    ),
    chipTheme: base.chipTheme.copyWith(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
      side: BorderSide(color: scheme.outline),
      backgroundColor: scheme.surface,
      selectedColor: scheme.primaryContainer,
      labelStyle: base.textTheme.labelLarge?.copyWith(color: scheme.onSurface),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(48, 48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(fontWeight: FontWeight.w600),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(48, 48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        side: BorderSide(color: scheme.outline),
        foregroundColor: scheme.onSurface,
        textStyle: const TextStyle(fontWeight: FontWeight.w600),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(fontWeight: FontWeight.w600),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: scheme.surface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: scheme.outline),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: scheme.outline),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: scheme.primary, width: 2),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: scheme.surface,
      indicatorColor: scheme.primaryContainer,
      height: 68,
      labelTextStyle: WidgetStatePropertyAll(
        base.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w600),
      ),
    ),
    navigationRailTheme: NavigationRailThemeData(
      backgroundColor: scheme.surface,
      indicatorColor: scheme.primaryContainer,
      selectedIconTheme: IconThemeData(color: scheme.onPrimaryContainer),
      selectedLabelTextStyle: TextStyle(
          color: scheme.onSurface, fontWeight: FontWeight.w700, fontSize: 12),
      unselectedLabelTextStyle:
          TextStyle(color: scheme.onSurfaceVariant, fontSize: 12),
    ),
    dividerTheme: DividerThemeData(color: scheme.outline, space: 1),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    dialogTheme: DialogThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: scheme.surface,
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: scheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      showDragHandle: true,
    ),
    listTileTheme: ListTileThemeData(
      iconColor: scheme.onSurfaceVariant,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
  );
}

/// Human labels / colors for route difficulty.
class DifficultyStyle {
  static Color color(String? difficulte) {
    final d = (difficulte ?? '').toLowerCase();
    if (d.contains('très') || d.contains('difficile') && d.contains('tres')) {
      return RandoColors.danger;
    }
    if (d.contains('difficile')) return const Color(0xFFC05621);
    if (d.contains('moyen')) return RandoColors.ochre;
    if (d.contains('facile')) return RandoColors.forest;
    return RandoColors.inkMuted;
  }

  static String label(String? difficulte) =>
      (difficulte == null || difficulte.isEmpty) ? 'Non renseigné' : difficulte;
}
