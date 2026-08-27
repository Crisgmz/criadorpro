import 'package:flutter/material.dart';

import '../theme/app_spacing.dart';
import '../theme/semantic_colors.dart';
import 'motion.dart';

/// Aviso en línea, encima del formulario que lo provoca.
///
/// El prototipo pone el error del inicio de sesión **dentro** de la pantalla y
/// no en una franja al pie. La diferencia importa: un `SnackBar` aparece lejos
/// del campo que hay que corregir, tapa el teclado y se va solo antes de que el
/// criador levante la vista.
///
/// El tono se calcula sobre la superficie del tema en vez de fijarse: el
/// `#fdecee` del prototipo está pensado sobre blanco y en modo oscuro sería un
/// rectángulo encendido.
class CpAlert extends StatelessWidget {
  const CpAlert({required this.message, super.key, this.tone = CpAlertTone.error, this.onClose});

  final String message;
  final CpAlertTone tone;

  /// Si se pasa, aparece la equis para descartarlo.
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final semantic = context.semantic;

    final accent = switch (tone) {
      CpAlertTone.error => semantic.action,
      CpAlertTone.warning => semantic.warning,
      CpAlertTone.info => semantic.brand,
    };
    final icon = switch (tone) {
      CpAlertTone.error => Icons.error_outline,
      CpAlertTone.warning => Icons.warning_amber_rounded,
      CpAlertTone.info => Icons.info_outline,
    };

    return CpFadeUp(
      child: Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.md),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Color.alphaBlend(accent.withValues(alpha: 0.10), theme.colorScheme.surface),
          border: Border.all(color: accent.withValues(alpha: 0.45)),
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 20, color: accent),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                message,
                // El aviso también se anuncia solo: quien usa lector de
                // pantalla no lo vería aparecer (`RNF-25`).
                semanticsLabel: message,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: accent,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            if (onClose != null)
              InkResponse(
                onTap: onClose,
                child: Icon(Icons.close, size: 18, color: accent),
              ),
          ],
        ),
      ),
    );
  }
}

enum CpAlertTone { error, warning, info }
