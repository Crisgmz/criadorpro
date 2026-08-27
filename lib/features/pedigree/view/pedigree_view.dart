import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/base/view_state.dart';
import '../../../core/error/failure_messages.dart';
import '../../../core/export/export_button.dart';
import '../../../core/providers/providers.dart';
import '../../../core/router/routes.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/cp_alert.dart';
import '../../../core/widgets/cp_cards.dart';
import '../../../core/widgets/cp_empty_state.dart';
import '../../../core/widgets/cp_segmented.dart';
import '../../../core/widgets/motion.dart';
import '../../../core/widgets/subject_card.dart';
import '../../../l10n/generated/app_l10n.dart';
import '../model/pedigree_node.dart';
import '../viewmodel/pedigree_viewmodel.dart';

/// Pantalla 23 — árbol genealógico, `RF-PED-01` a `RF-PED-07`.
///
/// El recorrido es **vertical, por generaciones**: el ejemplar arriba y cada
/// generación debajo, rotulada. Sustituye al árbol horizontal con zoom, que
/// obligaba a arrastrar y ampliar para leer un nombre — en un teléfono, a un
/// brazo de distancia y con sol, eso no se hace.
///
/// La disposición vertical además **cabe entera en la anchura del teléfono**:
/// no hay nada que se salga por el lado, y desplazarse hacia abajo es el gesto
/// que el criador ya hace en el resto de la app.
class PedigreeView extends ConsumerStatefulWidget {
  const PedigreeView({required this.birdId, super.key});

  final String birdId;

  @override
  ConsumerState<PedigreeView> createState() => _PedigreeViewState();
}

class _PedigreeViewState extends ConsumerState<PedigreeView> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => ref.read(pedigreeViewModelProvider(widget.birdId)).load(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final theme = Theme.of(context);
    final viewModel = ref.watch(pedigreeViewModelProvider(widget.birdId));
    final root = viewModel.root;

    return Scaffold(
      backgroundColor: theme.colorScheme.surfaceContainerLowest,
      appBar: AppBar(
        // Título y ejemplar juntos: el pedigrí de un ave sin decir de cuál es
        // no significa nada, y volver a leer el nombre en la tarjeta llega
        // tarde si el criador abrió la pantalla equivocada.
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(l10n.pedigreeTitle),
            if (root != null)
              Text(
                '${root.bird.displayName} · ${Formatters.plate(root.bird.plate)}',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
          ],
        ),
        bottom: root == null
            ? null
            : PreferredSize(
                preferredSize: const Size.fromHeight(64),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.screen,
                    0,
                    AppSpacing.screen,
                    AppSpacing.md,
                  ),
                  child: _DepthSelector(viewModel: viewModel),
                ),
              ),
      ),
      body: switch (viewModel.state) {
        ViewState.loading when root == null => const Center(child: CircularProgressIndicator()),
        ViewState.error => CpEmptyState(
          icon: Icons.error_outline,
          title: failureMessage(l10n, viewModel.failure!),
        ),
        _ when root == null => const SizedBox.shrink(),
        _ => _Tree(root: root, viewModel: viewModel),
      },
    );
  }
}

/// `RF-PED-02` — dos, tres o cuatro generaciones.
class _DepthSelector extends StatelessWidget {
  const _DepthSelector({required this.viewModel});

  final PedigreeViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);

    return CpSegmented<int>(
      segments: [
        for (final option in PedigreeViewModel.depthOptions)
          CpSegment(
            value: option,
            label: l10n.pedigreeGenerations(option),
            // Las profundidades que el plan no permite se ven, pero
            // deshabilitadas: esconderlas ocultaría que existen.
            enabled: viewModel.isDepthAvailable(option),
          ),
      ],
      selected: viewModel.depth,
      onChanged: viewModel.setDepth,
    );
  }
}

class _Tree extends ConsumerWidget {
  const _Tree({required this.root, required this.viewModel});

  final PedigreeNode root;
  final PedigreeViewModel viewModel;

  /// Nodos de una generación, de arriba abajo y con los huecos incluidos.
  ///
  /// Los `null` son parte del resultado, no un error: mantienen la posición de
  /// cada casilla para que el par de cada progenitor quede siempre junto.
  static List<PedigreeNode?> levelOf(PedigreeNode? root, int generation) {
    var level = <PedigreeNode?>[root];
    for (var i = 0; i < generation; i++) {
      level = [
        for (final node in level) ...[node?.father, node?.mother],
      ];
    }
    return level;
  }

  String _generationLabel(AppL10n l10n, int generation) => switch (generation) {
    1 => l10n.pedigreeGeneration1,
    2 => l10n.pedigreeGeneration2,
    3 => l10n.pedigreeGeneration3,
    _ => l10n.pedigreeGeneration4,
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppL10n.of(context);

    final hasEmptySlot = [
      for (var generation = 1; generation <= viewModel.depth; generation++)
        ...levelOf(root, generation),
    ].any((node) => node == null);

    return ListView(
      padding: const EdgeInsets.only(bottom: AppSpacing.xxl),
      children: [
        const SizedBox(height: AppSpacing.md),

        // `RF-PED-03`: decir que el plan recorta el árbol. Callarlo haría
        // pensar que al ejemplar le faltan ancestros.
        if (viewModel.isLimitedByPlan)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screen),
            child: CpAlert(
              message: l10n.pedigreePlanNotice(viewModel.allowedDepth),
              tone: CpAlertTone.info,
            ),
          ),

        // `RF-PED-06`: se avisa una vez, no en cada nodo afectado.
        if (root.hasCycle)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screen),
            child: CpAlert(message: l10n.pedigreeCycleNotice, tone: CpAlertTone.warning),
          ),

        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screen),
          child: CpSubjectCard(
            title: root.bird.displayName,
            subtitle: [
              l10n.birdsPlateLabel(Formatters.plate(root.bird.plate)),
              if ((root.bird.line ?? '').isNotEmpty) root.bird.line!,
            ].join(' · '),
            photoPath: root.bird.photoPath,
          ),
        ),

        for (var generation = 1; generation <= viewModel.depth; generation++) ...[
          const _Connector(),
          CpSectionLabel(_generationLabel(l10n, generation)),
          _GenerationGrid(
            nodes: levelOf(root, generation),
            // El rol solo se rotula en la primera generación: en la segunda,
            // «abuelo paterno» por partida cuádruple es ruido, y la posición
            // ya lo dice.
            showRoles: generation == 1,
          ),
        ],

        // `RF-PED-05` — una casilla vacía no es un error, es lo normal. Se
        // explica una vez, y solo si hay alguna.
        if (hasEmptySlot) ...[
          const SizedBox(height: AppSpacing.lg),
          CpInfoCard(message: l10n.pedigreeEmptyNotice),
        ],

        // `RF-PED-08` — el pedigrí se imprime y viaja con el ejemplar vendido.
        const SizedBox(height: AppSpacing.lg),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screen),
          child: CpExportButton(
            label: l10n.exportPedigree,
            onExport: () => ref
                .read(exportersProvider)
                .pedigree(
                  l10n: l10n,
                  locale: Localizations.localeOf(context).toLanguageTag(),
                  farmName: ref.read(currentProfileProvider).value?.farmName ?? l10n.appName,
                  root: root,
                  depth: viewModel.depth,
                  now: DateTime.now(),
                ),
          ),
        ),
      ],
    );
  }
}

/// Línea vertical que ata una generación con la siguiente.
class _Connector extends StatelessWidget {
  const _Connector();

  @override
  Widget build(BuildContext context) => Center(
    child: Container(
      width: 2,
      height: AppSpacing.lg,
      margin: const EdgeInsets.only(top: AppSpacing.md),
      color: Theme.of(context).colorScheme.outlineVariant,
    ),
  );
}

class _GenerationGrid extends StatelessWidget {
  const _GenerationGrid({required this.nodes, required this.showRoles});

  final List<PedigreeNode?> nodes;
  final bool showRoles;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);

    // Dos columnas por **rama**, no por orden de nivel: a la izquierda todo lo
    // que cuelga del padre, a la derecha todo lo de la madre. Es lo que permite
    // seguir una línea con el dedo hacia abajo sin perderla, que es para lo que
    // se consulta un pedigrí. Emparejar por orden de nivel pondría al abuelo
    // paterno junto a la abuela paterna, y la columna dejaría de significar
    // nada a partir de la segunda generación.
    final half = nodes.length ~/ 2;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screen),
      child: Column(
        children: [
          for (var row = 0; row < half; row++) ...[
            if (row > 0) const SizedBox(height: AppSpacing.sm),
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: CpFadeUp(
                      delay: cpStagger(row * 2),
                      child: _Slot(
                        node: nodes[row],
                        role: showRoles ? l10n.pedigreeRoleFather : null,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: CpFadeUp(
                      delay: cpStagger(row * 2 + 1),
                      child: _Slot(
                        node: nodes[half + row],
                        role: showRoles ? l10n.pedigreeRoleMother : null,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Slot extends StatelessWidget {
  const _Slot({required this.node, required this.role});

  final PedigreeNode? node;
  final String? role;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);

    final current = node;
    if (current == null) {
      return CpBirdCard.empty(name: l10n.pedigreeEmptySlot, role: role, subtitle: '—');
    }

    return CpBirdCard(
      sex: current.bird.sex,
      name: current.bird.displayName,
      role: role,
      subtitle: current.isCycle ? l10n.pedigreeCycle : Formatters.plate(current.bird.plate),
      // `RF-PED-07` — desde cualquier nodo se abre su ficha.
      onTap: () => context.push(Routes.birdDetail(current.bird.id)),
    );
  }
}

/// Solo para las capturas de `test/ui_preview_test.dart`.
@visibleForTesting
class PedigreePreview extends StatelessWidget {
  const PedigreePreview({required this.root, required this.depth, super.key});

  final PedigreeNode root;
  final int depth;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        CpSubjectCard(
          title: root.bird.displayName,
          subtitle:
              '${l10n.birdsPlateLabel(Formatters.plate(root.bird.plate))} · '
              '${root.bird.line ?? ""}',
          photoPath: root.bird.photoPath,
        ),
        for (var generation = 1; generation <= depth; generation++) ...[
          const _Connector(),
          CpSectionLabel(switch (generation) {
            1 => l10n.pedigreeGeneration1,
            2 => l10n.pedigreeGeneration2,
            3 => l10n.pedigreeGeneration3,
            _ => l10n.pedigreeGeneration4,
          }, padding: const EdgeInsets.only(top: AppSpacing.lg, bottom: AppSpacing.sm)),
          _GenerationGrid(nodes: _Tree.levelOf(root, generation), showRoles: generation == 1),
        ],
        const SizedBox(height: AppSpacing.lg),
        CpInfoCard(message: l10n.pedigreeEmptyNotice),
      ],
    );
  }
}
