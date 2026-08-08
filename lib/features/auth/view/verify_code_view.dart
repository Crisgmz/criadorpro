import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/error/failure_messages.dart';
import '../../../core/providers/providers.dart';
import '../../../core/router/routes.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/cp_button.dart';
import '../../../l10n/generated/app_l10n.dart';
import '../repository/auth_repository.dart';
import '../viewmodel/verify_code_viewmodel.dart';
import 'widgets/auth_scaffold.dart';
import 'widgets/otp_input.dart';

/// Pantallas 5 y 8 — las seis casillas del código.
///
/// La misma vista sirve a los dos flujos; el prototipo lo dice explícitamente
/// («mismo componente que la pantalla 5»). Lo que cambia es el
/// [VerificationPurpose]: en el alta la sesión queda abierta y el router
/// redirige a Inicio, y en la recuperación se sigue a la pantalla 9.
class VerifyCodeView extends ConsumerStatefulWidget {
  const VerifyCodeView({required this.email, required this.purpose, super.key});

  final String email;
  final VerificationPurpose purpose;

  @override
  ConsumerState<VerifyCodeView> createState() => _VerifyCodeViewState();
}

class _VerifyCodeViewState extends ConsumerState<VerifyCodeView> {
  final _codeController = TextEditingController();

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  VerifyCodeArgs get _args => (email: widget.email, purpose: widget.purpose);

  Future<void> _verify() async {
    final l10n = AppL10n.of(context);
    final viewModel = ref.read(verifyCodeViewModelProvider(_args));
    final verified = await viewModel.verify();
    if (!mounted) return;

    if (!verified) {
      final failure = viewModel.failure;
      if (failure != null) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(failureMessage(l10n, failure))));
        viewModel.clearFailure();
        _codeController.clear();
      }
      return;
    }

    switch (widget.purpose) {
      // Verificar el alta abre sesión; el `redirect` del router lleva a Inicio.
      case VerificationPurpose.signUp:
        break;
      case VerificationPurpose.passwordRecovery:
        context.go(Routes.recoverPassword);
    }
  }

  Future<void> _resend() async {
    final l10n = AppL10n.of(context);
    final viewModel = ref.read(verifyCodeViewModelProvider(_args));
    await viewModel.resend();
    if (!mounted) return;

    _codeController.clear();
    final failure = viewModel.failure;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(failure == null ? l10n.verifyCodeResent : failureMessage(l10n, failure)),
        ),
      );
    if (failure != null) viewModel.clearFailure();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final theme = Theme.of(context);
    final viewModel = ref.watch(verifyCodeViewModelProvider(_args));

    return AuthScaffold(
      title: l10n.verifyTitle,
      children: [
        // El correo va en negrita dentro de la frase: es el dato que el usuario
        // necesita comprobar antes de ir a buscar el mensaje.
        Text.rich(
          TextSpan(
            style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            children: [
              TextSpan(text: l10n.verifySubtitle),
              const TextSpan(text: ' '),
              TextSpan(
                text: widget.email,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurface,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.xl),

        OtpInput(
          controller: _codeController,
          semanticsLabel: l10n.verifyCodeFieldLabel,
          enabled: !viewModel.isLoading,
          hasError: viewModel.codeError != null || viewModel.hasError,
          onChanged: viewModel.setCode,
          onCompleted: (_) => _verify(),
        ),
        if (viewModel.codeError != null) ...[
          const SizedBox(height: AppSpacing.sm),
          Text(
            validationMessage(l10n, viewModel.codeError!),
            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error),
            textAlign: TextAlign.center,
          ),
        ],
        const SizedBox(height: AppSpacing.xl),

        CpButton(
          label: l10n.verifyAction,
          isLoading: viewModel.isLoading,
          onPressed: viewModel.isComplete ? _verify : null,
        ),
        const SizedBox(height: AppSpacing.md),

        // `RF-AUT-08` — reenvío tras la cuenta regresiva visible de 60 s.
        Center(
          child: viewModel.canResend
              ? TextButton(onPressed: _resend, child: Text(l10n.verifyResend))
              : Text(
                  l10n.verifyResendIn(viewModel.secondsLeft),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
        ),
      ],
    );
  }
}
