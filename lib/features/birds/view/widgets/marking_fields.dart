import 'package:flutter/material.dart';

import '../../../../core/domain/markings.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/semantic_colors.dart';
import '../../../../l10n/generated/app_l10n.dart';

/// Marca de nacimiento — tres zonas con sus posiciones dibujadas encima.
///
/// El criador no memoriza «posición 3»: mira el pie derecho y toca el punto.
/// Por eso se dibujan las dos patas y el pico, y los números van **sobre** el
/// dibujo. Una lista de casillas numeradas obligaría a aprender una
/// codificación que aquí se ve.
class BirthMarkPicker extends StatelessWidget {
  const BirthMarkPicker({required this.value, required this.onChanged, super.key});

  /// `1,4`, `none`, o nulo si todavía no se ha dicho nada.
  final String? value;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final theme = Theme.of(context);
    final hasNoMark = BirthMark.isNone(value);
    final positions = BirthMark.positionsOf(value);
    final zones = BirthMark.zonesOf(value);

    void toggle(int position) {
      final next = {...positions};
      if (!next.remove(position)) next.add(position);
      onChanged(BirthMark.encode(positions: next, hasNoMark: false));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                l10n.markingNoMark,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            // «Sin marca» no es lo mismo que dejarlo en blanco: en blanco es
            // «no se ha dicho», esto es «se miró y no tiene».
            Switch(
              value: hasNoMark,
              onChanged: (on) => onChanged(BirthMark.encode(positions: {}, hasNoMark: on)),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),

        // Atenuado en lugar de oculto: así se ve que las marcas siguen ahí,
        // solo que no aplican.
        Opacity(
          opacity: hasNoMark ? 0.4 : 1,
          child: IgnorePointer(
            ignoring: hasNoMark,
            child: Column(
              children: [
                Row(
                  children: [
                    for (final zone in MarkZone.values) ...[
                      Expanded(
                        child: _ZoneCard(
                          zone: zone,
                          isActive: zones.contains(zone),
                          selected: positions,
                          onToggle: toggle,
                        ),
                      ),
                      if (zone != MarkZone.values.last) const SizedBox(width: AppSpacing.sm),
                    ],
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                _MarkCode(value: value, hasNoMark: hasNoMark),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ZoneCard extends StatelessWidget {
  const _ZoneCard({
    required this.zone,
    required this.isActive,
    required this.selected,
    required this.onToggle,
  });

  final MarkZone zone;
  final bool isActive;
  final Set<int> selected;
  final ValueChanged<int> onToggle;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final theme = Theme.of(context);
    // Ámbar de la zona marcada, como en el prototipo. No es el rojo de acción:
    // marcar no es una acción destructiva ni primaria, es un estado.
    final semantic = context.semantic;

    // El dibujo inactivo se apoya en el borde del tema para que en oscuro no
    // quede una pata blanca sobre una tarjeta navy.
    final lineColor = isActive ? semantic.markLabel : theme.colorScheme.outline;
    final fillColor = isActive ? semantic.markFill : theme.colorScheme.surfaceContainerHigh;

    final label = switch (zone) {
      MarkZone.leftFoot => l10n.markingLeftFoot,
      MarkZone.rightFoot => l10n.markingRightFoot,
      MarkZone.beak => l10n.markingBeak,
    };

    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xs,
        AppSpacing.sm,
        AppSpacing.xs,
        AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: isActive ? semantic.markSurface : theme.cardTheme.color,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(
          color: isActive ? semantic.markBorder : theme.colorScheme.outlineVariant,
          width: 2,
        ),
      ),
      child: Column(
        children: [
          AspectRatio(
            aspectRatio: 100 / 140,
            child: LayoutBuilder(
              builder: (context, constraints) => Stack(
                alignment: Alignment.center,
                children: [
                  CustomPaint(
                    size: Size(constraints.maxWidth, constraints.maxHeight),
                    painter: zone == MarkZone.beak
                        ? _BeakPainter(line: lineColor, fill: fillColor)
                        : _FootPainter(
                            line: lineColor,
                            fill: fillColor,
                            flip: zone == MarkZone.rightFoot,
                          ),
                  ),
                  for (final (index, position) in zone.positions.indexed)
                    Align(
                      // Las dos posiciones de cada zona, a izquierda y derecha
                      // sobre el dibujo, como en el prototipo.
                      alignment: Alignment(
                        index == 0 ? -0.45 : 0.45,
                        zone == MarkZone.beak ? 0.25 : -0.4,
                      ),
                      child: _MarkDot(
                        position: position,
                        isOn: selected.contains(position),
                        surface: isActive
                            ? semantic.markSurface
                            : (theme.cardTheme.color ?? theme.colorScheme.surface),
                        onTap: () => onToggle(position),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            label.toUpperCase(),
            textAlign: TextAlign.center,
            style: theme.textTheme.labelSmall?.copyWith(
              color: isActive ? semantic.markLabel : theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _MarkDot extends StatelessWidget {
  const _MarkDot({
    required this.position,
    required this.isOn,
    required this.surface,
    required this.onTap,
  });

  final int position;
  final bool isOn;

  /// Fondo de la tarjeta en la que va. Sin esto, un punto sin marcar dibujado
  /// con el `surface` del tema salía negro sobre la tarjeta ámbar en oscuro.
  final Color surface;

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Semantics(
      selected: isOn,
      button: true,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Container(
          width: 26,
          height: 26,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isOn ? theme.colorScheme.primary : surface,
            shape: BoxShape.circle,
            border: Border.all(
              color: isOn ? Colors.white : theme.colorScheme.outlineVariant,
              width: isOn ? 2 : 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: (isOn ? theme.colorScheme.primary : Colors.black).withValues(alpha: 0.2),
                blurRadius: isOn ? 8 : 3,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Text(
            '$position',
            style: theme.textTheme.labelSmall?.copyWith(
              color: isOn ? theme.colorScheme.onPrimary : theme.colorScheme.onSurfaceVariant,
              letterSpacing: 0,
            ),
          ),
        ),
      ),
    );
  }
}

/// Píldora con el código resultante: `1 · 4`.
class _MarkCode extends StatelessWidget {
  const _MarkCode({required this.value, required this.hasNoMark});

  final String? value;
  final bool hasNoMark;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final theme = Theme.of(context);
    final code = BirthMark.codeOf(value);

    final text = code != null
        ? l10n.markingCode(code)
        : (hasNoMark ? l10n.markingNoMarkSet : l10n.markingHint);
    final isSet = code != null;

    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.xs),
        decoration: BoxDecoration(
          color: isSet ? theme.colorScheme.secondary : theme.colorScheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(AppRadius.pill),
        ),
        child: Text(
          text,
          style: theme.textTheme.labelMedium?.copyWith(
            color: isSet ? theme.colorScheme.onSecondary : theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

/// Pata esquemática: cinco trazos desde el tarso. Se dibuja con `CustomPaint` y
/// no con una imagen porque cambia de color al marcarse y tiene que escalar sin
/// pixelarse.
class _FootPainter extends CustomPainter {
  const _FootPainter({required this.line, required this.fill, required this.flip});

  final Color line;
  final Color fill;
  final bool flip;

  static const List<(Offset, Offset, double)> _limbs = [
    (Offset(50, 78), Offset(50, 124), 18),
    (Offset(50, 78), Offset(50, 24), 16),
    (Offset(50, 78), Offset(16, 47), 14),
    (Offset(50, 78), Offset(84, 47), 14),
    (Offset(50, 78), Offset(28, 93), 12),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 100;
    canvas.save();
    if (flip) {
      canvas
        ..translate(size.width, 0)
        ..scale(-1, 1);
    }
    canvas.scale(scale);

    // Dos pasadas: la ancha hace de contorno y la estrecha, de relleno.
    for (final (color, extra) in [(line, 6.0), (fill, 0.0)]) {
      final paint = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;
      for (final (from, to, width) in _limbs) {
        paint.strokeWidth = width + extra;
        canvas.drawLine(from, to, paint);
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_FootPainter old) => old.line != line || old.fill != fill || old.flip != flip;
}

/// Pico esquemático visto de frente, con las dos fosas nasales.
class _BeakPainter extends CustomPainter {
  const _BeakPainter({required this.line, required this.fill});

  final Color line;
  final Color fill;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 100;
    canvas
      ..save()
      ..scale(scale);

    final path = Path()
      ..moveTo(50, 20)
      ..lineTo(92, 54)
      ..lineTo(86, 92)
      ..lineTo(50, 124)
      ..lineTo(14, 92)
      ..lineTo(8, 54)
      ..close();

    canvas
      ..drawPath(path, Paint()..color = fill)
      ..drawPath(
        path,
        Paint()
          ..color = line
          ..style = PaintingStyle.stroke
          ..strokeWidth = 7
          ..strokeJoin = StrokeJoin.round,
      );

    for (final (cx, angle) in [(39.0, -0.21), (61.0, 0.21)]) {
      canvas
        ..save()
        ..translate(cx, 55)
        ..rotate(angle)
        ..drawOval(
          Rect.fromCenter(center: Offset.zero, width: 7.6, height: 19),
          Paint()..color = line,
        )
        ..restore();
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_BeakPainter old) => old.line != line || old.fill != fill;
}

/// Cintas de ala: una paleta por ala.
class WingBandPicker extends StatelessWidget {
  const WingBandPicker({
    required this.left,
    required this.right,
    required this.onLeftChanged,
    required this.onRightChanged,
    super.key,
  });

  final WingBand? left;
  final WingBand? right;
  final ValueChanged<WingBand?> onLeftChanged;
  final ValueChanged<WingBand?> onRightChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);

    return Column(
      children: [
        _WingRow(label: l10n.markingLeftWing, selected: left, onChanged: onLeftChanged),
        const SizedBox(height: AppSpacing.sm),
        _WingRow(label: l10n.markingRightWing, selected: right, onChanged: onRightChanged),
      ],
    );
  }
}

class _WingRow extends StatelessWidget {
  const _WingRow({required this.label, required this.selected, required this.onChanged});

  final String label;
  final WingBand? selected;
  final ValueChanged<WingBand?> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: theme.colorScheme.outlineVariant, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: theme.textTheme.titleSmall),
          const SizedBox(height: AppSpacing.sm),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // «Ninguna» primero y con borde discontinuo: es una opción, no la
              // ausencia de opciones.
              _BandDot(
                color: null,
                isSelected: selected == null,
                tooltip: l10n.markingBandNone,
                onTap: () => onChanged(null),
              ),
              for (final band in WingBand.values)
                _BandDot(
                  color: band.color,
                  isSelected: selected == band,
                  tooltip: bandLabel(l10n, band),
                  onTap: () => onChanged(band),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BandDot extends StatelessWidget {
  const _BandDot({
    required this.isSelected,
    required this.tooltip,
    required this.onTap,
    this.color,
  });

  final Color? color;
  final bool isSelected;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Tooltip(
      // El color no puede ser el único portador de significado (`RNF-25`): al
      // no caber la etiqueta, va como descripción accesible y como tooltip.
      message: tooltip,
      child: Semantics(
        label: tooltip,
        selected: isSelected,
        button: true,
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              // Doble anillo para el seleccionado: un borde de color se
              // confundiría con la propia cinta.
              border: isSelected ? Border.all(color: theme.colorScheme.secondary, width: 2) : null,
            ),
            child: Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: color ?? theme.colorScheme.surface,
                shape: BoxShape.circle,
                border: Border.all(
                  color: color == null
                      ? theme.colorScheme.outline
                      : Colors.black.withValues(alpha: 0.12),
                  width: 1.5,
                ),
              ),
              child: color == null
                  ? Icon(Icons.close, size: 14, color: theme.colorScheme.onSurfaceVariant)
                  : null,
            ),
          ),
        ),
      ),
    );
  }
}

String bandLabel(AppL10n l10n, WingBand band) => switch (band) {
  WingBand.red => l10n.bandRed,
  WingBand.pink => l10n.bandPink,
  WingBand.blue => l10n.bandBlue,
  WingBand.green => l10n.bandGreen,
  WingBand.yellow => l10n.bandYellow,
};

/// Lectura de las dos cintas para la ficha: `Roja · Azul`.
String? wingBandSummary(AppL10n l10n, String? left, String? right) {
  final l = WingBand.fromId(left);
  final r = WingBand.fromId(right);
  if (l == null && r == null) return null;
  return [if (l != null) bandLabel(l10n, l), if (r != null) bandLabel(l10n, r)].join(' · ');
}
