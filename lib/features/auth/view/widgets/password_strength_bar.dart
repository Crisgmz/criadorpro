import 'package:flutter/material.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/semantic_colors.dart';
import '../../../../l10n/generated/app_l10n.dart';
import '../../model/password_strength.dart';

/// Medidor de fuerza de la contraseña — pantallas 4 y 9.
///
/// Informativo: `RV-02` es explícito en que no bloquea por sí solo. Por eso no
/// se pinta en rojo de error aunque la calificación sea débil — el rojo está
/// reservado a lo que sí impide continuar.
class PasswordStrengthBar extends StatelessWidget {
  const PasswordStrengthBar({required this.strength, super.key});

  final PasswordStrength strength;

  @override
  Widget build(BuildContext context) {
    if (strength == PasswordStrength.none) return const SizedBox.shrink();

    final l10n = AppL10n.of(context);
    final theme = Theme.of(context);

    final (color, label) = switch (strength) {
      PasswordStrength.none => (Colors.transparent, ''),
      PasswordStrength.weak => (context.semantic.warning, l10n.authPasswordStrengthWeak),
      PasswordStrength.medium => (context.semantic.female, l10n.authPasswordStrengthMedium),
      PasswordStrength.strong => (context.semantic.male, l10n.authPasswordStrengthStrong),
    };

    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.sm),
      child: Row(
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.pill),
              child: TweenAnimationBuilder<double>(
                duration: const Duration(milliseconds: 200),
                tween: Tween(begin: 0, end: strength.fraction),
                builder: (context, value, _) => LinearProgressIndicator(
                  value: value,
                  minHeight: 6,
                  backgroundColor: theme.colorScheme.surfaceContainerHighest,
                  valueColor: AlwaysStoppedAnimation<Color>(color),
                ),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          // El color no viaja solo: la etiqueta dice la calificación — `RNF-25`.
          Text(label, style: theme.textTheme.bodySmall?.copyWith(color: color)),
        ],
      ),
    );
  }
}
