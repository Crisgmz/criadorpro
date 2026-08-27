import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/domain/sex.dart';
import '../../../core/error/failure_messages.dart';
import '../../../core/providers/providers.dart';
import '../../../core/router/routes.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/cp_alert.dart';
import '../../../core/widgets/cp_button.dart';
import '../../../core/widgets/cp_cards.dart';
import '../../../core/widgets/cp_text_field.dart';
import '../../../l10n/generated/app_l10n.dart';
import '../../auth/view/widgets/auth_scaffold.dart';
import '../../birds/model/bird.dart';

/// Redactar una solicitud de encuentro — `RF-COM`.
///
/// Terminología: **solicitud de encuentro**, nunca ninguno de los términos
/// prohibidos por el BRD §8. La compuerta de compilación revisa los `.arb`
/// antes de cada envío y este es el módulo donde más importa.
class MeetingRequestView extends ConsumerStatefulWidget {
  const MeetingRequestView({required this.toOwner, super.key});

  final String toOwner;

  @override
  ConsumerState<MeetingRequestView> createState() => _MeetingRequestViewState();
}

class _MeetingRequestViewState extends ConsumerState<MeetingRequestView> {
  Bird? _bird;

  Future<void> _pickBird() async {
    // Reutiliza el selector de progenitor (pantalla 18): es la misma tarea
    // —elegir un ejemplar propio de una lista— y tener dos pantallas para eso
    // sería tener dos sitios donde arreglar el mismo fallo.
    final chosen = await context.push<Bird>(Routes.parentPicker(Sex.male.id));
    if (chosen == null) return;

    setState(() => _bird = chosen);
    ref.read(meetingRequestViewModelProvider(widget.toOwner)).setBird(chosen.id);
  }

  Future<void> _pickDate() async {
    final viewModel = ref.read(meetingRequestViewModelProvider(widget.toOwner));
    final today = viewModel.today;

    final picked = await showDatePicker(
      context: context,
      initialDate: viewModel.date ?? today,
      // Un encuentro se propone hacia adelante: una fecha pasada no es una
      // propuesta, es un error de tecleo.
      firstDate: today,
      lastDate: DateTime(today.year + 1, 12, 31),
    );
    if (picked != null) viewModel.setDate(picked);
  }

  Future<void> _submit() async {
    final l10n = AppL10n.of(context);
    final viewModel = ref.read(meetingRequestViewModelProvider(widget.toOwner));
    final sent = await viewModel.submit();
    if (!mounted || sent == null) return;

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.communitySent)));
    Navigator.of(context).pop(sent);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final locale = Localizations.localeOf(context).toLanguageTag();
    final viewModel = ref.watch(meetingRequestViewModelProvider(widget.toOwner));

    return AuthScaffold(
      title: l10n.communityRequestTitle,
      children: [
        if (viewModel.failure != null)
          CpAlert(
            message: failureMessage(l10n, viewModel.failure!),
            onClose: viewModel.clearFailure,
          ),

        CpTextField(
          label: l10n.communityFieldMessage,
          maxLines: 4,
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
          onChanged: viewModel.setMessage,
        ),
        const SizedBox(height: AppSpacing.md),

        CpSectionLabel(
          l10n.communityFieldBird,
          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
        ),
        if (_bird == null)
          CpButton(
            label: l10n.communityFieldBird,
            variant: CpButtonVariant.secondary,
            icon: Icons.add,
            onPressed: _pickBird,
          )
        else
          CpBirdCard(
            sex: _bird!.sex,
            name: _bird!.displayName,
            subtitle: l10n.birdsPlateLabel(Formatters.plate(_bird!.plate)),
            onTap: _pickBird,
          ),
        const SizedBox(height: AppSpacing.md),

        CpTextField(
          label: l10n.communityFieldPlace,
          textCapitalization: TextCapitalization.sentences,
          onChanged: viewModel.setPlace,
        ),
        const SizedBox(height: AppSpacing.md),

        InkWell(
          onTap: _pickDate,
          borderRadius: BorderRadius.circular(AppRadius.md),
          child: InputDecorator(
            decoration: InputDecoration(
              labelText: l10n.communityFieldDate,
              prefixIcon: const Icon(Icons.event_outlined),
            ),
            child: Text(viewModel.date == null ? '—' : Formatters.date(viewModel.date!, locale)),
          ),
        ),
        const SizedBox(height: AppSpacing.xl),

        CpButton(
          label: l10n.communityRequestNew,
          isLoading: viewModel.isLoading,
          onPressed: viewModel.canSubmit ? _submit : null,
        ),
      ],
    );
  }
}
