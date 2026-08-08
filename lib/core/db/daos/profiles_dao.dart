import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/profiles.dart';

part 'profiles_dao.g.dart';

@DriftAccessor(tables: [Profiles])
class ProfilesDao extends DatabaseAccessor<AppDatabase> with _$ProfilesDaoMixin {
  ProfilesDao(super.db);

  Stream<ProfileRow?> watchById(String id) =>
      (select(profiles)..where((t) => t.id.equals(id))).watchSingleOrNull();

  Future<ProfileRow?> findById(String id) =>
      (select(profiles)..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<void> upsert(ProfilesCompanion profile) => into(profiles).insertOnConflictUpdate(profile);

  /// Empuja el contador de placas hasta [atLeast], nunca hacia atrás.
  ///
  /// `RS-01`: el contador solo crece. El `MAX` evita que dos altas casi
  /// simultáneas lo hagan retroceder si la segunda termina antes.
  Future<void> bumpNextPlate({required String ownerId, required int atLeast}) => customUpdate(
    'UPDATE profiles SET next_plate = MAX(next_plate, ?) WHERE id = ?',
    variables: [Variable.withInt(atLeast), Variable.withString(ownerId)],
    updates: {profiles},
  );

  /// Reserva un bloque de [count] placas correlativas y devuelve la primera.
  ///
  /// Es lo que hace posible registrar una camada de ocho crías con placas
  /// seguidas. Debe llamarse **dentro** de la transacción que crea las crías:
  /// así, si alguna inserción falla, la reserva se deshace con ella y el
  /// contador no avanza (`RS-04`).
  ///
  /// La reserva es local a propósito. Existe la RPC `next_plate()` en el
  /// servidor, pero pedirla aquí pondría la red en el camino crítico de la
  /// función estrella del producto, y eso lo prohíbe `RF-SIN-01`. El servidor
  /// sigue siendo la autoridad cuando dos dispositivos del mismo criadero
  /// registran a la vez; hasta entonces manda el contador del perfil.
  Future<int> reservePlateBlock({required String ownerId, required int count}) async {
    final profile = await findById(ownerId);
    final first = profile?.nextPlate ?? 1;
    await bumpNextPlate(ownerId: ownerId, atLeast: first + count);
    return first;
  }

  Future<void> clear() => delete(profiles).go();
}
