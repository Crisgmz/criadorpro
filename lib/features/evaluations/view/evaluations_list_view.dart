import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/base/view_state.dart';
import '../../../core/error/failure_messages.dart';
import '../../../core/providers/providers.dart';
import '../../../core/router/routes.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/semantic_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/cp_empty_state.dart';
import '../../../l10n/generated/app_l10n.dart';
import '../../dashboard/view/widgets/app_drawer.dart';
import '../model/evaluation.dart';
import 'evaluation_labels.dart';

/// Pantalla 24 — historial de pruebas del criadero.
class EvaluationsListView extends ConsumerStatefulWidget {
  const EvaluationsListView({super.key});

  @override
  ConsumerState<EvaluationsListView> createState() => _EvaluationsListViewState();
}

class _EvaluationsListViewState extends ConsumerState<EvaluationsListView> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => ref.read(evaluationsListViewModelProvider).load(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final locale = Localizations.localeOf(context).toLanguageTag();
    final viewModel = ref.watch(evaluationsListViewModelProvider);

    return Scaffold(
      drawer: const AppDrawer(),
      appBar: AppBar(title: Text(l10n.testsTitle)),
      floatingActionButton: (!viewModel.isAvailable || viewModel.evaluations.isEmpty)
          ? null
          : FloatingActionButton.extended(
              onPressed: () => context.push(Routes.evaluationNew),
              icon: const Icon(Icons.add),
              label: Text(l10n.testsNew),
            ),
      body: !viewModel.isAvailable
          // `RF-PRU-06`: se informa la restricción **sin ocultar** el módulo.
          // Esconderlo dejaría al criador sin saber que existe.
          ? CpEmptyState(
              icon: Icons.workspace_premium_outlined,
              title: l10n.testsPlanTitle,
              message: l10n.testsPlanMessage,
              actionLabel: l10n.dashboardSeePlans,
              onAction: () => context.push(Routes.settings),
            )
          : Column(
              children: [
                _Stats(stats: viewModel.stats, locale: locale),
                _ResultFilter(selected: viewModel.filter, onSelected: viewModel.setFilter),
                Expanded(
                  child: switch (viewModel.state) {
                    ViewState.loading when viewModel.evaluations.isEmpty => const Center(
                      child: CircularProgressIndicator(),
                    ),
                    ViewState.error => CpEmptyState(
                      icon: Icons.error_outline,
                      title: failureMessage(l10n, viewModel.failure!),
                    ),
                    _ when viewModel.evaluations.isEmpty => CpEmptyState(
                      icon: viewModel.filter == null ? Icons.assignment_outlined : Icons.search_off,
                      title: viewModel.filter == null
                          ? l10n.testsEmptyTitle
                          : l10n.testsEmptyFilteredTitle,
                      message: viewModel.filter == null
                          ? l10n.testsEmptyMessage
                          : l10n.testsEmptyFilteredMessage,
                      // Filtrar sin resultados no ofrece crear: el criador está
                      // buscando algo concreto, no registrando.
                      actionLabel: viewModel.filter == null ? l10n.testsNew : null,
                      onAction: viewModel.filter == null
                          ? () => context.push(Routes.evaluationNew)
                          : null,
                    ),
                    _ => ListView.separated(
                      padding: const EdgeInsets.only(bottom: 96),
                      itemCount: viewModel.evaluations.length,
                      separatorBuilder: (_, _) => const Divider(height: 1, indent: AppSpacing.md),
                      itemBuilder: (context, index) =>
                          _EvaluationTile(evaluation: viewModel.evaluations[index], locale: locale),
                    ),
                  },
                ),
              ],
            ),
    );
  }
}

/// `RF-PRU-03` — total, porcentaje favorable y condición promedio.
class _Stats extends StatelessWidget {
  const _Stats({required this.stats, required this.locale});

  final EvaluationStats stats;
  final String locale;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        children: [
          Expanded(
            child: _StatCard(label: l10n.testsStatTotal, value: '${stats.total}'),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: _StatCard(
              label: l10n.testsStatFavorable,
              value: '${stats.favorablePercent} %',
              color: context.semantic.favorable,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: _StatCard(
              label: l10n.testsStatCondition,
              // Sin condición anotada en ninguna prueba, un «0,0» diría que los
              // ejemplares están en pésimo estado. Un guion no dice nada, que
              // es exactamente lo que se sabe.
              value: stats.averageCondition == null
                  ? '—'
                  : Formatters.decimal(stats.averageCondition!, locale),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.label, required this.value, this.color});

  final String label;
  final String value;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: theme.textTheme.titleLarge?.copyWith(
                color: color,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

/// `RF-PRU-04` — filtro por resultado.
class _ResultFilter extends StatelessWidget {
  const _ResultFilter({required this.selected, required this.onSelected});

  final EvaluationResult? selected;
  final ValueChanged<EvaluationResult?> onSelected;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);

    return SizedBox(
      height: 48,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        children: [
          FilterChip(
            label: Text(l10n.commonAll),
            selected: selected == null,
            onSelected: (_) => onSelected(null),
          ),
          for (final result in EvaluationResult.values) ...[
            const SizedBox(width: AppSpacing.sm),
            FilterChip(
              label: Text(resultLabel(l10n, result)),
              selected: selected == result,
              onSelected: (isSelected) => onSelected(isSelected ? result : null),
            ),
          ],
        ],
      ),
    );
  }
}

class _EvaluationTile extends StatelessWidget {
  const _EvaluationTile({required this.evaluation, required this.locale});

  final Evaluation evaluation;
  final String locale;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final theme = Theme.of(context);
    final color = switch (evaluation.result) {
      EvaluationResult.favorable => context.semantic.favorable,
      EvaluationResult.unfavorable => context.semantic.unfavorable,
      EvaluationResult.undefined => context.semantic.undefinedResult,
    };

    final subtitle = [
      Formatters.date(evaluation.date, locale),
      if (evaluation.place != null) evaluation.place!,
      if (evaluation.condition != null) '${l10n.testsFieldCondition} ${evaluation.condition}',
    ].join(' · ');

    return ListTile(
      onTap: () => context.push(Routes.birdDetail(evaluation.birdId)),
      leading: CircleAvatar(
        backgroundColor: color.withValues(alpha: 0.16),
        child: Icon(Icons.assignment_outlined, color: color, size: 20),
      ),
      // `RNF-25` — el resultado se nombra, no solo se colorea.
      title: Text(resultLabel(l10n, evaluation.result), style: theme.textTheme.titleSmall),
      subtitle: Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: const Icon(Icons.chevron_right),
    );
  }
}
