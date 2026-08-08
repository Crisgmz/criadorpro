import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_spacing.dart';
import 'app_typography.dart';
import 'semantic_colors.dart';

/// Tema de la app.
///
/// El `ColorScheme` se declara a mano en lugar de derivarlo con `fromSeed`: el
/// sistema de diseño del PRD es una paleta cerrada con contrastes ya
/// verificados, y el algoritmo de armonización de Material desplazaría los
/// tonos exactos que el diseño fija.
abstract final class AppTheme {
  static ThemeData get light => _build(_lightScheme);
  static ThemeData get dark => _build(_darkScheme);

  static const ColorScheme _lightScheme = ColorScheme(
    brightness: Brightness.light,
    // El rojo de acción es el `primary` porque es lo que Material pinta en los
    // botones. El navy de marca viaja en `secondary`.
    primary: AppColors.action,
    onPrimary: Colors.white,
    primaryContainer: Color(0xFFFCE7EB),
    onPrimaryContainer: Color(0xFF7A0A1C),
    secondary: AppColors.navy,
    onSecondary: Colors.white,
    secondaryContainer: Color(0xFFE3E9F0),
    onSecondaryContainer: AppColors.navy,
    tertiary: AppColors.warning,
    onTertiary: Colors.white,
    tertiaryContainer: Color(0xFFFAF0DC),
    onTertiaryContainer: Color(0xFF6B4712),
    // El error comparte el rojo de acción: el PRD usa #C8102E también para el
    // borde y el mensaje de un campo inválido.
    error: AppColors.action,
    onError: Colors.white,
    errorContainer: Color(0xFFFCE7EB),
    onErrorContainer: Color(0xFF7A0A1C),
    surface: AppColors.surface,
    onSurface: AppColors.navy,
    onSurfaceVariant: AppColors.mutedText,
    surfaceContainerLowest: Colors.white,
    surfaceContainerLow: Color(0xFFFAFBFC),
    surfaceContainer: AppColors.background,
    surfaceContainerHigh: Color(0xFFEDF1F5),
    surfaceContainerHighest: AppColors.border,
    outline: Color(0xFFC3CEDA),
    outlineVariant: AppColors.border,
    inverseSurface: AppColors.navy,
    onInverseSurface: Colors.white,
    inversePrimary: AppColors.actionLight,
    shadow: Colors.black,
    scrim: Colors.black,
  );

  static const ColorScheme _darkScheme = ColorScheme(
    brightness: Brightness.dark,
    primary: AppColors.actionLight,
    onPrimary: Color(0xFF3D0410),
    primaryContainer: Color(0xFF8E0C20),
    onPrimaryContainer: Color(0xFFFCE7EB),
    secondary: Color(0xFFA9C3DE),
    onSecondary: AppColors.navyDeep,
    secondaryContainer: AppColors.navySurface,
    onSecondaryContainer: Color(0xFFDCE7F2),
    tertiary: Color(0xFFDFAE5F),
    onTertiary: Color(0xFF3D2A05),
    tertiaryContainer: Color(0xFF6B4712),
    onTertiaryContainer: Color(0xFFFAF0DC),
    error: AppColors.actionLight,
    onError: Color(0xFF3D0410),
    errorContainer: Color(0xFF8E0C20),
    onErrorContainer: Color(0xFFFCE7EB),
    surface: AppColors.navyDeep,
    onSurface: Color(0xFFE7ECF2),
    onSurfaceVariant: AppColors.mutedTextDark,
    surfaceContainerLowest: Color(0xFF071320),
    surfaceContainerLow: Color(0xFF0E2133),
    surfaceContainer: AppColors.navySurface,
    surfaceContainerHigh: Color(0xFF1A3349),
    surfaceContainerHighest: Color(0xFF223E56),
    outline: Color(0xFF3D5872),
    outlineVariant: AppColors.borderDark,
    inverseSurface: Color(0xFFE7ECF2),
    onInverseSurface: AppColors.navy,
    inversePrimary: AppColors.action,
    shadow: Colors.black,
    scrim: Colors.black,
  );

  static ThemeData _build(ColorScheme scheme) {
    final isLight = scheme.brightness == Brightness.light;
    final base = ThemeData(colorScheme: scheme, useMaterial3: true);

    return base.copyWith(
      // Vocabulario del oficio (sexo, aviso, acento de marca): cambia con el
      // tema, así que ningún widget necesita preguntar por el brillo.
      extensions: [isLight ? SemanticColors.light : SemanticColors.dark],
      scaffoldBackgroundColor: isLight ? AppColors.background : AppColors.navyDeep,
      textTheme: AppTypography.apply(base.textTheme, scheme),
      // Barra superior siempre clara y con el título centrado: el navy del
      // producto se reserva a tarjetas dentro del contenido (membresía,
      // resumen del criadero), no al cromado de la pantalla.
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 2,
        centerTitle: true,
        titleTextStyle: base.textTheme.titleLarge?.copyWith(
          color: scheme.onSurface,
          fontWeight: FontWeight.w600,
        ),
      ),
      // Tarjeta: fondo blanco, radio 16, borde de 1 px, sin sombra — PRD §6.
      //
      // En oscuro no puede usar `surface`: es el mismo color del fondo de
      // pantalla y la tarjeta se volvería un rectángulo de borde sin cuerpo.
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        color: isLight ? scheme.surface : scheme.surfaceContainerLow,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.card),
          side: BorderSide(color: scheme.outlineVariant),
        ),
      ),
      // Campo: alto 52, radio 12, borde 1,5 px que pasa a navy al enfocar.
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        // Mismo motivo que en la tarjeta: en oscuro el campo tiene que
        // despegarse del fondo.
        fillColor: isLight ? scheme.surface : scheme.surfaceContainerLow,
        constraints: const BoxConstraints(minHeight: AppSizes.control),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.md,
        ),
        border: _fieldBorder(scheme.outlineVariant),
        enabledBorder: _fieldBorder(scheme.outlineVariant),
        focusedBorder: _fieldBorder(isLight ? AppColors.navy : scheme.secondary),
        errorBorder: _fieldBorder(scheme.error),
        focusedErrorBorder: _fieldBorder(scheme.error, width: 2),
        disabledBorder: _fieldBorder(scheme.outlineVariant.withValues(alpha: 0.5)),
        errorStyle: base.textTheme.bodySmall?.copyWith(color: scheme.error),
      ),
      // Ojo con `Size.fromHeight`: equivale a `Size(double.infinity, alto)` y
      // dentro de una Row o de las acciones de un diálogo fuerza ancho
      // infinito, lo que revienta el layout. El alto lo fija el mínimo; el
      // ancho lo decide quien coloca el botón (`CpButton.expanded`).
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(AppSizes.minTouchTarget, AppSizes.control),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
          textStyle: base.textTheme.labelLarge,
          // El deshabilitado del diseño es el mismo color al 40 % — PRD §6.
          disabledBackgroundColor: scheme.primary.withValues(alpha: 0.4),
          disabledForegroundColor: scheme.onPrimary.withValues(alpha: 0.9),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(AppSizes.minTouchTarget, AppSizes.control),
          foregroundColor: isLight ? AppColors.navy : scheme.onSurface,
          side: BorderSide(color: isLight ? AppColors.navy : scheme.outline, width: 1.5),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
          textStyle: base.textTheme.labelLarge,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          // 44 × 44 es el área táctil mínima de `RNF-23`.
          minimumSize: const Size(AppSizes.minTouchTarget, AppSizes.minTouchTarget),
          textStyle: base.textTheme.labelLarge,
        ),
      ),
      // Barra inferior. El indicador es el navy suave y no el rojo: navegar no
      // es una acción destacada, y el rojo está reservado al botón primario.
      //
      // Los estados se declaran explícitamente porque el destino de ejemplares
      // usa el símbolo de marca (`BrandIcon`), que se tiñe desde este
      // `IconTheme`; sin él quedaría de un color fijo junto a iconos que sí
      // cambian al seleccionarse.
      navigationBarTheme: NavigationBarThemeData(
        // 72 en vez de los 80 de Material: la barra siempre muestra etiqueta y
        // hay que dejar sitio al contenido, pero por debajo de 72 el icono y su
        // texto se aprietan y el destino baja de los 44 px de `RNF-23`.
        height: 72,
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        indicatorColor: scheme.secondaryContainer,
        indicatorShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.pill)),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            size: 24,
            color: selected ? scheme.onSecondaryContainer : scheme.onSurfaceVariant,
          );
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return base.textTheme.labelMedium!.copyWith(
            fontFamily: AppTypography.fontFamily,
            fontSize: 12,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
            color: selected ? scheme.onSecondaryContainer : scheme.onSurfaceVariant,
          );
        }),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.sm)),
      ),
      dividerTheme: DividerThemeData(color: scheme.outlineVariant, space: 1, thickness: 1),
      listTileTheme: const ListTileThemeData(
        contentPadding: EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.xs),
      ),
    );
  }

  static OutlineInputBorder _fieldBorder(Color color, {double width = 1.5}) => OutlineInputBorder(
    borderRadius: BorderRadius.circular(AppRadius.md),
    borderSide: BorderSide(color: color, width: width),
  );
}
