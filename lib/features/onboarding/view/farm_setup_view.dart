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
import '../../auth/view/widgets/auth_scaffold.dart';
import '../viewmodel/farm_setup_viewmodel.dart';
import 'widgets/plan_card.dart';

/// Pantallas 11–13 — configuración inicial del criadero.
///
/// Las tres viven en una sola vista porque son un formulario con pasos, no tres
/// destinos: volver atrás no debe perder lo escrito (`RF-ONB-07`).
class FarmSetupView extends ConsumerStatefulWidget {
  const FarmSetupView({super.key});

  @override
  ConsumerState<FarmSetupView> createState() => _FarmSetupViewState();
}

class _FarmSetupViewState extends ConsumerState<FarmSetupView> {
  /// Solo avanza de paso. El cierre ocurre en la pantalla de planes, nunca
  /// antes: pasar del paso 2 directamente a guardar se saltaría `RF-ONB-04`.
  void _next() => ref.read(farmSetupViewModelProvider).next();

  /// `RF-ONB-05` — se puede posponer la elección de plan y entrar con Gratis.
  Future<void> _finish() async {
    final l10n = AppL10n.of(context);
    final viewModel = ref.read(farmSetupViewModelProvider);
    final saved = await viewModel.submit(locale: Localizations.localeOf(context).languageCode);
    if (!mounted) return;

    if (!saved) {
      final failure = viewModel.failure;
      if (failure != null) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(failureMessage(l10n, failure))));
        viewModel.clearFailure();
      }
      return;
    }

    context.go(Routes.onboardingDone);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final viewModel = ref.watch(farmSetupViewModelProvider);

    return AuthScaffold(
      title: switch (viewModel.step) {
        FarmSetupStep.profile => l10n.setupProfileTitle,
        FarmSetupStep.numbering => l10n.setupNumberingTitle,
        FarmSetupStep.plan => l10n.setupPlanTitle,
      },
      subtitle: switch (viewModel.step) {
        FarmSetupStep.profile => l10n.setupProfileSubtitle,
        FarmSetupStep.numbering => l10n.setupNumberingSubtitle,
        FarmSetupStep.plan => l10n.setupPlanSubtitle,
      },
      showBackButton: !viewModel.isFirstStep,
      onBack: viewModel.back,
      children: [
        _StepProgress(
          label: l10n.setupStepOf(viewModel.stepNumber, viewModel.stepCount),
          progress: viewModel.progress,
        ),
        const SizedBox(height: AppSpacing.lg),
        switch (viewModel.step) {
          FarmSetupStep.profile => _ProfileStep(viewModel: viewModel),
          FarmSetupStep.numbering => _NumberingStep(viewModel: viewModel),
          FarmSetupStep.plan => _PlanStep(onChoose: _finish),
        },
        const SizedBox(height: AppSpacing.xl),
        if (viewModel.step != FarmSetupStep.plan)
          CpButton(
            label: viewModel.step == FarmSetupStep.numbering ? l10n.setupFinish : l10n.commonNext,
            isLoading: viewModel.isLoading,
            onPressed: _next,
          ),
      ],
    );
  }
}

class _StepProgress extends StatelessWidget {
  const _StepProgress({required this.label, required this.progress});

  final String label;
  final double progress;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.labelMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: AppSpacing.sm),
        ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.pill),
          child: TweenAnimationBuilder<double>(
            duration: const Duration(milliseconds: 240),
            tween: Tween(begin: 0, end: progress),
            builder: (context, value, _) => LinearProgressIndicator(
              value: value,
              minHeight: 6,
              backgroundColor: theme.colorScheme.surfaceContainerHighest,
            ),
          ),
        ),
      ],
    );
  }
}

/// Pantalla 11 — `RF-ONB-01`: solo el nombre del criadero es obligatorio.
class _ProfileStep extends StatelessWidget {
  const _ProfileStep({required this.viewModel});

  final FarmSetupViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ValidateOnBlur(
          onBlur: viewModel.validateFarmName,
          builder: (context, focusNode) => CpTextField(
            label: l10n.setupFarmName,
            focusNode: focusNode,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.next,
            prefixIcon: Icons.home_work_outlined,
            errorText: viewModel.farmNameError == null
                ? null
                : validationMessage(l10n, viewModel.farmNameError!),
            onChanged: viewModel.setFarmName,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        CpTextField(
          label: l10n.setupLocation,
          helper: l10n.commonOptional,
          textCapitalization: TextCapitalization.words,
          textInputAction: TextInputAction.done,
          prefixIcon: Icons.place_outlined,
          onChanged: viewModel.setLocation,
        ),
      ],
    );
  }
}

/// Pantalla 12 — `RF-ONB-02` y `RF-ONB-03`: la numeración continúa desde la
/// placa que el criador ya usa, que es lo que le permite migrar su libro sin
/// retranscribirlo.
class _NumberingStep extends StatelessWidget {
  const _NumberingStep({required this.viewModel});

  final FarmSetupViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ValidateOnBlur(
          onBlur: viewModel.validatePlate,
          builder: (context, focusNode) => CpTextField(
            label: l10n.setupCurrentPlate,
            focusNode: focusNode,
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.done,
            prefixIcon: Icons.tag,
            errorText: viewModel.plateError == null
                ? null
                : validationMessage(l10n, viewModel.plateError!),
            onChanged: viewModel.setPlate,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: theme.colorScheme.secondaryContainer,
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.info_outline, size: 20, color: theme.colorScheme.onSecondaryContainer),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  l10n.setupNumberingHint,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSecondaryContainer,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Pantalla 13 — `RF-ONB-04`: los tres planes en comparación, con Pro
/// recomendado. `RF-ONB-05`: «Después» siempre disponible, nadie queda
/// bloqueado tras el muro de pago.
class _PlanStep extends StatelessWidget {
  const _PlanStep({required this.onChoose});

  final Future<void> Function() onChoose;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PlanCard(plan: PlanOption.free, onPressed: onChoose),
        const SizedBox(height: AppSpacing.md),
        PlanCard(plan: PlanOption.pro, isRecommended: true, onPressed: onChoose),
        const SizedBox(height: AppSpacing.md),
        PlanCard(plan: PlanOption.elite, onPressed: onChoose),
        const SizedBox(height: AppSpacing.lg),
        Text(
          l10n.setupPlanLater,
          textAlign: TextAlign.center,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
      ],
    );
  }
}
