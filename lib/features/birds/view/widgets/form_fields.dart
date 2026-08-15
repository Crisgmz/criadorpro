import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/domain/sex.dart';
import '../../../../core/router/routes.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/sex_badge.dart';
import '../../../../l10n/generated/app_l10n.dart';
import '../../model/bird.dart';
import '../parent_picker_view.dart';

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

/// Selector de padre o madre — `RF-REG-11`.
///
/// Abre la pantalla 18 en lugar de desplegar una lista: un `Dropdown` deja de
/// servir en cuanto el criadero pasa de veinte ejemplares, y no permite ni
/// buscar ni dar de alta al progenitor que falta. Al volver, el formulario
/// sigue montado con todo lo capturado (CU-02 alterno A).
class ParentField extends StatelessWidget {
  const ParentField({
    required this.label,
    required this.sex,
    required this.value,
    required this.onChanged,
    super.key,
    this.excludeId,
  });

  final String label;
  final Sex sex;
  final Bird? value;

  /// El propio ejemplar cuando se edita: nadie puede ser su propio padre.
  final String? excludeId;

  final ValueChanged<Bird?> onChanged;

  Future<void> _pick(BuildContext context) async {
    final selection = await context.push<ParentSelection>(
      Routes.parentPicker(sex.id, excludeId: excludeId),
    );
    // `null` es «cancelé»; un `ParentSelection` con `bird` nulo es «sin
    // registrar», que sí es una elección y debe aplicarse.
    if (selection != null) onChanged(selection.bird);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final bird = value;

    return InkWell(
      onTap: () => _pick(context),
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(SexBadge.iconOf(sex), color: SexBadge.colorOf(context, sex)),
          suffixIcon: const Icon(Icons.chevron_right),
        ),
        child: Text(
          // La placa siempre delante: es como el criador los distingue.
          bird == null
              ? l10n.parentPickerNone
              : (bird.name == null ? '#${bird.plate}' : '#${bird.plate} · ${bird.name}'),
          overflow: TextOverflow.ellipsis,
        ),
      ),
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
