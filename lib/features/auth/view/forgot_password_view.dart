import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/error/failure_messages.dart';
import '../../../core/providers/providers.dart';
import '../../../core/router/routes.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/cp_button.dart';
import '../../../core/widgets/cp_text_field.dart';
import '../../../l10n/generated/app_l10n.dart';
import 'widgets/auth_scaffold.dart';

/// Pantalla 7 — recuperar contraseña, paso del correo.
class ForgotPasswordView extends ConsumerStatefulWidget {
  const ForgotPasswordView({super.key});

  @override
  ConsumerState<ForgotPasswordView> createState() => _ForgotPasswordViewState();
}

class _ForgotPasswordViewState extends ConsumerState<ForgotPasswordView> {
  Future<void> _submit() async {
    final l10n = AppL10n.of(context);
    final viewModel = ref.read(forgotPasswordViewModelProvider);
    final email = await viewModel.submit();
    if (!mounted) return;

    if (email == null) {
      final failure = viewModel.failure;
      if (failure != null) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(failureMessage(l10n, failure))));
        viewModel.clearFailure();
      }
      return;
    }

    await context.push(Routes.recoverCodeFor(email));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final theme = Theme.of(context);
    final viewModel = ref.watch(forgotPasswordViewModelProvider);

    return AuthScaffold(
      title: l10n.recoverTitle,
      subtitle: l10n.recoverSubtitle,
      children: [
        ValidateOnBlur(
          onBlur: viewModel.validateEmail,
          builder: (context, focusNode) => CpTextField(
            label: l10n.authEmail,
            focusNode: focusNode,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.done,
            prefixIcon: Icons.alternate_email,
            autofillHints: const [AutofillHints.email],
            errorText: viewModel.emailError == null
                ? null
                : validationMessage(l10n, viewModel.emailError!),
            onChanged: viewModel.setEmail,
            onSubmitted: (_) => _submit(),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        CpButton(
          label: l10n.recoverSendCode,
          isLoading: viewModel.isLoading,
          onPressed: viewModel.isBackendConfigured ? _submit : null,
        ),
        const SizedBox(height: AppSpacing.md),
        // `RF-AUT-12` — la recuperación no cuesta nada y no depende del plan.
        // El copy lo dice explícitamente porque es una duda real del usuario.
        Text(
          l10n.recoverAlwaysFree,
          style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
