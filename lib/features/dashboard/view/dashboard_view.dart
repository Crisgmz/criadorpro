import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers/providers.dart';
import '../../../core/router/routes.dart';
import '../../../core/sync/sync_service.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/semantic_colors.dart';
import '../../../core/widgets/brand.dart';
import '../../../core/widgets/navy_surface.dart';
import '../../../l10n/generated/app_l10n.dart';
import 'widgets/app_drawer.dart';

class DashboardView extends ConsumerWidget {
  const DashboardView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppL10n.of(context);
    final viewModel = ref.watch(dashboardViewModelProvider);

    return Scaffold(
      drawer: const AppDrawer(),
      appBar: AppBar(
        title: Text(l10n.appName),
        actions: [
          IconButton(
            tooltip: l10n.syncNow,
            onPressed: viewModel.syncStatus == SyncStatus.syncing ? null : viewModel.syncNow,
            icon: viewModel.syncStatus == SyncStatus.syncing
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.sync),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: viewModel.syncNow,
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.screen),
          children: [
            // `RF-REG-02` y `RF-REG-16`: el aviso lleva el número exacto del
            // límite y un acceso a planes. Nunca un error genérico — al criador
            // le sirve saber cuánto le queda, no que «algo falló».
            if (viewModel.isAtPlanLimit)
              _PlanBanner(
                message: l10n.dashboardPlanLimitReached(viewModel.planLimit!),
                isBlocking: true,
              )
            else if (viewModel.isNearPlanLimit)
              _PlanBanner(
                message: l10n.dashboardPlanLimitNear(viewModel.activeCount, viewModel.planLimit!),
                isBlocking: false,
              ),
            if (viewModel.isNearPlanLimit || viewModel.isAtPlanLimit)
              const SizedBox(height: AppSpacing.md),

            // Los cuatro contadores de `RF-REG-01`: totales, machos, hembras y
            // camadas. El de camadas es el que dice cuánto se ha usado el
            // registro de cruce, que es la función que hace rentable la app.
            _FarmCard(
              farmName: viewModel.farmName.isEmpty ? l10n.appName : viewModel.farmName,
              total: viewModel.total,
              label: l10n.dashboardTotalBirds,
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Expanded(
                  child: _MetricCard(
                    label: l10n.dashboardMales,
                    value: viewModel.males,
                    color: context.semantic.male,
                    icon: Icons.male,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: _MetricCard(
                    label: l10n.dashboardFemales,
                    value: viewModel.females,
                    color: context.semantic.female,
                    icon: Icons.female,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: _MetricCard(
                    label: l10n.dashboardClutches,
                    value: viewModel.clutches,
                    color: context.semantic.brand,
                    icon: Icons.egg_outlined,
                  ),
                ),
              ],
            ),
            if (viewModel.unsexed > 0) ...[
              const SizedBox(height: AppSpacing.md),
              _MetricCard(
                label: l10n.dashboardUnsexed,
                value: viewModel.unsexed,
                color: context.semantic.unknownSex,
                icon: Icons.help_outline,
              ),
            ],

            const SizedBox(height: AppSpacing.lg),
            Text(l10n.dashboardQuickActions, style: AppTypography.sectionLabel(context)),
            const SizedBox(height: AppSpacing.sm),
            _QuickActions(isAtPlanLimit: viewModel.isAtPlanLimit),
            const SizedBox(height: AppSpacing.md),
            _SyncStatusLine(pendingChanges: viewModel.pendingChanges, status: viewModel.syncStatus),
          ],
        ),
      ),
    );
  }
}

/// Tarjeta navy del criadero (PRD, pantalla 15).
///
/// El navy va aquí y no en la barra superior: es el patrón que el producto usa
/// para destacar contenido —igual que la tarjeta de membresía o la de nómina—,
/// mientras el cromado de la pantalla se mantiene claro.
class _FarmCard extends StatelessWidget {
  const _FarmCard({required this.farmName, required this.total, required this.label});

  final String farmName;
  final int total;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return NavySurface(
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  farmName,
                  style: theme.textTheme.titleMedium?.copyWith(color: Colors.white),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: AppSpacing.sm),
                Text('$total', style: AppTypography.metric(context).copyWith(color: Colors.white)),
                Text(label, style: theme.textTheme.bodyMedium?.copyWith(color: Colors.white70)),
              ],
            ),
          ),
          const BrandSymbol(size: 44, onDark: true, opacity: 0.35),
        ],
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });

  final String label;
  final int value;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color),
            const SizedBox(height: AppSpacing.sm),
            Text('$value', style: AppTypography.metric(context)),
            Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SyncStatusLine extends StatelessWidget {
  const _SyncStatusLine({required this.pendingChanges, required this.status});

  final int pendingChanges;
  final SyncStatus status;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final theme = Theme.of(context);

    final (icon, text) = switch (status) {
      SyncStatus.syncing => (Icons.sync, l10n.syncInProgress),
      SyncStatus.failed => (Icons.sync_problem, l10n.syncFailed),
      SyncStatus.offline => (Icons.cloud_off, l10n.offlineBanner),
      _ when pendingChanges > 0 => (Icons.cloud_upload_outlined, l10n.syncPending(pendingChanges)),
      _ => (Icons.cloud_done_outlined, l10n.syncAllSynced),
    };

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: 16, color: theme.colorScheme.onSurfaceVariant),
        const SizedBox(width: AppSpacing.sm),
        Text(
          text,
          style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
      ],
    );
  }
}

/// Aviso de capacidad del plan — `RF-REG-02` y `RF-REG-16`.
///
/// Ámbar cuando queda margen y rojo cuando ya no se puede crear. En ninguno de
/// los dos casos se bloquea la consulta: `RS-03` es tajante en que el límite
/// afecta a crear, nunca a leer ni a exportar.
class _PlanBanner extends StatelessWidget {
  const _PlanBanner({required this.message, required this.isBlocking});

  final String message;
  final bool isBlocking;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final background = isBlocking ? scheme.errorContainer : scheme.tertiaryContainer;
    final foreground = isBlocking ? scheme.onErrorContainer : scheme.onTertiaryContainer;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                isBlocking ? Icons.block : Icons.warning_amber_rounded,
                size: 20,
                color: foreground,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  message,
                  style: theme.textTheme.bodyMedium?.copyWith(color: foreground),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: TextButton(
              // Todavía no existe la pantalla de planes (`RF-CTA-04`, fase 3);
              // hasta entonces se lleva a Mi cuenta, que es donde vivirá.
              onPressed: () => context.go(Routes.settings),
              child: Text(l10n.dashboardSeePlans, style: TextStyle(color: foreground)),
            ),
          ),
        ],
      ),
    );
  }
}

/// Accesos rápidos de Inicio (PRD, pantalla 15).
///
/// Aquí viven porque contabilidad y empleomanía **no ocupan pestaña** (PRD §7:
/// la barra inferior se reserva a lo que el criador toca a diario). Sin estos
/// atajos serían inalcanzables desde la pantalla principal.
class _QuickActions extends StatelessWidget {
  const _QuickActions({required this.isAtPlanLimit});

  /// Con el plan lleno no se puede crear, pero sí consultar (`RF-REG-16`), así
  /// que solo se apagan los accesos que registran.
  final bool isAtPlanLimit;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);

    return Row(
      children: [
        Expanded(
          child: _QuickAction(
            icon: Icons.add,
            label: l10n.dashboardQuickAdd,
            onTap: isAtPlanLimit ? null : () => context.push(Routes.birdNew),
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        // La camada va junto al alta suelta y no escondida en una lista: es la
        // función que hace rentable la app, y el criador la usa más que el alta
        // de uno en uno.
        Expanded(
          child: _QuickAction(
            icon: Icons.egg_outlined,
            label: l10n.dashboardQuickClutch,
            onTap: isAtPlanLimit ? null : () => context.push(Routes.clutchNew),
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: _QuickAction(
            icon: Icons.account_balance_wallet_outlined,
            label: l10n.accountingTitle,
            onTap: () => context.push(Routes.accounting),
          ),
        ),
      ],
    );
  }
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final enabled = onTap != null;
    final foreground = enabled ? theme.colorScheme.secondary : theme.colorScheme.outline;

    return Material(
      // Del tema de tarjeta y no de `surface`: es visualmente una tarjeta, y en
      // oscuro `surface` es el color del fondo de pantalla.
      color: theme.cardTheme.color,
      borderRadius: BorderRadius.circular(AppRadius.card),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.card),
        child: Container(
          height: 88,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.card),
            border: Border.all(color: theme.colorScheme.outlineVariant),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: foreground),
              const SizedBox(height: AppSpacing.xs),
              Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(color: foreground),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
