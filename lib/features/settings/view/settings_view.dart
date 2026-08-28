import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/app_config.dart';
import '../../../core/error/failure_messages.dart';
import '../../../core/providers/providers.dart';
import '../../../core/router/routes.dart';
import '../../../core/sync/sync_service.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/motion.dart';
import '../../../l10n/generated/app_l10n.dart';
import '../../dashboard/view/widgets/app_drawer.dart';

class SettingsView extends ConsumerWidget {
  const SettingsView({super.key});

  Future<void> _confirmSignOut(BuildContext context, WidgetRef ref) async {
    final l10n = AppL10n.of(context);
    final viewModel = ref.read(settingsViewModelProvider);

    final confirmed = await showCpDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.authSignOutConfirmTitle),
        content: Text(
          viewModel.hasPendingChanges
              ? '${l10n.syncPending(viewModel.pendingChanges)}\n\n${l10n.authSignOutConfirmMessage}'
              : l10n.authSignOutConfirmMessage,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.commonCancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.authSignOut),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    final signedOut = await viewModel.signOut();
    if (signedOut) return; // El router redirige al login por sí solo.

    final failure = viewModel.failure;
    if (failure != null) {
      messenger.showSnackBar(SnackBar(content: Text(failureMessage(l10n, failure))));
      viewModel.clearFailure();
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppL10n.of(context);
    final theme = Theme.of(context);
    final settings = ref.watch(settingsViewModelProvider);
    final appSettings = ref.watch(appSettingsProvider);

    return Scaffold(
      drawer: const AppDrawer(),
      appBar: AppBar(title: Text(l10n.settingsTitle)),
      body: ListView(
        children: [
          _SectionHeader(l10n.settingsAccount),
          ListTile(
            leading: const Icon(Icons.person_outline),
            title: Text(settings.farmName ?? settings.email ?? '—'),
            subtitle: settings.farmName == null ? null : Text(settings.email ?? ''),
          ),
          ListTile(
            leading: const Icon(Icons.workspace_premium_outlined),
            title: Text(l10n.settingsPlan),
            subtitle: Text(_planUsage(l10n, settings.plan, settings.birdCount)),
            trailing: Chip(label: Text(_planName(l10n, settings.plan))),
          ),

          // Publicarse en Comunidad es **opt-in** y vive aquí, junto al resto
          // de lo que el criador decide sobre su cuenta. Nadie aparece en el
          // directorio por haberse registrado.
          SwitchListTile(
            secondary: const Icon(Icons.groups_outlined),
            title: Text(l10n.communityPublicToggle),
            subtitle: Text(l10n.communityPublicToggleHint),
            value: settings.isPublic,
            onChanged: (value) => ref.read(settingsViewModelProvider).setPublic(value: value),
          ),

          const Divider(),
          // `PRD §7` — contabilidad y empleomanía se abren desde Inicio y desde
          // Mi cuenta, no desde la barra inferior.
          _SectionHeader(l10n.settingsAdmin),
          ListTile(
            leading: const Icon(Icons.account_balance_wallet_outlined),
            title: Text(l10n.accountingTitle),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push(Routes.accounting),
          ),
          ListTile(
            leading: const Icon(Icons.badge_outlined),
            title: Text(l10n.payrollTitle),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push(Routes.payroll),
          ),

          const Divider(),
          _SectionHeader(l10n.settingsSync),
          ListTile(
            leading: Icon(_syncIcon(settings.syncStatus, settings.pendingChanges)),
            title: Text(_syncText(l10n, settings.syncStatus, settings.pendingChanges)),
            trailing: settings.syncStatus == SyncStatus.syncing
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : TextButton(
                    onPressed: settings.isSyncAvailable ? settings.syncNow : null,
                    child: Text(l10n.syncNow),
                  ),
          ),

          const Divider(),
          _SectionHeader(l10n.settingsAppearance),
          ListTile(
            leading: const Icon(Icons.brightness_6_outlined),
            title: Text(l10n.settingsTheme),
            subtitle: Text(_themeName(l10n, appSettings.themeMode)),
            onTap: () => _pickTheme(context, ref),
          ),
          ListTile(
            leading: const Icon(Icons.language_outlined),
            title: Text(l10n.settingsLanguage),
            subtitle: Text(_languageName(l10n, appSettings.locale?.languageCode)),
            onTap: () => _pickLanguage(context, ref),
          ),

          const Divider(),
          ListTile(
            leading: Icon(Icons.logout, color: theme.colorScheme.error),
            title: Text(l10n.authSignOut, style: TextStyle(color: theme.colorScheme.error)),
            onTap: () => _confirmSignOut(context, ref),
          ),

          // `RF-CTA-11` — va el último y detrás de escribir una palabra:
          // irreversible y sin copia. App Store lo exige a toda app que permita
          // crear una cuenta, así que esconderlo no es una opción.
          ListTile(
            leading: Icon(Icons.delete_forever_outlined, color: theme.colorScheme.error),
            title: Text(l10n.accountDelete, style: TextStyle(color: theme.colorScheme.error)),
            onTap: () => context.push(Routes.deleteAccount),
          ),
          const SizedBox(height: AppSpacing.xl),
        ],
      ),
    );
  }

  Future<void> _pickTheme(BuildContext context, WidgetRef ref) async {
    final l10n = AppL10n.of(context);
    final appSettings = ref.read(appSettingsProvider);

    final choice = await showModalBottomSheet<ThemeMode>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: RadioGroup<ThemeMode>(
          groupValue: appSettings.themeMode,
          onChanged: (value) => Navigator.of(sheetContext).pop(value),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final mode in ThemeMode.values)
                RadioListTile<ThemeMode>(value: mode, title: Text(_themeName(l10n, mode))),
            ],
          ),
        ),
      ),
    );
    if (choice != null) await appSettings.setThemeMode(choice);
  }

  Future<void> _pickLanguage(BuildContext context, WidgetRef ref) async {
    final l10n = AppL10n.of(context);
    final appSettings = ref.read(appSettingsProvider);
    const options = <String?>[null, 'es', 'en'];

    final choice = await showModalBottomSheet<String>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: RadioGroup<String?>(
          groupValue: appSettings.locale?.languageCode,
          // `pop(null)` cerraría el sheet sin distinguir "idioma del sistema"
          // de "cancelar", así que devolvemos un centinela.
          onChanged: (value) => Navigator.of(sheetContext).pop(value ?? '_system'),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final code in options)
                RadioListTile<String?>(value: code, title: Text(_languageName(l10n, code))),
            ],
          ),
        ),
      ),
    );
    if (choice == null) return;
    await appSettings.setLocale(choice == '_system' ? null : Locale(choice));
  }

  static String _planName(AppL10n l10n, SubscriptionPlan plan) => switch (plan) {
    SubscriptionPlan.free => l10n.planFree,
    SubscriptionPlan.pro => l10n.planPro,
    SubscriptionPlan.elite => l10n.planElite,
  };

  static String _planUsage(AppL10n l10n, SubscriptionPlan plan, int count) {
    final limit = plan.birdLimit;
    return limit == null ? l10n.planUsageUnlimited(count) : l10n.planUsage(count, limit);
  }

  static String _themeName(AppL10n l10n, ThemeMode mode) => switch (mode) {
    ThemeMode.system => l10n.settingsThemeSystem,
    ThemeMode.light => l10n.settingsThemeLight,
    ThemeMode.dark => l10n.settingsThemeDark,
  };

  static String _languageName(AppL10n l10n, String? code) => switch (code) {
    'es' => l10n.settingsLanguageEs,
    'en' => l10n.settingsLanguageEn,
    _ => l10n.settingsLanguageSystem,
  };

  static IconData _syncIcon(SyncStatus status, int pending) => switch (status) {
    SyncStatus.syncing => Icons.sync,
    SyncStatus.failed => Icons.sync_problem,
    SyncStatus.offline => Icons.cloud_off,
    _ when pending > 0 => Icons.cloud_upload_outlined,
    _ => Icons.cloud_done_outlined,
  };

  static String _syncText(AppL10n l10n, SyncStatus status, int pending) => switch (status) {
    SyncStatus.syncing => l10n.syncInProgress,
    SyncStatus.failed => l10n.syncFailed,
    SyncStatus.offline => l10n.offlineBanner,
    _ when pending > 0 => l10n.syncPending(pending),
    _ => l10n.syncAllSynced,
  };
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.md, AppSpacing.md, AppSpacing.xs),
    child: Text(text.toUpperCase(), style: AppTypography.sectionLabel(context)),
  );
}
