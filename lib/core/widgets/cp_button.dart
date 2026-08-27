import 'package:flutter/material.dart';

import '../theme/app_spacing.dart';
import 'motion.dart';

enum CpButtonVariant { primary, secondary, text, danger }

/// Botón de la app. Centraliza el estado de carga para que ninguna View tenga
/// que inventarse su propio spinner dentro de un botón.
class CpButton extends StatelessWidget {
  const CpButton({
    required this.label,
    super.key,
    this.onPressed,
    this.variant = CpButtonVariant.primary,
    this.icon,
    this.isLoading = false,
    this.expanded = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final CpButtonVariant variant;
  final IconData? icon;

  /// Mientras es `true` el botón se bloquea y muestra progreso.
  final bool isLoading;

  /// `false` para que ocupe solo lo que necesita (barras de acciones, diálogos).
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final enabled = onPressed != null && !isLoading;

    final child = isLoading
        ? SizedBox(
            height: 20,
            width: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              color: variant == CpButtonVariant.primary || variant == CpButtonVariant.danger
                  ? scheme.onPrimary
                  : scheme.primary,
            ),
          )
        : _Label(label: label, icon: icon);

    final button = switch (variant) {
      CpButtonVariant.primary => FilledButton(onPressed: enabled ? onPressed : null, child: child),
      CpButtonVariant.danger => FilledButton(
        onPressed: enabled ? onPressed : null,
        style: FilledButton.styleFrom(
          backgroundColor: scheme.error,
          foregroundColor: scheme.onError,
        ),
        child: child,
      ),
      CpButtonVariant.secondary => OutlinedButton(
        onPressed: enabled ? onPressed : null,
        child: child,
      ),
      CpButtonVariant.text => TextButton(onPressed: enabled ? onPressed : null, child: child),
    };

    // Se hunde al tocarlo, no al soltarlo: la tinta de Material llega tarde
    // para confirmar que el toque entró. Solo cuando está activo — un botón
    // deshabilitado que responde al dedo promete algo que no va a pasar.
    final pressable = enabled ? CpPressable(child: button) : button;

    // El ancho lo declara el botón, no el tema: un `minimumSize` infinito en el
    // tema estiraría también a los botones que viven dentro de una Row o de las
    // acciones de un diálogo, y ahí el layout no admite ancho infinito.
    if (expanded) return SizedBox(width: double.infinity, child: pressable);
    return Align(
      alignment: Alignment.centerLeft,
      child: IntrinsicWidth(child: pressable),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label({required this.label, this.icon});

  final String label;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    if (icon == null) return Text(label);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 20),
        const SizedBox(width: AppSpacing.sm),
        Flexible(child: Text(label, overflow: TextOverflow.ellipsis)),
      ],
    );
  }
}
