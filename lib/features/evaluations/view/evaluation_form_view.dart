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
import '../../../core/widgets/cp_cards.dart';
import '../../../core/widgets/cp_segmented.dart';
import '../../../core/widgets/cp_text_field.dart';
import '../../../core/widgets/motion.dart';
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
  final _durationController = TextEditingController();
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
    _durationController.dispose();
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

          // El tipo va primero: decide qué significa todo lo demás. Un pesaje
          // de rutina y una prueba de campo no se leen igual.
          SectionLabel(l10n.evalFieldType),
          CpSegmented<EvaluationType>(
            segments: [
              for (final type in EvaluationType.values)
                CpSegment(value: type, label: evaluationTypeLabel(l10n, type)),
            ],
            selected: viewModel.type,
            onChanged: viewModel.setType,
          ),

          const SizedBox(height: AppSpacing.lg),
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
          SectionLabel(l10n.evalIndices),
          Text(
            l10n.evalIndicesHint,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: AppSpacing.sm),
          _IndexRow(
            label: l10n.evalStamina,
            value: viewModel.stamina,
            onChanged: viewModel.setStamina,
          ),
          _IndexRow(
            label: l10n.evalAgility,
            value: viewModel.agility,
            onChanged: viewModel.setAgility,
          ),
          _IndexRow(
            label: l10n.evalResponse,
            value: viewModel.response,
            onChanged: viewModel.setResponse,
          ),

          const SizedBox(height: AppSpacing.lg),
          SectionLabel(l10n.evalFinalCondition),
          CpSegmented<FinalCondition>(
            segments: [
              for (final condition in FinalCondition.values)
                CpSegment(value: condition, label: finalConditionLabel(l10n, condition)),
            ],
            selected: viewModel.finalCondition ?? FinalCondition.good,
            onChanged: viewModel.setFinalCondition,
          ),

          const SizedBox(height: AppSpacing.lg),
          SectionLabel(l10n.birdSectionExtra),
          Row(
            children: [
              Expanded(
                child: CpTextField(
                  label: l10n.fieldWeight,
                  controller: _weightController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  prefixIcon: Icons.monitor_weight_outlined,
                  onChanged: viewModel.setWeight,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: CpTextField(
                  label: l10n.evalFieldDuration,
                  controller: _durationController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  prefixIcon: Icons.timer_outlined,
                  onChanged: viewModel.setDuration,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          CpTextField(
            label: l10n.fieldNotes,
            controller: _notesController,
            maxLines: 3,
            onChanged: viewModel.setNotes,
          ),

          // El diseño lo dice aquí, y conviene: un criador que no sabe quién ve
          // estos números no los anota con sinceridad.
          const SizedBox(height: AppSpacing.md),
          CpInfoCard(message: l10n.evalPrivacy),

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

/// Un índice de desempeño: cinco puntos, del 1 al 5.
///
/// Cinco botones y no un desplegable ni un deslizador: se toca una vez, se ve
/// el valor sin abrir nada, y en el galpón un deslizador con guantes no acierta.
class _IndexRow extends StatelessWidget {
  const _IndexRow({required this.label, required this.value, required this.onChanged});

  final String label;
  final int? value;
  final ValueChanged<int?> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        children: [
          Expanded(child: Text(label, style: theme.textTheme.bodyLarge)),
          for (var n = 1; n <= 5; n++)
            Padding(
              padding: const EdgeInsets.only(left: AppSpacing.xs),
              child: _IndexDot(n: n, selected: value == n, onTap: () => onChanged(n)),
            ),
        ],
      ),
    );
  }
}

class _IndexDot extends StatelessWidget {
  const _IndexDot({required this.n, required this.selected, required this.onTap});

  final int n;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final brand = context.semantic.brand;

    return CpPressable(
      child: Material(
        color: selected ? brand : theme.colorScheme.surfaceContainerHighest,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(
            width: 36,
            height: 36,
            child: Center(
              child: Text(
                '$n',
                style: theme.textTheme.titleSmall?.copyWith(
                  color: selected ? Colors.white : theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
