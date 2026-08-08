import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/error/failure_messages.dart';
import '../../../core/providers/providers.dart';
import '../../../core/router/routes.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/cp_button.dart';
import '../../../core/widgets/cp_text_field.dart';
import '../../../l10n/generated/app_l10n.dart';
import 'widgets/auth_scaffold.dart';

/// Pantalla 6 — iniciar sesión.
class LoginView extends ConsumerStatefulWidget {
  const LoginView({super.key});

  @override
  ConsumerState<LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends ConsumerState<LoginView> {
  late final TextEditingController _emailController;
  final _passwordController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Si la última vez se marcó «recordarme», el correo ya viene escrito.
    _emailController = TextEditingController(text: ref.read(loginViewModelProvider).initialEmail);
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final l10n = AppL10n.of(context);
    final viewModel = ref.read(loginViewModelProvider);
    final signedIn = await viewModel.submit();
    // Con la sesión abierta no hay nada que hacer aquí: el router redirige solo.
    if (!mounted || signedIn) return;

    final failure = viewModel.failure;
    if (failure != null) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(failureMessage(l10n, failure))));
      viewModel.clearFailure();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final theme = Theme.of(context);
    final viewModel = ref.watch(loginViewModelProvider);

    return AuthScaffold(
      title: l10n.loginTitle,
      subtitle: l10n.loginSubtitle,
      children: [
        AutofillGroup(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ValidateOnBlur(
                onBlur: viewModel.validateEmail,
                builder: (context, focusNode) => CpTextField(
                  label: l10n.authEmail,
                  controller: _emailController,
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
                onBlur: viewModel.validatePassword,
                builder: (context, focusNode) => CpTextField.password(
                  label: l10n.authPassword,
                  controller: _passwordController,
                  focusNode: focusNode,
                  textInputAction: TextInputAction.done,
                  autofillHints: const [AutofillHints.password],
                  errorText: _messageFor(l10n, viewModel.passwordError),
                  onChanged: viewModel.setPassword,
                  onSubmitted: (_) => _submit(),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            Expanded(
              child: InkWell(
                onTap: () => viewModel.setRememberMe(value: !viewModel.rememberMe),
                borderRadius: BorderRadius.circular(AppRadius.sm),
                child: Row(
                  children: [
                    Checkbox(
                      value: viewModel.rememberMe,
                      onChanged: (value) => viewModel.setRememberMe(value: value ?? false),
                    ),
                    Flexible(child: Text(l10n.loginRememberMe, style: theme.textTheme.bodySmall)),
                  ],
                ),
              ),
            ),
            TextButton(
              onPressed: () => context.push(Routes.recover),
              child: Text(l10n.loginForgotPassword),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),

        CpButton(
          label: l10n.welcomeSignIn,
          isLoading: viewModel.isLoading,
          onPressed: viewModel.isBackendConfigured ? _submit : null,
        ),
      ],
    );
  }

  String? _messageFor(AppL10n l10n, ValidationError? error) =>
      error == null ? null : validationMessage(l10n, error);
}
