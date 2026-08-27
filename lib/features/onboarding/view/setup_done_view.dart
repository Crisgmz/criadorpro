import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers/providers.dart';
import '../../../core/router/routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/cp_button.dart';
import '../../../core/widgets/motion.dart';
import '../../../l10n/generated/app_l10n.dart';

/// Pantalla 14 — «¡Todo listo, Criador!».
///
/// `RF-ONB-06`: confirma la configuración terminada mostrando el nombre del
/// criadero. Es la única pantalla de felicitación del producto, así que no se
/// repite el patrón en ningún otro sitio.
class SetupDoneView extends ConsumerWidget {
  const SetupDoneView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppL10n.of(context);
    final theme = Theme.of(context);
    final farmName = ref.watch(currentProfileProvider).value?.farmName;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
        systemNavigationBarColor: AppColors.navy,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: AppColors.navy,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              children: [
                const Spacer(),
                // Dos anillos, como el prototipo: un halo tenue de 110 y el
                // disco verde de 78 dentro. El halo es lo que separa el verde
                // del navy sin ponerle un borde.
                const CpPop(
                  child: SizedBox(
                    height: 110,
                    width: 110,
                    child: DecoratedBox(
                      decoration: BoxDecoration(color: Color(0x14FFFFFF), shape: BoxShape.circle),
                      child: Center(
                        child: SizedBox(
                          height: 78,
                          width: 78,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: AppColors.male,
                              shape: BoxShape.circle,
                            ),
                            // La palomita se dibuja después del rebote: leído
                            // en orden, dice «hecho» al final y no de entrada.
                            child: Center(child: CpDrawCheck(color: Colors.white, size: 40)),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                Text(
                  l10n.setupDoneTitle,
                  style: theme.textTheme.headlineMedium?.copyWith(color: Colors.white),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  farmName == null ? l10n.setupDoneBodyFallback : l10n.setupDoneBody(farmName),
                  style: theme.textTheme.bodyLarge?.copyWith(color: Colors.white70),
                  textAlign: TextAlign.center,
                ),
                const Spacer(),
                CpButton(label: l10n.setupDoneAction, onPressed: () => context.go(Routes.home)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
