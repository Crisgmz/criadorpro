import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../l10n/generated/app_l10n.dart';
import '../config/app_config.dart';
import '../providers/providers.dart';
import '../router/routes.dart';
import '../widgets/cp_button.dart';

/// Botón de exportación, igual en las tres pantallas que exportan.
///
/// Lleva dentro tres cosas que si no habría que repetir en cada sitio: la
/// restricción de plan (PRD §6 — exportar a PDF es de Pro en adelante), el
/// estado de ocupado mientras se arma el documento, y el aviso si falla.
///
/// **Deshabilitado, no escondido**: un criador del plan gratuito tiene que ver
/// que la app exporta, o no sabrá que existe la función por la que pagaría.
class CpExportButton extends ConsumerStatefulWidget {
  const CpExportButton({required this.label, required this.onExport, super.key});

  final String label;

  /// Arma y entrega el documento. La pantalla lo compone porque es quien tiene
  /// el `BuildContext` con las traducciones y el locale del usuario.
  final Future<void> Function() onExport;

  @override
  ConsumerState<CpExportButton> createState() => _CpExportButtonState();
}

class _CpExportButtonState extends ConsumerState<CpExportButton> {
  bool _busy = false;

  Future<void> _run() async {
    final l10n = AppL10n.of(context);
    final messenger = ScaffoldMessenger.of(context);

    setState(() => _busy = true);
    try {
      await widget.onExport();
    } on Object catch (error, stackTrace) {
      // Armar un PDF toca fuentes, assets y la hoja de compartir del sistema.
      // Que falle no puede tumbar la pantalla ni quedarse callado.
      debugPrint('Exportación falló: $error\n$stackTrace');
      if (mounted) messenger.showSnackBar(SnackBar(content: Text(l10n.exportFailed)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final plan = ref.watch(currentPlanProvider);

    if (plan == SubscriptionPlan.free) {
      return CpButton(
        label: l10n.exportPlanTitle,
        variant: CpButtonVariant.secondary,
        icon: Icons.workspace_premium_outlined,
        onPressed: () => context.push(Routes.settings),
      );
    }

    return CpButton(
      label: widget.label,
      variant: CpButtonVariant.secondary,
      icon: Icons.picture_as_pdf_outlined,
      isLoading: _busy,
      onPressed: _run,
    );
  }
}
