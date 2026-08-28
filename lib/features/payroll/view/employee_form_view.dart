import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/failure_messages.dart';
import '../../../core/providers/providers.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/cp_alert.dart';
import '../../../core/widgets/cp_button.dart';
import '../../../core/widgets/cp_text_field.dart';
import '../../../l10n/generated/app_l10n.dart';
import '../../auth/view/widgets/auth_scaffold.dart';
import '../model/employee.dart';
import 'payroll_labels.dart';

/// Alta y edición de un empleado — `RF-NOM-01`.
class EmployeeFormView extends ConsumerStatefulWidget {
  const EmployeeFormView({super.key, this.employeeId});

  final String? employeeId;

  @override
  ConsumerState<EmployeeFormView> createState() => _EmployeeFormViewState();
}

class _EmployeeFormViewState extends ConsumerState<EmployeeFormView> {
  final _nameController = TextEditingController();
  final _roleController = TextEditingController();
  final _phoneController = TextEditingController();
  final _documentController = TextEditingController();
  final _salaryController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final viewModel = ref.read(employeeFormViewModelProvider(widget.employeeId));
      await viewModel.load();
      if (!mounted) return;

      // Al editar, los campos llegan con lo guardado. Se escriben una sola vez
      // aquí y no en cada build: hacerlo en build movería el cursor al inicio
      // cada vez que el criador teclea una letra.
      _nameController.text = viewModel.name;
      _roleController.text = viewModel.role;
      _phoneController.text = viewModel.phone;
      _documentController.text = viewModel.document;
      _salaryController.text = viewModel.salary;
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _roleController.dispose();
    _phoneController.dispose();
    _documentController.dispose();
    _salaryController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final l10n = AppL10n.of(context);
    final viewModel = ref.read(employeeFormViewModelProvider(widget.employeeId));
    final saved = await viewModel.submit();
    if (!mounted || saved == null) return;

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.payrollEmployeeSaved)));
    Navigator.of(context).pop(saved);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final viewModel = ref.watch(employeeFormViewModelProvider(widget.employeeId));

    return AuthScaffold(
      title: viewModel.isEditing ? l10n.payrollEmployeeEditTitle : l10n.payrollEmployeeFormTitle,
      children: [
        if (viewModel.failure != null)
          CpAlert(
            message: failureMessage(l10n, viewModel.failure!),
            onClose: viewModel.clearFailure,
          ),

        ValidateOnBlur(
          onBlur: viewModel.validateName,
          builder: (context, focusNode) => CpTextField(
            label: l10n.payrollFieldName,
            controller: _nameController,
            focusNode: focusNode,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.next,
            prefixIcon: Icons.person_outline,
            errorText: viewModel.nameError == null
                ? null
                : validationMessage(l10n, viewModel.nameError!),
            onChanged: viewModel.setName,
          ),
        ),
        const SizedBox(height: AppSpacing.md),

        CpTextField(
          label: l10n.payrollFieldRole,
          controller: _roleController,
          textCapitalization: TextCapitalization.sentences,
          textInputAction: TextInputAction.next,
          prefixIcon: Icons.work_outline,
          onChanged: viewModel.setRole,
        ),
        const SizedBox(height: AppSpacing.md),

        CpTextField(
          label: l10n.payrollFieldPhone,
          controller: _phoneController,
          keyboardType: TextInputType.phone,
          textInputAction: TextInputAction.next,
          prefixIcon: Icons.phone_outlined,
          onChanged: viewModel.setPhone,
        ),
        const SizedBox(height: AppSpacing.md),

        CpTextField(
          label: l10n.payrollFieldDocument,
          controller: _documentController,
          keyboardType: TextInputType.number,
          textInputAction: TextInputAction.next,
          prefixIcon: Icons.badge_outlined,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(11),
          ],
          onChanged: viewModel.setDocument,
        ),
        // `RV-17`: advertencia, nunca bloqueo. Hay trabajadores sin documento
        // dominicano, y un pago que no se puede registrar por eso es peor que
        // un número mal escrito.
        if (viewModel.isDocumentSuspicious) ...[
          const SizedBox(height: AppSpacing.sm),
          CpAlert(message: l10n.payrollDocumentWarning, tone: CpAlertTone.warning),
        ],
        const SizedBox(height: AppSpacing.md),

        CpTextField(
          label: l10n.payrollFieldSalary,
          controller: _salaryController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          prefixIcon: Icons.attach_money,
          onChanged: viewModel.setSalary,
        ),
        const SizedBox(height: AppSpacing.md),

        _FrequencySelector(value: viewModel.frequency, onChanged: viewModel.setFrequency),
        const SizedBox(height: AppSpacing.md),

        InkWell(
          onTap: () async {
            final now = DateTime.now();
            final picked = await showDatePicker(
              context: context,
              initialDate: viewModel.startDate ?? now,
              firstDate: DateTime(now.year - 40),
              // Sin futuro: alguien que todavía no ha entrado no está en la
              // plantilla, y su sueldo no debería sumar al costo del mes.
              lastDate: DateTime(now.year, now.month, now.day),
            );
            if (picked != null) viewModel.setStartDate(picked);
          },
          borderRadius: BorderRadius.circular(AppRadius.md),
          child: InputDecorator(
            decoration: InputDecoration(
              labelText: l10n.employeeStartDate,
              prefixIcon: const Icon(Icons.event_outlined),
            ),
            child: Text(
              viewModel.startDate == null
                  ? '—'
                  : Formatters.date(
                      viewModel.startDate!,
                      Localizations.localeOf(context).toLanguageTag(),
                    ),
            ),
          ),
        ),

        if (viewModel.isEditing) ...[
          const SizedBox(height: AppSpacing.sm),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(l10n.payrollActive),
            value: viewModel.isActive,
            onChanged: (value) => viewModel.setActive(value: value),
          ),
        ],
        const SizedBox(height: AppSpacing.xl),

        CpButton(
          label: l10n.commonSave,
          isLoading: viewModel.isLoading,
          onPressed: viewModel.canSubmit ? _submit : null,
        ),
      ],
    );
  }
}

class _FrequencySelector extends StatelessWidget {
  const _FrequencySelector({required this.value, required this.onChanged});

  final PayFrequency value;
  final ValueChanged<PayFrequency> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.payrollFieldFrequency.toUpperCase(),
          style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: AppSpacing.sm),
        // Segmentado y no desplegable: son tres opciones fijas y el criador
        // tiene que ver las tres para elegir sin abrir nada.
        SegmentedButton<PayFrequency>(
          segments: [
            for (final frequency in PayFrequency.values)
              ButtonSegment(value: frequency, label: Text(frequencyLabel(l10n, frequency))),
          ],
          selected: {value},
          showSelectedIcon: false,
          onSelectionChanged: (selection) => onChanged(selection.first),
        ),
      ],
    );
  }
}
