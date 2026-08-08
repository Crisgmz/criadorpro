import 'package:flutter/material.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../l10n/generated/app_l10n.dart';
import '../../model/bird.dart';

/// Piezas compartidas por los formularios del módulo de registros.
///
/// Viven aquí y no dentro de una pantalla porque el alta de ejemplar y el
/// registro de camada piden exactamente los mismos datos de origen: si el
/// selector de progenitores se comportara distinto en cada una, el criador
/// tendría que aprender dos formularios para una misma idea.

/// Rótulo de agrupador: mayúsculas con tracking — PRD §6.
class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
    child: Text(text.toUpperCase(), style: AppTypography.sectionLabel(context)),
  );
}

/// Selector de padre o madre entre los ejemplares del criadero.
///
/// Los candidatos ya vienen filtrados por sexo desde el repositorio (`RV-10`):
/// la pantalla no puede ofrecer una hembra como padre.
class ParentDropdown extends StatelessWidget {
  const ParentDropdown({
    required this.label,
    required this.value,
    required this.candidates,
    required this.onChanged,
    super.key,
  });

  final String label;
  final String? value;
  final List<Bird> candidates;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    // Si el progenitor guardado ya no está entre los candidatos (por ejemplo,
    // se dio de baja), no lo preseleccionamos para no romper el Dropdown.
    final safeValue = candidates.any((bird) => bird.id == value) ? value : null;

    return DropdownButtonFormField<String?>(
      initialValue: safeValue,
      isExpanded: true,
      decoration: InputDecoration(labelText: label),
      items: [
        DropdownMenuItem(value: null, child: Text(l10n.commonNone)),
        for (final bird in candidates)
          DropdownMenuItem(
            value: bird.id,
            // La placa siempre delante: es como el criador los distingue.
            child: Text(
              bird.name == null ? '#${bird.plate}' : '#${bird.plate} · ${bird.name}',
              overflow: TextOverflow.ellipsis,
            ),
          ),
      ],
      onChanged: onChanged,
    );
  }
}

/// Aviso en línea bajo un campo: la regla se cumple pero conviene mirarla.
///
/// `RV-08` y `RV-12` advierten sin bloquear, así que no puede usar el rojo de
/// error — el usuario debe poder guardar igualmente.
class InlineWarning extends StatelessWidget {
  const InlineWarning({required this.message, super.key});

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.xs, left: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, size: 16, color: theme.colorScheme.tertiary),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Text(
              message,
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.tertiary),
            ),
          ),
        ],
      ),
    );
  }
}

/// Campo de fecha: abre el calendario y muestra la elegida ya formateada.
///
/// No se escribe a mano a propósito — `dd/mm/aaaa` tecleado en un galpón, con
/// una mano ocupada, es una fuente de errores que el calendario elimina.
class DateField extends StatelessWidget {
  const DateField({
    required this.label,
    required this.value,
    required this.formatted,
    required this.onTap,
    super.key,
    this.onClear,
    this.errorText,
  });

  final String label;
  final DateTime? value;
  final String formatted;
  final VoidCallback onTap;
  final VoidCallback? onClear;
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          errorText: errorText,
          prefixIcon: const Icon(Icons.event_outlined),
          suffixIcon: (value == null || onClear == null)
              ? null
              : IconButton(icon: const Icon(Icons.clear), onPressed: onClear),
        ),
        child: Text(value == null ? l10n.commonOptional : formatted),
      ),
    );
  }
}
