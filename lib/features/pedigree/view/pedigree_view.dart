import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/base/view_state.dart';
import '../../../core/error/failure_messages.dart';
import '../../../core/providers/providers.dart';
import '../../../core/router/routes.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/semantic_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/cp_empty_state.dart';
import '../../../l10n/generated/app_l10n.dart';
import '../../birds/view/bird_labels.dart';
import '../model/pedigree_node.dart';
import '../viewmodel/pedigree_viewmodel.dart';

/// Pantalla 23 — árbol genealógico, `RF-PED-01` a `RF-PED-07`.
///
/// El árbol crece hacia la derecha: el ejemplar a la izquierda y sus ancestros
/// en columnas sucesivas. Es la disposición del libro de papel, y la única que
/// permite seguir una línea con el dedo sin perderla.
class PedigreeView extends ConsumerStatefulWidget {
  const PedigreeView({required this.birdId, super.key});

  final String birdId;

  @override
  ConsumerState<PedigreeView> createState() => _PedigreeViewState();
}

class _PedigreeViewState extends ConsumerState<PedigreeView> {
  /// Alto reservado a cada nodo de la última generación. Todo lo demás se
  /// deduce de aquí: la generación n reparte el alto total entre 2ⁿ nodos.
  static const double _slotHeight = 74;
  static const double _columnWidth = 168;

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
    final viewModel = ref.watch(pedigreeViewModelProvider(widget.birdId));
    final root = viewModel.root;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.pedigreeTitle)),
      body: switch (viewModel.state) {
        ViewState.loading when root == null => const Center(child: CircularProgressIndicator()),
        ViewState.error => CpEmptyState(
          icon: Icons.error_outline,
          title: failureMessage(l10n, viewModel.failure!),
        ),
        _ when root == null => const SizedBox.shrink(),
        _ => Column(
          children: [
            _DepthSelector(viewModel: viewModel),

            // `RF-PED-03`: decir que el plan recorta el árbol. Callarlo haría
            // pensar que al ejemplar le faltan ancestros.
            if (viewModel.isLimitedByPlan)
              _Notice(
                icon: Icons.lock_outline,
                message: l10n.pedigreePlanNotice(viewModel.allowedDepth),
                onAction: () => context.push(Routes.settings),
                actionLabel: l10n.dashboardSeePlans,
              ),

            // `RF-PED-06`: se avisa una vez, no en cada nodo afectado.
            if (root.hasCycle)
              _Notice(icon: Icons.report_problem_outlined, message: l10n.pedigreeCycleNotice),

            const _Legend(),
            Expanded(
              child: _Tree(root: root, depth: viewModel.depth),
            ),
          ],
        ),
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

    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.md, AppSpacing.md, 0),
      child: SegmentedButton<int>(
        segments: [
          for (final option in PedigreeViewModel.depthOptions)
            ButtonSegment(
              value: option,
              label: Text('$option'),
              // Las profundidades que el plan no permite se ven, pero
              // deshabilitadas: esconderlas ocultaría que existen.
              enabled: viewModel.isDepthAvailable(option),
              tooltip: l10n.pedigreeGenerations(option),
            ),
        ],
        selected: {viewModel.depth},
        showSelectedIcon: false,
        onSelectionChanged: (selection) => viewModel.setDepth(selection.first),
      ),
    );
  }
}

/// `RF-PED-04` — el color nunca va solo (`RNF-25`).
class _Legend extends StatelessWidget {
  const _Legend();

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final theme = Theme.of(context);
    final semantic = context.semantic;

    Widget item(Color color, String label) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: AppSpacing.xs),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
      ],
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          item(semantic.male, l10n.pedigreeLegendMale),
          const SizedBox(width: AppSpacing.md),
          item(semantic.female, l10n.pedigreeLegendFemale),
        ],
      ),
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({required this.icon, required this.message, this.onAction, this.actionLabel});

  final IconData icon;
  final String message;
  final VoidCallback? onAction;
  final String? actionLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.md, AppSpacing.md, 0),
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: theme.colorScheme.tertiaryContainer,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: theme.colorScheme.onTertiaryContainer),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              message,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onTertiaryContainer,
              ),
            ),
          ),
          if (onAction != null && actionLabel != null)
            TextButton(onPressed: onAction, child: Text(actionLabel!)),
        ],
      ),
    );
  }
}

/// `RF-PED-07` — desplazar y ampliar.
class _Tree extends StatelessWidget {
  const _Tree({required this.root, required this.depth});

  final PedigreeNode root;
  final int depth;

  /// Nodos de una generación, de arriba abajo y con los huecos incluidos.
  ///
  /// Los `null` son parte del resultado, no un error: mantienen la posición de
  /// cada casilla para que padre y madre queden siempre alineados con su hijo.
  static List<PedigreeNode?> levelOf(PedigreeNode? root, int generation) {
    var level = <PedigreeNode?>[root];
    for (var i = 0; i < generation; i++) {
      level = [
        for (final node in level) ...[node?.father, node?.mother],
      ];
    }
    return level;
  }

  @override
  Widget build(BuildContext context) {
    final columns = depth + 1;
    final leaves = 1 << depth;
    final height = leaves * _PedigreeViewState._slotHeight;

    return InteractiveViewer(
      // Sin restringir al viewport: el árbol es más grande que la pantalla por
      // diseño y se recorre desplazándolo.
      constrained: false,
      minScale: 0.4,
      maxScale: 2.5,
      boundaryMargin: const EdgeInsets.all(AppSpacing.xl),
      child: SizedBox(
        width: columns * _PedigreeViewState._columnWidth,
        height: height,
        child: Row(
          children: [
            for (var generation = 0; generation < columns; generation++)
              SizedBox(
                width: _PedigreeViewState._columnWidth,
                child: Column(
                  children: [
                    // Cada generación reparte el mismo alto total entre sus
                    // 2^n casillas, y así todo queda alineado sin calcular
                    // posiciones a mano.
                    for (final node in levelOf(root, generation))
                      Expanded(child: _NodeCard(node: node)),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _NodeCard extends StatelessWidget {
  const _NodeCard({this.node});

  final PedigreeNode? node;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final theme = Theme.of(context);
    final current = node;

    // `RF-PED-05` — progenitor desconocido: casilla vacía, nunca error.
    if (current == null) {
      return _Slot(
        border: theme.colorScheme.outlineVariant,
        child: Center(
          child: Text(
            l10n.pedigreeUnknown,
            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ),
      );
    }

    final bird = current.bird;
    final color = switch (bird.sex.id) {
      'male' => context.semantic.male,
      'female' => context.semantic.female,
      _ => context.semantic.unknownSex,
    };

    return _Slot(
      border: color.withValues(alpha: 0.5),
      background: color.withValues(alpha: 0.08),
      // `RF-PED-07` — abrir la ficha desde el nodo.
      onTap: () => context.push(Routes.birdDetail(bird.id)),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            bird.displayName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleSmall,
          ),
          Text(
            // `RF-PED-04` — la etiqueta de sexo acompaña siempre al color.
            '${Formatters.plate(bird.plate)} · ${sexLabel(l10n, bird.sex)}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(color: color),
          ),
          if (current.isCycle)
            Text(
              l10n.pedigreeCycle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.error),
            ),
        ],
      ),
    );
  }
}

class _Slot extends StatelessWidget {
  const _Slot({required this.child, required this.border, this.background, this.onTap});

  final Widget child;
  final Color border;
  final Color? background;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(AppSpacing.xs),
    child: Material(
      color: background ?? Colors.transparent,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
          decoration: BoxDecoration(
            border: Border.all(color: border),
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          child: child,
        ),
      ),
    ),
  );
}
