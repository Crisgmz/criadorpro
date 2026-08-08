import 'package:flutter/material.dart';

/// Paleta de Criador Pro — PRD §6.
///
/// Dos colores de marca con papeles distintos: el navy viste las superficies
/// (splash, encabezados, tarjeta de membresía) y el rojo es el color de acción
/// (botón primario, error, indicadores). Por eso el `primary` del `ColorScheme`
/// es el rojo: es lo que Material pinta en los botones.
///
/// El verde de macho y el azul de hembra son una convención cerrada del
/// producto: se aplican igual en listas, fichas, pedigrí y estadísticas, y no
/// significan nunca otra cosa. Nunca van solos — `RNF-25` exige etiqueta
/// textual acompañando al color.
abstract final class AppColors {
  // Marca
  static const Color navy = Color(0xFF0E2A47);
  static const Color action = Color(0xFFC8102E);

  /// Ámbar de advertencia: franja sin conexión, avisos de límite de plan.
  static const Color warning = Color(0xFFB7791F);

  // Código de sexo — convención cerrada.
  static const Color male = Color(0xFF1E7A4C);
  static const Color female = Color(0xFF2B6CB0);
  static const Color unknownSex = mutedText;

  // Neutros
  static const Color background = Color(0xFFF4F6F9);
  static const Color border = Color(0xFFE7ECF2);

  /// El PRD fija #6B7A8C, pero sobre el fondo de pantalla (#F4F6F9) da 4,39:1
  /// y `RNF-22` exige 4,5:1 en texto de cuerpo. Se oscurece ocho puntos por
  /// canal —indistinguible a ojo— para cumplir el umbral: ante un choque entre
  /// documentos manda el más específico, y los umbrales los decide el SRS.
  static const Color mutedText = Color(0xFF637284);
  static const Color surface = Color(0xFFFFFFFF);

  // Resultado de prueba de campo. Reutiliza el verde y el rojo del sistema
  // para no introducir una segunda escala cromática.
  static const Color favorable = male;
  static const Color unfavorable = action;
  static const Color undefined = mutedText;

  // Variantes oscuras. El PRD no especifica tema oscuro; se deriva del navy
  // aclarando los acentos lo justo para sostener el contraste de `RNF-22`.
  static const Color navyDeep = Color(0xFF0B1B2B);
  static const Color navySurface = Color(0xFF13293F);
  static const Color actionLight = Color(0xFFE8536B);
  static const Color mutedTextDark = Color(0xFF9BAABC);
  static const Color borderDark = Color(0xFF23394F);

  // El verde y el azul del PRD están calculados para leerse sobre blanco: sobre
  // el navy profundo del tema oscuro caen por debajo del 4,5:1 de `RNF-22`.
  // Estas variantes conservan el tono —la convención sigue siendo verde macho,
  // azul hembra— y solo suben la luminosidad lo necesario.
  static const Color maleLight = Color(0xFF4FBF8B);
  static const Color femaleLight = Color(0xFF6FA8DC);
  static const Color warningLight = Color(0xFFDFAE5F);
  static const Color unknownSexLight = mutedTextDark;
}
