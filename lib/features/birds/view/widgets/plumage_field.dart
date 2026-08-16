import 'package:flutter/material.dart';

import '../../../../core/domain/plumage_color.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../l10n/generated/app_l10n.dart';

String plumageColorLabel(AppL10n l10n, PlumageColor color) => switch (color) {
  PlumageColor.giro => l10n.colorGiro,
  PlumageColor.red => l10n.colorRed,
  PlumageColor.cinnamon => l10n.colorCinnamon,
  PlumageColor.white => l10n.colorWhite,
  PlumageColor.mottled => l10n.colorMottled,
  PlumageColor.ash => l10n.colorAsh,
  PlumageColor.barred => l10n.colorBarred,
  PlumageColor.yellow => l10n.colorYellow,
  PlumageColor.dark => l10n.colorDark,
  PlumageColor.black => l10n.colorBlack,
};

/// Muestra de color. Nunca va sola — siempre acompaña a un nombre (`RNF-25`).
class PlumageSwatch extends StatelessWidget {
  const PlumageSwatch({required this.color, super.key, this.size = 18});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      color: color,
      shape: BoxShape.circle,
      // El blanco sobre fondo claro necesita borde para verse.
      border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
    ),
  );
}

/// Color del plumaje — desplegable con la muestra en cada opción.
///
/// Desplegable y no una cuadrícula de muestras: el color es un dato secundario
/// del ejemplar, y diez círculos ocupando media pantalla le darían un peso que
/// no tiene frente a la placa o al sexo.
class PlumageField extends StatelessWidget {
  const PlumageField({required this.selected, required this.onChanged, super.key});

  final PlumageColor? selected;
  final ValueChanged<PlumageColor?> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);

    return DropdownButtonFormField<PlumageColor?>(
      initialValue: selected,
      isExpanded: true,
      decoration: InputDecoration(labelText: l10n.fieldColor),
      items: [
        // El color es opcional: sin esta entrada no habría forma de dejarlo en
        // blanco después de haber elegido uno.
        DropdownMenuItem(value: null, child: Text(l10n.commonNone)),
        for (final color in PlumageColor.values)
          DropdownMenuItem(
            value: color,
            child: Row(
              children: [
                PlumageSwatch(color: color.swatch),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(plumageColorLabel(l10n, color), overflow: TextOverflow.ellipsis),
                ),
              ],
            ),
          ),
      ],
      onChanged: onChanged,
    );
  }
}
