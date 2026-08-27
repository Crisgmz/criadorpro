import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers/providers.dart';
import '../../../core/router/routes.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/brand.dart';
import '../../../core/widgets/cp_alert.dart';
import '../../../core/widgets/cp_button.dart';
import '../../../l10n/generated/app_l10n.dart';

/// Pantalla 3 — bienvenida.
///
/// `RF-AUT-11` exige que, si se ofrece acceso con Google, iOS ofrezca también
/// «Iniciar sesión con Apple». Es requisito de App Store, no una preferencia:
/// por eso los dos botones se muestran juntos y ninguno se activa por separado.
class WelcomeView extends ConsumerWidget {
  const WelcomeView({super.key});

  /// Apple solo aparece donde su SDK existe.
  static bool get _showAppleButton => !kIsWeb && Platform.isIOS;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppL10n.of(context);
    final theme = Theme.of(context);
    final isBackendConfigured = ref.watch(authRepositoryProvider).isEnabled;

    void notYetAvailable() => ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(l10n.errorAuthProviderUnavailable)));

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: AppSpacing.xl),
                  const Center(child: BrandLockup(width: 240)),
                  const SizedBox(height: AppSpacing.lg),
                  Text(
                    l10n.welcomeTitle,
                    style: theme.textTheme.headlineMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    l10n.welcomeSubtitle,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSpacing.xxl),

                  // Un solo componente de aviso en toda la app: el mismo que
                  // usa el error del inicio de sesión, en tono de advertencia.
                  if (!isBackendConfigured)
                    CpAlert(message: l10n.errorAuthNotConfigured, tone: CpAlertTone.warning),

                  CpButton(
                    label: l10n.welcomeCreateAccount,
                    onPressed: isBackendConfigured ? () => context.push(Routes.signUp) : null,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  CpButton(
                    label: l10n.welcomeSignIn,
                    variant: CpButtonVariant.secondary,
                    onPressed: () => context.push(Routes.login),
                  ),

                  const SizedBox(height: AppSpacing.lg),
                  _OrDivider(label: l10n.welcomeOr),
                  const SizedBox(height: AppSpacing.lg),

                  // `RF-AUT-11` — pendientes de credenciales de plataforma. Se
                  // muestran deshabilitados en lugar de ocultarse para que la
                  // pantalla ya sea la definitiva cuando se activen.
                  CpButton(
                    label: l10n.welcomeContinueWithGoogle,
                    variant: CpButtonVariant.secondary,
                    icon: Icons.g_mobiledata,
                    onPressed: notYetAvailable,
                  ),
                  if (_showAppleButton) ...[
                    const SizedBox(height: AppSpacing.sm),
                    CpButton(
                      label: l10n.welcomeContinueWithApple,
                      variant: CpButtonVariant.secondary,
                      icon: Icons.apple,
                      onPressed: notYetAvailable,
                    ),
                  ],

                  const SizedBox(height: AppSpacing.xl),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _OrDivider extends StatelessWidget {
  const _OrDivider({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        const Expanded(child: Divider()),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          child: Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ),
        const Expanded(child: Divider()),
      ],
    );
  }
}
