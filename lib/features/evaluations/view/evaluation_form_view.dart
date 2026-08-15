import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/domain/sex.dart';
import '../../../core/error/failure_messages.dart';
import '../../../core/providers/providers.dart';
import '../../../core/router/routes.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/semantic_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/cp_button.dart';
import '../../../core/widgets/cp_text_field.dart';
import '../../../l10n/generated/app_l10n.dart';
import '../../birds/model/bird.dart';
import '../../birds/view/parent_picker_view.dart';
import '../../birds/view/widgets/form_fields.dart';
import '../model/evaluation.dart';
import '../viewmodel/evaluation_form_viewmodel.dart';
import 'evaluation_labels.dart';

/// Pantalla 25 — registro de una prueba de campo, `RF-PRU-01` y `RF-PRU-02`.
class EvaluationFormView extends ConsumerStatefulWidget {
  const EvaluationFormView({super.key, this.birdId});

  /// Preseleccionado cuando se abre desde la ficha de un ejemplar.
  final String? birdId;

  @override
  ConsumerState<EvaluationFormView> createState() => _EvaluationFormViewState();
}

class _EvaluationFormViewState extends ConsumerState<EvaluationFormView> {
  final _placeController = TextEditingController();
  final _weightController = TextEditingController();
  final _notesController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _viewModel.load());
  }

  @override
  void dispose() {
    _placeController.dispose();
    _weightController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  EvaluationFormViewModel get _viewModel =>
      ref.read(evaluationFormViewModelProvider(widget.birdId));

  Future<void> _pickDate() async {
    final viewModel = _viewModel;
    final now = DateTime.now();

    final picked = await showDatePicker(
      context: context,
      initialDate: viewModel.date,
      firstDate: DateTime(now.year - 20),
      lastDate: now,
    );
    if (picked != null) viewModel.setDate(picked);
  }

  /// Reutiliza la pantalla 18: elegir el ejemplar evaluado es el mismo gesto
  /// que elegir un progenitor, con buscador y alta al vuelo.
  Future<void> _pickBird() async {
    final selection = await context.push<ParentSelection>(Routes.parentPicker(Sex.male.id));
    if (selection != null) _viewModel.setBird(selection.bird);
  }

  Future<void> _submit() async {
    final l10n = AppL10n.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final viewModel = _viewModel;

    final saved = await viewModel.submit();
    if (!mounted) return;

    if (saved != null) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.testsSaved)));
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
    final viewModel = ref.watch(evaluationFormViewModelProvider(widget.birdId));

    return Scaffold(
      appBar: AppBar(title: Text(l10n.testsFormTitle)),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          // El ejemplar es lo único obligatorio: una prueba sin sujeto no dice
          // nada. Abierta desde la ficha viene fijo y no se puede cambiar.
          if (!viewModel.isBirdLocked) ...[
            SectionLabel(l10n.testsFieldBird),
            _BirdField(bird: viewModel.bird, onTap: _pickBird),
            const SizedBox(height: AppSpacing.lg),
          ],

          SectionLabel(l10n.birdSectionIdentity),
          DateField(
            label: l10n.fieldBirthDate,
            value: viewModel.date,
            formatted: Formatters.date(viewModel.date, locale),
            onTap: _pickDate,
          ),
          const SizedBox(height: AppSpacing.md),
          CpTextField(
            label: l10n.testsFieldPlace,
            controller: _placeController,
            textCapitalization: TextCapitalization.words,
            prefixIcon: Icons.place_outlined,
            helper: l10n.commonOptional,
            onChanged: viewModel.setPlace,
          ),

          const SizedBox(height: AppSpacing.lg),
          SectionLabel(l10n.testsFieldResult),
          _ResultSelector(selected: viewModel.result, onChanged: viewModel.setResult),

          const SizedBox(height: AppSpacing.lg),
          SectionLabel(l10n.testsFieldCondition),
          _ConditionScale(
            value: viewModel.condition,
            min: viewModel.minCondition,
            max: viewModel.maxCondition,
            onChanged: viewModel.setCondition,
          ),
          InlineWarning(message: l10n.testsFieldConditionHint),

          const SizedBox(height: AppSpacing.lg),
          SectionLabel(l10n.birdSectionExtra),
          CpTextField(
            label: l10n.fieldWeight,
            controller: _weightController,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            prefixIcon: Icons.monitor_weight_outlined,
            helper: l10n.commonOptional,
            onChanged: viewModel.setWeight,
          ),
          const SizedBox(height: AppSpacing.md),
          CpTextField(
            label: l10n.fieldNotes,
            controller: _notesController,
            maxLines: 3,
            onChanged: viewModel.setNotes,
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

class _BirdField extends StatelessWidget {
  const _BirdField({required this.onTap, this.bird});

  final Bird? bird;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: l10n.testsFieldBird,
          prefixIcon: const Icon(Icons.search),
          suffixIcon: const Icon(Icons.chevron_right),
        ),
        child: Text(
          bird == null
              ? l10n.parentPickerNone
              : '#${bird!.plate}${bird!.name == null ? '' : ' · ${bird!.name}'}',
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}

/// `RF-PRU-02` — favorable, desfavorable o sin definir.
class _ResultSelector extends StatelessWidget {
  const _ResultSelector({required this.selected, required this.onChanged});

  final EvaluationResult selected;
  final ValueChanged<EvaluationResult> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);

    return SegmentedButton<EvaluationResult>(
      segments: [
        for (final result in EvaluationResult.values)
          ButtonSegment(value: result, label: Text(resultLabel(l10n, result))),
      ],
      selected: {selected},
      showSelectedIcon: false,
      onSelectionChanged: (selection) => onChanged(selection.first),
    );
  }
}

/// Condición de 1 a 10 como diez botones y no como un deslizador: el criador
/// piensa en un número entero, y un `Slider` obliga a apuntar con precisión a
/// un valor concreto en un galpón, con el teléfono en una mano.
class _ConditionScale extends StatelessWidget {
  const _ConditionScale({
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  final int? value;
  final int min;
  final int max;
  final ValueChanged<int?> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: [
        for (var i = min; i <= max; i++)
          ChoiceChip(
            label: Text('$i'),
            selected: value == i,
            onSelected: (_) => onChanged(i),
            selectedColor: context.semantic.favorable.withValues(alpha: 0.18),
            labelStyle: theme.textTheme.bodyMedium,
          ),
      ],
    );
  }
}
