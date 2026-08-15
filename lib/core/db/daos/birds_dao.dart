import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/birds.dart';

part 'birds_dao.g.dart';

@DriftAccessor(tables: [Birds])
class BirdsDao extends DatabaseAccessor<AppDatabase> with _$BirdsDaoMixin {
  BirdsDao(super.db);

  /// Lista viva de ejemplares del criadero, ya filtrada. La UI se suscribe a
  /// este stream y se redibuja sola cuando la sincronización trae cambios.
  Stream<List<BirdRow>> watchAll({
    required String ownerId,
    String? search,
    String? sex,
    String? status,
  }) {
    final query = select(birds)
      ..where((t) => t.ownerId.equals(ownerId) & t.isDeleted.equals(false));

    if (sex != null) {
      query.where((t) => t.sex.equals(sex));
    }
    if (status != null) {
      query.where((t) => t.status.equals(status));
    }
    // `RF-REG-04`: se busca por placa o por nombre. Los dígitos sueltos se
    // comparan también contra la placa, que es como el criador la busca.
    final term = search?.trim() ?? '';
    if (term.isNotEmpty) {
      final pattern = '%${term.toLowerCase()}%';
      final plate = int.tryParse(term.replaceAll('#', '').trim());
      query.where(
        (t) => plate == null
            ? t.name.lower().like(pattern)
            : t.name.lower().like(pattern) | t.plate.equals(plate),
      );
    }

    // `RF-REG-03`: ordenada por placa descendente — lo último registrado va
    // arriba, que es lo que el criador acaba de tocar.
    query.orderBy([(t) => OrderingTerm(expression: t.plate, mode: OrderingMode.desc)]);
    return query.watch();
  }

  /// `RV-08` — comprueba si la placa ya está usada en ese criadero.
  Future<bool> existsWithPlate({
    required String ownerId,
    required int plate,
    String? excludeId,
  }) async {
    final query = select(birds)
      ..where((t) => t.ownerId.equals(ownerId) & t.isDeleted.equals(false) & t.plate.equals(plate))
      ..limit(1);
    if (excludeId != null) {
      query.where((t) => t.id.equals(excludeId).not());
    }
    return await query.getSingleOrNull() != null;
  }

  /// Placa más alta registrada. La usa `RV-07` para que la numeración inicial
  /// no pueda quedar por debajo de lo que ya existe.
  Future<int> highestPlate(String ownerId) async {
    final highest = birds.plate.max();
    final query = selectOnly(birds)
      ..addColumns([highest])
      ..where(birds.ownerId.equals(ownerId) & birds.isDeleted.equals(false));
    final row = await query.getSingle();
    return row.read(highest) ?? 0;
  }

  Stream<BirdRow?> watchById(String id) =>
      (select(birds)..where((t) => t.id.equals(id))).watchSingleOrNull();

  Future<BirdRow?> findById(String id) =>
      (select(birds)..where((t) => t.id.equals(id))).getSingleOrNull();

  /// Candidatos a padre/madre: ejemplares vivos del criadero de ese sexo,
  /// excluyendo al propio ejemplar para no crear un ciclo genealógico.
  Future<List<BirdRow>> parentCandidates({
    required String ownerId,
    required String sex,
    String? excludeId,
  }) {
    final query = select(birds)
      ..where((t) => t.ownerId.equals(ownerId) & t.isDeleted.equals(false) & t.sex.equals(sex));
    if (excludeId != null) {
      query.where((t) => t.id.equals(excludeId).not());
    }
    query.orderBy([(t) => OrderingTerm(expression: t.plate, mode: OrderingMode.desc)]);
    return query.get();
  }

  /// Crías de un ejemplar, sea como padre o como madre — `RF-REG-13`.
  ///
  /// Orden ascendente por placa: dentro de una camada las placas son
  /// correlativas, y el criador las lee en el orden en que las asignó.
  Stream<List<BirdRow>> watchChildren(String parentId) =>
      (select(birds)
            ..where(
              (t) =>
                  (t.fatherId.equals(parentId) | t.motherId.equals(parentId)) &
                  t.isDeleted.equals(false),
            )
            ..orderBy([(t) => OrderingTerm(expression: t.plate)]))
          .watch();

  /// Cuenta los ejemplares que consumen cupo del plan.
  ///
  /// `RS-02` es explícito: solo cuentan los activos. Un ejemplar vendido o
  /// fallecido sigue en el libro pero no ocupa plaza.
  Future<int> countForOwner(String ownerId) async {
    final total = birds.id.count();
    final query = selectOnly(birds)
      ..addColumns([total])
      ..where(
        birds.ownerId.equals(ownerId) &
            birds.isDeleted.equals(false) &
            birds.status.equals('active'),
      );
    final row = await query.getSingle();
    return row.read(total) ?? 0;
  }

  Stream<int> watchCountForOwner(String ownerId) {
    final total = birds.id.count();
    final query = selectOnly(birds)
      ..addColumns([total])
      ..where(
        birds.ownerId.equals(ownerId) &
            birds.isDeleted.equals(false) &
            birds.status.equals('active'),
      );
    return query.watchSingle().map((row) => row.read(total) ?? 0);
  }

  /// Conteo por sexo para el resumen del dashboard: `{'male': 12, 'female': 8}`.
  Stream<Map<String, int>> watchSexTally(String ownerId) {
    final total = birds.id.count();
    final query = selectOnly(birds)
      ..addColumns([birds.sex, total])
      ..where(birds.ownerId.equals(ownerId) & birds.isDeleted.equals(false))
      ..groupBy([birds.sex]);
    return query.watch().map(
      (rows) => {
        for (final row in rows) (row.read(birds.sex) ?? 'unknown'): (row.read(total) ?? 0),
      },
    );
  }

  Future<void> upsert(BirdsCompanion bird) => into(birds).insertOnConflictUpdate(bird);

  Future<void> upsertAll(List<BirdsCompanion> rows) => batch((batch) {
    batch.insertAllOnConflictUpdate(birds, rows);
  });

  /// Borrado lógico: la fila se conserva para que la sincronización pueda
  /// propagar la baja al resto de dispositivos.
  Future<void> softDelete(String id, DateTime deletedAt) =>
      (update(birds)..where((t) => t.id.equals(id))).write(
        BirdsCompanion(isDeleted: const Value(true), updatedAt: Value(deletedAt)),
      );

  /// Borra los datos locales al cerrar sesión.
  Future<void> clear() => delete(birds).go();
}
