import 'package:flutter/material.dart';

import '../theme/app_spacing.dart';
import 'cp_button.dart';

/// Estado vacío con una salida clara. Nunca dejamos una lista vacía sin
/// explicar qué hacer a continuación.
class CpEmptyState extends StatelessWidget {
  const CpEmptyState({
    required this.title,
    super.key,
    this.icon,
    this.iconWidget,
    this.message,
    this.actionLabel,
    this.onAction,
  }) : assert(icon != null || iconWidget != null, 'hace falta un icono');

  final IconData? icon;

  /// Para cuando el icono no es de Material — por ejemplo el símbolo de marca.
  final Widget? iconWidget;
  final String title;
  final String? message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // PRD §6: el ícono va en el color de borde, no en el de texto. Es
            // decorativo — quien informa es el título, y un gris más oscuro le
            // robaría atención.
            iconWidget ?? Icon(icon, size: 56, color: theme.colorScheme.outlineVariant),
            const SizedBox(height: AppSpacing.md),
            Text(title, style: theme.textTheme.titleMedium, textAlign: TextAlign.center),
            if (message != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                message!,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
            ],
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: AppSpacing.lg),
              // Ancho fijo de 220 px (PRD §6): a ancho completo el botón
              // dominaría una pantalla que, por definición, está vacía.
              SizedBox(
                width: 220,
                child: CpButton(label: actionLabel!, onPressed: onAction),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
