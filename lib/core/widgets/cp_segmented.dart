import 'package:flutter/material.dart';

import '../theme/app_spacing.dart';
import 'motion.dart';

/// Selector de píldora del diseño: la opción activa es una tarjeta blanca
/// elevada sobre un carril gris.
///
/// No es `SegmentedButton` de Material: aquel dibuja un contorno continuo con
/// palomita, y en el prototipo el activo se lee como una pestaña que sale
/// hacia el usuario. Se usa igual en las pestañas de la ficha y en el selector
/// de generaciones del pedigrí, que es lo que hace que las dos pantallas
/// parezcan de la misma app.
class CpSegmented<T> extends StatelessWidget {
  const CpSegmented({
    required this.segments,
    required this.selected,
    required this.onChanged,
    super.key,
    this.height = 48,
  });

  final List<CpSegment<T>> segments;
  final T selected;
  final ValueChanged<T> onChanged;
  final double height;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      height: height,
      padding: const EdgeInsets.all(AppSpacing.xs),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      child: Row(
        children: [
          for (final segment in segments)
            Expanded(
              child: _Segment(
                segment: segment,
                isSelected: segment.value == selected,
                onTap: segment.enabled ? () => onChanged(segment.value) : null,
              ),
            ),
        ],
      ),
    );
  }
}

class CpSegment<T> {
  const CpSegment({required this.value, required this.label, this.enabled = true});

  final T value;
  final String label;

  /// Deshabilitado se **ve**, no se esconde: una opción que el plan no permite
  /// tiene que seguir diciendo que existe (`RF-PED-03`).
  final bool enabled;
}

class _Segment<T> extends StatelessWidget {
  const _Segment({required this.segment, required this.isSelected, required this.onTap});

  final CpSegment<T> segment;
  final bool isSelected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final color = switch ((isSelected, onTap == null)) {
      (_, true) => theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
      (true, _) => theme.colorScheme.onSurface,
      (false, _) => theme.colorScheme.onSurfaceVariant,
    };

    return CpPressable(
      child: AnimatedContainer(
        duration: CpMotion.content,
        curve: CpMotion.easeOut,
        decoration: BoxDecoration(
          color: isSelected ? theme.colorScheme.surface : Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(AppRadius.md),
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                child: Text(
                  segment.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: color,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
