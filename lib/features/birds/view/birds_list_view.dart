import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/base/view_state.dart';
import '../../../core/domain/markings.dart';
import '../../../core/domain/sex.dart';
import '../../../core/error/failure_messages.dart';
import '../../../core/providers/providers.dart';
import '../../../core/router/routes.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/semantic_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/brand.dart';
import '../../../core/widgets/cp_empty_state.dart';
import '../../../core/widgets/cp_text_field.dart';
import '../../../core/widgets/motion.dart';
import '../../../core/widgets/sex_badge.dart';
import '../../../l10n/generated/app_l10n.dart';
import '../../dashboard/view/widgets/app_drawer.dart';
import '../model/bird.dart';
import 'bird_labels.dart';
import 'widgets/marking_fields.dart';

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
        actions: [
          // El alta va arriba y no abajo, como en el diseño: el pulgar la
          // encuentra igual y deja de tapar la última fila de la lista.
          Padding(
            padding: const EdgeInsets.only(right: AppSpacing.md),
            child: _AddButton(onPressed: () => context.push(Routes.birdNew)),
          ),
        ],
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
        _ => Column(
          children: [
            // Cuántos hay: con la lista filtrada es la única forma de saber si
            // el filtro dejó fuera medio criadero o solo un par de aves.
            _RecordCount(count: viewModel.birds.length),
            const Divider(height: 1),
            Expanded(child: _BirdsList(birds: viewModel.birds)),
          ],
        ),
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
      // Las primeras filas entran escalonadas: la lista se lee de arriba
      // abajo en vez de aparecer de golpe. De la décima en adelante entran ya
      // colocadas, para que desplazarse no arrastre un retardo por fila.
      itemBuilder: (context, index) => CpFadeUp(
        delay: cpStagger(index),
        child: _BirdTile(bird: birds[index]),
      ),
    );
  }
}

/// Botón de alta: disco rojo de acción, como en el diseño.
class _AddButton extends StatelessWidget {
  const _AddButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);

    return CpPressable(
      child: Material(
        color: context.semantic.action,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onPressed,
          child: Tooltip(
            message: l10n.birdsAdd,
            // 44 px es el mínimo táctil del PRD §6; el disco del diseño es
            // mayor, así que no hace falta área extra.
            child: const SizedBox(
              width: 44,
              height: 44,
              child: Icon(Icons.add, color: Colors.white),
            ),
          ),
        ),
      ),
    );
  }
}

class _RecordCount extends StatelessWidget {
  const _RecordCount({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screen, vertical: AppSpacing.sm),
      child: Text(
        l10n.birdsRecordCount(count),
        textAlign: TextAlign.center,
        style: theme.textTheme.titleSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
      ),
    );
  }
}

class _BirdTile extends StatelessWidget {
  const _BirdTile({required this.bird});

  final Bird bird;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final theme = Theme.of(context);

    // La placa encabeza el subtítulo: es el identificador del criador, y el
    // nombre —que es opcional— va arriba solo porque se reconoce antes.
    final subtitle = [
      l10n.birdsPlateLabel(Formatters.plate(bird.plate)),
      if ((bird.line ?? '').isNotEmpty) bird.line!,
    ].join(' · ');

    return InkWell(
      onTap: () => context.push(Routes.birdDetail(bird.id)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screen, vertical: AppSpacing.sm),
        child: Row(
          children: [
            _BirdThumbnail(bird: bird),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    bird.displayName,
                    style: theme.textTheme.titleMedium,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    subtitle,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            _StatusLabel(status: bird.status),
          ],
        ),
      ),
    );
  }
}

/// Foto del ejemplar, o su silueta, con la cinta de ala como franja inferior.
///
/// La cinta es lo que el criador ve desde lejos en el galpón: reconocer la fila
/// por el mismo color que lleva el ave puesta le ahorra leer la placa. El color
/// no va solo (`RNF-25`) — lo acompaña la descripción accesible, porque la
/// etiqueta no cabe en cinco píxeles.
class _BirdThumbnail extends StatelessWidget {
  const _BirdThumbnail({required this.bird});

  final Bird bird;

  static const double _size = 56;
  static const double _bandHeight = 5;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final theme = Theme.of(context);

    final photo = bird.photoPath == null ? null : File(bird.photoPath!);
    final hasPhoto = photo != null && photo.existsSync();

    final band = WingBand.fromId(bird.wingBandLeft) ?? WingBand.fromId(bird.wingBandRight);

    return Semantics(
      label: band == null ? null : l10n.birdWingBandOf(bandLabel(l10n, band)),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: SizedBox(
          width: _size,
          height: _size,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (hasPhoto)
                Image.file(photo, fit: BoxFit.cover)
              else
                ColoredBox(
                  color: theme.colorScheme.surfaceContainerHighest,
                  child: const Center(child: BrandSymbol(size: 28, opacity: 0.45)),
                ),
              if (band != null)
                Align(
                  alignment: Alignment.bottomCenter,
                  child: Container(height: _bandHeight, color: band.color),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Estado en versaleta al margen derecho, como en el diseño.
///
/// Va en texto y no en un punto de color: el color solo no puede portar el
/// significado (`RNF-25`), y «MUERTO» tiene que leerse sin interpretar un tono.
class _StatusLabel extends StatelessWidget {
  const _StatusLabel({required this.status});

  final BirdStatus status;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final theme = Theme.of(context);
    final semantic = context.semantic;

    final color = switch (status) {
      BirdStatus.active => semantic.male,
      BirdStatus.sold => semantic.action,
      BirdStatus.loaned => semantic.warning,
      BirdStatus.deceased => theme.colorScheme.onSurfaceVariant,
    };

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 108),
      child: Text(
        statusLabel(l10n, status).toUpperCase(),
        textAlign: TextAlign.end,
        style: theme.textTheme.labelMedium?.copyWith(color: color, fontWeight: FontWeight.w700),
      ),
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

/// Solo para las capturas de `test/ui_preview_test.dart`: la lista real vive
/// detrás de la autenticación y de una base con datos, y esta es la única forma
/// de mirarla con el ojo antes de darla por buena.
@visibleForTesting
class BirdsListPreview extends StatelessWidget {
  const BirdsListPreview({required this.birds, super.key});

  final List<Bird> birds;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      _RecordCount(count: birds.length),
      const Divider(height: 1),
      for (final bird in birds) ...[
        _BirdTile(bird: bird),
        const Divider(height: 1, indent: AppSpacing.screen),
      ],
    ],
  );
}
