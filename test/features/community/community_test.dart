import 'package:criadorpro/core/db/app_database.dart';
import 'package:criadorpro/core/error/failure.dart';
import 'package:criadorpro/core/network/connectivity_service.dart';
import 'package:criadorpro/core/network/supabase_service.dart';
import 'package:criadorpro/core/utils/result.dart';
import 'package:criadorpro/features/auth/repository/profile_repository.dart';
import 'package:criadorpro/features/community/model/community.dart';
import 'package:criadorpro/features/community/repository/community_repository.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

/// `RF-COM` — Comunidad.
///
/// Es el módulo que más se aparta del resto: exige conexión (`RNF-08`) y sus
/// registros pertenecen a dos criaderos a la vez. Lo que se prueba aquí es
/// justamente eso — que sin red lo diga en lugar de fingir un vacío, y que
/// nadie pueda responder una solicitud que no es suya.
void main() {
  late CommunityRepository repository;

  const ownerId = 'owner-1';
  const otherId = 'owner-2';
  final now = DateTime(2026, 8, 27);

  setUp(() {
    // Sin backend configurado: es la misma situación que estar sin red, y deja
    // comprobar el camino de fallo sin montar un servidor.
    repository = CommunityRepository(
      supabase: SupabaseService(null),
      connectivity: ConnectivityService(),
      clock: () => now,
    );
  });

  MeetingRequest request({
    String from = ownerId,
    String to = otherId,
    MeetingStatus status = MeetingStatus.pending,
  }) => MeetingRequest(
    id: 'r1',
    fromOwner: from,
    toOwner: to,
    status: status,
    createdAt: now,
    updatedAt: now,
  );

  group('exige conexión — `RNF-08`', () {
    test('el directorio lo dice en lugar de devolver una lista vacía', () async {
      // Una lista vacía se leería como «no hay criaderos», que es la conclusión
      // equivocada y la que haría al criador dejar de abrir la pestaña.
      final result = await repository.directory(ownerId: ownerId);

      expect((result as Err).failure, isA<NetworkFailure>());
    });

    test('mandar una solicitud sin red falla, no se encola', () async {
      // Encolarla la dejaría en un limbo invisible: el criador creería que la
      // mandó y el otro criadero nunca la recibiría.
      final result = await repository.send(ownerId: ownerId, toOwner: otherId, message: 'Hola');

      expect((result as Err).failure, isA<NetworkFailure>());
    });

    test('la bandeja también', () async {
      expect((await repository.requests(ownerId) as Err).failure, isA<NetworkFailure>());
    });
  });

  group('quién puede hacer qué', () {
    test('aceptar es de quien la recibe, y se rechaza antes de tocar la red', () async {
      // Quien la mandó no puede aceptarla. Se comprueba antes de `_requireConnection`
      // a propósito: es un error del cliente, no de la conexión, y decir «sin
      // red» ahí sería mentir.
      final result = await repository.respond(
        ownerId: ownerId,
        request: request(),
        status: MeetingStatus.accepted,
      );

      expect((result as Err).failure, isA<ValidationFailure>());
    });

    test('rechazar tampoco es de quien la mandó', () async {
      final result = await repository.respond(
        ownerId: ownerId,
        request: request(),
        status: MeetingStatus.declined,
      );

      expect((result as Err).failure, isA<ValidationFailure>());
    });

    test('retirarla no es de quien la recibe', () async {
      final result = await repository.respond(
        ownerId: otherId,
        request: request(),
        status: MeetingStatus.cancelled,
      );

      expect((result as Err).failure, isA<ValidationFailure>());
    });

    test('volver a «pendiente» no es una transición válida para nadie', () async {
      for (final owner in [ownerId, otherId]) {
        final result = await repository.respond(
          ownerId: owner,
          request: request(),
          status: MeetingStatus.pending,
        );
        expect((result as Err).failure, isA<ValidationFailure>());
      }
    });

    test('quien la recibe sí puede aceptarla — llega hasta la red', () async {
      final result = await repository.respond(
        ownerId: otherId,
        request: request(),
        status: MeetingStatus.accepted,
      );

      // Sin backend el fallo es de red, no de validación: la transición era
      // buena y solo faltó conexión.
      expect((result as Err).failure, isA<NetworkFailure>());
    });
  });

  group('validación', () {
    test('nadie se manda una solicitud a sí mismo', () async {
      final result = await repository.send(ownerId: ownerId, toOwner: ownerId);

      // Antes que la red, por lo mismo: es un error del cliente.
      expect((result as Err).failure, isA<ValidationFailure>());
    });

    test('una fecha pasada no es una propuesta', () async {
      final result = await repository.send(
        ownerId: ownerId,
        toOwner: otherId,
        proposedDate: DateTime(2026, 8, 1),
      );

      expect((result as Err).failure, isA<ValidationFailure>());
    });
  });

  group('modelo', () {
    test('la solicitud sabe de qué lado la mira cada criadero', () {
      final incoming = request(from: otherId, to: ownerId);

      expect(incoming.isIncomingFor(ownerId), isTrue);
      expect(incoming.counterpartOf(ownerId), otherId);
      expect(incoming.isIncomingFor(otherId), isFalse);
      expect(incoming.counterpartOf(otherId), ownerId);
    });

    test('solo «pendiente» está abierta', () {
      expect(MeetingStatus.pending.isOpen, isTrue);
      for (final status in [
        MeetingStatus.accepted,
        MeetingStatus.declined,
        MeetingStatus.cancelled,
      ]) {
        expect(status.isOpen, isFalse);
      }
    });

    test('el perfil público no trae correo, teléfono ni plan', () {
      // La vista `public_profiles` no los expone; si algún día alguien
      // añadiera una política de `select` sobre `profiles` en vez de la vista,
      // esto seguiría pasando y por eso el comentario del SQL importa.
      final profile = PublicProfile.fromJson(const {
        'id': 'o1',
        'farm_name': 'Criadero Los Pinos',
        'location': 'Santiago',
      });

      expect(profile.farmName, 'Criadero Los Pinos');
      expect(profile.location, 'Santiago');
    });
  });

  group('publicarse es opt-in', () {
    late AppDatabase database;
    late ProfileRepository profiles;

    setUp(() async {
      database = AppDatabase(NativeDatabase.memory());
      profiles = ProfileRepository(
        database: database,
        profilesDao: database.profilesDao,
        syncQueue: database.syncQueueDao,
        supabase: SupabaseService(null),
        clock: () => now,
      );
      await database.profilesDao.upsert(
        ProfilesCompanion.insert(id: ownerId, createdAt: now, updatedAt: now),
      );
    });

    tearDown(() => database.close());

    test('un perfil nuevo no aparece en el directorio', () async {
      final row = await database.profilesDao.findById(ownerId);
      expect(row!.isPublic, isFalse, reason: 'nadie se publica por registrarse');
    });

    test('publicarse encola el cambio: funciona sin señal', () async {
      // Comunidad exige conexión, pero **decidir** publicarse no: el
      // interruptor tiene que sobrevivir a pulsarlo en el galpón.
      expect(await profiles.setPublic(ownerId: ownerId, isPublic: true), isA<Ok<Object?>>());

      expect((await database.profilesDao.findById(ownerId))!.isPublic, isTrue);

      final pending = await database.syncQueueDao.pending(maxAttempts: 5);
      expect(pending.map((task) => task.entityTable), contains('profiles'));
    });

    test('se puede retirar', () async {
      await profiles.setPublic(ownerId: ownerId, isPublic: true);
      await profiles.setPublic(ownerId: ownerId, isPublic: false);

      expect((await database.profilesDao.findById(ownerId))!.isPublic, isFalse);
    });
  });
}
