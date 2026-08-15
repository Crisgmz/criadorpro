import 'package:criadorpro/core/db/app_database.dart';
import 'package:criadorpro/core/domain/sex.dart';
import 'package:criadorpro/core/network/supabase_service.dart';
import 'package:criadorpro/features/birds/model/bird.dart';
import 'package:criadorpro/features/birds/repository/birds_repository.dart';
import 'package:criadorpro/features/birds/viewmodel/parent_picker_viewmodel.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

/// Pantalla 18 — `RF-REG-11`. Lo que importa es que nunca ofrezca un candidato
/// del sexo equivocado: `RV-10` se valida después en el repositorio, pero si la
/// lista lo ofrece el criador ya ha perdido el tiempo.
void main() {
  late AppDatabase database;
  late BirdsRepository repository;

  const ownerId = 'owner-1';
  final now = DateTime(2026, 8, 5);

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
    repository = BirdsRepository(
      database: database,
      birdsDao: database.birdsDao,
      profilesDao: database.profilesDao,
      syncQueue: database.syncQueueDao,
      supabase: SupabaseService(null),
      clock: () => now,
    );
  });

  tearDown(() => database.close());

  Future<void> givenBird({
    required String id,
    required Sex sex,
    required int plate,
    String? name,
    BirdStatus status = BirdStatus.active,
  }) => database.birdsDao.upsert(
    BirdsCompanion.insert(
      id: id,
      ownerId: ownerId,
      plate: plate,
      sex: sex.id,
      status: status.id,
      createdAt: now,
      updatedAt: now,
      name: Value(name),
    ),
  );

  ParentPickerViewModel viewModelFor(Sex sex, {String? excludeId}) => ParentPickerViewModel(
    repository: repository,
    ownerId: ownerId,
    sex: sex,
    excludeId: excludeId,
  );

  group('RV-10 · solo candidatos del sexo pedido', () {
    test('elegir padre nunca ofrece hembras', () async {
      await givenBird(id: 'macho', sex: Sex.male, plate: 1);
      await givenBird(id: 'hembra', sex: Sex.female, plate: 2);
      await givenBird(id: 'indefinido', sex: Sex.unknown, plate: 3);

      final viewModel = viewModelFor(Sex.male);
      await viewModel.load();

      expect(viewModel.candidates.map((b) => b.id), ['macho']);
      viewModel.dispose();
    });

    test('un ejemplar no puede aparecer como su propio progenitor', () async {
      await givenBird(id: 'yo', sex: Sex.male, plate: 1);
      await givenBird(id: 'otro', sex: Sex.male, plate: 2);

      final viewModel = viewModelFor(Sex.male, excludeId: 'yo');
      await viewModel.load();

      expect(viewModel.candidates.map((b) => b.id), ['otro']);
      viewModel.dispose();
    });
  });

  group('buscador', () {
    test('busca por placa y por nombre, como en la lista general', () async {
      await givenBird(id: 'a', sex: Sex.male, plate: 40, name: 'Giro Colorado');
      await givenBird(id: 'b', sex: Sex.male, plate: 41, name: 'Cenizo');

      final viewModel = viewModelFor(Sex.male);
      await viewModel.load();

      await viewModel.setSearch('giro');
      expect(viewModel.candidates.map((b) => b.id), ['a']);

      await viewModel.setSearch('41');
      expect(viewModel.candidates.map((b) => b.id), ['b']);

      // Con `#` delante, que es como el criador escribe una placa.
      await viewModel.setSearch('#40');
      expect(viewModel.candidates.map((b) => b.id), ['a']);
      viewModel.dispose();
    });

    test('sin resultados por búsqueda se distingue del criadero vacío', () async {
      await givenBird(id: 'a', sex: Sex.male, plate: 40, name: 'Giro');

      final viewModel = viewModelFor(Sex.male);
      await viewModel.load();
      expect(viewModel.isFilteredEmpty, isFalse);

      await viewModel.setSearch('no existe');
      expect(viewModel.candidates, isEmpty);
      // Es lo que decide si la pantalla ofrece «registrar uno nuevo» o no.
      expect(viewModel.isFilteredEmpty, isTrue);
      viewModel.dispose();
    });

    test('sin ejemplares de ese sexo no cuenta como búsqueda vacía', () async {
      await givenBird(id: 'hembra', sex: Sex.female, plate: 1);

      final viewModel = viewModelFor(Sex.male);
      await viewModel.load();

      expect(viewModel.candidates, isEmpty);
      expect(viewModel.isFilteredEmpty, isFalse);
      viewModel.dispose();
    });
  });

  group('CU-02 alterno A · alta al vuelo', () {
    test('tras crear uno nuevo la lista lo incluye y se limpia la búsqueda', () async {
      final viewModel = viewModelFor(Sex.male);
      await viewModel.load();
      await viewModel.setSearch('Nuevo');
      expect(viewModel.candidates, isEmpty);

      // Lo que haría la pantalla de alta al volver.
      await givenBird(id: 'recien', sex: Sex.male, plate: 50, name: 'Recién');
      await viewModel.refreshAfterCreate();

      expect(viewModel.search, isEmpty);
      expect(viewModel.candidates.map((b) => b.id), ['recien']);
      viewModel.dispose();
    });
  });

  test('los ejemplares dados de baja no se ofrecen como progenitores', () async {
    await givenBird(id: 'vivo', sex: Sex.male, plate: 1);
    await givenBird(id: 'muerto', sex: Sex.male, plate: 2);
    await repository.delete('muerto');

    final viewModel = viewModelFor(Sex.male);
    await viewModel.load();

    expect(viewModel.candidates.map((b) => b.id), ['vivo']);
    viewModel.dispose();
  });
}
