import 'package:flutter/material.dart';

/// Escala tipográfica de Criador Pro — PRD §6.
///
/// El PRD define seis roles con tamaño, peso e interlineado concretos. Se
/// mapean sobre el `TextTheme` de Material para que los widgets del framework
/// los hereden sin que cada pantalla tenga que declarar estilos:
///
/// | Rol del PRD        | Estilo Material | Especificación          |
/// |--------------------|-----------------|-------------------------|
/// | Título de pantalla | headlineSmall   | Inter 600 · 24          |
/// | Título de sección  | titleMedium     | Inter 600 · 17          |
/// | Cuerpo             | bodyLarge       | Inter 400 · 15 / 1,55   |
/// | Secundario         | bodyMedium      | Inter 400 · 13,5        |
/// | Etiqueta           | labelSmall      | Inter 600 · 11 · +0,1em |
/// | Dato numérico      | headlineMedium  | Inter 700 · 28          |
abstract final class AppTypography {
  /// Familia empaquetada en el binario (ver `pubspec.yaml`).
  static const String fontFamily = 'Inter';

  /// El orden importa: primero la escala y **después** la familia y el color.
  /// Al revés, cada `copyWith` sustituiría el estilo entero por uno sin
  /// `fontFamily` y la app acabaría dibujando con la fuente del sistema.
  ///
  /// El color no es opcional. Cada `const TextStyle` de aquí abajo reemplaza el
  /// estilo entero de la base, incluido su color, y un `TextStyle` sin color se
  /// pinta **blanco**: sobre tarjeta blanca el texto desaparece sin que nada
  /// falle. Solo se salvan los widgets que declaran color en el sitio de uso,
  /// que es justo lo que el tema debería evitar.
  static TextTheme apply(TextTheme base, ColorScheme scheme) => base
      .copyWith(
        // Dato numérico: totales, contadores y montos.
        displaySmall: const TextStyle(fontSize: 32, fontWeight: FontWeight.w700, height: 1.15),
        headlineMedium: const TextStyle(fontSize: 28, fontWeight: FontWeight.w700, height: 1.2),

        // Título de pantalla.
        headlineSmall: const TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w600,
          height: 1.25,
          letterSpacing: -0.2,
        ),

        // Título de sección: barras de navegación y agrupadores.
        titleLarge: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600, height: 1.3),
        titleMedium: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600, height: 1.3),
        titleSmall: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, height: 1.35),

        // Cuerpo. El 1,55 del PRD es generoso a propósito: esto se lee a un brazo
        // de distancia, con el teléfono en una mano y un ave en la otra.
        bodyLarge: const TextStyle(fontSize: 15, fontWeight: FontWeight.w400, height: 1.55),

        // Secundario: subtítulos y metadatos.
        bodyMedium: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w400, height: 1.45),
        bodySmall: const TextStyle(fontSize: 12, fontWeight: FontWeight.w400, height: 1.4),

        // Etiqueta: agrupadores en mayúsculas.
        labelLarge: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, letterSpacing: 0.1),
        labelMedium: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, letterSpacing: 0.1),
        labelSmall: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 1.1),
      )
      .apply(
        fontFamily: fontFamily,
        // `bodyColor` cubre body/title/label/headlineSmall; `displayColor`,
        // display* y headline{Large,Medium} — el dato numérico entre ellos.
        bodyColor: scheme.onSurface,
        displayColor: scheme.onSurface,
      );

  /// Etiqueta de sección en formularios y fichas: mayúsculas con tracking.
  static TextStyle sectionLabel(BuildContext context) {
    final theme = Theme.of(context);
    return theme.textTheme.labelSmall!.copyWith(color: theme.colorScheme.onSurfaceVariant);
  }

  /// Números grandes de las tarjetas de resumen.
  ///
  /// Con cifras tabulares para que un contador que pasa de 99 a 100 no desplace
  /// lo que tiene al lado.
  static TextStyle metric(BuildContext context) => Theme.of(
    context,
  ).textTheme.headlineMedium!.copyWith(fontFeatures: const [FontFeature.tabularFigures()]);
}
