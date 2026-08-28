import 'dart:convert';

import 'package:criadorpro/core/db/app_database.dart';
import 'package:criadorpro/core/domain/sex.dart';
import 'package:criadorpro/core/export/backup_service.dart';
import 'package:criadorpro/features/birds/model/bird.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

/// «Descargar mis datos» — pantalla 25.
///
/// Es lo último que el criador puede hacer antes de un borrado irreversible, y
/// lo que se lleva es todo lo que tendrá. Lo que se prueba aquí es que no se
/// deje nada suyo fuera **ni se lleve nada de otro**.
void main() {
  late AppDatabase database;
  late _CapturedBackup target;
  late BackupService service;

  const ownerId = 'owner-1';
  const otherId = 'owner-2';
  final now = DateTime.utc(2026, 8, 27, 12);

  setUp(() async {
    database = AppDatabase(NativeDatabase.memory());
    target = _CapturedBackup();
    service = BackupService(database: database, target: target);

    for (final owner in [ownerId, otherId]) {
      await database.profilesDao.upsert(
        ProfilesCompanion.insert(
          id: owner,
          farmName: Value('Criadero de $owner'),
          createdAt: now,
          updatedAt: now,
        ),
      );
    }
  });

  tearDown(() => database.close());

  Future<void> givenBird({required String owner, required int plate, String? photoPath}) =>
      database.birdsDao.upsert(
        BirdsCompanion.insert(
          id: 'b-$owner-$plate',
          ownerId: owner,
          plate: plate,
          sex: Sex.male.id,
          status: BirdStatus.active.id,
          photoPath: Value(photoPath),
          createdAt: now,
          updatedAt: now,
        ),
      );

  Future<Map<String, dynamic>> exported() async {
    await service.export(ownerId: ownerId, now: now);
    return jsonDecode(utf8.decode(target.bytes!)) as Map<String, dynamic>;
  }

  test('lleva los registros del criador', () async {
    await givenBird(owner: ownerId, plate: 1);
    await givenBird(owner: ownerId, plate: 2);

    final backup = await exported();
    final birds = (backup['tables'] as Map)['birds'] as List;

    expect(birds, hasLength(2));
    expect(backup['records'], 3, reason: 'dos ejemplares y el perfil');
  });

  test('**no** lleva los de otro criadero', () async {
    await givenBird(owner: ownerId, plate: 1);
    await givenBird(owner: otherId, plate: 1);

    final backup = await exported();
    final birds = (backup['tables'] as Map)['birds'] as List;

    expect(birds, hasLength(1));
    expect((birds.single as Map)['owner_id'], ownerId);

    // El perfil filtra por `id`, no por `owner_id`: si esa rama estuviera mal,
    // el respaldo se llevaría el nombre del criadero ajeno.
    final profiles = (backup['tables'] as Map)['profiles'] as List;
    expect(profiles, hasLength(1));
    expect((profiles.single as Map)['id'], ownerId);
  });

  test('no lleva la cola de sincronización', () async {
    await givenBird(owner: ownerId, plate: 1);

    final backup = await exported();

    // Es fontanería de la app: no significa nada fuera de este teléfono, y
    // llevarla solo confundiría a quien abra el archivo.
    expect((backup['tables'] as Map).containsKey('sync_queue_entries'), isFalse);
  });

  test('no lleva rutas locales', () async {
    await givenBird(owner: ownerId, plate: 1, photoPath: '/data/user/0/foto.jpg');

    final backup = await exported();
    final bird = ((backup['tables'] as Map)['birds'] as List).single as Map;

    // Apunta a este teléfono: en el respaldo es ruido que confunde.
    expect(bird.containsKey('photo_path'), isFalse);
    expect(bird.containsKey('is_dirty'), isFalse);
  });

  test('el archivo dice qué es y cuándo se hizo', () async {
    await givenBird(owner: ownerId, plate: 1);
    await exported();

    final backup = jsonDecode(utf8.decode(target.bytes!)) as Map<String, dynamic>;
    // Dentro del archivo, no solo en el nombre: dentro de dos años hay que
    // poder saber qué se está leyendo aunque alguien lo renombrara.
    expect(backup['format'], BackupService.formatVersion);
    expect(backup['exportedAt'], now.toIso8601String());
    expect(target.fileName, 'criadorpro-respaldo-20260827.json');
  });

  test('un criadero sin nada se exporta igual', () async {
    // Aunque solo tenga el perfil: fallar aquí dejaría sin respaldo justo a
    // quien más fácil lo tiene para irse.
    final backup = await exported();
    expect(backup['records'], 1);
  });
}

/// Captura el respaldo en vez de abrir la hoja de compartir, que dejaría la
/// prueba esperando a un humano.
class _CapturedBackup implements BackupTarget {
  List<int>? bytes;
  String? fileName;

  @override
  Future<void> share({required List<int> bytes, required String fileName}) async {
    this.bytes = bytes;
    this.fileName = fileName;
  }
}
