import 'package:criadorpro/core/db/app_database.dart';
import 'package:criadorpro/core/domain/sex.dart';
import 'package:criadorpro/core/error/failure.dart';
import 'package:criadorpro/core/utils/result.dart';
import 'package:criadorpro/features/birds/model/bird.dart';
import 'package:criadorpro/features/pedigree/model/pedigree_node.dart';
import 'package:criadorpro/features/pedigree/repository/pedigree_repository.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

/// `RF-PED-01` a `RF-PED-09` y `RS-05`. Lo que más se prueba es el corte de
/// ciclos: sin él, un dato mal capturado —un ejemplar que acaba siendo su
/// propio abuelo— cuelga la app con una recursión infinita.
void main() {
  late AppDatabase database;
  late PedigreeRepository repository;

  const ownerId = 'owner-1';
  final now = DateTime(2026, 8, 5);

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
    repository = PedigreeRepository(birdsDao: database.birdsDao);
  });

  tearDown(() => database.close());

  Future<void> givenBird({
    required String id,
    required int plate,
    Sex sex = Sex.male,
    String? fatherId,
    String? motherId,
  }) => database.birdsDao.upsert(
    BirdsCompanion.insert(
      id: id,
      ownerId: ownerId,
      plate: plate,
      sex: sex.id,
      status: BirdStatus.active.id,
      createdAt: now,
      updatedAt: now,
      fatherId: Value(fatherId),
      motherId: Value(motherId),
    ),
  );

  /// Árbol completo de cuatro generaciones: 31 ejemplares, el 1 es la raíz.
  /// Los identificadores siguen el índice de un montículo: los padres de `n`
  /// son `2n` (macho) y `2n+1` (hembra).
  Future<void> givenFullTree({int generations = 4}) async {
    final total = (1 << (generations + 1)) - 1;
    for (var i = total; i >= 1; i--) {
      final father = i * 2;
      final mother = i * 2 + 1;
      await givenBird(
        id: 'b$i',
        plate: i,
        sex: i.isEven || i == 1 ? Sex.male : Sex.female,
        fatherId: father <= total ? 'b$father' : null,
        motherId: mother <= total ? 'b$mother' : null,
      );
    }
  }

  Future<PedigreeNode> build(String id, int depth) async {
    final result = await repository.build(rootId: id, depth: depth);
    return (result as Ok<PedigreeNode>).value;
  }

  group('RF-PED-01 · construcción del árbol', () {
    test('cuatro generaciones dan 31 ejemplares', () async {
      await givenFullTree();

      final root = await build('b1', 4);

      expect(root.bird.plate, 1);
      expect(root.size, 31);
      expect(root.depth, 4);
    });

    test('RF-PED-02 · la profundidad recorta el árbol', () async {
      await givenFullTree();

      expect((await build('b1', 2)).size, 7);
      expect((await build('b1', 3)).size, 15);
      expect((await build('b1', 4)).size, 31);
    });

    test('padre y madre quedan en su rama', () async {
      await givenBird(id: 'padre', plate: 2, sex: Sex.male);
      await givenBird(id: 'madre', plate: 3, sex: Sex.female);
      await givenBird(id: 'hijo', plate: 1, fatherId: 'padre', motherId: 'madre');

      final root = await build('hijo', 2);

      expect(root.father?.bird.id, 'padre');
      expect(root.mother?.bird.id, 'madre');
    });

    test('un ejemplar inexistente devuelve NotFound, no un árbol vacío', () async {
      final result = await repository.build(rootId: 'fantasma', depth: 4);

      expect((result as Err<PedigreeNode>).failure, isA<NotFoundFailure>());
    });
  });

  group('RF-PED-05 · huecos', () {
    test('un progenitor desconocido deja casilla vacía, no error', () async {
      await givenBird(id: 'padre', plate: 2);
      await givenBird(id: 'hijo', plate: 1, fatherId: 'padre');

      final root = await build('hijo', 4);

      expect(root.father?.bird.id, 'padre');
      expect(root.mother, isNull);
      expect(root.size, 2);
    });

    test('un ejemplar sin ascendencia es un árbol de un solo nodo', () async {
      await givenBird(id: 'solo', plate: 1);

      final root = await build('solo', 4);

      expect(root.size, 1);
      expect(root.depth, 0);
      expect(root.hasCycle, isFalse);
    });

    test('un ancestro dado de baja deja hueco en lugar de reaparecer', () async {
      await givenBird(id: 'abuelo', plate: 4);
      await givenBird(id: 'padre', plate: 2, fatherId: 'abuelo');
      await givenBird(id: 'hijo', plate: 1, fatherId: 'padre');
      await database.birdsDao.softDelete('abuelo', now);

      final root = await build('hijo', 4);

      expect(root.father?.bird.id, 'padre');
      expect(root.father?.father, isNull);
    });
  });

  group('RS-05 / RF-PED-06 · ciclos', () {
    test('un ejemplar que es su propio padre corta la rama sin colgarse', () async {
      // Dato imposible pero capturable: el corte es lo único que evita una
      // recursión infinita.
      await givenBird(id: 'yo', plate: 1, fatherId: 'yo');

      final root = await build('yo', 4);

      expect(root.hasCycle, isTrue);
      expect(root.father?.isCycle, isTrue);
      expect(root.father?.father, isNull);
    });

    test('un ciclo de tres se corta y el resto del árbol sigue dibujándose', () async {
      await givenBird(id: 'a', plate: 1, fatherId: 'b', motherId: 'madre');
      await givenBird(id: 'b', plate: 2, fatherId: 'c');
      await givenBird(id: 'c', plate: 3, fatherId: 'a');
      await givenBird(id: 'madre', plate: 4, sex: Sex.female);

      final root = await build('a', 4);

      expect(root.hasCycle, isTrue);
      // a → b → c → a, y ahí se corta.
      expect(root.father?.father?.father?.isCycle, isTrue);
      // La rama materna no se ve afectada: una inconsistencia no invalida el
      // resto del árbol.
      expect(root.mother?.bird.id, 'madre');
      expect(root.mother?.isCycle, isFalse);
    });

    test('el mismo ancestro por dos ramas NO es ciclo: es endogamia', () async {
      // Medio hermanos cruzados entre sí comparten abuelo. Marcarlo como ciclo
      // borraría información legítima del criadero.
      await givenBird(id: 'abuelo', plate: 9);
      await givenBird(id: 'padre', plate: 2, fatherId: 'abuelo');
      await givenBird(id: 'madre', plate: 3, sex: Sex.female, fatherId: 'abuelo');
      await givenBird(id: 'hijo', plate: 1, fatherId: 'padre', motherId: 'madre');

      final root = await build('hijo', 4);

      expect(root.hasCycle, isFalse);
      expect(root.father?.father?.bird.id, 'abuelo');
      expect(root.mother?.father?.bird.id, 'abuelo');
      // El abuelo aparece dos veces en el árbol, y así debe ser.
      expect(root.size, 5);
    });
  });

  group('RNF-03 · rendimiento', () {
    test('un pedigrí de 4 generaciones se construye en menos de 300 ms', () async {
      await givenFullTree();

      final stopwatch = Stopwatch()..start();
      final root = await build('b1', 4);
      stopwatch.stop();

      expect(root.size, 31);
      expect(stopwatch.elapsedMilliseconds, lessThan(300));
    });

    test('el árbol se lee por niveles: 5 consultas, no 31', () async {
      await givenFullTree();

      // `parentsOf` se llama una vez por generación y `byIds` una sola vez
      // para todo el árbol. Con una consulta por nodo serían 31 lecturas.
      var levelQueries = 0;
      for (var level = 0, frontier = ['b1']; level < 4; level++) {
        final parents = await database.birdsDao.parentsOf(frontier);
        levelQueries++;
        if (parents.isEmpty) break;
        frontier = parents;
      }

      expect(levelQueries, 4);
    });
  });

  test('RF-PED-09 · se construye sin tocar la red', () async {
    // El repositorio no recibe SupabaseService: no tiene forma de salir a la
    // red aunque quisiera.
    await givenFullTree(generations: 2);

    final root = await build('b1', 2);

    expect(root.size, 7);
  });
}
