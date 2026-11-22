import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Temas institucionales. Cada uno tiene variante clara y oscura; MaterialApp elige
/// automáticamente según el modo del sistema (ThemeMode.system).
enum AppPalette {
  guinda('Guinda IPN', Color(0xFF6C1D45), Color(0xFFD4AF37)),
  azul('Azul ESCOM', Color(0xFF003366), Color(0xFF0099FF));

  const AppPalette(this.label, this.primary, this.accent);
  final String label;
  final Color primary;
  final Color accent;
}

class AppTheme {
  static ThemeData build(AppPalette palette, Brightness brightness) {
    final dark = brightness == Brightness.dark;
    var scheme = ColorScheme.fromSeed(
      seedColor: palette.primary,
      brightness: brightness,
      secondary: palette.accent,
    );
    // En claro se usa el color institucional exacto como primario.
    if (!dark) scheme = scheme.copyWith(primary: palette.primary, onPrimary: Colors.white);

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      appBarTheme: AppBarTheme(
        backgroundColor: dark ? scheme.surfaceContainer : palette.primary,
        foregroundColor: dark ? scheme.onSurface : Colors.white,
        centerTitle: false,
        // La barra superior siempre es oscura (guinda/azul o gris en modo oscuro):
        // íconos de la barra de estado claros para que sean legibles.
        systemOverlayStyle: SystemUiOverlayStyle.light,
      ),
      navigationBarTheme: NavigationBarThemeData(indicatorColor: scheme.primaryContainer),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: scheme.primaryContainer,
        foregroundColor: scheme.onPrimaryContainer,
      ),
      snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
      listTileTheme: const ListTileThemeData(contentPadding: EdgeInsets.symmetric(horizontal: 16)),
    );
  }
}
