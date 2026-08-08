import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/generated/app_l10n.dart';
import '../providers/providers.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

/// Franja de "sin conexión".
///
/// No es una advertencia de error: la app funciona igual estando offline, así
/// que el tono es informativo y ocupa lo mínimo.
class OfflineBanner extends ConsumerWidget {
  const OfflineBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isOnline = ref.watch(isOnlineProvider).value ?? true;
    if (isOnline) return const SizedBox.shrink();

    final theme = Theme.of(context);
    // PRD §6: ámbar al 15 % y texto de 12 px. El ámbar avisa sin alarmar —
    // estar sin conexión es normal en el galpón, no un error.
    return Material(
      color: AppColors.warning.withValues(alpha: 0.15),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.cloud_off, size: 16, color: _foregroundOf(theme)),
              const SizedBox(width: AppSpacing.sm),
              Flexible(
                child: Text(
                  AppL10n.of(context).offlineBanner,
                  style: theme.textTheme.bodySmall?.copyWith(color: _foregroundOf(theme)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Sobre el ámbar claro del tema claro, el propio ámbar da el contraste que
  /// pide `RNF-22`; en oscuro hay que aclararlo o se pierde contra el fondo.
  Color _foregroundOf(ThemeData theme) {
    return theme.brightness == Brightness.light
        ? const Color(0xFF6B4712)
        : theme.colorScheme.tertiary;
  }
}
