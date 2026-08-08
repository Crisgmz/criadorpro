import 'package:flutter/material.dart';

import '../domain/sex.dart';
import '../theme/app_spacing.dart';
import '../theme/semantic_colors.dart';

/// Distintivo de sexo: verde macho, azul hembra. Es el mismo código de color en
/// listas, fichas y pedigrí, así que siempre se usa este widget.
///
/// El color nunca va solo: lleva icono y texto para no depender de la
/// percepción cromática del usuario.
class SexBadge extends StatelessWidget {
  const SexBadge({required this.sex, required this.label, super.key, this.compact = false});

  final Sex sex;

  /// Etiqueta ya traducida ("Macho" / "Hembra" / "Sin definir").
  final String label;

  /// `true` deja solo el icono y el color, para celdas estrechas del pedigrí.
  final bool compact;

  /// PRD §6 — el fondo es el color de sexo al 12 %.
  static const double _backgroundOpacity = 0.12;

  /// Necesita el contexto porque el verde y el azul del PRD se aclaran en tema
  /// oscuro para sostener `RNF-22`; el tono —y con él la convención— no cambia.
  static Color colorOf(BuildContext context, Sex sex) => switch (sex) {
    Sex.male => context.semantic.male,
    Sex.female => context.semantic.female,
    Sex.unknown => context.semantic.unknownSex,
  };

  static IconData iconOf(Sex sex) => switch (sex) {
    Sex.male => Icons.male,
    Sex.female => Icons.female,
    Sex.unknown => Icons.help_outline,
  };

  @override
  Widget build(BuildContext context) {
    final color = colorOf(context, sex);
    final icon = iconOf(sex);

    if (compact) {
      return Tooltip(
        message: label,
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.xs),
          decoration: BoxDecoration(
            color: color.withValues(alpha: _backgroundOpacity),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 16, color: color),
        ),
      );
    }

    // PRD §6: fondo del color de sexo al 12 %, texto del color pleno, radio 6.
    // No es una píldora — el radio corto la distingue de los filtros y las
    // etiquetas de estado, que sí lo son.
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: _backgroundOpacity),
        borderRadius: BorderRadius.circular(AppRadius.badge),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: AppSpacing.xs),
          Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.labelSmall?.copyWith(color: color, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}
