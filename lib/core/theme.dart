import 'package:flutter/material.dart';

/// Uygulamanın açık ve koyu teması.
///
/// Renkler tek bir tohum renkten (gece mavisi) türetilir; hilâl ikonu ve
/// bildirim çubuğu düzeni de aynı paleti kullanır.
class AppTheme {
  const AppTheme._();

  /// Gece göğü mavisi — hilâlin arkasındaki renk.
  static const Color seed = Color(0xFF1B3A6B);

  /// Vurgu: hilâlin altın rengi.
  static const Color crescent = Color(0xFFE8B84B);

  static ThemeData light() => _build(Brightness.light);
  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final scheme = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: brightness,
    );
    return ThemeData(
      colorScheme: scheme,
      useMaterial3: true,
      scaffoldBackgroundColor: scheme.surface,
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 2,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: scheme.surfaceContainerLow,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        margin: EdgeInsets.zero,
      ),
      listTileTheme: const ListTileThemeData(
        contentPadding: EdgeInsets.symmetric(horizontal: 16),
      ),
      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant.withValues(alpha: 0.5),
        space: 1,
        thickness: 1,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}

/// Ana ekranda vakit satırlarının durumu — renklendirmeyi tek yerde tutar.
enum PrayerRowState { past, current, next, upcoming }

extension PrayerRowStyle on PrayerRowState {
  Color foreground(ColorScheme scheme) => switch (this) {
        PrayerRowState.past => scheme.onSurfaceVariant.withValues(alpha: 0.55),
        PrayerRowState.current => scheme.onPrimaryContainer,
        PrayerRowState.next => scheme.onTertiaryContainer,
        PrayerRowState.upcoming => scheme.onSurface,
      };

  Color? background(ColorScheme scheme) => switch (this) {
        PrayerRowState.current => scheme.primaryContainer,
        PrayerRowState.next => scheme.tertiaryContainer,
        _ => null,
      };

  FontWeight get weight => switch (this) {
        PrayerRowState.current || PrayerRowState.next => FontWeight.w700,
        _ => FontWeight.w500,
      };
}
