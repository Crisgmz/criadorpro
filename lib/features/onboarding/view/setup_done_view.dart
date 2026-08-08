import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers/providers.dart';
import '../../../core/router/routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/cp_button.dart';
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
                Container(
                  height: 96,
                  width: 96,
                  decoration: const BoxDecoration(color: AppColors.male, shape: BoxShape.circle),
                  child: const Icon(Icons.check_rounded, size: 56, color: Colors.white),
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
