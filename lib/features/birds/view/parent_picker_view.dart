import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/domain/sex.dart';
import '../../../core/providers/providers.dart';
import '../../../core/router/routes.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/cp_empty_state.dart';
import '../../../core/widgets/cp_text_field.dart';
import '../../../core/widgets/sex_badge.dart';
import '../../../l10n/generated/app_l10n.dart';
import '../model/bird.dart';
import '../viewmodel/parent_picker_viewmodel.dart';
import 'bird_labels.dart';

/// Pantalla 18 — «Elegir progenitor», `RF-REG-11`.
///
/// Se abre desde el formulario anterior y **se cierra devolviendo la elección**,
/// nunca navegando: así el formulario sigue montado detrás con todo lo que el
/// criador había capturado (CU-02 alterno A).
///
/// Devuelve `ParentSelection` por `pop`: distingue «elegí este ejemplar» de
/// «quiero dejarlo sin registrar», que un `Bird?` a secas confundiría con
/// «cancelé».
class ParentPickerView extends ConsumerStatefulWidget {
  const ParentPickerView({required this.sex, super.key, this.excludeId});

  final Sex sex;

  /// El propio ejemplar cuando se edita: nadie puede ser su propio padre
  /// (`RV-10`).
  final String? excludeId;

  @override
  ConsumerState<ParentPickerView> createState() => _ParentPickerViewState();
}

/// Resultado de la pantalla 18.
class ParentSelection {
  const ParentSelection(this.bird);

  /// `null` significa «sin registrar», una elección deliberada.
  final Bird? bird;
}

class _ParentPickerViewState extends ConsumerState<ParentPickerView> {
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _viewModel.load());
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  ParentPickerArgs get _key => (sex: widget.sex, excludeId: widget.excludeId);

  ParentPickerViewModel get _viewModel => ref.read(parentPickerViewModelProvider(_key));

  /// Alta al vuelo. El formulario devuelve el ejemplar creado, así que se puede
  /// elegir directamente sin obligar al criador a buscarlo en una lista que
  /// acaba de cambiar.
  Future<void> _createNew() async {
    final created = await context.push<Bird?>(Routes.birdNew);
    if (!mounted) return;

    if (created != null && created.sex == widget.sex) {
      context.pop(ParentSelection(created));
      return;
    }

    // Se creó de otro sexo (o no se llegó a crear): la lista se relee y el
    // criador decide. Devolver un ejemplar del sexo equivocado rompería
    // `RV-10` justo después.
    _searchController.clear();
    await _viewModel.refreshAfterCreate();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final viewModel = ref.watch(parentPickerViewModelProvider(_key));
    final isMale = widget.sex == Sex.male;

    return Scaffold(
      appBar: AppBar(
        title: Text(isMale ? l10n.parentPickerTitleFather : l10n.parentPickerTitleMother),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: CpTextField(
              label: l10n.commonSearch,
              hint: l10n.parentPickerSearchHint,
              controller: _searchController,
              prefixIcon: Icons.search,
              onChanged: viewModel.setSearch,
            ),
          ),

          // «Sin registrar» arriba y siempre visible: es una respuesta legítima
          // —el progenitor puede no estar en el libro— y no debe costar más
          // que elegir un ejemplar.
          ListTile(
            leading: const Icon(Icons.remove_circle_outline),
            title: Text(l10n.parentPickerNone),
            subtitle: Text(l10n.parentPickerNoneHint),
            onTap: () => context.pop(const ParentSelection(null)),
          ),
          const Divider(height: 1),

          Expanded(
            child: viewModel.candidates.isEmpty
                ? _EmptyState(
                    isFilteredEmpty: viewModel.isFilteredEmpty,
                    isMale: isMale,
                    onCreate: _createNew,
                  )
                : ListView.builder(
                    itemCount: viewModel.candidates.length,
                    itemBuilder: (context, index) {
                      final bird = viewModel.candidates[index];
                      return _CandidateTile(
                        bird: bird,
                        onTap: () => context.pop(ParentSelection(bird)),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: viewModel.candidates.isEmpty
          ? null
          : FloatingActionButton.extended(
              onPressed: _createNew,
              icon: const Icon(Icons.add),
              label: Text(l10n.parentPickerCreate),
            ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.isFilteredEmpty, required this.isMale, required this.onCreate});

  final bool isFilteredEmpty;
  final bool isMale;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);

    // Buscar sin resultados no ofrece crear: el criador está buscando algo
    // concreto, no dando de alta.
    if (isFilteredEmpty) {
      return CpEmptyState(
        icon: Icons.search_off,
        title: l10n.parentPickerSearchEmptyTitle,
        message: l10n.parentPickerSearchEmptyMessage,
      );
    }

    return CpEmptyState(
      icon: isMale ? Icons.male : Icons.female,
      title: isMale ? l10n.parentPickerEmptyMaleTitle : l10n.parentPickerEmptyFemaleTitle,
      message: l10n.parentPickerEmptyMessage,
      actionLabel: l10n.parentPickerCreate,
      onAction: onCreate,
    );
  }
}

class _CandidateTile extends StatelessWidget {
  const _CandidateTile({required this.bird, required this.onTap});

  final Bird bird;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final color = SexBadge.colorOf(context, bird.sex);

    final subtitle = [
      Formatters.plate(bird.plate),
      if (bird.line != null) bird.line!,
      ageLabel(l10n, bird.birthDate),
    ].join(' · ');

    return ListTile(
      onTap: onTap,
      leading: CircleAvatar(
        backgroundColor: color.withValues(alpha: 0.16),
        child: Icon(SexBadge.iconOf(bird.sex), color: color),
      ),
      title: Text(bird.displayName, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis),
    );
  }
}
