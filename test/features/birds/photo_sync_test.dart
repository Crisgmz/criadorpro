import 'package:criadorpro/core/db/app_database.dart';
import 'package:criadorpro/core/db/daos/birds_dao.dart';
import 'package:criadorpro/core/domain/sex.dart';
import 'package:criadorpro/core/media/photo_service.dart';
import 'package:criadorpro/core/media/photo_sync.dart';
import 'package:criadorpro/core/network/supabase_service.dart';
import 'package:criadorpro/core/utils/result.dart';
import 'package:criadorpro/features/birds/model/bird.dart';
import 'package:criadorpro/features/birds/repository/birds_repository.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

/// `RF-REG-15` — la foto sale del teléfono.
///
/// Lo que se prueba aquí es el estado del que se deduce el trabajo pendiente:
/// si «qué falta por subir» se calcula mal, la foto se queda en el dispositivo
/// y **nada falla a la vista** — que es el peor modo de fallo posible.
void main() {
  late AppDatabase database;
  late BirdsDao dao;
  late BirdsRepository repository;

  const ownerId = 'owner-1';
  final now = DateTime(2026, 8, 26);

  setUp(() async {
    database = AppDatabase(NativeDatabase.memory());
    dao = database.birdsDao;
    repository = BirdsRepository(
      database: database,
      birdsDao: dao,
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

  Future<Bird> givenBird({String? photoPath, String? photoUrl, int plate = 1}) async {
    final result = await repository.save(
      Bird(
        id: '',
        ownerId: ownerId,
        plate: plate,
        sex: Sex.male,
        status: BirdStatus.active,
        photoPath: photoPath,
        photoUrl: photoUrl,
        createdAt: now,
        updatedAt: now,
      ),
    );
    return (result as Ok<Bird>).value;
  }

  group('qué está pendiente', () {
    test('con foto local y sin URL está por subir', () async {
      await givenBird(photoPath: '/tmp/foto.jpg');

      expect(await dao.photosPendingUpload(ownerId), hasLength(1));
      expect(await dao.photosPendingDownload(ownerId), isEmpty);
    });

    test('con URL y sin foto local está por bajar — el dispositivo nuevo', () async {
      await givenBird(photoUrl: '$ownerId/b1.jpg');

      expect(await dao.photosPendingDownload(ownerId), hasLength(1));
      expect(await dao.photosPendingUpload(ownerId), isEmpty);
    });

    test('con las dos cosas no hay nada que hacer', () async {
      await givenBird(photoPath: '/tmp/foto.jpg', photoUrl: '$ownerId/b1.jpg');

      expect(await dao.photosPendingUpload(ownerId), isEmpty);
      expect(await dao.photosPendingDownload(ownerId), isEmpty);
    });

    test('un ejemplar dado de baja no arrastra su foto', () async {
      final bird = await givenBird(photoPath: '/tmp/foto.jpg');
      await repository.delete(bird.id);

      expect(await dao.photosPendingUpload(ownerId), isEmpty);
    });
  });

  group('cambiar la foto', () {
    test('sustituirla suelta la URL para que se vuelva a subir', () async {
      final bird = await givenBird(photoPath: '/tmp/vieja.jpg', photoUrl: '$ownerId/b1.jpg');

      await repository.save(bird.copyWith(photoPath: () => '/tmp/nueva.jpg'));

      final stored = await dao.findById(bird.id);
      expect(
        stored!.photoUrl,
        isNull,
        reason: 'con la URL vieja puesta, los demás dispositivos se quedan con la foto anterior',
      );
      expect(await dao.photosPendingUpload(ownerId), hasLength(1));
    });

    test('quitarla también suelta la URL, y no se vuelve a bajar', () async {
      final bird = await givenBird(photoPath: '/tmp/foto.jpg', photoUrl: '$ownerId/b1.jpg');

      await repository.save(bird.copyWith(photoPath: () => null));

      expect((await dao.findById(bird.id))!.photoUrl, isNull);
      expect(await dao.photosPendingDownload(ownerId), isEmpty);
    });

    test('guardar sin tocar la foto conserva su URL', () async {
      final bird = await givenBird(photoPath: '/tmp/foto.jpg', photoUrl: '$ownerId/b1.jpg');

      await repository.save(bird.copyWith(name: () => 'Giro'));

      expect((await dao.findById(bird.id))!.photoUrl, '$ownerId/b1.jpg');
    });
  });

  group('anotar la subida', () {
    test('escribe la URL y encola el cambio', () async {
      final bird = await givenBird(photoPath: '/tmp/foto.jpg');
      await database.syncQueueDao.clear();

      await repository.setPhotoUrl(id: bird.id, objectPath: '$ownerId/${bird.id}.jpg');

      expect((await dao.findById(bird.id))!.photoUrl, '$ownerId/${bird.id}.jpg');

      // Sin encolar, la foto se vería en este teléfono y en ninguno más.
      final pending = await database.syncQueueDao.pending(maxAttempts: 5);
      expect(pending.map((task) => task.entityId), contains(bird.id));
    });

    test('no mueve `updated_at`', () async {
      final bird = await givenBird(photoPath: '/tmp/foto.jpg');

      await repository.setPhotoUrl(id: bird.id, objectPath: '$ownerId/${bird.id}.jpg');

      // `RS-09` resuelve conflictos por el `updated_at` más reciente. Si subir
      // una foto lo moviera, esta fila ganaría contra una edición real hecha
      // en otro dispositivo mientras tanto, y se perdería lo que el criador
      // escribió allí.
      expect((await dao.findById(bird.id))!.updatedAt, bird.updatedAt);
    });

    test('un ejemplar que ya no existe no revienta', () async {
      await repository.setPhotoUrl(id: 'no-existe', objectPath: 'x/y.jpg');
    });
  });

  test('la ruta en Storage es determinista: volver a subir sustituye', () {
    expect(
      PhotoSyncService.objectPath(ownerId: 'o1', id: 'b1'),
      PhotoSyncService.objectPath(ownerId: 'o1', id: 'b1'),
    );
    // El propietario va primero: es lo que compara la política de Storage.
    expect(PhotoSyncService.objectPath(ownerId: 'o1', id: 'b1'), startsWith('o1/'));
  });

  test('sin backend configurado no intenta nada', () async {
    final service = PhotoSyncService(
      photos: PhotoService(),
      supabase: SupabaseService(null),
      subjects: [repository],
    );

    await givenBird(photoPath: '/tmp/foto.jpg');
    // No debe lanzar: en modo solo local la app funciona entera.
    await service.sync(ownerId);
  });
}
