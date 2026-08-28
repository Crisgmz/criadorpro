import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers/providers.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/semantic_colors.dart';
import '../../../core/widgets/cp_alert.dart';
import '../../../core/widgets/cp_button.dart';
import '../../../core/widgets/cp_text_field.dart';
import '../../../l10n/generated/app_l10n.dart';

/// Pantalla 25 — Eliminar cuenta.
///
/// A pantalla completa y no en un diálogo, como el diseño. La diferencia no es
/// estética: en un diálogo no cabe la lista de lo que se pierde ni el respaldo,
/// y un «¿seguro?» de dos botones se acepta sin leerlo.
///
/// El botón de conservar la cuenta es el **primario**. El de borrar está debajo,
/// deshabilitado hasta escribir la palabra: la salida fácil tiene que ser la que
/// no destruye nada.
class DeleteAccountView extends ConsumerStatefulWidget {
  const DeleteAccountView({super.key});

  @override
  ConsumerState<DeleteAccountView> createState() => _DeleteAccountViewState();
}

class _DeleteAccountViewState extends ConsumerState<DeleteAccountView> {
  String _typed = '';
  bool _busy = false;

  Future<void> _downloadBackup() async {
    final l10n = AppL10n.of(context);
    final messenger = ScaffoldMessenger.of(context);

    setState(() => _busy = true);
    try {
      final count = await ref
          .read(backupServiceProvider)
          .export(ownerId: ref.read(currentOwnerIdProvider), now: DateTime.now());
      messenger.showSnackBar(SnackBar(content: Text(l10n.backupDone(count))));
    } on Object catch (error, stackTrace) {
      debugPrint('Respaldo falló: $error\n$stackTrace');
      messenger.showSnackBar(SnackBar(content: Text(l10n.backupFailed)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete() async {
    final l10n = AppL10n.of(context);
    final messenger = ScaffoldMessenger.of(context);

    if (await ref.read(settingsViewModelProvider).deleteAccount()) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.accountDeleteDone)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final theme = Theme.of(context);
    final settings = ref.watch(settingsViewModelProvider);
    final word = l10n.accountDeleteConfirmWord;
    final canDelete = _typed.trim().toUpperCase() == word.toUpperCase();

    return Scaffold(
      backgroundColor: theme.colorScheme.surfaceContainerLowest,
      appBar: AppBar(title: Text(l10n.deleteAccountTitle)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.screen,
          AppSpacing.lg,
          AppSpacing.screen,
          AppSpacing.xxl,
        ),
        children: [
          Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: theme.colorScheme.error),
              const SizedBox(width: AppSpacing.sm),
              Text(
                l10n.deleteAccountPermanent,
                style: theme.textTheme.titleMedium?.copyWith(color: theme.colorScheme.error),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),

          Text(l10n.deleteAccountIntro, style: theme.textTheme.bodyLarge),
          const SizedBox(height: AppSpacing.sm),
          // Enumerarlo, y con el número real de registros: «se borrarán tus
          // datos» no significa nada; «tus 148 registros» sí.
          _Bullet(l10n.deleteAccountBullet1(settings.birdCount)),
          _Bullet(l10n.deleteAccountBullet2),
          _Bullet(l10n.deleteAccountBullet3),
          _Bullet(l10n.deleteAccountBullet4),

          const SizedBox(height: AppSpacing.md),
          // La suscripción no se cancela sola al borrar la cuenta: la cobra la
          // tienda, no nosotros. Callarlo dejaría al criador pagando por una
          // cuenta que ya no existe.
          CpAlert(message: l10n.deleteAccountStoreNote, tone: CpAlertTone.warning),

          const SizedBox(height: AppSpacing.md),
          CpButton(
            label: l10n.deleteAccountDownload,
            variant: CpButtonVariant.secondary,
            icon: Icons.cloud_download_outlined,
            isLoading: _busy,
            onPressed: _downloadBackup,
          ),

          const SizedBox(height: AppSpacing.xl),
          CpTextField(
            label: l10n.accountDeleteConfirmHint,
            textCapitalization: TextCapitalization.characters,
            onChanged: (value) => setState(() => _typed = value),
          ),
          const SizedBox(height: AppSpacing.lg),

          // La salida fácil primero y como acción principal: lo que no destruye
          // nada tiene que ser lo que el pulgar encuentra sin pensar.
          CpButton(
            label: l10n.deleteAccountKeep,
            onPressed: () => context.canPop() ? context.pop() : null,
          ),
          const SizedBox(height: AppSpacing.sm),
          CpButton(
            label: l10n.accountDelete,
            variant: CpButtonVariant.danger,
            isLoading: settings.isLoading,
            onPressed: canDelete ? _delete : null,
          ),
        ],
      ),
    );
  }
}

class _Bullet extends StatelessWidget {
  const _Bullet(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('•', style: TextStyle(color: context.semantic.action)),
          const SizedBox(width: AppSpacing.sm),
          Expanded(child: Text(text, style: theme.textTheme.bodyMedium)),
        ],
      ),
    );
  }
}
