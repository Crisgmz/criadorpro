import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/providers/providers.dart';
import '../../../../core/router/routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/brand.dart';
import '../../../../core/widgets/navy_surface.dart';
import '../../../../l10n/generated/app_l10n.dart';

/// Panel lateral — pantalla 37 «Mi cuenta».
///
/// Vive en el shell y no en cada pantalla para que el ☰ esté disponible en las
/// tres pestañas. Aquí cuelgan los módulos que **no ocupan pestaña** (PRD §7):
/// la barra inferior se reserva a lo que el criador toca a diario.
class AppDrawer extends ConsumerWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppL10n.of(context);
    final profile = ref.watch(currentProfileProvider).valueOrNull;

    return Drawer(
      child: SafeArea(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            _Header(
              farmName: profile?.farmName ?? l10n.appName,
              fullName: profile?.fullName ?? '',
              location: profile?.location ?? '',
            ),
            const SizedBox(height: AppSpacing.md),

            // `RF-CTA-01`: la tarjeta de membresía es el único lugar donde se
            // comunica el plan vigente.
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              child: _MembershipCard(plan: profile?.effectivePlan ?? SubscriptionPlan.free),
            ),
            const SizedBox(height: AppSpacing.lg),

            // Secciones del diseño (pantalla 37). El orden importa: primero
            // lo que se paga, luego el criadero, después la cuenta y la ayuda.
            //
            // La tarjeta de arriba **es** el rótulo de esta sección: ya dice
            // «MEMBRESÍA», y repetirlo debajo lo diría dos veces.
            ListTile(
              leading: const Icon(Icons.credit_card_outlined),
              title: Text(l10n.drawerBilling),
              onTap: () => _open(context, Routes.settings),
            ),

            const Divider(height: AppSpacing.lg),
            _GroupLabel(l10n.drawerGroupFarm),
            ListTile(
              leading: const BrandIcon(),
              title: Text(l10n.navBirds),
              onTap: () => _go(context, Routes.birds),
            ),
            ListTile(
              leading: const Icon(Icons.groups_outlined),
              title: Text(l10n.navCommunity),
              onTap: () => _go(context, Routes.community),
            ),
            ListTile(
              leading: const Icon(Icons.assignment_outlined),
              title: Text(l10n.navTests),
              onTap: () => _go(context, Routes.evaluations),
            ),
            ListTile(
              // Contabilidad y empleomanía **no ocupan pestaña** (PRD §7): son
              // módulos administrativos y la barra inferior se reserva a lo que
              // el criador toca a diario.
              leading: const Icon(Icons.account_balance_wallet_outlined),
              title: Text(l10n.accountingTitle),
              onTap: () => _open(context, Routes.accounting),
            ),
            ListTile(
              leading: const Icon(Icons.badge_outlined),
              title: Text(l10n.payrollTitle),
              onTap: () => _open(context, Routes.payroll),
            ),

            const Divider(height: AppSpacing.lg),
            _GroupLabel(l10n.drawerGroupAccount),
            ListTile(
              leading: const Icon(Icons.person_outline),
              title: Text(l10n.drawerProfile),
              onTap: () => _open(context, Routes.profile),
            ),
            ListTile(
              leading: const Icon(Icons.settings_outlined),
              title: Text(l10n.navSettings),
              onTap: () => _go(context, Routes.settings),
            ),

            const Divider(height: AppSpacing.lg),
            _GroupLabel(l10n.drawerGroupHelp),
            ListTile(
              leading: const Icon(Icons.support_agent_outlined),
              title: Text(l10n.drawerSupport),
              onTap: () => _open(context, Routes.support),
            ),

            const Divider(height: AppSpacing.lg),
            _GroupLabel(l10n.drawerGroupApp),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.sm,
                AppSpacing.md,
                AppSpacing.lg,
              ),
              child: Text(
                '${l10n.drawerVersion} ${AppConfig.version}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Va a una pestaña del shell. Cierra el panel antes de navegar: dejarlo
  /// abierto sobre la pantalla nueva obligaría al usuario a descartarlo a mano.
  void _go(BuildContext context, String route) {
    final router = GoRouter.of(context);
    Navigator.of(context).pop();
    router.go(route);
  }

  /// Abre un módulo administrativo **apilándolo**.
  ///
  /// Contabilidad y empleomanía no son pestañas (PRD §7), así que no tienen
  /// barra inferior con la que volver. Con `go` sustituían la pila entera y la
  /// cabecera se quedaba sin flecha: se entraba y no había salida más que
  /// volviendo a abrir el panel.
  void _open(BuildContext context, String route) {
    final router = GoRouter.of(context);
    Navigator.of(context).pop();
    unawaited(router.push(route));
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.farmName, required this.fullName, required this.location});

  final String farmName;
  final String fullName;
  final String location;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final initials = _initialsOf(fullName.isEmpty ? farmName : fullName);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      color: AppColors.navy,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: AppColors.action,
                child: Text(
                  initials,
                  style: theme.textTheme.titleMedium?.copyWith(color: Colors.white),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
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
                    if (location.isNotEmpty)
                      Text(
                        location,
                        style: theme.textTheme.bodySmall?.copyWith(color: Colors.white70),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static String _initialsOf(String value) {
    final parts = value.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.characters.first.toUpperCase();
    return (parts.first.characters.first + parts[1].characters.first).toUpperCase();
  }
}

/// Tarjeta de membresía navy — `RF-CTA-01`.
class _MembershipCard extends StatelessWidget {
  const _MembershipCard({required this.plan});

  final SubscriptionPlan plan;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final theme = Theme.of(context);

    final name = switch (plan) {
      SubscriptionPlan.free => l10n.planFree,
      SubscriptionPlan.pro => l10n.planPro,
      SubscriptionPlan.elite => l10n.planElite,
    };

    return NavySurface(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.drawerMembership,
            style: theme.textTheme.labelSmall?.copyWith(color: Colors.white70),
          ),
          const SizedBox(height: AppSpacing.xs),
          Row(
            children: [
              Text(name, style: theme.textTheme.titleLarge?.copyWith(color: Colors.white)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: AppSpacing.xs,
                ),
                decoration: BoxDecoration(
                  color: AppColors.action,
                  borderRadius: BorderRadius.circular(AppRadius.badge),
                ),
                child: Text(
                  name.toUpperCase(),
                  style: theme.textTheme.labelSmall?.copyWith(color: Colors.white),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            plan.birdLimit == null
                ? l10n.drawerPlanUnlimited
                : l10n.drawerPlanLimit(plan.birdLimit!),
            style: theme.textTheme.bodySmall?.copyWith(color: Colors.white70),
          ),
        ],
      ),
    );
  }
}

class _GroupLabel extends StatelessWidget {
  const _GroupLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(AppSpacing.md, 0, AppSpacing.md, AppSpacing.sm),
    child: Text(label, style: AppTypography.sectionLabel(context)),
  );
}
