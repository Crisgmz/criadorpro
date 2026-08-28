import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/domain/bird_traits.dart';
import '../../../core/domain/sex.dart';
import '../../../core/error/failure_messages.dart';
import '../../../core/providers/providers.dart';
import '../../../core/router/routes.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/cp_button.dart';
import '../../../core/widgets/cp_photo_field.dart';
import '../../../core/widgets/cp_text_field.dart';
import '../../../core/widgets/sex_badge.dart';
import '../../../l10n/generated/app_l10n.dart';
import '../model/bird.dart';
import '../viewmodel/bird_form_viewmodel.dart';
import 'bird_labels.dart';
import 'widgets/form_fields.dart';
import 'widgets/marking_fields.dart';
import 'widgets/trait_picker.dart';

/// Alta y edición de un ejemplar. Sin [birdId] es un alta.
class BirdFormView extends ConsumerStatefulWidget {
  const BirdFormView({super.key, this.birdId, this.returnsResult = false});

  final String? birdId;

  /// `true` cuando el alta es un paso dentro de otra tarea —el selector de
  /// progenitor— y quien la abrió espera el ejemplar de vuelta.
  final bool returnsResult;

  @override
  ConsumerState<BirdFormView> createState() => _BirdFormViewState();
}

class _BirdFormViewState extends ConsumerState<BirdFormView> {
  final _nameController = TextEditingController();
  final _plateController = TextEditingController();
  final _lineController = TextEditingController();
  final _weightController = TextEditingController();
  final _notesController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // `ref` no se puede leer durante initState: lo dejamos para el siguiente
    // microtask, cuando el provider ya está disponible.
    Future.microtask(_load);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _plateController.dispose();
    _lineController.dispose();
    _weightController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  BirdFormViewModel get _viewModel => ref.read(birdFormViewModelProvider(widget.birdId));

  Future<void> _load() async {
    await _viewModel.load();
    if (!mounted) return;
    final viewModel = _viewModel;
    _nameController.text = viewModel.name;
    _plateController.text = viewModel.plate;
    _lineController.text = viewModel.line;
    _weightController.text = viewModel.weight;
    _notesController.text = viewModel.notes;
  }

  Future<void> _pickBirthDate() async {
    final viewModel = _viewModel;
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: viewModel.birthDate ?? now,
      firstDate: DateTime(now.year - 30),
      lastDate: now,
    );
    if (picked != null) viewModel.setBirthDate(picked);
  }

  Future<void> _submit() async {
    final l10n = AppL10n.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final viewModel = _viewModel;

    final saved = await viewModel.submit();
    if (!mounted) return;

    if (saved != null) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.birdSaved)));

      // Editar vuelve a la ficha de donde se vino, y el alta que abrió el
      // selector de progenitor devuelve el ejemplar. Pero un alta suelta acaba
      // en la lista: es donde el criador ve el resultado de lo que hizo, y
      // volver a Inicio le obliga a buscarlo.
      if (viewModel.isEditing || widget.returnsResult) {
        navigator.pop(saved);
      } else {
        context.go(Routes.birds);
      }
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
    final viewModel = ref.watch(birdFormViewModelProvider(widget.birdId));

    return Scaffold(
      appBar: AppBar(title: Text(viewModel.isEditing ? l10n.birdEdit : l10n.birdNew)),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          SectionLabel(l10n.birdSectionIdentity),
          // La placa va primero y es lo único obligatorio (`RF-REG-06`): es el
          // dato con el que el criador identifica al ejemplar en su libro.
          Focus(
            onFocusChange: (hasFocus) {
              if (!hasFocus) viewModel.validatePlate();
            },
            child: CpTextField(
              label: l10n.fieldPlate,
              controller: _plateController,
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.next,
              prefixIcon: Icons.tag,
              errorText: viewModel.plateError == null
                  ? null
                  : validationMessage(l10n, viewModel.plateError!),
              onChanged: viewModel.setPlate,
            ),
          ),
          // `RV-08` — duplicar advierte pero no bloquea: el libro de papel a
          // veces repite y el criador necesita poder reflejarlo tal cual.
          if (viewModel.isPlateTaken) InlineWarning(message: l10n.birdPlateTaken),
          const SizedBox(height: AppSpacing.md),
          CpTextField(
            label: l10n.fieldName,
            controller: _nameController,
            helper: l10n.commonOptional,
            textInputAction: TextInputAction.next,
            onChanged: viewModel.setName,
          ),
          const SizedBox(height: AppSpacing.md),
          _SexSelector(selected: viewModel.sex, onChanged: viewModel.setSex),
          const SizedBox(height: AppSpacing.md),
          DateField(
            label: l10n.fieldBirthDate,
            value: viewModel.birthDate,
            formatted: viewModel.birthDate == null
                ? ''
                : Formatters.date(viewModel.birthDate!, locale),
            onTap: _pickBirthDate,
            onClear: () => viewModel.setBirthDate(null),
          ),

          const SizedBox(height: AppSpacing.lg),
          SectionLabel(l10n.birdSectionOrigin),
          ParentField(
            label: l10n.fieldFather,
            sex: Sex.male,
            value: viewModel.father,
            excludeId: viewModel.excludeId,
            onChanged: viewModel.setFather,
          ),
          const SizedBox(height: AppSpacing.md),
          ParentField(
            label: l10n.fieldMother,
            sex: Sex.female,
            value: viewModel.mother,
            excludeId: viewModel.excludeId,
            onChanged: viewModel.setMother,
          ),
          const SizedBox(height: AppSpacing.md),
          CpTextField(
            label: l10n.fieldLine,
            controller: _lineController,
            textInputAction: TextInputAction.next,
            onChanged: viewModel.setLine,
          ),

          const SizedBox(height: AppSpacing.lg),
          SectionLabel(l10n.birdSectionExtra),
          PhotoField(
            path: viewModel.photoPath,
            isBusy: viewModel.isCapturingPhoto,
            onCapture: viewModel.capturePhoto,
            onRemove: viewModel.removePhoto,
          ),
          const SizedBox(height: AppSpacing.md),
          DropdownButtonFormField<BirdStatus>(
            initialValue: viewModel.status,
            decoration: InputDecoration(labelText: l10n.fieldStatus),
            items: [
              for (final status in BirdStatus.values)
                DropdownMenuItem(value: status, child: Text(statusLabel(l10n, status))),
            ],
            onChanged: (status) => viewModel.setStatus(status ?? BirdStatus.active),
          ),
          const SizedBox(height: AppSpacing.md),
          TraitField(
            trait: BirdTrait.plumage,
            value: viewModel.color,
            onChanged: viewModel.setColor,
          ),
          const SizedBox(height: AppSpacing.md),
          TraitField(trait: BirdTrait.comb, value: viewModel.comb, onChanged: viewModel.setComb),

          const SizedBox(height: AppSpacing.lg),
          // Marca de nacimiento: es como el criador identifica la nidada antes
          // de que las crías tengan placa.
          SectionLabel(l10n.markingTitle),
          BirthMarkPicker(value: viewModel.birthMark, onChanged: viewModel.setBirthMark),

          const SizedBox(height: AppSpacing.lg),
          SectionLabel(l10n.markingBands),
          WingBandPicker(
            left: viewModel.wingLeft,
            right: viewModel.wingRight,
            onLeftChanged: viewModel.setWingLeft,
            onRightChanged: viewModel.setWingRight,
          ),
          const SizedBox(height: AppSpacing.md),
          CpTextField(
            label: l10n.fieldWeight,
            controller: _weightController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
            errorText: viewModel.weightError == null
                ? null
                : validationMessage(l10n, viewModel.weightError!),
            onChanged: viewModel.setWeight,
          ),
          const SizedBox(height: AppSpacing.md),
          CpTextField(
            label: l10n.fieldNotes,
            controller: _notesController,
            maxLines: 4,
            onChanged: viewModel.setNotes,
          ),

          const SizedBox(height: AppSpacing.xl),
          CpButton(label: l10n.commonSave, isLoading: viewModel.isLoading, onPressed: _submit),
          const SizedBox(height: AppSpacing.md),
        ],
      ),
    );
  }
}

class _SexSelector extends StatelessWidget {
  const _SexSelector({required this.selected, required this.onChanged});

  final Sex selected;
  final ValueChanged<Sex> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);

    return Align(
      alignment: Alignment.centerLeft,
      child: SegmentedButton<Sex>(
        segments: [
          for (final sex in Sex.values)
            ButtonSegment(
              value: sex,
              icon: Icon(SexBadge.iconOf(sex)),
              label: Text(sexLabel(l10n, sex)),
            ),
        ],
        selected: {selected},
        onSelectionChanged: (selection) => onChanged(selection.first),
      ),
    );
  }
}

/// Aviso en línea bajo un campo: la regla se cumple pero conviene mirarla.
///
/// `RV-08` y `RV-12` advierten sin bloquear, así que no puede usar el rojo de
/// error — el usuario debe poder guardar igualmente.
