import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/base/view_state.dart';
import '../../../core/export/export_button.dart';
import '../../../core/providers/providers.dart';
import '../../../core/router/routes.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/semantic_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/cp_empty_state.dart';
import '../../../l10n/generated/app_l10n.dart';
import '../model/transaction.dart';
import '../viewmodel/accounting_viewmodel.dart';
import 'accounting_labels.dart';

/// Pantalla 29 — cierre mensual, `RF-CON-04` a `RF-CON-06`.
class AccountingView extends ConsumerStatefulWidget {
  const AccountingView({super.key});

  @override
  ConsumerState<AccountingView> createState() => _AccountingViewState();
}

class _AccountingViewState extends ConsumerState<AccountingView> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => ref.read(accountingViewModelProvider).load(),
    );
  }

  Future<void> _create() async {
    await context.push(Routes.transactionNew);
    if (!mounted) return;
    // Un movimiento en un mes que antes estaba vacío tiene que habilitar la
    // navegación hacia él.
    await ref.read(accountingViewModelProvider).refreshMonths();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final locale = Localizations.localeOf(context).toLanguageTag();
    final viewModel = ref.watch(accountingViewModelProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.accountingTitle)),
      floatingActionButton: !viewModel.isAvailable
          ? null
          : FloatingActionButton.extended(
              onPressed: _create,
              icon: const Icon(Icons.add),
              label: Text(l10n.accountingNew),
            ),
      body: switch (viewModel.state) {
        ViewState.loading => const Center(child: CircularProgressIndicator()),
        // El módulo es de Pro, y como en pruebas de campo la pantalla se
        // muestra con su explicación en lugar de esconderse.
        _ when !viewModel.isAvailable => CpEmptyState(
          icon: Icons.workspace_premium_outlined,
          title: l10n.accountingPlanTitle,
          message: l10n.accountingPlanMessage,
          actionLabel: l10n.dashboardSeePlans,
          onAction: () => context.push(Routes.settings),
        ),
        _ => Column(
          children: [
            _MonthNavigator(viewModel: viewModel, locale: locale),
            _BalanceCard(balance: viewModel.balance, locale: locale),
            Expanded(
              child: viewModel.transactions.isEmpty
                  ? CpEmptyState(
                      icon: Icons.receipt_long_outlined,
                      title: l10n.accountingEmptyTitle,
                      message: l10n.accountingEmptyMessage,
                      actionLabel: l10n.accountingNew,
                      onAction: _create,
                    )
                  : ListView(
                      padding: const EdgeInsets.only(bottom: 96),
                      children: [
                        _CategoryBreakdown(balance: viewModel.balance, locale: locale),
                        const Divider(height: AppSpacing.xl),
                        for (final transaction in viewModel.transactions)
                          _TransactionTile(transaction: transaction, locale: locale),

                        // `RF-CON-07` — el mes cerrado, para el contable o
                        // para el archivo del criador.
                        const SizedBox(height: AppSpacing.lg),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screen),
                          child: CpExportButton(
                            label: l10n.exportMonth,
                            onExport: () => ref
                                .read(exportersProvider)
                                .monthlyReport(
                                  l10n: l10n,
                                  locale: locale,
                                  farmName:
                                      ref.read(currentProfileProvider).value?.farmName ??
                                      l10n.appName,
                                  balance: viewModel.balance,
                                  transactions: viewModel.transactions,
                                  now: DateTime.now(),
                                ),
                          ),
                        ),
                      ],
                    ),
            ),
          ],
        ),
      },
    );
  }
}

/// `RF-CON-05` — navegación entre meses.
class _MonthNavigator extends StatelessWidget {
  const _MonthNavigator({required this.viewModel, required this.locale});

  final AccountingViewModel viewModel;
  final String locale;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            tooltip: l10n.accountingPreviousMonth,
            icon: const Icon(Icons.chevron_left),
            // Deshabilitado y no oculto: así se ve que se acabó el histórico.
            onPressed: viewModel.canGoBack ? viewModel.goToPreviousMonth : null,
          ),
          Text(Formatters.monthYear(viewModel.month, locale), style: theme.textTheme.titleMedium),
          IconButton(
            tooltip: l10n.accountingNextMonth,
            icon: const Icon(Icons.chevron_right),
            onPressed: viewModel.canGoForward ? viewModel.goToNextMonth : null,
          ),
        ],
      ),
    );
  }
}

/// `RF-CON-04` — ingresos, gastos y balance.
class _BalanceCard extends StatelessWidget {
  const _BalanceCard({required this.balance, required this.locale});

  final MonthlyBalance balance;
  final String locale;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final theme = Theme.of(context);
    final semantic = context.semantic;

    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.md, 0, AppSpacing.md, AppSpacing.md),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: _Amount(
                      label: l10n.accountingIncome,
                      value: balance.income,
                      color: semantic.favorable,
                      locale: locale,
                    ),
                  ),
                  Expanded(
                    child: _Amount(
                      label: l10n.accountingExpense,
                      value: balance.expense,
                      color: semantic.unfavorable,
                      locale: locale,
                    ),
                  ),
                ],
              ),
              const Divider(height: AppSpacing.lg),
              // `RF-CON-04`: el balance negativo va en rojo **y sin mensajes
              // adicionales**. Un mes en pérdidas es información, no un error.
              _Amount(
                label: l10n.accountingBalance,
                value: balance.balance,
                color: balance.isNegative ? semantic.unfavorable : theme.colorScheme.onSurface,
                locale: locale,
                large: true,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Amount extends StatelessWidget {
  const _Amount({
    required this.label,
    required this.value,
    required this.color,
    required this.locale,
    this.large = false,
  });

  final String label;
  final double value;
  final Color color;
  final String locale;
  final bool large;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          Formatters.currency(value, locale),
          style: (large ? theme.textTheme.headlineMedium : theme.textTheme.titleMedium)?.copyWith(
            color: color,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

/// `RF-CON-06` — desglose por categoría con barras proporcionales.
class _CategoryBreakdown extends StatelessWidget {
  const _CategoryBreakdown({required this.balance, required this.locale});

  final MonthlyBalance balance;
  final String locale;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final theme = Theme.of(context);

    final entries = balance.byCategory.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    if (entries.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.accountingByCategory, style: theme.textTheme.labelSmall),
          const SizedBox(height: AppSpacing.sm),
          for (final entry in entries)
            _CategoryBar(
              category: entry.key,
              amount: entry.value / 100,
              share: balance.shareOf(entry.key),
              locale: locale,
            ),
        ],
      ),
    );
  }
}

class _CategoryBar extends StatelessWidget {
  const _CategoryBar({
    required this.category,
    required this.amount,
    required this.share,
    required this.locale,
  });

  final TransactionCategory category;
  final double amount;
  final double share;
  final String locale;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final theme = Theme.of(context);
    final color = category.type == TransactionType.income
        ? context.semantic.favorable
        : context.semantic.unfavorable;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  categoryLabel(l10n, category),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium,
                ),
              ),
              Text(
                Formatters.currency(amount, locale),
                style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.pill),
            child: LinearProgressIndicator(
              value: share,
              minHeight: 6,
              backgroundColor: theme.colorScheme.surfaceContainerHighest,
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
        ],
      ),
    );
  }
}

class _TransactionTile extends StatelessWidget {
  const _TransactionTile({required this.transaction, required this.locale});

  final Transaction transaction;
  final String locale;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final theme = Theme.of(context);
    final isIncome = transaction.type == TransactionType.income;
    final color = isIncome ? context.semantic.favorable : context.semantic.unfavorable;

    final subtitle = [
      Formatters.date(transaction.date, locale),
      if (transaction.description != null) transaction.description!,
      if (transaction.recurrenceSourceId != null) recurrenceLabel(l10n, Recurrence.monthly),
    ].join(' · ');

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: color.withValues(alpha: 0.16),
        child: Icon(isIncome ? Icons.arrow_downward : Icons.arrow_upward, color: color, size: 20),
      ),
      title: Text(categoryLabel(l10n, transaction.category), style: theme.textTheme.titleSmall),
      subtitle: Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: Text(
        // El signo va delante del importe: es lo que distingue un ingreso de un
        // gasto de un vistazo, sin tener que leer la categoría.
        '${isIncome ? '+' : '−'} ${Formatters.currency(transaction.amount, locale)}',
        style: theme.textTheme.bodyMedium?.copyWith(color: color, fontWeight: FontWeight.w600),
      ),
    );
  }
}
