import 'package:flutter/material.dart';

import '../../../../core/domain/plumage.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../l10n/generated/app_l10n.dart';

/// Traducción del catálogo de colores. Las claves viven en inglés en la base.
String plumageColorLabel(AppL10n l10n, PlumageColor color) => switch (color) {
  PlumageColor.white => l10n.colorWhite,
  PlumageColor.giro => l10n.colorGiro,
  PlumageColor.red => l10n.colorRed,
  PlumageColor.cinnamon => l10n.colorCinnamon,
  PlumageColor.yellow => l10n.colorYellow,
  PlumageColor.ash => l10n.colorAsh,
  PlumageColor.barred => l10n.colorBarred,
  PlumageColor.mottled => l10n.colorMottled,
  PlumageColor.dark => l10n.colorDark,
  PlumageColor.black => l10n.colorBlack,
};

String beakMarkLabel(AppL10n l10n, BeakMark mark) => switch (mark) {
  BeakMark.upper => l10n.beakMarkUpper,
  BeakMark.lower => l10n.beakMarkLower,
  BeakMark.left => l10n.beakMarkLeft,
  BeakMark.right => l10n.beakMarkRight,
};

/// Paleta de color de plumaje.
///
/// Muestras en cuadrícula y no un desplegable: el criador reconoce el color de
/// un vistazo, y leer diez nombres en una lista desplegable es más lento que
/// verlos. La muestra **nunca va sola** — siempre lleva su nombre (`RNF-25`),
/// porque hay colores del oficio que se distinguen por el patrón y no por el
/// tono.
class PlumagePicker extends StatelessWidget {
  const PlumagePicker({required this.selected, required this.onChanged, super.key});

  final PlumageColor? selected;
  final ValueChanged<PlumageColor?> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final theme = Theme.of(context);

    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: [
        for (final color in PlumageColor.values)
          ChoiceChip(
            selected: selected == color,
            // Tocar el ya elegido lo retira: el color es opcional y sin esto no
            // habría forma de dejarlo en blanco.
            onSelected: (_) => onChanged(selected == color ? null : color),
            avatar: Container(
              decoration: BoxDecoration(
                color: color.swatch,
                shape: BoxShape.circle,
                // El blanco sobre fondo claro necesita borde para verse.
                border: Border.all(color: theme.colorScheme.outlineVariant),
              ),
            ),
            label: Text(plumageColorLabel(l10n, color)),
          ),
      ],
    );
  }
}

/// Marca de nacimiento en el pie — cuatro posiciones por pata.
///
/// Se dibujan las dos patas por separado porque así se lee el ave: el criador
/// mira la izquierda, luego la derecha. Un campo de texto obligaría a recordar
/// una codificación que aquí se ve.
class FootMarkPicker extends StatelessWidget {
  const FootMarkPicker({required this.value, required this.onChanged, super.key});

  /// Formato almacenado: `izquierda|derecha`, posiciones separadas por comas.
  final String? value;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final left = FootMark.leftOf(value);
    final right = FootMark.rightOf(value);

    void toggle({required bool isLeft, required int position}) {
      final target = isLeft ? {...left} : {...right};
      if (!target.remove(position)) target.add(position);
      onChanged(FootMark.encode(left: isLeft ? target : left, right: isLeft ? right : target));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _FootRow(
          label: l10n.footMarkLeft,
          selected: left,
          onToggle: (position) => toggle(isLeft: true, position: position),
        ),
        const SizedBox(height: AppSpacing.sm),
        _FootRow(
          label: l10n.footMarkRight,
          selected: right,
          onToggle: (position) => toggle(isLeft: false, position: position),
        ),
      ],
    );
  }
}

class _FootRow extends StatelessWidget {
  const _FootRow({required this.label, required this.selected, required this.onToggle});

  final String label;
  final Set<int> selected;
  final ValueChanged<int> onToggle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      children: [
        SizedBox(
          width: 110,
          child: Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ),
        for (var position = 1; position <= FootMark.positions; position++)
          Padding(
            padding: const EdgeInsets.only(right: AppSpacing.xs),
            child: ChoiceChip(
              label: Text('$position'),
              selected: selected.contains(position),
              onSelected: (_) => onToggle(position),
            ),
          ),
      ],
    );
  }
}

/// Marca en el pico.
class BeakMarkPicker extends StatelessWidget {
  const BeakMarkPicker({required this.selected, required this.onChanged, super.key});

  final BeakMark? selected;
  final ValueChanged<BeakMark?> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);

    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: [
        for (final mark in BeakMark.values)
          ChoiceChip(
            label: Text(beakMarkLabel(l10n, mark)),
            selected: selected == mark,
            onSelected: (_) => onChanged(selected == mark ? null : mark),
          ),
      ],
    );
  }
}

/// Texto de la marca para la ficha: `I 1,3 · D 2`, o nada si no tiene.
String? footMarkSummary(AppL10n l10n, String? value) {
  final left = FootMark.leftOf(value);
  final right = FootMark.rightOf(value);
  if (left.isEmpty && right.isEmpty) return null;

  String side(Set<int> positions) {
    if (positions.isEmpty) return '—';
    final sorted = positions.toList()..sort();
    return sorted.join(',');
  }

  return l10n.footMarkSummary(side(left), side(right));
}
