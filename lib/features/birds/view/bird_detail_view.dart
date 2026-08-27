import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/base/view_state.dart';
import '../../../core/domain/markings.dart';
import '../../../core/error/failure_messages.dart';
import '../../../core/providers/providers.dart';
import '../../../core/router/routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/semantic_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/brand.dart';
import '../../../core/widgets/cp_empty_state.dart';
import '../../../core/widgets/motion.dart';
import '../../../core/widgets/sex_badge.dart';
import '../../../l10n/generated/app_l10n.dart';
import '../../evaluations/model/evaluation.dart';
import '../../evaluations/view/evaluation_labels.dart';
import '../model/bird.dart';
import '../viewmodel/bird_detail_viewmodel.dart';
import 'bird_labels.dart';
import 'widgets/form_fields.dart';
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
              onDelete: () => _confirmDelete(context, ref),
            ),
            Material(
              color: Theme.of(context).colorScheme.surface,
              child: TabBar(
                tabs: [
                  Tab(text: l10n.birdTabData),
                  Tab(text: l10n.birdTabTests),
                  Tab(text: l10n.birdTabOffspring),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Expanded(
              child: TabBarView(
                children: [
                  _DataTab(
                    bird: bird,
                    father: viewModel.father,
                    mother: viewModel.mother,
                    locale: locale,
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

/// Cabecera navy — pantalla 22 del prototipo.
///
/// El navy va aquí y no en la barra superior: el PRD reserva el color de marca
/// a bloques de contenido, y esta cabecera **es** contenido — identifica al
/// ejemplar mientras se cambia de pestaña.
class BirdRecordHeader extends StatelessWidget {
  const BirdRecordHeader({
    required this.bird,
    super.key,
    required this.onClose,
    required this.onEdit,
    required this.onDelete,
  });

  final Bird bird;
  final VoidCallback onClose;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final theme = Theme.of(context);
    final photo = bird.photoPath == null ? null : File(bird.photoPath!);
    final hasPhoto = photo != null && photo.existsSync();

    final subtitle = [Formatters.plate(bird.plate), if (bird.line != null) bird.line!].join(' · ');

    return Container(
      width: double.infinity,
      color: AppColors.navy,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.sm,
            AppSpacing.md,
            AppSpacing.md,
          ),
          child: Stack(
            children: [
              // Marca de agua al 6 %, como en el prototipo: da cuerpo al navy
              // sin competir con el nombre.
              Positioned(
                right: -28,
                bottom: -24,
                child: BrandSymbol(size: 128, onDark: true, opacity: 0.06),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _HeaderButton(icon: Icons.close, tooltip: l10n.commonClose, onTap: onClose),
                      Expanded(
                        child: Text(
                          l10n.birdRecordTitle,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: Colors.white.withValues(alpha: 0.5),
                          ),
                        ),
                      ),
                      _HeaderButton(
                        icon: Icons.edit_outlined,
                        tooltip: l10n.commonEdit,
                        onTap: onEdit,
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      _HeaderButton(
                        icon: Icons.delete_outline,
                        tooltip: l10n.commonDelete,
                        onTap: onDelete,
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      _HeaderPhoto(photo: hasPhoto ? photo : null),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              bird.displayName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.headlineSmall?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.xs),
                            Text(
                              subtitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: Colors.white.withValues(alpha: 0.55),
                              ),
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            Wrap(
                              spacing: AppSpacing.xs,
                              runSpacing: AppSpacing.xs,
                              children: [
                                _HeaderChip(
                                  label: statusLabel(l10n, bird.status).toUpperCase(),
                                  // El verde solo para el ejemplar en activo: un
                                  // vendido o fallecido en verde diría lo
                                  // contrario de lo que pasa.
                                  color: bird.status == BirdStatus.active
                                      ? AppColors.male
                                      : Colors.white.withValues(alpha: 0.14),
                                ),
                                // El prototipo rotula aquí «GALLO». Es
                                // vocabulario prohibido (BRD §8): va el sexo.
                                _HeaderChip(
                                  label: sexLabel(l10n, bird.sex).toUpperCase(),
                                  color: Colors.white.withValues(alpha: 0.14),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
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
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: Container(
        width: 36,
        height: 36,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
        child: Icon(icon, size: 18, color: Colors.white),
      ),
    ),
  );
}

class _HeaderPhoto extends StatelessWidget {
  const _HeaderPhoto({this.photo});

  final File? photo;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final theme = Theme.of(context);

    return Container(
      width: 78,
      height: 78,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: photo != null
            ? null
            : Border.all(color: Colors.white.withValues(alpha: 0.28), width: 1.5),
      ),
      child: photo != null
          ? Image.file(photo!, fit: BoxFit.cover)
          : Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                BrandSymbol(size: 26, onDark: true, opacity: 0.5),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  l10n.birdPhotoPlaceholder,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: Colors.white.withValues(alpha: 0.5),
                    fontSize: 8.5,
                  ),
                ),
              ],
            ),
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
  const _DataTab({required this.bird, required this.locale, this.father, this.mother});

  final Bird bird;
  final Bird? father;
  final Bird? mother;
  final String locale;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);

    return ListView(
      padding: const EdgeInsets.fromLTRB(AppSpacing.md, 0, AppSpacing.md, AppSpacing.lg),
      children: [
        SectionLabel(l10n.birdSectionIdentity),
        _DataRow(label: l10n.fieldPlate, value: Formatters.plate(bird.plate)),
        _DataRow(
          label: l10n.fieldBirthDate,
          value: bird.birthDate == null ? '—' : Formatters.date(bird.birthDate!, locale),
        ),
        _DataRow(label: l10n.fieldAge, value: ageLabel(l10n, bird.birthDate)),
        _DataRow(label: l10n.fieldStatus, value: statusLabel(l10n, bird.status)),

        const SizedBox(height: AppSpacing.lg),
        SectionLabel(l10n.birdSectionOrigin),
        _ParentRow(label: l10n.fieldFather, parent: father),
        _ParentRow(label: l10n.fieldMother, parent: mother),
        _DataRow(label: l10n.fieldLine, value: bird.line ?? '—'),
        const SizedBox(height: AppSpacing.sm),
        // El pedigrí completo se abre desde aquí y no desde una pestaña: es
        // una vista aparte, con su propio desplazamiento y zoom.
        OutlinedButton.icon(
          onPressed: () => context.push(Routes.birdPedigree(bird.id)),
          icon: const Icon(Icons.account_tree_outlined),
          label: Text(l10n.pedigreeSee),
        ),

        const SizedBox(height: AppSpacing.lg),
        SectionLabel(l10n.birdSectionExtra),
        _DataRow(label: l10n.fieldColor, value: bird.color ?? '—'),
        _DataRow(label: l10n.fieldComb, value: bird.comb ?? '—'),
        // Marca de nacimiento y cintas de ala, como en la ficha del prototipo.
        _DataRow(
          label: l10n.markingTitle,
          value: BirthMark.isNone(bird.birthMark)
              ? l10n.markingNoMarkSet
              : BirthMark.codeOf(bird.birthMark) ?? '—',
        ),
        _DataRow(
          label: l10n.markingBands,
          value: wingBandSummary(l10n, bird.wingBandLeft, bird.wingBandRight) ?? '—',
        ),
        _DataRow(
          label: l10n.fieldWeight,
          value: bird.weightG == null ? '—' : Formatters.number(bird.weightG!.toDouble(), locale),
        ),
        if (bird.notes != null) ...[
          const SizedBox(height: AppSpacing.md),
          Text(l10n.fieldNotes, style: AppTypography.sectionLabel(context)),
          const SizedBox(height: AppSpacing.xs),
          Text(bird.notes!, style: Theme.of(context).textTheme.bodyMedium),
        ],
      ],
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
      padding: const EdgeInsets.fromLTRB(AppSpacing.md, 0, AppSpacing.md, AppSpacing.lg),
      children: [
        for (final evaluation in evaluations)
          _EvaluationRow(evaluation: evaluation, locale: locale),
        const SizedBox(height: AppSpacing.md),
        OutlinedButton.icon(
          onPressed: () => context.push(Routes.evaluationNewFor(birdId)),
          icon: const Icon(Icons.add),
          label: Text(l10n.testsNew),
        ),
      ],
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

    final details = [
      Formatters.date(evaluation.date, locale),
      if (evaluation.place != null) evaluation.place!,
      if (evaluation.condition != null) '${l10n.testsFieldCondition} ${evaluation.condition}',
    ].join(' · ');

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        backgroundColor: color.withValues(alpha: 0.16),
        child: Icon(Icons.assignment_outlined, color: color, size: 20),
      ),
      // `RNF-25` — el resultado se nombra además de colorearse.
      title: Text(resultLabel(l10n, evaluation.result), style: theme.textTheme.titleSmall),
      subtitle: Text(details, maxLines: 1, overflow: TextOverflow.ellipsis),
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

/// Progenitor: además de nombrarlo, lleva a su ficha si está registrado.
class _ParentRow extends StatelessWidget {
  const _ParentRow({required this.label, this.parent});

  final String label;
  final Bird? parent;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    if (parent == null) return _DataRow(label: label, value: l10n.birdUnknownParent);

    return InkWell(
      onTap: () => context.push(Routes.birdDetail(parent!.id)),
      child: _DataRow(
        label: label,
        value: parent!.displayName,
        trailing: const Icon(Icons.chevron_right, size: 18),
      ),
    );
  }
}

class _DataRow extends StatelessWidget {
  const _DataRow({required this.label, required this.value, this.trailing});

  final String label;
  final String value;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value,
              style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}
