import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/base/view_state.dart';
import '../../../core/domain/markings.dart';
import '../../../core/error/failure_messages.dart';
import '../../../core/providers/providers.dart';
import '../../../core/router/routes.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/semantic_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/cp_empty_state.dart';
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
    final confirmed = await showDialog<bool>(
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
      appBar: AppBar(
        // La placa y no el nombre: el nombre es opcional y muchos ejemplares no
        // lo tienen, así que la barra se quedaría en blanco.
        title: Text(bird == null ? '' : Formatters.plate(bird.plate)),
        actions: [
          if (bird != null) ...[
            IconButton(
              tooltip: l10n.commonEdit,
              icon: const Icon(Icons.edit_outlined),
              onPressed: () => context.push(Routes.birdEdit(birdId)),
            ),
            IconButton(
              tooltip: l10n.commonDelete,
              icon: const Icon(Icons.delete_outline),
              onPressed: () => _confirmDelete(context, ref),
            ),
          ],
        ],
        bottom: bird == null
            ? null
            : TabBar(
                tabs: [
                  Tab(text: l10n.birdTabData),
                  Tab(text: l10n.birdTabTests),
                  Tab(text: l10n.birdTabOffspring),
                ],
              ),
      ),
      body: switch (viewModel.state) {
        ViewState.loading => const Center(child: CircularProgressIndicator()),
        ViewState.error => CpEmptyState(
          icon: Icons.error_outline,
          title: failureMessage(l10n, viewModel.failure!),
        ),
        _ when bird == null => const SizedBox.shrink(),
        _ => Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.md, AppSpacing.md, 0),
              child: _Header(bird: bird),
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

class _Header extends StatelessWidget {
  const _Header({required this.bird});

  final Bird bird;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final color = SexBadge.colorOf(context, bird.sex);

    // `RF-REG-15`: con foto, manda la foto. El icono de sexo no se pierde —
    // sigue en la insignia de debajo, que además lleva su etiqueta textual.
    final photo = bird.photoPath == null ? null : File(bird.photoPath!);
    final hasPhoto = photo != null && photo.existsSync();

    return Row(
      children: [
        CircleAvatar(
          radius: 32,
          backgroundColor: color.withValues(alpha: 0.16),
          foregroundImage: hasPhoto ? FileImage(photo) : null,
          child: Icon(SexBadge.iconOf(bird.sex), size: 32, color: color),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(bird.displayName, style: Theme.of(context).textTheme.headlineSmall),
              Text(
                Formatters.plate(bird.plate),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              SexBadge(sex: bird.sex, label: sexLabel(l10n, bird.sex)),
            ],
          ),
        ),
      ],
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
