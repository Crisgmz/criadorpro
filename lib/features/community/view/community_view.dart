import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/base/view_state.dart';
import '../../../core/error/failure.dart';
import '../../../core/error/failure_messages.dart';
import '../../../core/providers/providers.dart';
import '../../../core/router/routes.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/semantic_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/cp_alert.dart';
import '../../../core/widgets/cp_cards.dart';
import '../../../core/widgets/cp_empty_state.dart';
import '../../../core/widgets/cp_segmented.dart';
import '../../../core/widgets/cp_text_field.dart';
import '../../../core/widgets/motion.dart';
import '../../../l10n/generated/app_l10n.dart';
import '../../dashboard/view/widgets/app_drawer.dart';
import '../model/community.dart';
import '../viewmodel/community_viewmodel.dart';
import 'community_labels.dart';

/// Comunidad — `RF-COM`.
///
/// Es la única pantalla del producto que **exige conexión** (`RNF-08`), así que
/// lo dice en lugar de fingir un vacío: sin señal, un directorio en blanco se
/// leería como «no hay nadie».
class CommunityView extends ConsumerStatefulWidget {
  const CommunityView({super.key});

  @override
  ConsumerState<CommunityView> createState() => _CommunityViewState();
}

class _CommunityViewState extends ConsumerState<CommunityView> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => ref.read(communityViewModelProvider).load(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final viewModel = ref.watch(communityViewModelProvider);
    final isPublic = ref.watch(currentProfileProvider).value?.isPublic ?? false;

    return Scaffold(
      drawer: const AppDrawer(),
      appBar: AppBar(
        title: Text(l10n.communityTitle),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(64),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.screen,
              0,
              AppSpacing.screen,
              AppSpacing.md,
            ),
            child: CpSegmented<CommunityTab>(
              segments: [
                CpSegment(value: CommunityTab.directory, label: l10n.communityDirectory),
                CpSegment(
                  value: CommunityTab.requests,
                  // La insignia va en el rótulo y no como punto: sin el número,
                  // una solicitud puede quedarse días sin que nadie la abra.
                  label: viewModel.pendingCount == 0
                      ? l10n.communityRequests
                      : '${l10n.communityRequests} (${viewModel.pendingCount})',
                ),
              ],
              selected: viewModel.tab,
              onChanged: viewModel.setTab,
            ),
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: viewModel.load,
        child: switch (viewModel.state) {
          ViewState.loading => const Center(child: CircularProgressIndicator()),

          // Sin conexión se explica, no se deja en blanco: Comunidad es la
          // excepción de `RNF-08` y el criador tiene que saber que el resto de
          // la app le sigue funcionando.
          ViewState.error when viewModel.failure is NetworkFailure => ListView(
            children: [
              const SizedBox(height: AppSpacing.xl),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screen),
                child: CpAlert(message: l10n.communityOffline, tone: CpAlertTone.warning),
              ),
            ],
          ),

          ViewState.error => CpEmptyState(
            icon: Icons.error_outline,
            title: failureMessage(l10n, viewModel.failure!),
          ),

          _ when viewModel.tab == CommunityTab.directory => _Directory(
            viewModel: viewModel,
            isPublic: isPublic,
          ),
          _ => _Requests(viewModel: viewModel),
        },
      ),
    );
  }
}

class _Directory extends ConsumerWidget {
  const _Directory({required this.viewModel, required this.isPublic});

  final CommunityViewModel viewModel;
  final bool isPublic;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppL10n.of(context);

    return ListView(
      padding: const EdgeInsets.only(bottom: AppSpacing.xxl),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.screen,
            AppSpacing.md,
            AppSpacing.screen,
            AppSpacing.md,
          ),
          child: CpTextField(
            label: l10n.commonSearch,
            hint: l10n.communitySearchHint,
            prefixIcon: Icons.search,
            onChanged: viewModel.search,
          ),
        ),

        // Publicarse es **opt-in**: nadie aparece por haberse registrado. Si no
        // lo está, se le dice aquí, que es donde se entiende para qué sirve.
        if (!isPublic)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screen),
            child: CpInfoCard(message: l10n.communityNotPublicMessage),
          ),

        if (viewModel.directory.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.xl),
            child: CpEmptyState(
              icon: viewModel.query.trim().isEmpty ? Icons.groups_outlined : Icons.search_off,
              title: viewModel.query.trim().isEmpty
                  ? l10n.communityEmptyTitle
                  : l10n.communityNoResults,
              message: viewModel.query.trim().isEmpty ? l10n.communityEmptyMessage : null,
            ),
          )
        else
          for (final (index, profile) in viewModel.directory.indexed)
            CpFadeUp(
              delay: cpStagger(index),
              child: _FarmTile(profile: profile, viewModel: viewModel),
            ),
      ],
    );
  }
}

class _FarmTile extends ConsumerWidget {
  const _FarmTile({required this.profile, required this.viewModel});

  final PublicProfile profile;
  final CommunityViewModel viewModel;

  Future<void> _report(BuildContext context, WidgetRef ref) async {
    final l10n = AppL10n.of(context);
    final messenger = ScaffoldMessenger.of(context);

    final confirmed = await showCpDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.communityReportTitle),
        content: Text(l10n.communityReportMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.communityReport),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    if (await viewModel.report(profile.id)) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.communityReported)));
    }
  }

  Future<void> _block(BuildContext context, WidgetRef ref) async {
    final l10n = AppL10n.of(context);
    final messenger = ScaffoldMessenger.of(context);

    if (await viewModel.block(profile.id)) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.communityBlocked)));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppL10n.of(context);
    final theme = Theme.of(context);

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: context.semantic.brand.withValues(alpha: 0.12),
        child: Icon(Icons.home_work_outlined, color: context.semantic.brand),
      ),
      title: Text(profile.farmName),
      subtitle: Text(
        profile.location ?? profile.bio ?? '',
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
      ),
      trailing: PopupMenuButton<_FarmAction>(
        onSelected: (action) => switch (action) {
          _FarmAction.request => context.push(Routes.meetingRequestFor(profile.id)),
          // Denunciar y bloquear los exigen App Store y Play para cualquier
          // contenido de usuarios; sin ellos el módulo no pasa revisión.
          _FarmAction.report => _report(context, ref),
          _FarmAction.block => _block(context, ref),
        },
        itemBuilder: (context) => [
          PopupMenuItem(value: _FarmAction.request, child: Text(l10n.communityRequestNew)),
          PopupMenuItem(value: _FarmAction.report, child: Text(l10n.communityReport)),
          PopupMenuItem(value: _FarmAction.block, child: Text(l10n.communityBlock)),
        ],
      ),
      onTap: () => context.push(Routes.meetingRequestFor(profile.id)),
    );
  }
}

enum _FarmAction { request, report, block }

class _Requests extends StatelessWidget {
  const _Requests({required this.viewModel});

  final CommunityViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final locale = Localizations.localeOf(context).toLanguageTag();

    if (viewModel.incoming.isEmpty && viewModel.outgoing.isEmpty) {
      return CpEmptyState(
        icon: Icons.mail_outline,
        title: l10n.communityRequestsEmpty,
        message: l10n.communityRequestsEmptyMessage,
      );
    }

    return ListView(
      padding: const EdgeInsets.only(bottom: AppSpacing.xxl),
      children: [
        if (viewModel.incoming.isNotEmpty) ...[
          CpSectionLabel(l10n.communityIncoming),
          for (final request in viewModel.incoming)
            _RequestTile(request: request, viewModel: viewModel, isIncoming: true, locale: locale),
        ],
        if (viewModel.outgoing.isNotEmpty) ...[
          CpSectionLabel(l10n.communityOutgoing),
          for (final request in viewModel.outgoing)
            _RequestTile(request: request, viewModel: viewModel, isIncoming: false, locale: locale),
        ],
      ],
    );
  }
}

class _RequestTile extends StatelessWidget {
  const _RequestTile({
    required this.request,
    required this.viewModel,
    required this.isIncoming,
    required this.locale,
  });

  final MeetingRequest request;
  final CommunityViewModel viewModel;
  final bool isIncoming;
  final String locale;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final theme = Theme.of(context);

    final detail = [
      if (request.proposedDate != null) Formatters.date(request.proposedDate!, locale),
      if ((request.place ?? '').isNotEmpty) request.place!,
    ].join(' · ');

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screen, vertical: AppSpacing.sm),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          border: Border.all(color: theme.colorScheme.outlineVariant),
          borderRadius: BorderRadius.circular(AppRadius.card),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    request.counterpartName ?? l10n.commonNone,
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                _StatusChip(status: request.status),
              ],
            ),
            if (detail.isNotEmpty)
              Text(
                detail,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            if ((request.message ?? '').isNotEmpty) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(request.message!, style: theme.textTheme.bodyMedium),
            ],

            // Solo se ofrecen las transiciones que corresponden: aceptar es de
            // quien la recibe, retirarla de quien la mandó. Lo mismo comprueba
            // el repositorio y lo refuerza la política de la base.
            if (request.status.isOpen) ...[
              const SizedBox(height: AppSpacing.sm),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: isIncoming
                    ? [
                        TextButton(
                          onPressed: () => viewModel.respond(request, MeetingStatus.declined),
                          child: Text(l10n.communityDecline),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        FilledButton(
                          onPressed: () => viewModel.respond(request, MeetingStatus.accepted),
                          child: Text(l10n.communityAccept),
                        ),
                      ]
                    : [
                        TextButton(
                          onPressed: () => viewModel.respond(request, MeetingStatus.cancelled),
                          child: Text(l10n.communityCancel),
                        ),
                      ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final MeetingStatus status;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final theme = Theme.of(context);
    final semantic = context.semantic;

    final color = switch (status) {
      MeetingStatus.pending => semantic.warning,
      MeetingStatus.accepted => semantic.male,
      MeetingStatus.declined => semantic.action,
      MeetingStatus.cancelled => theme.colorScheme.onSurfaceVariant,
    };

    // Texto y no solo color (`RNF-25`).
    return Text(
      meetingStatusLabel(l10n, status).toUpperCase(),
      style: theme.textTheme.labelSmall?.copyWith(color: color, fontWeight: FontWeight.w700),
    );
  }
}
