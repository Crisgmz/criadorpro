import 'package:uuid/uuid.dart';

import '../../../core/error/failure.dart';
import '../../../core/network/connectivity_service.dart';
import '../../../core/network/supabase_service.dart';
import '../../../core/utils/result.dart';
import '../model/community.dart';

/// Comunidad — `RF-COM`.
///
/// **Es el único repositorio que exige conexión.** `RNF-08` lo permite para
/// autenticación, Comunidad y compras, y aquí es lo correcto: un directorio de
/// criaderos ajenos no es el libro del criador, y guardarlo en local mostraría
/// desconocidos que ya se dieron de baja. Todo lo demás del producto sigue
/// resolviéndose contra Drift sin red (`RF-SIN-01`).
///
/// Por lo mismo no toca `sync_queue`: una solicitud escrita sin señal que se
/// queda en una cola invisible es peor que decirle al criador que ahora no se
/// puede. Sin red, cada método devuelve [NetworkFailure] y la pantalla lo dice.
class CommunityRepository {
  CommunityRepository({
    required SupabaseService supabase,
    required ConnectivityService connectivity,
    Uuid uuid = const Uuid(),
    DateTime Function() clock = DateTime.now,
  }) : _supabase = supabase,
       _connectivity = connectivity,
       _uuid = uuid,
       _clock = clock;

  final SupabaseService _supabase;
  final ConnectivityService _connectivity;
  final Uuid _uuid;
  final DateTime Function() _clock;

  static const String directoryView = 'public_profiles';
  static const String requestsTable = 'meeting_requests';
  static const String blocksTable = 'community_blocks';
  static const String reportsTable = 'community_reports';

  /// Cuántos criaderos trae el directorio de una vez.
  static const int pageSize = 40;

  Future<Failure?> _requireConnection() async {
    if (!_supabase.isEnabled) {
      return const NetworkFailure(debugMessage: 'sin backend configurado');
    }
    if (!await _connectivity.isOnline()) {
      return const NetworkFailure(debugMessage: 'comunidad requiere conexión');
    }
    return null;
  }

  /// Directorio de criaderos publicados — `RF-COM-01`.
  ///
  /// Excluye a quien el criador haya bloqueado. Se filtra aquí y no en la vista
  /// porque un bloqueo es asimétrico: quien bloquea deja de ver, y el bloqueado
  /// no tiene por qué enterarse.
  Future<Result<List<PublicProfile>>> directory({
    required String ownerId,
    String query = '',
  }) async {
    final offline = await _requireConnection();
    if (offline != null) return Err(offline);

    return guard(() async {
      final blocked = await _blockedIds(ownerId);

      var request = _supabase.client
          .from(directoryView)
          .select()
          // Uno mismo no aparece en su propio directorio.
          .neq('id', ownerId);

      final trimmed = query.trim();
      if (trimmed.isNotEmpty) request = request.ilike('farm_name', '%$trimmed%');

      final rows = await request.order('farm_name').limit(pageSize);

      return [
        for (final row in rows)
          if (!blocked.contains(row['id'] as String)) PublicProfile.fromJson(row),
      ];
    }, (error, _) => NetworkFailure(debugMessage: error.toString(), cause: error));
  }

  /// Solicitudes en las que participa el criador, recibidas y enviadas.
  Future<Result<List<MeetingRequest>>> requests(String ownerId) async {
    final offline = await _requireConnection();
    if (offline != null) return Err(offline);

    return guard(() async {
      final rows = await _supabase.client
          .from(requestsTable)
          .select()
          .eq('is_deleted', false)
          .order('created_at', ascending: false);

      final requests = [for (final row in rows) MeetingRequest.fromJson(row)];
      if (requests.isEmpty) return requests;

      // El nombre del otro criadero se resuelve aparte y no se guarda en la
      // fila: un nombre congelado dejaría la bandeja mostrando criaderos que ya
      // se llaman de otra forma.
      final names = await _farmNames({
        for (final request in requests) request.counterpartOf(ownerId),
      });

      return [
        for (final request in requests)
          request.withCounterpart(names[request.counterpartOf(ownerId)]),
      ];
    }, (error, _) => NetworkFailure(debugMessage: error.toString(), cause: error));
  }

  /// Manda una solicitud de encuentro — `RF-COM`.
  Future<Result<MeetingRequest>> send({
    required String ownerId,
    required String toOwner,
    String? fromBirdId,
    String? message,
    String? place,
    DateTime? proposedDate,
  }) async {
    // Lo que está mal en la solicitud se dice **antes** de mirar la red: decir
    // «sin conexión» a quien escribió una fecha pasada le manda a buscar señal
    // para volver a encontrarse el mismo error.
    if (toOwner == ownerId) {
      return const Err(ValidationFailure('to', debugMessage: 'no se puede a uno mismo'));
    }

    final now = _clock();
    if (proposedDate != null && proposedDate.isBefore(DateTime(now.year, now.month, now.day))) {
      return const Err(ValidationFailure('date', debugMessage: 'fecha pasada'));
    }

    final offline = await _requireConnection();
    if (offline != null) return Err(offline);

    final request = MeetingRequest(
      id: _uuid.v4(),
      fromOwner: ownerId,
      toOwner: toOwner,
      fromBirdId: fromBirdId,
      message: _trimToNull(message),
      place: _trimToNull(place),
      proposedDate: proposedDate,
      status: MeetingStatus.pending,
      createdAt: now,
      updatedAt: now,
    );

    return guard(() async {
      await _supabase.client.from(requestsTable).insert(request.toInsertJson());
      return request;
    }, (error, _) => NetworkFailure(debugMessage: error.toString(), cause: error));
  }

  /// Responde una solicitud recibida, o retira una enviada.
  ///
  /// Quién puede hacer qué se comprueba aquí **y** en la base: la política de
  /// `meeting_requests` solo deja escribir a las dos partes, así que un cliente
  /// mal escrito no puede aceptar una solicitud ajena.
  Future<Result<void>> respond({
    required String ownerId,
    required MeetingRequest request,
    required MeetingStatus status,
  }) async {
    final isIncoming = request.isIncomingFor(ownerId);
    final allowed = switch (status) {
      // Aceptar y rechazar es de quien la recibe.
      MeetingStatus.accepted || MeetingStatus.declined => isIncoming,
      // Retirarla, de quien la mandó.
      MeetingStatus.cancelled => !isIncoming,
      MeetingStatus.pending => false,
    };
    if (!allowed) {
      return const Err(ValidationFailure('status', debugMessage: 'transición no permitida'));
    }

    final offline = await _requireConnection();
    if (offline != null) return Err(offline);

    return guard(() async {
      await _supabase.client.from(requestsTable).update({'status': status.id}).eq('id', request.id);
    }, (error, _) => NetworkFailure(debugMessage: error.toString(), cause: error));
  }

  // --- Denuncia y bloqueo ---------------------------------------------------
  //
  // App Store y Play los exigen para cualquier contenido de usuarios: sin ellos
  // el módulo no pasa revisión por bien que funcione lo demás. Las **reglas** de
  // moderación siguen sin aprobarse (decisión abierta §13); esto es el
  // mecanismo, no la política.

  Future<Result<void>> block({required String ownerId, required String blockedId}) async {
    final offline = await _requireConnection();
    if (offline != null) return Err(offline);

    return guard(() async {
      await _supabase.client.from(blocksTable).upsert({
        'blocker_id': ownerId,
        'blocked_id': blockedId,
      });
    }, (error, _) => NetworkFailure(debugMessage: error.toString(), cause: error));
  }

  Future<Result<void>> report({
    required String ownerId,
    required String reportedId,
    String? reason,
  }) async {
    final offline = await _requireConnection();
    if (offline != null) return Err(offline);

    return guard(() async {
      await _supabase.client.from(reportsTable).insert({
        'id': _uuid.v4(),
        'reporter_id': ownerId,
        'reported_id': reportedId,
        'reason': _trimToNull(reason),
      });
    }, (error, _) => NetworkFailure(debugMessage: error.toString(), cause: error));
  }

  Future<Set<String>> _blockedIds(String ownerId) async {
    final rows = await _supabase.client
        .from(blocksTable)
        .select('blocked_id')
        .eq('blocker_id', ownerId);
    return {for (final row in rows) row['blocked_id'] as String};
  }

  Future<Map<String, String>> _farmNames(Set<String> ids) async {
    if (ids.isEmpty) return const {};

    // Solo de quien esté publicado: si alguien se retiró del directorio, su
    // nombre deja de mostrarse aunque quede una solicitud abierta con él.
    final rows = await _supabase.client
        .from(directoryView)
        .select('id, farm_name')
        .inFilter('id', ids.toList());

    return {for (final row in rows) row['id'] as String: row['farm_name'] as String? ?? ''};
  }

  static String? _trimToNull(String? value) {
    final trimmed = value?.trim();
    return (trimmed == null || trimmed.isEmpty) ? null : trimmed;
  }
}
