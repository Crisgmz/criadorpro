import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/base/view_state.dart';
import '../../../core/providers/providers.dart';
import '../../../core/router/routes.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/semantic_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/cp_empty_state.dart';
import '../../../core/widgets/motion.dart';
import '../../../l10n/generated/app_l10n.dart';
import '../model/employee.dart';
import '../model/payroll_payment.dart';
import 'payroll_labels.dart';

/// Empleomanía — `RF-NOM-01`, `RF-NOM-02` y `RS-07`.
///
/// No ocupa pestaña (PRD §7): es un módulo administrativo que se abre a
/// pantalla completa desde Inicio y desde el panel lateral, como contabilidad.
class PayrollView extends ConsumerStatefulWidget {
  const PayrollView({super.key});

  @override
  ConsumerState<PayrollView> createState() => _PayrollViewState();
}

class _PayrollViewState extends ConsumerState<PayrollView> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => ref.read(payrollViewModelProvider).load());
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final locale = Localizations.localeOf(context).toLanguageTag();
    final viewModel = ref.watch(payrollViewModelProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.payrollTitle)),
      floatingActionButton: !viewModel.isAvailable
          ? null
          : FloatingActionButton.extended(
              onPressed: () => context.push(Routes.employeeNew),
              icon: const Icon(Icons.person_add_alt),
              label: Text(l10n.payrollNewEmployee),
            ),
      body: switch (viewModel.state) {
        ViewState.loading => const Center(child: CircularProgressIndicator()),

        // El módulo es de Élite, y como en pruebas de campo la pantalla se
        // muestra con su explicación en lugar de esconderse: esconderla dejaría
        // al criador sin saber que existe.
        _ when !viewModel.isAvailable => CpEmptyState(
          icon: Icons.workspace_premium_outlined,
          title: l10n.payrollPlanTitle,
          message: l10n.payrollPlanMessage,
          actionLabel: l10n.dashboardSeePlans,
          onAction: () => context.push(Routes.settings),
        ),

        _ when !viewModel.hasEmployees => CpEmptyState(
          icon: Icons.badge_outlined,
          title: l10n.payrollEmptyTitle,
          message: l10n.payrollEmptyMessage,
          actionLabel: l10n.payrollNewEmployee,
          onAction: () => context.push(Routes.employeeNew),
        ),

        _ => ListView(
          padding: const EdgeInsets.only(bottom: 96),
          children: [
            _SummaryCard(summary: viewModel.summary, locale: locale),

            _SectionTitle(l10n.payrollTeam),
            for (final (index, employee) in viewModel.employees.indexed)
              CpFadeUp(
                delay: cpStagger(index),
                child: _EmployeeTile(employee: employee, locale: locale),
              ),

            if (viewModel.payments.isNotEmpty) ...[
              const Divider(height: AppSpacing.xl),
              _SectionTitle(l10n.payrollHistory),
              for (final payment in viewModel.payments)
                _PaymentTile(
                  payment: payment,
                  employeeName: viewModel.nameOf(payment.employeeId),
                  locale: locale,
                ),
            ],
          ],
        ),
      },
    );
  }
}

/// `RS-07` — costo mensual estimado y lo realmente pagado.
class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.summary, required this.locale});

  final PayrollSummary summary;
  final String locale;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.all(AppSpacing.screen),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.payrollMonthlyCost.toUpperCase(),
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              Formatters.currency(summary.monthlyCost, locale),
              style: theme.textTheme.displaySmall,
            ),
            // `RS-07` obliga a rotularlo como estimación: el 4,33 del semanal
            // no cuadra con ningún mes concreto, y presentarlo como exacto haría
            // que el criador lo cuadrara contra su banco y no le diera.
            Text(
              l10n.payrollMonthlyCostEstimate,
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Expanded(
                  child: _Metric(
                    label: l10n.payrollActive,
                    value: Formatters.number(summary.activeCount, locale),
                  ),
                ),
                Expanded(
                  child: _Metric(
                    label: l10n.payrollPaidThisMonth,
                    value: Formatters.currency(summary.paidThisMonth, locale),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
        Text(value, style: theme.textTheme.titleMedium),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.screen, AppSpacing.sm, AppSpacing.screen, 0),
      child: Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
      ),
    );
  }
}

class _EmployeeTile extends StatelessWidget {
  const _EmployeeTile({required this.employee, required this.locale});

  final Employee employee;
  final String locale;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final theme = Theme.of(context);

    final subtitle = [
      if ((employee.role ?? '').isNotEmpty) employee.role!,
      '${Formatters.currency(employee.salary, locale)} · '
          '${frequencyLabel(l10n, employee.frequency)}',
    ].join(' · ');

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: employee.isActive
            ? context.semantic.brand.withValues(alpha: 0.12)
            : theme.colorScheme.surfaceContainerHighest,
        child: Icon(
          Icons.person_outline,
          color: employee.isActive ? context.semantic.brand : theme.colorScheme.onSurfaceVariant,
        ),
      ),
      title: Text(employee.name),
      subtitle: Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis),
      // El estado va en texto y no solo en el color del avatar (`RNF-25`).
      trailing: employee.isActive
          ? IconButton(
              tooltip: l10n.payrollPay,
              icon: const Icon(Icons.payments_outlined),
              onPressed: () => context.push(Routes.paymentNewFor(employee.id)),
            )
          : Text(
              l10n.payrollInactive,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
      onTap: () => context.push(Routes.employeeEdit(employee.id)),
    );
  }
}

class _PaymentTile extends ConsumerWidget {
  const _PaymentTile({required this.payment, required this.locale, this.employeeName});

  final PayrollPayment payment;
  final String? employeeName;
  final String locale;

  /// `RF-NOM-04` — el recibo que el empleado se lleva.
  ///
  /// No pasa por `CpExportButton` porque el módulo entero es de Élite, y Élite
  /// ya incluye exportación: aquí la restricción de plan sería redundante.
  Future<void> _exportReceipt(BuildContext context, WidgetRef ref, String locale) async {
    final l10n = AppL10n.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final employee = await ref.read(payrollRepositoryProvider).findEmployee(payment.employeeId);
    if (employee == null) return;

    try {
      await ref
          .read(exportersProvider)
          .payrollReceipt(
            l10n: l10n,
            locale: locale,
            farmName: ref.read(currentProfileProvider).value?.farmName ?? l10n.appName,
            employee: employee,
            payment: payment,
            now: DateTime.now(),
          );
    } on Object catch (error, stackTrace) {
      debugPrint('Recibo no se generó: $error\n$stackTrace');
      messenger.showSnackBar(SnackBar(content: Text(l10n.exportFailed)));
    }
  }

  Future<void> _confirmVoid(BuildContext context, WidgetRef ref) async {
    final l10n = AppL10n.of(context);

    final confirmed = await showCpDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.payrollVoidTitle),
        // Decirlo antes, no después: anular el pago mueve también el balance
        // del mes, y esa consecuencia no es obvia.
        content: Text(l10n.payrollVoidMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.commonDelete),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    if (await ref.read(payrollViewModelProvider).voidPayment(payment.id)) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.payrollVoided)));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppL10n.of(context);
    final theme = Theme.of(context);

    return ListTile(
      title: Text(employeeName ?? l10n.commonNone),
      subtitle: Text(
        l10n.payrollPeriodRange(
          Formatters.shortDate(payment.periodStart, locale),
          Formatters.shortDate(payment.periodEnd, locale),
        ),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(Formatters.currency(payment.net, locale), style: theme.textTheme.titleSmall),
          // Menú y no dos iconos sueltos: el recibo se pide de vez en cuando y
          // anular es raro; en la fila competirían con el importe, que es lo
          // que el criador viene a leer.
          PopupMenuButton<_PaymentAction>(
            onSelected: (action) => switch (action) {
              _PaymentAction.receipt => _exportReceipt(context, ref, locale),
              _PaymentAction.cancel => _confirmVoid(context, ref),
            },
            itemBuilder: (context) => [
              PopupMenuItem(value: _PaymentAction.receipt, child: Text(l10n.exportReceipt)),
              PopupMenuItem(value: _PaymentAction.cancel, child: Text(l10n.payrollVoidTitle)),
            ],
          ),
        ],
      ),
    );
  }
}

enum _PaymentAction { receipt, cancel }
