import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/base/view_state.dart';
import '../../../core/domain/markings.dart';
import '../../../core/domain/sex.dart';
import '../../../core/error/failure_messages.dart';
import '../../../core/providers/providers.dart';
import '../../../core/router/routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/semantic_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/cp_alert.dart';
import '../../../core/widgets/cp_button.dart';
import '../../../core/widgets/cp_cards.dart';
import '../../../core/widgets/cp_empty_state.dart';
import '../../../core/widgets/cp_segmented.dart';
import '../../../core/widgets/motion.dart';
import '../../../core/widgets/sex_badge.dart';
import '../../../core/widgets/subject_card.dart';
import '../../../l10n/generated/app_l10n.dart';
import '../../evaluations/model/evaluation.dart';
import '../../evaluations/view/evaluation_labels.dart';
import '../model/bird.dart';
import '../model/weight_entry.dart';
import '../viewmodel/bird_detail_viewmodel.dart';
import 'bird_labels.dart';
import 'widgets/marking_fields.dart';

/// Ficha del ejemplar — pantallas 20 a 22, `RF-REG-12`.
///
/// Tres pestañas: Datos, Pruebas y Descendencia. La cabecera queda fuera de
/// ellas porque identifica al ejemplar: al cambiar de pestaña el criador tiene
/// que seguir viendo de quién está mirando los datos.
class BirdDetailView extends ConsumerWidget {
  const BirdDetailView({required this.birdId, super.key});

  final String birdId;

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final l10n = AppL10n.of(context);
    final confirmed = await showCpDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.birdDeleteTitle),
        content: Text(l10n.birdDeleteMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.commonCancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.commonDelete),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final deleted = await ref.read(birdDetailViewModelProvider(birdId)).delete();
    if (!deleted) return;

    messenger.showSnackBar(SnackBar(content: Text(l10n.birdDeleted)));
    if (navigator.canPop()) navigator.pop();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppL10n.of(context);
    final locale = Localizations.localeOf(context).toLanguageTag();
    final viewModel = ref.watch(birdDetailViewModelProvider(birdId));
    final bird = viewModel.bird;

    final scaffold = Scaffold(
      // Sin barra superior: la cabecera navy del prototipo la sustituye, y una
      // barra clara encima le robaría el aire que la hace funcionar.
      body: switch (viewModel.state) {
        ViewState.loading => const Center(child: CircularProgressIndicator()),
        ViewState.error => CpEmptyState(
          icon: Icons.error_outline,
          title: failureMessage(l10n, viewModel.failure!),
        ),
        _ when bird == null => const SizedBox.shrink(),
        _ => Column(
          children: [
            BirdRecordHeader(
              bird: bird,
              onClose: () => context.canPop() ? context.pop() : context.go(Routes.birds),
              onEdit: () => context.push(Routes.birdEdit(birdId)),
            ),
            // Píldora y no la `TabBar` de Material: el diseño lee la pestaña
            // activa como una tarjeta que sale hacia el usuario, y es el mismo
            // control que el selector de generaciones del pedigrí.
            Container(
              color: Theme.of(context).colorScheme.surface,
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.screen,
                AppSpacing.sm,
                AppSpacing.screen,
                AppSpacing.md,
              ),
              child: _RecordTabs(
                labels: [l10n.birdTabData, l10n.birdTabTests, l10n.birdTabOffspring],
              ),
            ),
            Expanded(
              child: TabBarView(
                children: [
                  _DataTab(
                    bird: bird,
                    father: viewModel.father,
                    mother: viewModel.mother,
                    locale: locale,
                    pedigreeDepth: viewModel.pedigreeDepth,
                    onDelete: () => _confirmDelete(context, ref),
                  ),
                  _TestsTab(
                    birdId: birdId,
                    evaluations: viewModel.evaluations,
                    isAvailable: viewModel.areEvaluationsAvailable,
                    locale: locale,
                  ),
                  _OffspringTab(groups: viewModel.offspring, locale: locale),
                ],
              ),
            ),
          ],
        ),
      },
    );

    // `DefaultTabController` envuelve el Scaffold entero porque la `TabBar` vive
    // en la barra superior y la `TabBarView` en el cuerpo: sin un ancestro
    // común no se encuentran.
    return DefaultTabController(length: 3, child: scaffold);
  }
}

/// Cabecera navy — pantalla 22 del diseño.
///
/// Comparte pieza con la tarjeta del pedigrí ([CpSubjectCard]): en las dos
/// pantallas lo primero que hay que resolver es de qué ave se habla, y
/// resolverlo igual evita reorientarse al pasar de una a otra.
class BirdRecordHeader extends StatelessWidget {
  const BirdRecordHeader({
    required this.bird,
    required this.onClose,
    required this.onEdit,
    super.key,
  });

  final Bird bird;
  final VoidCallback onClose;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);

    return ColoredBox(
      color: AppColors.navy,
      child: SafeArea(
        bottom: false,
        child: CpSubjectCard(
          title: bird.displayName,
          subtitle: [
            l10n.birdsPlateLabel(Formatters.plate(bird.plate)),
            if ((bird.line ?? '').isNotEmpty) bird.line!,
          ].join(' · '),
          photoPath: bird.photoPath,
          showWatermark: true,
          borderRadius: 0,
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.screen,
            AppSpacing.sm,
            AppSpacing.screen,
            AppSpacing.lg,
          ),
          overline: l10n.birdRecordTitle,
          leading: _HeaderButton(icon: Icons.close, tooltip: l10n.commonClose, onTap: onClose),
          trailing: _HeaderButton(
            icon: Icons.edit_outlined,
            tooltip: l10n.commonEdit,
            onTap: onEdit,
          ),
          badges: [
            _HeaderChip(
              label: statusLabel(l10n, bird.status).toUpperCase(),
              // El verde solo para el ejemplar en activo: un vendido o muerto
              // en verde diría lo contrario de lo que pasa.
              color: bird.status == BirdStatus.active
                  ? AppColors.male
                  : Colors.white.withValues(alpha: 0.14),
            ),
            // El diseño rotula aquí «GALLO». Es vocabulario prohibido
            // (BRD §8) y la compuerta de compilación lo rechazaría: va el sexo.
            _HeaderChip(
              label: sexLabel(l10n, bird.sex).toUpperCase(),
              color: Colors.white.withValues(alpha: 0.14),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeaderButton extends StatelessWidget {
  const _HeaderButton({required this.icon, required this.tooltip, required this.onTap});

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: tooltip,
    child: Material(
      color: Colors.white.withValues(alpha: 0.10),
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: SizedBox(
          width: AppSizes.minTouchTarget,
          height: AppSizes.minTouchTarget,
          child: Icon(icon, size: 20, color: Colors.white),
        ),
      ),
    ),
  );
}

/// Pestañas de la ficha, con el aspecto de píldora del diseño.
///
/// Se ata al `DefaultTabController` en lugar de llevar su propio estado: la
/// `TabBarView` de debajo también responde al deslizamiento lateral, y dos
/// fuentes de verdad se desincronizarían en cuanto el criador arrastrara.
class _RecordTabs extends StatefulWidget {
  const _RecordTabs({required this.labels});

  final List<String> labels;

  @override
  State<_RecordTabs> createState() => _RecordTabsState();
}

class _RecordTabsState extends State<_RecordTabs> {
  TabController? _controller;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final controller = DefaultTabController.of(context);
    if (identical(controller, _controller)) return;
    _controller?.removeListener(_onChanged);
    _controller = controller..addListener(_onChanged);
  }

  @override
  void dispose() {
    _controller?.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    if (controller == null) return const SizedBox.shrink();

    return CpSegmented<int>(
      segments: [
        for (final (index, label) in widget.labels.indexed) CpSegment(value: index, label: label),
      ],
      selected: controller.index,
      onChanged: controller.animateTo,
    );
  }
}

class _HeaderChip extends StatelessWidget {
  const _HeaderChip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 4),
    decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(AppRadius.pill)),
    child: Text(
      label,
      style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Colors.white),
    ),
  );
}

/// Pantalla 20 — pestaña por defecto.
class _DataTab extends StatelessWidget {
  const _DataTab({
    required this.bird,
    required this.locale,
    required this.pedigreeDepth,
    required this.onDelete,
    this.father,
    this.mother,
  });

  final Bird bird;
  final Bird? father;
  final Bird? mother;
  final String locale;
  final int pedigreeDepth;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final theme = Theme.of(context);

    return ListView(
      padding: const EdgeInsets.only(top: AppSpacing.md, bottom: AppSpacing.xxl),
      children: [
        // El pedigrí encabeza la pestaña: es a lo que el criador entra a mirar
        // cuando abre la ficha de un reproductor, y enterrarlo bajo la lista de
        // datos lo dejaba a un desplazamiento de distancia.
        CpActionCard(
          icon: Icons.account_tree_outlined,
          title: l10n.pedigreeSee,
          subtitle: l10n.pedigreeRegistered(pedigreeDepth),
          onTap: () => context.push(Routes.birdPedigree(bird.id)),
        ),

        const SizedBox(height: AppSpacing.md),
        CpDataCard(
          rows: [
            CpDataRow(
              label: l10n.fieldBirthDate,
              value: bird.birthDate == null ? '—' : Formatters.date(bird.birthDate!, locale),
            ),
            CpDataRow(label: l10n.fieldAge, value: ageLabel(l10n, bird.birthDate)),
            CpDataRow(label: l10n.fieldStatus, value: statusLabel(l10n, bird.status)),
            CpDataRow(
              label: l10n.markingTitle,
              value: BirthMark.isNone(bird.birthMark)
                  ? l10n.markingNoMarkSet
                  : BirthMark.codeOf(bird.birthMark) ?? '—',
            ),
            CpDataRow(
              label: l10n.markingBands,
              value: wingBandSummary(l10n, bird.wingBandLeft, bird.wingBandRight) ?? '—',
            ),
            CpDataRow(label: l10n.fieldColor, value: bird.color ?? '—'),
            CpDataRow(label: l10n.fieldComb, value: bird.comb ?? '—'),
          ],
        ),

        CpSectionLabel(l10n.weightTitle),
        _WeightSection(birdId: bird.id, locale: locale),

        CpSectionLabel(l10n.birdBreeders),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screen),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: _ParentCard(role: l10n.fieldFather, parent: father, sex: Sex.male),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: _ParentCard(role: l10n.fieldMother, parent: mother, sex: Sex.female),
                ),
              ],
            ),
          ),
        ),

        if (bird.notes != null) ...[
          CpSectionLabel(l10n.fieldNotes),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screen),
            child: Text(bird.notes!, style: theme.textTheme.bodyLarge),
          ),
        ],

        const SizedBox(height: AppSpacing.xl),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screen),
          // Dar de baja va al final y en rojo perfilado, no relleno: es
          // destructivo, pero también es la salida normal de un ejemplar que se
          // vende o se muere, así que no debe dar miedo pulsarlo.
          child: CpButton(
            label: l10n.birdDeactivate,
            variant: CpButtonVariant.secondary,
            icon: Icons.block_outlined,
            onPressed: onDelete,
          ),
        ),
      ],
    );
  }
}

/// Peso vigente y su tendencia — `RF-REG-14`.
///
/// Lo que el criador quiere saber no es cuánto pesa hoy —eso lo lee de una
/// vez— sino si va subiendo o bajando desde la última pesada. Un número suelto
/// no dice nada; dos, sí.
class _WeightSection extends ConsumerWidget {
  const _WeightSection({required this.birdId, required this.locale});

  final String birdId;
  final String locale;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppL10n.of(context);
    final theme = Theme.of(context);
    final semantic = context.semantic;
    final history = ref.watch(weightHistoryProvider(birdId));
    final unit = ref.watch(weightUnitProvider);

    return history.when(
      loading: () => const SizedBox(height: 72),
      // Nunca en silencio: un historial vacío por error se lee como «nunca lo
      // pesé», que es la conclusión equivocada.
      error: (error, _) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screen),
        child: CpAlert(message: l10n.errorUnknown),
      ),
      data: (trend) {
        final latest = trend.latest;
        final change = trend.changeG;

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screen),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  border: Border.all(color: theme.colorScheme.outlineVariant),
                  borderRadius: BorderRadius.circular(AppRadius.card),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            latest == null
                                ? l10n.weightNotWeighed
                                : Formatters.weight(latest.weightG, locale, unit: unit),
                            style: theme.textTheme.headlineSmall,
                          ),
                          if (latest != null)
                            Text(
                              Formatters.date(latest.date, locale),
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          // Con una sola pesada no hay tendencia: pintar «+0 g»
                          // sugeriría que el ave se estancó, y no es eso.
                          if (change != null)
                            Text(
                              change > 0 ? l10n.weightGain(change) : l10n.weightLoss(change),
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: change > 0 ? semantic.male : semantic.action,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                        ],
                      ),
                    ),
                    IconButton.filledTonal(
                      tooltip: l10n.weightAdd,
                      icon: const Icon(Icons.add),
                      onPressed: () => context.push(Routes.birdWeightNew(birdId)),
                    ),
                  ],
                ),
              ),

              if (trend.entries.length > 1) ...[
                const SizedBox(height: AppSpacing.sm),
                // Solo las últimas: el historial completo de un ave de tres
                // años sería una lista interminable dentro de la ficha.
                for (final entry in trend.entries.take(5).skip(1))
                  _WeightRow(entry: entry, locale: locale, unit: unit),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _WeightRow extends StatelessWidget {
  const _WeightRow({required this.entry, required this.locale, required this.unit});

  final WeightEntry entry;
  final String locale;
  final WeightUnit unit;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: AppSpacing.sm),
      child: Row(
        children: [
          Expanded(
            child: Text(
              Formatters.date(entry.date, locale),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          // De dónde salió el número: una pesada que el criador no recuerda
          // haber hecho es una pesada en la que no confía.
          if (entry.isFromEvaluation)
            Padding(
              padding: const EdgeInsets.only(right: AppSpacing.sm),
              child: Text(
                l10n.weightFromEvaluation,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          Text(
            Formatters.weight(entry.weightG, locale, unit: unit),
            style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

/// Progenitor en la ficha. Sin registrar es una casilla vacía y no un error:
/// que el criador no sepa quién fue el padre es lo normal (`RF-PED-05`).
class _ParentCard extends StatelessWidget {
  const _ParentCard({required this.role, required this.parent, required this.sex});

  final String role;
  final Bird? parent;
  final Sex sex;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final current = parent;

    if (current == null) {
      return CpBirdCard.empty(name: l10n.pedigreeEmptySlot, role: role, subtitle: '—');
    }

    return CpBirdCard(
      sex: current.sex,
      name: current.displayName,
      role: role,
      subtitle: l10n.birdsPlateLabel(Formatters.plate(current.plate)),
      onTap: () => context.push(Routes.birdDetail(current.id)),
    );
  }
}

/// Pantalla 21 — historial de pruebas del ejemplar, `RF-PRU-05`.
class _TestsTab extends StatelessWidget {
  const _TestsTab({
    required this.birdId,
    required this.evaluations,
    required this.isAvailable,
    required this.locale,
  });

  final String birdId;
  final List<Evaluation> evaluations;
  final bool isAvailable;
  final String locale;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);

    // `RF-PRU-06`: con plan gratuito se explica la restricción en lugar de
    // mostrar un vacío que parecería un error del programa.
    if (!isAvailable) {
      return CpEmptyState(
        icon: Icons.workspace_premium_outlined,
        title: l10n.testsPlanTitle,
        message: l10n.testsPlanMessage,
        actionLabel: l10n.dashboardSeePlans,
        onAction: () => context.push(Routes.settings),
      );
    }

    // «Estado vacío accionable» es literal en `RF-PRU-05`: desde aquí se
    // registra la primera prueba, con el ejemplar ya elegido.
    if (evaluations.isEmpty) {
      return CpEmptyState(
        icon: Icons.assignment_outlined,
        title: l10n.birdTestsEmptyTitle,
        message: l10n.birdTestsEmptyMessage,
        actionLabel: l10n.testsNew,
        onAction: () => context.push(Routes.evaluationNewFor(birdId)),
      );
    }

    return ListView(
      padding: const EdgeInsets.only(bottom: AppSpacing.xxl),
      children: [
        // Las cifras son **de este ejemplar**, no del criadero: en su ficha lo
        // que se pregunta es cómo va este ave, y las del criadero ya están en
        // la pantalla de pruebas.
        _BirdTestStats(evaluations: evaluations, locale: locale),

        const SizedBox(height: AppSpacing.md),
        for (final evaluation in evaluations)
          _EvaluationRow(evaluation: evaluation, locale: locale),

        const SizedBox(height: AppSpacing.lg),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screen),
          child: CpButton(
            label: l10n.testsNew,
            icon: Icons.add,
            onPressed: () => context.push(Routes.evaluationNewFor(birdId)),
          ),
        ),
      ],
    );
  }
}

/// Las tres cifras del ejemplar — pantalla 22.
///
/// Se calculan aquí y no en el repositorio porque las evaluaciones ya están
/// cargadas: pedir una consulta agregada para tres números sobre una lista que
/// se tiene delante sería una ida y vuelta a la base por nada.
class _BirdTestStats extends StatelessWidget {
  const _BirdTestStats({required this.evaluations, required this.locale});

  final List<Evaluation> evaluations;
  final String locale;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);

    // Mismo criterio que las del criadero: el porcentaje solo mira las pruebas
    // de campo, porque una revisión física no es favorable ni desfavorable.
    final rated = evaluations.where((e) => e.type.countsForStats).toList();
    final favorable = rated.where((e) => e.result == EvaluationResult.favorable).length;
    final percent = rated.isEmpty ? 0 : ((favorable / rated.length) * 100).round();

    final indices = evaluations.map((e) => e.performanceIndex).nonNulls.toList();
    final average = indices.isEmpty ? null : indices.reduce((a, b) => a + b) / indices.length;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screen),
      child: Row(
        children: [
          Expanded(
            child: _StatBox(value: '${evaluations.length}', label: l10n.testsStatTotal),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: _StatBox(
              value: '$percent%',
              label: l10n.testsStatFavorable,
              color: context.semantic.favorable,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: _StatBox(
              // Sin índices anotados, un «0,0» diría que el ave está en pésimo
              // estado. Un guion no dice nada, que es lo que se sabe.
              value: average == null ? '—' : Formatters.decimal(average, locale),
              label: l10n.evalIndexAverage,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatBox extends StatelessWidget {
  const _StatBox({required this.value, required this.label, this.color});

  final String value;
  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border.all(color: theme.colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      child: Column(
        children: [
          Text(value, style: theme.textTheme.headlineSmall?.copyWith(color: color)),
          Text(
            label.toUpperCase(),
            textAlign: TextAlign.center,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              letterSpacing: 0.8,
            ),
          ),
        ],
      ),
    );
  }
}

class _EvaluationRow extends StatelessWidget {
  const _EvaluationRow({required this.evaluation, required this.locale});

  final Evaluation evaluation;
  final String locale;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final theme = Theme.of(context);
    final color = switch (evaluation.result) {
      EvaluationResult.favorable => context.semantic.favorable,
      EvaluationResult.unfavorable => context.semantic.unfavorable,
      EvaluationResult.undefined => context.semantic.undefinedResult,
    };

    // Fecha · duración · peso, como en el diseño. El tipo pasa al título:
    // saber si fue una prueba de campo o un pesaje cambia cómo se lee la fila.
    final details = [
      Formatters.date(evaluation.date, locale),
      if (evaluation.durationMin != null) '${evaluation.durationMin} min',
      if (evaluation.weightG != null) Formatters.weight(evaluation.weightG!, locale),
      if ((evaluation.place ?? '').isNotEmpty) evaluation.place!,
    ].join(' · ');

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.screen),
      // Barra de color a la izquierda, como el diseño: marca el resultado sin
      // robarle sitio al texto.
      leading: Container(width: 4, height: 40, color: color),
      title: Text(evaluationTypeLabel(l10n, evaluation.type), style: theme.textTheme.titleSmall),
      subtitle: Text(details, maxLines: 1, overflow: TextOverflow.ellipsis),
      // `RNF-25` — el resultado se nombra además de colorearse.
      trailing: Text(
        resultLabel(l10n, evaluation.result),
        style: theme.textTheme.labelMedium?.copyWith(color: color, fontWeight: FontWeight.w600),
      ),
    );
  }
}

/// Pantalla 22 — descendencia agrupada por camada (`RF-REG-13`).
class _OffspringTab extends StatelessWidget {
  const _OffspringTab({required this.groups, required this.locale});

  final List<OffspringGroup> groups;
  final String locale;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);

    if (groups.isEmpty) {
      return CpEmptyState(
        icon: Icons.account_tree_outlined,
        title: l10n.birdOffspringEmptyTitle,
        message: l10n.birdOffspringEmptyMessage,
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(AppSpacing.md, 0, AppSpacing.md, AppSpacing.lg),
      children: [
        for (final group in groups) ...[
          _GroupHeader(group: group, locale: locale),
          for (final chick in group.chicks) _ChickTile(chick: chick),
          const SizedBox(height: AppSpacing.md),
        ],
      ],
    );
  }
}

class _GroupHeader extends StatelessWidget {
  const _GroupHeader({required this.group, required this.locale});

  final OffspringGroup group;
  final String locale;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final theme = Theme.of(context);

    final title = group.clutch == null
        ? l10n.birdOffspringLoose
        : l10n.birdOffspringClutchOf(Formatters.date(group.clutch!.date, locale));

    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.sm, bottom: AppSpacing.xs),
      child: Row(
        children: [
          Expanded(child: Text(title.toUpperCase(), style: AppTypography.sectionLabel(context))),
          Text(
            l10n.birdOffspringCount(group.chicks.length),
            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

/// Cada cría enlaza a su propia ficha — `RF-REG-13`.
class _ChickTile extends StatelessWidget {
  const _ChickTile({required this.chick});

  final Bird chick;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final color = SexBadge.colorOf(context, chick.sex);

    return ListTile(
      contentPadding: EdgeInsets.zero,
      // `push` y no `go`: se apila sobre la ficha actual, así el criador puede
      // bajar por la descendencia y volver por donde vino.
      onTap: () => context.push(Routes.birdDetail(chick.id)),
      leading: CircleAvatar(
        backgroundColor: color.withValues(alpha: 0.16),
        child: Icon(SexBadge.iconOf(chick.sex), color: color, size: 20),
      ),
      title: Text(chick.displayName, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        [Formatters.plate(chick.plate), sexLabel(l10n, chick.sex)].join(' · '),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: const Icon(Icons.chevron_right),
    );
  }
}

/// Solo para las capturas de `test/ui_preview_test.dart`: la ficha real vive
/// detrás de la autenticación y de una base con datos.
@visibleForTesting
class BirdRecordPreview extends StatelessWidget {
  const BirdRecordPreview({
    required this.bird,
    required this.locale,
    super.key,
    this.father,
    this.mother,
  });

  final Bird bird;
  final Bird? father;
  final Bird? mother;
  final String locale;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);

    return DefaultTabController(
      length: 3,
      child: Column(
        children: [
          BirdRecordHeader(bird: bird, onClose: () {}, onEdit: () {}),
          Container(
            color: Theme.of(context).colorScheme.surface,
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.screen,
              AppSpacing.sm,
              AppSpacing.screen,
              AppSpacing.md,
            ),
            child: _RecordTabs(
              labels: [l10n.birdTabData, l10n.birdTabTests, l10n.birdTabOffspring],
            ),
          ),
          Expanded(
            child: _DataTab(
              bird: bird,
              father: father,
              mother: mother,
              locale: locale,
              pedigreeDepth: 2,
              onDelete: () {},
            ),
          ),
        ],
      ),
    );
  }
}
