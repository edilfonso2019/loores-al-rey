import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Colores del brandbook IASDMR.
class Brand {
  static const azul = Color(0xFF0A245E); // principal, usar siempre
  static const azulMedio = Color(0xFF0F3999);
  static const azulClaro = Color(0xFF3E80F2);
  static const crema = Color(0xFFEFD19F);
  static const dorado = Color(0xFFF1BE48);
  static const coral = Color(0xFFFF8D6D);
  static const gris = Color(0xFF7E7E82);
  static const fondo = Color(0xFFF2F1EF);
  static const fondoTarjeta = Color(0xFFE4E3E1);

  static const fuente = 'NotoSans';
  static const fuenteLogo = 'GreatVibes';

  /// Gris para TEXTO secundario. [gris] (#7E7E82) solo da 3,6:1 sobre el
  /// fondo y no cumple WCAG AA (4,5:1); este da 5,9:1 en claro y 7:1 en
  /// oscuro. [gris] queda para íconos decorativos (3:1 basta).
  static Color textoSecundario(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
      ? const Color(0xFFA9ADB8)
      : const Color(0xFF5C5C60);
}

/// Espaciado en cuadrícula de 4/8 px. Toda la app usa estos valores para
/// que márgenes y separaciones sean consistentes.
class Space {
  static const double xxs = 4;
  static const double xs = 8;
  static const double s = 12;
  static const double m = 16;
  static const double l = 24;
  static const double xl = 32;

  /// Margen lateral de todas las pantallas.
  static const double gutter = m;

  /// Margen lateral de la letra (lectura cómoda, ~45-70 caracteres por línea).
  static const double reading = l;

  /// Área táctil mínima (Material / WCAG 2.5.5).
  static const double touch = 48;
}

/// Escala tipográfica (sp). Nada por debajo de [caption].
class FontSizes {
  static const double caption = 12;
  static const double small = 14;
  static const double body = 16;
  static const double title = 18;
}

/// Fondos elegibles para la letra ("Color de fondo" en Configuración).
enum LyricsBackground {
  defecto('Defecto', null, null),
  crema('Crema', Color(0xFFFBF3E2), Color(0xFF2B2416)),
  sepia('Sepia', Color(0xFFF4ECD8), Color(0xFF5B4636)),
  noche('Noche', Color(0xFF101828), Color(0xFFEDEDED));

  final String label;
  final Color? background;
  final Color? foreground;
  const LyricsBackground(this.label, this.background, this.foreground);
}

class AppTheme {
  /// Barras del sistema transparentes; iconos claros arriba (sobre el azul)
  /// y, abajo, según el tema.
  static SystemUiOverlayStyle overlay({required bool dark}) =>
      SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarDividerColor: Colors.transparent,
        systemNavigationBarIconBrightness: dark
            ? Brightness.light
            : Brightness.dark,
        systemNavigationBarContrastEnforced: false,
      );

  static ThemeData light() => _base(Brightness.light);
  static ThemeData dark() => _base(Brightness.dark);

  static ThemeData _base(Brightness brightness) {
    final dark = brightness == Brightness.dark;
    final scheme =
        ColorScheme.fromSeed(
          seedColor: Brand.azul,
          brightness: brightness,
        ).copyWith(
          primary: dark ? Brand.azulClaro : Brand.azul,
          onPrimary: Colors.white,
          secondary: Brand.dorado,
          onSecondary: Brand.azul,
          tertiary: Brand.coral,
          surface: dark ? const Color(0xFF0E1526) : Brand.fondo,
        );
    final base = ThemeData(
      colorScheme: scheme,
      useMaterial3: true,
      fontFamily: Brand.fuente,
      scaffoldBackgroundColor: scheme.surface,
    );
    return base.copyWith(
      // Flecha "‹" del Figma en todas las pantallas (consistencia).
      actionIconTheme: ActionIconThemeData(
        backButtonIconBuilder: (_) =>
            const Icon(Icons.arrow_back_ios_new_rounded),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: dark ? const Color(0xFF07183F) : Brand.azul,
        foregroundColor: Colors.white,
        centerTitle: true,
        elevation: 0,
        systemOverlayStyle: overlay(dark: dark),
        titleTextStyle: const TextStyle(
          fontFamily: Brand.fuente,
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      ),
      dividerTheme: DividerThemeData(
        color: dark ? Colors.white12 : Colors.black12,
        space: 1,
        thickness: 1,
      ),
      listTileTheme: ListTileThemeData(
        iconColor: dark ? Colors.white : Colors.black87,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? Colors.white : null,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? scheme.primary : null,
        ),
      ),
      snackBarTheme: const SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
