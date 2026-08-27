import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/config/app_config.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/semantic_colors.dart';
import '../../../core/widgets/cp_button.dart';
import '../../../core/widgets/cp_cards.dart';
import '../../../l10n/generated/app_l10n.dart';

/// Pantalla 15 — Soporte.
///
/// El canal es WhatsApp y no un formulario dentro de la app: en República
/// Dominicana es donde el criador ya escribe, y un buzón propio sería un sitio
/// más que alguien tendría que revisar. Se dice el horario y el tiempo típico
/// de respuesta porque escribir sin saber cuándo contestan es lo que hace que
/// la gente escriba tres veces.
class SupportView extends StatelessWidget {
  const SupportView({super.key});

  Future<void> _openWhatsApp() async {
    final uri = Uri.parse(AppConfig.supportWhatsAppUrl);
    // `externalApplication`: `wa.me` dentro de una vista web se queda en la
    // página de descarga en vez de abrir la conversación.
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surfaceContainerLowest,
      appBar: AppBar(title: Text(l10n.supportTitle)),
      body: ListView(
        padding: const EdgeInsets.only(top: AppSpacing.lg, bottom: AppSpacing.xxl),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screen),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.supportHeadline, style: theme.textTheme.headlineSmall),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  l10n.supportBody,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),

          CpDataCard(
            rows: [
              CpDataRow(label: l10n.supportNumber, value: AppConfig.supportPhoneE164),
              CpDataRow(label: l10n.supportHours, value: l10n.supportHoursValue),
              CpDataRow(label: l10n.supportResponse, value: l10n.supportResponseValue),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screen),
            child: CpButton(
              label: l10n.supportWhatsApp,
              icon: Icons.chat_outlined,
              onPressed: _openWhatsApp,
            ),
          ),
          const SizedBox(height: AppSpacing.md),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screen),
            child: Text(
              l10n.supportEmailHint(AppConfig.supportEmail),
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(color: context.semantic.brand),
            ),
          ),
        ],
      ),
    );
  }
}
