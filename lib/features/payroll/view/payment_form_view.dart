import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/failure_messages.dart';
import '../../../core/providers/providers.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/semantic_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/cp_alert.dart';
import '../../../core/widgets/cp_button.dart';
import '../../../core/widgets/cp_text_field.dart';
import '../../../l10n/generated/app_l10n.dart';
import '../../auth/view/widgets/auth_scaffold.dart';
import '../model/payroll_payment.dart';
import 'payroll_labels.dart';

/// Registro de un pago de nómina — `RF-NOM-03`, `RS-06` y `RV-15`.
class PaymentFormView extends ConsumerStatefulWidget {
  const PaymentFormView({required this.employeeId, super.key});

  final String employeeId;

  @override
  ConsumerState<PaymentFormView> createState() => _PaymentFormViewState();
}

class _PaymentFormViewState extends ConsumerState<PaymentFormView> {
  final _baseController = TextEditingController();
  final _bonusController = TextEditingController();
  final _deductionsController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final viewModel = ref.read(paymentFormViewModelProvider(widget.employeeId));
      await viewModel.load();
      if (!mounted) return;

      // La base llega propuesta con el salario del empleado: en el galpón,
      // teclear cuatro campos por empleado y por quincena es lo que hace que la
      // app se abandone.
      _baseController.text = viewModel.base;
    });
  }

  @override
  void dispose() {
    _baseController.dispose();
    _bonusController.dispose();
    _deductionsController.dispose();
    super.dispose();
  }

  Future<void> _pickDate({required bool isStart}) async {
    final viewModel = ref.read(paymentFormViewModelProvider(widget.employeeId));
    final initial = isStart ? viewModel.periodStart : viewModel.periodEnd;

    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(initial.year - 2),
      lastDate: DateTime(initial.year + 1, 12, 31),
    );
    if (picked == null) return;

    if (isStart) {
      await viewModel.setPeriodStart(picked);
    } else {
      await viewModel.setPeriodEnd(picked);
    }
  }

  Future<void> _submit() async {
    final l10n = AppL10n.of(context);
    final viewModel = ref.read(paymentFormViewModelProvider(widget.employeeId));
    final saved = await viewModel.submit();
    if (!mounted || saved == null) return;

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.payrollPaymentSaved)));
    Navigator.of(context).pop(saved);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final locale = Localizations.localeOf(context).toLanguageTag();
    final viewModel = ref.watch(paymentFormViewModelProvider(widget.employeeId));

    return AuthScaffold(
      title: l10n.payrollPaymentTitle,
      subtitle: viewModel.employee?.name,
      children: [
        if (viewModel.failure != null)
          CpAlert(
            message: failureMessage(l10n, viewModel.failure!),
            onClose: viewModel.clearFailure,
          ),

        Row(
          children: [
            Expanded(
              child: _DateField(
                label: l10n.payrollFieldPeriodStart,
                value: viewModel.periodStart,
                locale: locale,
                onTap: () => _pickDate(isStart: true),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: _DateField(
                label: l10n.payrollFieldPeriodEnd,
                value: viewModel.periodEnd,
                locale: locale,
                onTap: () => _pickDate(isStart: false),
              ),
            ),
          ],
        ),

        // Advertencia, no bloqueo: un adelanto o un ajuste sobre el mismo
        // período son legítimos. Lo que se evita es el duplicado por descuido.
        if (viewModel.hasOverlap) ...[
          const SizedBox(height: AppSpacing.sm),
          CpAlert(message: l10n.payrollOverlapWarning, tone: CpAlertTone.warning),
        ],
        const SizedBox(height: AppSpacing.md),

        CpTextField(
          label: l10n.payrollFieldBase,
          controller: _baseController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          textInputAction: TextInputAction.next,
          prefixIcon: Icons.attach_money,
          onChanged: viewModel.setBase,
        ),
        const SizedBox(height: AppSpacing.md),

        CpTextField(
          label: l10n.payrollFieldBonus,
          controller: _bonusController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          textInputAction: TextInputAction.next,
          prefixIcon: Icons.add_circle_outline,
          onChanged: viewModel.setBonus,
        ),
        const SizedBox(height: AppSpacing.md),

        CpTextField(
          label: l10n.payrollFieldDeductions,
          controller: _deductionsController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          prefixIcon: Icons.remove_circle_outline,
          onChanged: viewModel.setDeductions,
        ),
        const SizedBox(height: AppSpacing.md),

        _MethodSelector(value: viewModel.method, onChanged: viewModel.setMethod),
        const SizedBox(height: AppSpacing.lg),

        // El neto se ve antes de confirmar: es lo que el empleado va a recibir,
        // y descubrirlo después de guardar sería descubrirlo tarde.
        _NetCard(cents: viewModel.netCents, isNegative: viewModel.isNetNegative, locale: locale),

        // `RV-15` — «El neto no puede ser negativo». Esta sí bloquea.
        if (viewModel.isNetNegative) ...[
          const SizedBox(height: AppSpacing.sm),
          CpAlert(message: l10n.payrollNetNegative),
        ],
        const SizedBox(height: AppSpacing.xl),

        CpButton(
          label: l10n.payrollConfirmPayment,
          isLoading: viewModel.isLoading,
          onPressed: viewModel.canSubmit ? _submit : null,
        ),
      ],
    );
  }
}

class _DateField extends StatelessWidget {
  const _DateField({
    required this.label,
    required this.value,
    required this.locale,
    required this.onTap,
  });

  final String label;
  final DateTime value;
  final String locale;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(AppRadius.md),
    child: InputDecorator(
      decoration: InputDecoration(labelText: label, prefixIcon: const Icon(Icons.event_outlined)),
      child: Text(Formatters.shortDate(value, locale)),
    ),
  );
}

class _MethodSelector extends StatelessWidget {
  const _MethodSelector({required this.value, required this.onChanged});

  final PaymentMethod value;
  final ValueChanged<PaymentMethod> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.payrollFieldMethod.toUpperCase(),
          style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: AppSpacing.sm),
        SegmentedButton<PaymentMethod>(
          segments: [
            for (final method in PaymentMethod.values)
              ButtonSegment(value: method, label: Text(methodLabel(l10n, method))),
          ],
          selected: {value},
          showSelectedIcon: false,
          onSelectionChanged: (selection) => onChanged(selection.first),
        ),
      ],
    );
  }
}

class _NetCard extends StatelessWidget {
  const _NetCard({required this.cents, required this.isNegative, required this.locale});

  final int cents;
  final bool isNegative;
  final String locale;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final theme = Theme.of(context);
    final color = isNegative ? context.semantic.action : theme.colorScheme.onSurface;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            l10n.payrollNet,
            style: theme.textTheme.titleSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          Text(
            Formatters.currency(cents / 100, locale),
            style: theme.textTheme.headlineSmall?.copyWith(color: color),
          ),
        ],
      ),
    );
  }
}
