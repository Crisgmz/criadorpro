import 'package:flutter/material.dart';

import '../domain/sex.dart';
import '../theme/app_spacing.dart';
import '../theme/semantic_colors.dart';
import 'sex_badge.dart';

/// Piezas compartidas del diseño.
///
/// Viven en `core/` porque la ficha, el pedigrí y las camadas pintan lo mismo:
/// la tarjeta de un ejemplar teñida por sexo, un rótulo de sección en
/// versalitas y un bloque de datos de etiqueta y valor. Repetirlas en cada
/// feature es lo que hace que a los tres meses ninguna pantalla se parezca a
/// las otras.

/// Rótulo de sección: versalitas, espaciado y gris — `GENERACIÓN 1 · PADRES`.
class CpSectionLabel extends StatelessWidget {
  const CpSectionLabel(this.text, {super.key, this.padding});

  final String text;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding:
          padding ??
          const EdgeInsets.fromLTRB(
            AppSpacing.screen,
            AppSpacing.md,
            AppSpacing.screen,
            AppSpacing.sm,
          ),
      child: Text(
        text.toUpperCase(),
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
          letterSpacing: 1.2,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// Tarjeta de un ejemplar dentro de otra pantalla: pedigrí y reproductores.
///
/// El fondo va teñido por sexo —verde macho, azul hembra— porque es la
/// convención cerrada del producto (PRD §9). El color nunca informa solo: la
/// etiqueta de rol («PADRE», «MADRE») lleva además el icono y el texto
/// (`RNF-25`).
class CpBirdCard extends StatelessWidget {
  const CpBirdCard({
    required this.sex,
    required this.name,
    super.key,
    this.role,
    this.subtitle,
    this.onTap,
  });

  /// Casilla sin ejemplar registrado: gris, sin tinte y sin acción.
  const CpBirdCard.empty({required this.name, super.key, this.role, this.subtitle})
    : sex = null,
      onTap = null;

  /// `null` pinta la casilla vacía.
  final Sex? sex;
  final String name;

  /// «PADRE», «MADRE», «ABUELO»… Va arriba, en versalitas.
  final String? role;

  /// Normalmente la placa.
  final String? subtitle;

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isEmpty = sex == null;

    final accent = isEmpty ? theme.colorScheme.outline : SexBadge.colorOf(context, sex!);
    // Tinte muy bajo sobre la superficie del tema: así el mismo 8 % funciona
    // en claro y en oscuro sin dos paletas.
    final background = isEmpty
        ? theme.colorScheme.surface
        : Color.alphaBlend(accent.withValues(alpha: 0.10), theme.colorScheme.surface);

    return Material(
      color: background,
      borderRadius: BorderRadius.circular(AppRadius.card),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.card),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            border: Border.all(color: accent.withValues(alpha: isEmpty ? 0.4 : 0.35)),
            borderRadius: BorderRadius.circular(AppRadius.card),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (role != null) ...[
                Row(
                  children: [
                    if (!isEmpty) ...[
                      Icon(SexBadge.iconOf(sex!), size: 16, color: accent),
                      const SizedBox(width: AppSpacing.xs),
                    ],
                    Flexible(
                      child: Text(
                        role!.toUpperCase(),
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: isEmpty ? theme.colorScheme.onSurfaceVariant : accent,
                          letterSpacing: 1,
                          fontWeight: FontWeight.w600,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),
              ],
              Text(
                name,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: isEmpty ? theme.colorScheme.onSurfaceVariant : null,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (subtitle != null)
                Text(
                  subtitle!,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Bloque de datos: etiqueta a la izquierda, valor a la derecha, separados.
class CpDataCard extends StatelessWidget {
  const CpDataCard({required this.rows, super.key, this.margin});

  final List<CpDataRow> rows;
  final EdgeInsetsGeometry? margin;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      margin: margin ?? const EdgeInsets.symmetric(horizontal: AppSpacing.screen),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border.all(color: theme.colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      child: Column(
        children: [
          for (final (index, row) in rows.indexed) ...[
            if (index > 0) Divider(height: 1, color: theme.colorScheme.outlineVariant),
            row,
          ],
        ],
      ),
    );
  }
}

class CpDataRow extends StatelessWidget {
  const CpDataRow({required this.label, required this.value, super.key, this.valueColor});

  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      // 12 y no 16: con 16, ocho filas ocupaban pantalla y media y el criador
      // tenía que desplazarse para ver datos que caben de una vez.
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          // El valor va a tamaño de cuerpo y la etiqueta a secundario: el dato
          // es el contenido, el rótulo solo lo nombra.
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: theme.textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.w600,
                color: valueColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Aviso informativo dentro del contenido: círculo con la «i» y el texto.
///
/// No es `CpAlert`: aquel señala algo que hay que corregir y va teñido. Este
/// explica cómo leer lo que hay en pantalla y no debe llamar la atención.
class CpInfoCard extends StatelessWidget {
  const CpInfoCard({required this.message, super.key, this.icon = Icons.info_outline});

  final String message;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.screen),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border.all(color: theme.colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              message,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Tarjeta de acción destacada: icono en cuadro teñido, título, apoyo y
/// chevrón. Es el «Ver pedigrí completo» de la ficha.
class CpActionCard extends StatelessWidget {
  const CpActionCard({
    required this.icon,
    required this.title,
    required this.onTap,
    super.key,
    this.subtitle,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final brand = context.semantic.brand;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.screen),
      child: Material(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.card),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              // Borde de marca y no gris: es la acción principal de la
              // pestaña, y con el borde normal se perdería entre las tarjetas
              // de datos que tiene debajo.
              border: Border.all(color: brand, width: 1.5),
              borderRadius: BorderRadius.circular(AppRadius.card),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: brand.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  child: Icon(icon, color: brand),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: theme.textTheme.titleMedium),
                      if (subtitle != null)
                        Text(
                          subtitle!,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, color: theme.colorScheme.onSurfaceVariant),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
