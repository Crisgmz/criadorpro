import 'package:flutter/material.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/cp_button.dart';
import '../../../../l10n/generated/app_l10n.dart';

/// Los tres planes de la pantalla 13.
enum PlanOption {
  free(SubscriptionPlan.free),
  pro(SubscriptionPlan.pro),
  elite(SubscriptionPlan.elite);

  const PlanOption(this.plan);

  final SubscriptionPlan plan;
}

/// Tarjeta comparativa de un plan — `RF-ONB-04`.
///
/// Contratar no ocurre aquí: `RF-CTA-04` obliga a que el cambio de plan pase
/// por la compra dentro de la app, y `RS-12` a que sea el servidor quien lo
/// escriba tras validar el recibo. Mientras la compra no exista (fase 3),
/// cualquier opción entra con el plan Gratis.
class PlanCard extends StatelessWidget {
  const PlanCard({
    required this.plan,
    required this.onPressed,
    super.key,
    this.isRecommended = false,
  });

  final PlanOption plan;
  final Future<void> Function() onPressed;
  final bool isRecommended;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final (name, price, features) = switch (plan) {
      PlanOption.free => (
        l10n.planFree,
        l10n.setupPlanPriceFree,
        [
          l10n.setupPlanFeatureBirds(25),
          l10n.setupPlanFeatureClutches,
          l10n.setupPlanFeaturePedigree(2),
        ],
      ),
      PlanOption.pro => (
        l10n.planPro,
        l10n.setupPlanPricePro,
        [
          l10n.setupPlanFeatureBirds(500),
          l10n.setupPlanFeaturePedigree(4),
          l10n.setupPlanFeatureTests,
          l10n.setupPlanFeatureAccounting,
        ],
      ),
      PlanOption.elite => (
        l10n.planElite,
        l10n.setupPlanPriceElite,
        [
          l10n.setupPlanFeatureBirdsUnlimited,
          l10n.setupPlanFeatureEverythingPro,
          l10n.setupPlanFeaturePayroll,
        ],
      ),
    };

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(
          color: isRecommended ? scheme.primary : scheme.outlineVariant,
          width: isRecommended ? 2 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: Text(name, style: theme.textTheme.titleLarge)),
              if (isRecommended)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                    vertical: AppSpacing.xs,
                  ),
                  decoration: BoxDecoration(
                    color: scheme.primary,
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  child: Text(
                    l10n.setupPlanRecommended,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: scheme.onPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(price, style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: AppSpacing.md),
          for (final feature in features)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.check, size: 18, color: scheme.secondary),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(child: Text(feature, style: theme.textTheme.bodyMedium)),
                ],
              ),
            ),
          const SizedBox(height: AppSpacing.sm),
          CpButton(
            label: plan == PlanOption.free ? l10n.setupPlanStartFree : l10n.setupPlanChoose,
            variant: isRecommended ? CpButtonVariant.primary : CpButtonVariant.secondary,
            onPressed: onPressed,
          ),
        ],
      ),
    );
  }
}
