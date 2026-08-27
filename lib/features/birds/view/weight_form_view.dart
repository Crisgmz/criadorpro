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

/// Anotar una pesada — `RF-REG-14`.
class WeightFormView extends ConsumerStatefulWidget {
  const WeightFormView({required this.birdId, super.key});

  final String birdId;

  @override
  ConsumerState<WeightFormView> createState() => _WeightFormViewState();
}

class _WeightFormViewState extends ConsumerState<WeightFormView> {
  final _weightController = TextEditingController();

  @override
  void dispose() {
    _weightController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final viewModel = ref.read(weightFormViewModelProvider(widget.birdId));
    final now = DateTime.now();

    final picked = await showDatePicker(
      context: context,
      initialDate: viewModel.date,
      firstDate: DateTime(now.year - 20),
      // Sin futuro: un peso que todavía no se ha tomado no es un dato.
      lastDate: DateTime(now.year, now.month, now.day),
    );
    if (picked != null) viewModel.setDate(picked);
  }

  Future<void> _submit() async {
    final l10n = AppL10n.of(context);
    final viewModel = ref.read(weightFormViewModelProvider(widget.birdId));
    final saved = await viewModel.submit();
    if (!mounted || saved == null) return;

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.weightSaved)));
    Navigator.of(context).pop(saved);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final locale = Localizations.localeOf(context).toLanguageTag();
    final viewModel = ref.watch(weightFormViewModelProvider(widget.birdId));

    return AuthScaffold(
      title: l10n.weightFormTitle,
      children: [
        if (viewModel.failure != null)
          CpAlert(
            message: failureMessage(l10n, viewModel.failure!),
            onClose: viewModel.clearFailure,
          ),

        CpTextField(
          label: l10n.weightFieldValue,
          hint: 'g',
          controller: _weightController,
          keyboardType: TextInputType.number,
          autofocus: true,
          prefixIcon: Icons.monitor_weight_outlined,
          // En gramos porque es lo que marca la báscula del galpón; la ficha
          // los presenta en kilos.
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(5),
          ],
          onChanged: viewModel.setWeight,
        ),

        // `RV-12` — advertencia, nunca bloqueo: un pollito de 90 g existe.
        if (viewModel.isOutOfRange) ...[
          const SizedBox(height: AppSpacing.sm),
          CpAlert(message: l10n.weightOutOfRange, tone: CpAlertTone.warning),
        ],
        const SizedBox(height: AppSpacing.md),

        InkWell(
          onTap: _pickDate,
          borderRadius: BorderRadius.circular(AppRadius.md),
          child: InputDecorator(
            decoration: InputDecoration(
              labelText: l10n.weightFieldDate,
              prefixIcon: const Icon(Icons.event_outlined),
            ),
            child: Text(Formatters.date(viewModel.date, locale)),
          ),
        ),
        const SizedBox(height: AppSpacing.md),

        CpTextField(
          label: l10n.weightFieldNotes,
          maxLines: 3,
          textCapitalization: TextCapitalization.sentences,
          onChanged: viewModel.setNotes,
        ),
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
