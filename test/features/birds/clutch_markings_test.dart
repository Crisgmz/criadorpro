import 'package:criadorpro/core/db/app_database.dart';
import 'package:criadorpro/core/domain/markings.dart';
import 'package:criadorpro/core/network/supabase_service.dart';
import 'package:criadorpro/core/utils/result.dart';
import 'package:criadorpro/features/birds/model/clutch.dart';
import 'package:criadorpro/features/birds/repository/clutches_repository.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

/// Los campos que el diseño pide en el registro de cruce (pantalla 11).
///
/// Se prueba que **lleguen a la base**, no que el formulario los pinte: ya pasó
/// una vez que el repositorio construía la fila campo a campo y los descartaba
/// en silencio. Un dato capturado que no se guarda es peor que no pedirlo.
void main() {
  late AppDatabase database;
  late ClutchesRepository repository;

  const ownerId = 'owner-1';
  final now = DateTime(2026, 8, 27);

  setUp(() async {
    database = AppDatabase(NativeDatabase.memory());
    repository = ClutchesRepository(
      database: database,
      clutchesDao: database.clutchesDao,
      birdsDao: database.birdsDao,
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

  Future<ClutchRegistration> register({
    int hatched = 3,
    CrossStatus crossStatus = CrossStatus.done,
    String? birthMark,
    String? wingLeft,
    String? wingRight,
  }) async {
    final result = await repository.register(
      ownerId: ownerId,
      date: now,
      hatched: hatched,
      crossStatus: crossStatus,
      birthMark: birthMark,
      wingBandLeft: wingLeft,
      wingBandRight: wingRight,
    );
    return (result as Ok<ClutchRegistration>).value;
  }

  test('el estado del cruce se guarda', () async {
    final registration = await register(crossStatus: CrossStatus.test);

    final stored = await database.clutchesDao.findById(registration.clutch.id);
    expect(Clutch.fromRow(stored!).crossStatus, CrossStatus.test);
  });

  test('por omisión el cruce está hecho', () async {
    final registration = await register();
    expect(registration.clutch.crossStatus, CrossStatus.done);
  });

  test('la marca y las cintas se guardan en la camada', () async {
    final registration = await register(
      birthMark: '1,4',
      wingLeft: WingBand.red.id,
      wingRight: WingBand.blue.id,
    );

    final stored = Clutch.fromRow((await database.clutchesDao.findById(registration.clutch.id))!);
    expect(stored.birthMark, '1,4');
    expect(stored.wingBandLeft, WingBand.red.id);
    expect(stored.wingBandRight, WingBand.blue.id);
  });

  test('y **cada cría nace con ellas**', () async {
    // Es el punto de la pantalla: capturarlas una vez en lugar de quince. Si
    // se guardaran solo en la camada, la ficha de cada cría saldría en blanco
    // y el criador tendría que volver a marcarlas una por una.
    final registration = await register(
      hatched: 5,
      birthMark: '1,4',
      wingLeft: WingBand.red.id,
      wingRight: WingBand.blue.id,
    );

    expect(registration.chicks, hasLength(5));
    for (final chick in registration.chicks) {
      expect(chick.birthMark, '1,4');
      expect(chick.wingBandLeft, WingBand.red.id);
      expect(chick.wingBandRight, WingBand.blue.id);
    }
  });

  test('sin marcar, las crías nacen sin marca — no con una inventada', () async {
    final registration = await register(hatched: 2);

    for (final chick in registration.chicks) {
      expect(chick.birthMark, isNull);
      expect(chick.wingBandLeft, isNull);
    }
  });

  test('las notas de objetivo se guardan', () async {
    final result = await repository.register(
      ownerId: ownerId,
      date: now,
      hatched: 2,
      notes: 'Buscando más peso en la línea',
    );

    final registration = (result as Ok<ClutchRegistration>).value;
    expect(registration.clutch.notes, 'Buscando más peso en la línea');
  });
}
