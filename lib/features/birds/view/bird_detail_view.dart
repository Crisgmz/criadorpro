import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/base/view_state.dart';
import '../../../core/error/failure_messages.dart';
import '../../../core/providers/providers.dart';
import '../../../core/router/routes.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/cp_empty_state.dart';
import '../../../core/widgets/sex_badge.dart';
import '../../../l10n/generated/app_l10n.dart';
import '../model/bird.dart';
import 'bird_labels.dart';

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

    return Scaffold(
      appBar: AppBar(
        title: Text(bird?.name ?? ''),
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
      ),
      body: switch (viewModel.state) {
        ViewState.loading => const Center(child: CircularProgressIndicator()),
        ViewState.error => CpEmptyState(
          icon: Icons.error_outline,
          title: failureMessage(l10n, viewModel.failure!),
        ),
        _ when bird == null => const SizedBox.shrink(),
        _ => _Body(bird: bird, father: viewModel.father, mother: viewModel.mother, locale: locale),
      },
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.bird, required this.locale, this.father, this.mother});

  final Bird bird;
  final Bird? father;
  final Bird? mother;
  final String locale;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        _Header(bird: bird),
        const SizedBox(height: AppSpacing.lg),

        _SectionLabel(l10n.birdSectionIdentity),
        _DataRow(label: l10n.fieldPlate, value: Formatters.plate(bird.plate)),
        _DataRow(
          label: l10n.fieldBirthDate,
          value: bird.birthDate == null ? '—' : Formatters.date(bird.birthDate!, locale),
        ),
        _DataRow(label: l10n.fieldAge, value: ageLabel(l10n, bird.birthDate)),
        _DataRow(label: l10n.fieldStatus, value: statusLabel(l10n, bird.status)),

        const SizedBox(height: AppSpacing.lg),
        _SectionLabel(l10n.birdSectionOrigin),
        _DataRow(label: l10n.fieldFather, value: father?.displayName ?? l10n.birdUnknownParent),
        _DataRow(label: l10n.fieldMother, value: mother?.displayName ?? l10n.birdUnknownParent),
        _DataRow(label: l10n.fieldLine, value: bird.line ?? '—'),

        const SizedBox(height: AppSpacing.lg),
        _SectionLabel(l10n.birdSectionExtra),
        _DataRow(label: l10n.fieldColor, value: bird.color ?? '—'),
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

class _Header extends StatelessWidget {
  const _Header({required this.bird});

  final Bird bird;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final color = SexBadge.colorOf(context, bird.sex);

    return Row(
      children: [
        CircleAvatar(
          radius: 32,
          backgroundColor: color.withValues(alpha: 0.16),
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

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
    child: Text(text.toUpperCase(), style: AppTypography.sectionLabel(context)),
  );
}

class _DataRow extends StatelessWidget {
  const _DataRow({required this.label, required this.value});

  final String label;
  final String value;

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
        ],
      ),
    );
  }
}
