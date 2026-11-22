import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Temas institucionales; MaterialApp elige variante clara/oscura según el sistema.
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
    var scheme = ColorScheme.fromSeed(seedColor: palette.primary, brightness: brightness, secondary: palette.accent);
    if (!dark) scheme = scheme.copyWith(primary: palette.primary, onPrimary: Colors.white);
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      appBarTheme: AppBarTheme(
        backgroundColor: dark ? scheme.surfaceContainer : palette.primary,
        foregroundColor: dark ? scheme.onSurface : Colors.white,
        systemOverlayStyle: SystemUiOverlayStyle.light,
      ),
      snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(minimumSize: const Size(0, 52), textStyle: const TextStyle(fontSize: 16)),
      ),
    );
  }
}

/// Colores del escenario (canal de Xochimilco) que dependen del modo claro/oscuro.
class BoardColors {
  final Color water, waterDeep, rock, rockEdge, grid, bubble, whirl, current, exitOpen, exitClosed;
  const BoardColors._(this.water, this.waterDeep, this.rock, this.rockEdge, this.grid, this.bubble, this.whirl,
      this.current, this.exitOpen, this.exitClosed);

  factory BoardColors.of(BuildContext context) => Theme.of(context).brightness == Brightness.dark
      ? const BoardColors._(Color(0xFF0E3B4A), Color(0xFF0A2C38), Color(0xFF4E4A46), Color(0xFF2E2B28),
          Color(0x22FFFFFF), Color(0xFFB3E5FC), Color(0xFF7E57C2), Color(0xFF4DD0E1), Color(0xFF66BB6A),
          Color(0xFF8D6E63))
      : const BoardColors._(Color(0xFF7FD3D9), Color(0xFF4FB3BF), Color(0xFF8D8478), Color(0xFF6B6359),
          Color(0x22004D40), Color(0xFFFFFFFF), Color(0xFF5E35B1), Color(0xFF00838F), Color(0xFF2E7D32),
          Color(0xFF795548));

  static Color axolotl(String name) => switch (name) {
        'dorado' => const Color(0xFFFFC857),
        'azul' => const Color(0xFF6EC1E4),
        'verde' => const Color(0xFF8BD17C),
        _ => const Color(0xFFF7A8C4),
      };
}
