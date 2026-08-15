import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/failure_messages.dart';
import '../../../core/providers/providers.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/cp_button.dart';
import '../../../core/widgets/cp_text_field.dart';
import '../../../l10n/generated/app_l10n.dart';
import '../../birds/view/widgets/form_fields.dart';
import '../model/transaction.dart';
import 'accounting_labels.dart';

/// Pantalla 30 — registro de un movimiento, `RF-CON-01` a `RF-CON-03`.
class TransactionFormView extends ConsumerStatefulWidget {
  const TransactionFormView({super.key});

  @override
  ConsumerState<TransactionFormView> createState() => _TransactionFormViewState();
}

class _TransactionFormViewState extends ConsumerState<TransactionFormView> {
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => ref.read(transactionFormViewModelProvider).load(),
    );
  }

  @override
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final viewModel = ref.read(transactionFormViewModelProvider);
    final now = DateTime.now();

    final picked = await showDatePicker(
      context: context,
      initialDate: viewModel.date,
      firstDate: DateTime(now.year - 5),
      lastDate: now,
    );
    if (picked != null) viewModel.setDate(picked);
  }

  Future<void> _submit() async {
    final l10n = AppL10n.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final viewModel = ref.read(transactionFormViewModelProvider);

    final saved = await viewModel.submit();
    if (!mounted) return;

    if (saved != null) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.accountingSaved)));
      if (navigator.canPop()) navigator.pop(saved);
      return;
    }

    final failure = viewModel.failure;
    if (failure != null) {
      messenger.showSnackBar(SnackBar(content: Text(failureMessage(l10n, failure))));
      viewModel.clearFailure();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final locale = Localizations.localeOf(context).toLanguageTag();
    final viewModel = ref.watch(transactionFormViewModelProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.accountingFormTitle)),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          // El tipo va primero porque decide el catálogo de categorías: al
          // revés, el criador elegiría una categoría que luego desaparece.
          SectionLabel(l10n.accountingFieldType),
          SegmentedButton<TransactionType>(
            segments: [
              for (final type in TransactionType.values)
                ButtonSegment(value: type, label: Text(typeLabel(l10n, type))),
            ],
            selected: {viewModel.type},
            showSelectedIcon: false,
            onSelectionChanged: (selection) => viewModel.setType(selection.first),
          ),

          const SizedBox(height: AppSpacing.lg),
          CpTextField(
            label: l10n.accountingFieldAmount,
            controller: _amountController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            // Dígitos, coma y punto: el teclado del teléfono ofrece uno u otro
            // según el idioma, y el ViewModel acepta los dos.
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
            prefixIcon: Icons.payments_outlined,
            onChanged: viewModel.setAmount,
          ),

          const SizedBox(height: AppSpacing.md),
          // `RF-CON-02` — catálogo cerrado: es un desplegable, no un campo
          // libre. El criador no crea categorías propias.
          DropdownButtonFormField<TransactionCategory>(
            initialValue: viewModel.category,
            isExpanded: true,
            decoration: InputDecoration(labelText: l10n.accountingFieldCategory),
            items: [
              for (final category in viewModel.categories)
                DropdownMenuItem(value: category, child: Text(categoryLabel(l10n, category))),
            ],
            onChanged: (value) {
              if (value != null) viewModel.setCategory(value);
            },
          ),

          const SizedBox(height: AppSpacing.md),
          DateField(
            label: l10n.fieldBirthDate,
            value: viewModel.date,
            formatted: Formatters.date(viewModel.date, locale),
            onTap: _pickDate,
          ),

          const SizedBox(height: AppSpacing.md),
          CpTextField(
            label: l10n.fieldNotes,
            controller: _descriptionController,
            maxLines: 2,
            helper: l10n.commonOptional,
            onChanged: viewModel.setDescription,
          ),

          const SizedBox(height: AppSpacing.lg),
          // `RF-CON-03` — recurrencia. Los períodos vencidos se generan solos
          // al abrir la app (`RS-08`).
          DropdownButtonFormField<Recurrence>(
            initialValue: viewModel.recurrence,
            isExpanded: true,
            decoration: InputDecoration(labelText: l10n.accountingFieldRecurrence),
            items: [
              for (final recurrence in Recurrence.values)
                DropdownMenuItem(value: recurrence, child: Text(recurrenceLabel(l10n, recurrence))),
            ],
            onChanged: (value) {
              if (value != null) viewModel.setRecurrence(value);
            },
          ),

          const SizedBox(height: AppSpacing.xl),
          CpButton(
            label: l10n.commonSave,
            isLoading: viewModel.isLoading,
            onPressed: viewModel.canSubmit ? _submit : null,
          ),
          const SizedBox(height: AppSpacing.lg),
        ],
      ),
    );
  }
}
