import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/base/view_state.dart';
import '../../../core/domain/sex.dart';
import '../../../core/error/failure_messages.dart';
import '../../../core/providers/providers.dart';
import '../../../core/router/routes.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/brand.dart';
import '../../../core/widgets/cp_empty_state.dart';
import '../../../core/widgets/cp_text_field.dart';
import '../../../core/widgets/sex_badge.dart';
import '../../../l10n/generated/app_l10n.dart';
import '../../dashboard/view/widgets/app_drawer.dart';
import '../model/bird.dart';
import 'bird_labels.dart';

class BirdsListView extends ConsumerWidget {
  const BirdsListView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppL10n.of(context);
    final viewModel = ref.watch(birdsListViewModelProvider);

    return Scaffold(
      drawer: const AppDrawer(),
      appBar: AppBar(
        title: Text(l10n.birdsTitle),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(112),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.md, 0, AppSpacing.md, AppSpacing.sm),
            child: Column(
              children: [
                CpTextField(
                  label: l10n.commonSearch,
                  hint: l10n.birdsSearchHint,
                  prefixIcon: Icons.search,
                  onChanged: viewModel.setSearch,
                ),
                const SizedBox(height: AppSpacing.sm),
                Row(
                  children: [
                    Expanded(
                      child: _SexFilterBar(
                        selected: viewModel.sexFilter,
                        onSelected: viewModel.setSexFilter,
                      ),
                    ),
                    // `RF-REG-05` — el estado va en un menú y no en más chips:
                    // son cuatro valores que se usan poco, y en una fila junto
                    // al sexo competirían por el espacio de lo que sí se toca
                    // a diario.
                    _StatusFilterButton(
                      selected: viewModel.statusFilter,
                      onSelected: viewModel.setStatusFilter,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
      // Con la lista vacía el botón flotante sobra: el estado vacío ya trae su
      // acción primaria en el centro, y dos botones idénticos en la misma
      // pantalla obligan a decidir cuál pulsar cuando da igual. En cuanto hay
      // ejemplares que leer, el flotante vuelve — ahí no compite con nada.
      floatingActionButton: viewModel.birds.isEmpty
          ? null
          : FloatingActionButton.extended(
              onPressed: () => context.push(Routes.birdNew),
              icon: const Icon(Icons.add),
              label: Text(l10n.birdsAdd),
            ),
      body: switch (viewModel.state) {
        ViewState.loading when viewModel.birds.isEmpty => const Center(
          child: CircularProgressIndicator(),
        ),
        ViewState.error when viewModel.birds.isEmpty => CpEmptyState(
          icon: Icons.error_outline,
          title: failureMessage(l10n, viewModel.failure!),
        ),
        _ when viewModel.birds.isEmpty => CpEmptyState(
          icon: viewModel.isFiltered ? Icons.search_off : null,
          iconWidget: viewModel.isFiltered ? null : const BrandSymbol(size: 56, opacity: 0.35),
          title: viewModel.isFiltered ? l10n.birdsEmptySearchTitle : l10n.birdsEmptyTitle,
          message: viewModel.isFiltered ? l10n.birdsEmptySearchMessage : l10n.birdsEmptyMessage,
          actionLabel: viewModel.isFiltered ? null : l10n.birdsAdd,
          onAction: viewModel.isFiltered ? null : () => context.push(Routes.birdNew),
        ),
        _ => _BirdsList(birds: viewModel.birds),
      },
    );
  }
}

class _SexFilterBar extends StatelessWidget {
  const _SexFilterBar({required this.selected, required this.onSelected});

  final Sex? selected;
  final ValueChanged<Sex?> onSelected;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);

    return SizedBox(
      height: 40,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          FilterChip(
            label: Text(l10n.commonAll),
            selected: selected == null,
            onSelected: (_) => onSelected(null),
          ),
          for (final sex in Sex.values) ...[
            const SizedBox(width: AppSpacing.sm),
            FilterChip(
              avatar: Icon(SexBadge.iconOf(sex), size: 18, color: SexBadge.colorOf(context, sex)),
              label: Text(sexLabel(l10n, sex)),
              selected: selected == sex,
              onSelected: (isSelected) => onSelected(isSelected ? sex : null),
            ),
          ],
        ],
      ),
    );
  }
}

class _BirdsList extends StatelessWidget {
  const _BirdsList({required this.birds});

  final List<Bird> birds;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      // Espacio extra abajo para que el FAB no tape el último elemento.
      padding: const EdgeInsets.only(bottom: 96),
      itemCount: birds.length,
      separatorBuilder: (_, _) => const Divider(height: 1, indent: AppSpacing.md),
      itemBuilder: (context, index) => _BirdTile(bird: birds[index]),
    );
  }
}

class _BirdTile extends StatelessWidget {
  const _BirdTile({required this.bird});

  final Bird bird;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final color = SexBadge.colorOf(context, bird.sex);
    // La placa encabeza el subtítulo: es el identificador del criador.
    final subtitle = [
      Formatters.plate(bird.plate),
      if (bird.line != null) bird.line!,
      ageLabel(l10n, bird.birthDate),
      if (bird.status != BirdStatus.active) statusLabel(l10n, bird.status),
    ].join(' · ');

    return ListTile(
      onTap: () => context.push(Routes.birdDetail(bird.id)),
      leading: CircleAvatar(
        backgroundColor: color.withValues(alpha: 0.16),
        child: Icon(SexBadge.iconOf(bird.sex), color: color),
      ),
      title: Text(bird.displayName, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: const Icon(Icons.chevron_right),
    );
  }
}

/// Filtro por estado del ejemplar — `RF-REG-05`.
///
/// El punto sobre el embudo indica que hay un filtro puesto: sin él, una lista
/// filtrada se confunde con una lista vacía.
class _StatusFilterButton extends StatelessWidget {
  const _StatusFilterButton({required this.selected, required this.onSelected});

  final BirdStatus? selected;
  final ValueChanged<BirdStatus?> onSelected;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final theme = Theme.of(context);
    final isActive = selected != null;

    return PopupMenuButton<BirdStatus?>(
      tooltip: l10n.birdsFilterByStatus,
      onSelected: onSelected,
      icon: Badge(
        isLabelVisible: isActive,
        smallSize: 8,
        backgroundColor: theme.colorScheme.primary,
        child: Icon(
          Icons.filter_list,
          color: isActive ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant,
        ),
      ),
      itemBuilder: (context) => [
        PopupMenuItem<BirdStatus?>(value: null, child: Text(l10n.commonAll)),
        for (final status in BirdStatus.values)
          PopupMenuItem<BirdStatus?>(value: status, child: Text(statusLabel(l10n, status))),
      ],
    );
  }
}
