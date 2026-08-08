import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/app_config.dart';
import '../../../core/error/failure_messages.dart';
import '../../../core/providers/providers.dart';
import '../../../core/router/routes.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/cp_button.dart';
import '../../../core/widgets/cp_text_field.dart';
import '../../../l10n/generated/app_l10n.dart';
import 'widgets/auth_scaffold.dart';
import 'widgets/password_strength_bar.dart';
import 'widgets/phone_field.dart';

/// Pantalla 4 — crear cuenta.
class SignUpView extends ConsumerStatefulWidget {
  const SignUpView({super.key});

  @override
  ConsumerState<SignUpView> createState() => _SignUpViewState();
}

class _SignUpViewState extends ConsumerState<SignUpView> {
  final _phoneController = TextEditingController();

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final l10n = AppL10n.of(context);
    final viewModel = ref.read(signUpViewModelProvider);
    final email = await viewModel.submit(locale: Localizations.localeOf(context).languageCode);
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

    await context.push(Routes.verifyEmailFor(email));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final theme = Theme.of(context);
    final viewModel = ref.watch(signUpViewModelProvider);

    return AuthScaffold(
      title: l10n.signUpTitle,
      subtitle: l10n.signUpSubtitle,
      children: [
        AutofillGroup(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ValidateOnBlur(
                onBlur: viewModel.validateFullName,
                builder: (context, focusNode) => CpTextField(
                  label: l10n.authFullName,
                  focusNode: focusNode,
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.next,
                  prefixIcon: Icons.person_outline,
                  autofillHints: const [AutofillHints.name],
                  errorText: _messageFor(l10n, viewModel.fullNameError),
                  onChanged: viewModel.setFullName,
                ),
              ),
              const SizedBox(height: AppSpacing.md),

              ValidateOnBlur(
                onBlur: viewModel.validateEmail,
                builder: (context, focusNode) => CpTextField(
                  label: l10n.authEmail,
                  focusNode: focusNode,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  prefixIcon: Icons.alternate_email,
                  autofillHints: const [AutofillHints.email],
                  errorText: _messageFor(l10n, viewModel.emailError),
                  onChanged: viewModel.setEmail,
                ),
              ),
              const SizedBox(height: AppSpacing.md),

              ValidateOnBlur(
                onBlur: viewModel.validatePhone,
                builder: (context, focusNode) => PhoneField(
                  country: viewModel.country,
                  controller: _phoneController,
                  focusNode: focusNode,
                  errorText: _messageFor(l10n, viewModel.phoneError),
                  onCountryChanged: viewModel.setCountry,
                  onChanged: viewModel.setPhone,
                ),
              ),
              const SizedBox(height: AppSpacing.md),

              ValidateOnBlur(
                onBlur: viewModel.validatePassword,
                builder: (context, focusNode) => CpTextField.password(
                  label: l10n.authPassword,
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
                onBlur: viewModel.validatePasswordConfirmation,
                builder: (context, focusNode) => CpTextField.password(
                  label: l10n.authPasswordConfirmation,
                  focusNode: focusNode,
                  textInputAction: TextInputAction.done,
                  errorText: _messageFor(l10n, viewModel.passwordConfirmationError),
                  onChanged: viewModel.setPasswordConfirmation,
                  onSubmitted: (_) => viewModel.canSubmit ? _submit() : null,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: AppSpacing.lg),
        _TermsCheckbox(
          accepted: viewModel.acceptedTerms,
          onChanged: (value) => viewModel.setAcceptedTerms(value: value),
        ),
        const SizedBox(height: AppSpacing.lg),

        CpButton(
          label: l10n.welcomeCreateAccount,
          isLoading: viewModel.isLoading,
          // `RF-AUT-04` — bloqueado hasta aceptar los términos.
          onPressed: viewModel.canSubmit ? _submit : null,
        ),
        const SizedBox(height: AppSpacing.md),
        Center(
          child: Text(
            l10n.signUpAlreadyHaveAccount,
            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ),
      ],
    );
  }

  String? _messageFor(AppL10n l10n, ValidationError? error) =>
      error == null ? null : validationMessage(l10n, error);
}

/// `RV-05` — aceptación explícita, con los enlaces que exige `RF-CTA-12`.
class _TermsCheckbox extends StatelessWidget {
  const _TermsCheckbox({required this.accepted, required this.onChanged});

  final bool accepted;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final theme = Theme.of(context);

    return InkWell(
      onTap: () => onChanged(!accepted),
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Checkbox(value: accepted, onChanged: (value) => onChanged(value ?? false)),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: AppSpacing.sm + 2),
                child: Text(
                  l10n.signUpAcceptTerms,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
