import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/app_config.dart';
import '../../../core/error/failure_messages.dart';
import '../../../core/providers/providers.dart';
import '../../../core/router/routes.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/semantic_colors.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/cp_button.dart';
import '../../../core/widgets/cp_text_field.dart';
import '../../../core/widgets/motion.dart';
import '../../../l10n/generated/app_l10n.dart';
import 'widgets/auth_scaffold.dart';
import 'widgets/password_strength_bar.dart';

/// Pantalla 9 — nueva contraseña, y el modal de éxito de la pantalla 10.
class NewPasswordView extends ConsumerStatefulWidget {
  const NewPasswordView({super.key});

  @override
  ConsumerState<NewPasswordView> createState() => _NewPasswordViewState();
}

class _NewPasswordViewState extends ConsumerState<NewPasswordView> {
  Future<void> _submit() async {
    final l10n = AppL10n.of(context);
    final viewModel = ref.read(newPasswordViewModelProvider);
    final updated = await viewModel.submit();
    if (!mounted) return;

    if (!updated) {
      final failure = viewModel.failure;
      if (failure != null) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(failureMessage(l10n, failure))));
        viewModel.clearFailure();
      }
      return;
    }

    await _showSuccessDialog();
    if (mounted) context.go(Routes.login);
  }

  /// Pantalla 10 — modal de éxito con marca de verificación. `RF-AUT-13`: de
  /// aquí se va a iniciar sesión, nunca directamente a la aplicación.
  Future<void> _showSuccessDialog() {
    final l10n = AppL10n.of(context);

    return showCpDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        // Disco verde claro con la palomita dibujándose dentro, como el
        // prototipo: la confirmación se ve ocurrir, no aparece ya hecha.
        icon: SizedBox(
          height: 76,
          width: 76,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Color.alphaBlend(
                context.semantic.male.withValues(alpha: 0.14),
                Theme.of(context).colorScheme.surface,
              ),
              shape: BoxShape.circle,
            ),
            child: Center(child: CpDrawCheck(color: context.semantic.male, size: 38)),
          ),
        ),
        title: Text(l10n.newPasswordSuccessTitle, textAlign: TextAlign.center),
        content: Text(l10n.newPasswordSuccessBody, textAlign: TextAlign.center),
        actions: [
          // Las acciones de un diálogo van en una OverflowBar, que no acota el
          // ancho: un botón expandido no cabe ahí.
          CpButton(
            label: l10n.welcomeSignIn,
            expanded: false,
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final viewModel = ref.watch(newPasswordViewModelProvider);

    return AuthScaffold(
      title: l10n.newPasswordTitle,
      subtitle: l10n.newPasswordSubtitle,
      // Volver atrás aquí dejaría una sesión de recuperación a medias, así que
      // la salida es explícita: se cancela y se vuelve al inicio de sesión.
      showBackButton: false,
      children: [
        AutofillGroup(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ValidateOnBlur(
                onBlur: viewModel.validatePassword,
                builder: (context, focusNode) => CpTextField.password(
                  label: l10n.newPasswordLabel,
                  focusNode: focusNode,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.newPassword],
                  helper: l10n.authPasswordRule(AppConfig.minPasswordLength),
                  errorText: _messageFor(l10n, viewModel.passwordError),
                  onChanged: viewModel.setPassword,
                ),
              ),
              PasswordStrengthBar(strength: viewModel.passwordStrength),
              const SizedBox(height: AppSpacing.md),
              ValidateOnBlur(
                onBlur: viewModel.validateConfirmation,
                builder: (context, focusNode) => CpTextField.password(
                  label: l10n.authPasswordConfirmation,
                  focusNode: focusNode,
                  textInputAction: TextInputAction.done,
                  errorText: _messageFor(l10n, viewModel.confirmationError),
                  onChanged: viewModel.setConfirmation,
                  onSubmitted: (_) => _submit(),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        CpButton(label: l10n.newPasswordSave, isLoading: viewModel.isLoading, onPressed: _submit),
        const SizedBox(height: AppSpacing.sm),
        CpButton(
          label: l10n.commonCancel,
          variant: CpButtonVariant.text,
          onPressed: viewModel.isLoading ? null : () => context.go(Routes.login),
        ),
      ],
    );
  }

  String? _messageFor(AppL10n l10n, ValidationError? error) =>
      error == null ? null : validationMessage(l10n, error);
}
