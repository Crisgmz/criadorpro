import '../../../l10n/generated/app_l10n.dart';
import '../model/community.dart';

/// Traducción del estado de una solicitud.
///
/// Las claves se guardan en inglés y se traducen aquí, como los demás catálogos
/// cerrados: así el vocabulario visible se revisa en los `.arb` sin migrar nada
/// —y en este módulo la revisión importa más que en ninguno (BRD §8).
String meetingStatusLabel(AppL10n l10n, MeetingStatus status) => switch (status) {
  MeetingStatus.pending => l10n.statusPending,
  MeetingStatus.accepted => l10n.statusAccepted,
  MeetingStatus.declined => l10n.statusDeclined,
  MeetingStatus.cancelled => l10n.statusCancelled,
};
