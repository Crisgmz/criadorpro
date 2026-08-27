import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/base/view_state.dart';
import '../../../core/config/app_config.dart';
import '../../../core/error/failure_messages.dart';
import '../../../core/providers/providers.dart';
import '../../../core/router/routes.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/cp_alert.dart';
import '../../../core/widgets/cp_button.dart';
import '../../../core/widgets/cp_cards.dart';
import '../../../core/widgets/cp_segmented.dart';
import '../../../core/widgets/cp_text_field.dart';
import '../../../l10n/generated/app_l10n.dart';

/// Pantalla 13 — Mi perfil.
///
/// Hasta ahora no había forma de cambiar el nombre del criadero después del
/// onboarding: se escribía una vez y se quedaba. Un criador que se equivoca al
/// teclearlo lo arrastraba en cada pedigrí exportado.
class ProfileView extends ConsumerStatefulWidget {
  const ProfileView({super.key});

  @override
  ConsumerState<ProfileView> createState() => _ProfileViewState();
}

class _ProfileViewState extends ConsumerState<ProfileView> {
  final _nameController = TextEditingController();
  final _farmController = TextEditingController();
  final _locationController = TextEditingController();
  final _phoneController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final viewModel = ref.read(profileViewModelProvider);
      await viewModel.load();
      if (!mounted) return;

      // Una sola vez: escribirlos en cada build movería el cursor al inicio
      // cada vez que el criador teclea una letra.
      _nameController.text = viewModel.fullName;
      _farmController.text = viewModel.farmName;
      _locationController.text = viewModel.location;
      _phoneController.text = viewModel.phone;
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _farmController.dispose();
    _locationController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final l10n = AppL10n.of(context);
    final messenger = ScaffoldMessenger.of(context);

    if (await ref.read(profileViewModelProvider).submit()) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.profileSaved)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final theme = Theme.of(context);
    final viewModel = ref.watch(profileViewModelProvider);

    if (viewModel.state == ViewState.loading && viewModel.profile == null) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.profileTitle)),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: theme.colorScheme.surfaceContainerLowest,
      appBar: AppBar(title: Text(l10n.profileTitle)),
      body: ListView(
        padding: const EdgeInsets.only(top: AppSpacing.md, bottom: AppSpacing.xxl),
        children: [
          if (viewModel.failure != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screen),
              child: CpAlert(
                message: failureMessage(l10n, viewModel.failure!),
                onClose: viewModel.clearFailure,
              ),
            ),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screen),
            child: Column(
              children: [
                CpTextField(
                  label: l10n.profileFieldName,
                  controller: _nameController,
                  textCapitalization: TextCapitalization.words,
                  prefixIcon: Icons.person_outline,
                  onChanged: viewModel.setFullName,
                ),
                const SizedBox(height: AppSpacing.md),
                CpTextField(
                  label: l10n.profileFieldFarm,
                  controller: _farmController,
                  textCapitalization: TextCapitalization.words,
                  prefixIcon: Icons.home_work_outlined,
                  onChanged: viewModel.setFarmName,
                ),
                const SizedBox(height: AppSpacing.md),
                CpTextField(
                  label: l10n.profileFieldLocation,
                  controller: _locationController,
                  textCapitalization: TextCapitalization.words,
                  prefixIcon: Icons.place_outlined,
                  onChanged: viewModel.setLocation,
                ),
                const SizedBox(height: AppSpacing.md),
                CpTextField(
                  label: l10n.profileFieldPhone,
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  prefixIcon: Icons.phone_outlined,
                  onChanged: viewModel.setPhone,
                ),
              ],
            ),
          ),

          CpSectionLabel(l10n.settingsLanguage),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screen),
            child: CpSegmented<String>(
              segments: [
                for (final code in AppConfig.supportedLocales)
                  CpSegment(value: code, label: code == 'es' ? 'Español' : 'English'),
              ],
              selected: viewModel.locale ?? AppConfig.supportedLocales.first,
              onChanged: viewModel.setLocale,
            ),
          ),

          CpSectionLabel(l10n.profileNumbering),
          CpDataCard(
            rows: [
              // Se muestra y no se edita: retrocederla repetiría placas ya
              // usadas, y `RS-01` dice que eliminar un ejemplar tampoco libera
              // la suya.
              CpDataRow(label: l10n.profileNextPlate, value: Formatters.plate(viewModel.nextPlate)),
            ],
          ),

          const SizedBox(height: AppSpacing.xl),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screen),
            child: CpButton(
              label: l10n.commonSave,
              isLoading: viewModel.isLoading,
              onPressed: viewModel.canSubmit ? _submit : null,
            ),
          ),

          // «Zona de riesgo» separada del resto, como en el diseño: lo que hay
          // aquí no se deshace, y mezclarlo con los campos que sí se corrigen
          // invita a pulsarlo por inercia.
          CpSectionLabel(l10n.profileDangerZone),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screen),
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(color: theme.colorScheme.error.withValues(alpha: 0.4)),
                borderRadius: BorderRadius.circular(AppRadius.card),
              ),
              child: ListTile(
                leading: Icon(Icons.delete_forever_outlined, color: theme.colorScheme.error),
                title: Text(l10n.accountDelete, style: TextStyle(color: theme.colorScheme.error)),
                subtitle: Text(l10n.profileDeleteHint),
                onTap: () => context.push(Routes.settings),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Center(
            child: Text(
              '${l10n.drawerVersion} ${AppConfig.version}',
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }
}
