import 'package:criadorpro/core/config/app_config.dart';
import 'package:criadorpro/core/db/app_database.dart';
import 'package:criadorpro/core/media/photo_sync.dart';
import 'package:criadorpro/core/network/supabase_service.dart';
import 'package:criadorpro/core/utils/result.dart';
import 'package:criadorpro/features/accounting/repository/transactions_repository.dart';
import 'package:criadorpro/features/payroll/model/employee.dart';
import 'package:criadorpro/features/payroll/repository/payroll_repository.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

/// La foto del personal (pantalla 30).
///
/// Recorre el mismo camino que la del ejemplar, por la misma interfaz. Lo que
/// se prueba aquí es que el estado del que se deduce el trabajo pendiente se
/// calcule bien: si se calcula mal, la foto se queda en el teléfono y **nada
/// falla a la vista**, que es el peor modo de fallo posible.
void main() {
  late AppDatabase database;
  late PayrollRepository repository;

  const ownerId = 'owner-1';
  final now = DateTime(2026, 8, 27);

  setUp(() async {
    database = AppDatabase(NativeDatabase.memory());
    repository = PayrollRepository(
      database: database,
      payrollDao: database.payrollDao,
      profilesDao: database.profilesDao,
      syncQueue: database.syncQueueDao,
      supabase: SupabaseService(null),
      expenses: TransactionsRepository(
        database: database,
        transactionsDao: database.transactionsDao,
        profilesDao: database.profilesDao,
        syncQueue: database.syncQueueDao,
        supabase: SupabaseService(null),
        clock: () => now,
      ),
      clock: () => now,
    );

    await database.profilesDao.upsert(
      ProfilesCompanion.insert(
        id: ownerId,
        createdAt: now,
        updatedAt: now,
        plan: const Value('elite'),
      ),
    );
  });

  tearDown(() => database.close());

  Future<Employee> givenEmployee({String? photoPath, String? photoUrl}) async {
    final result = await repository.saveEmployee(
      Employee(
        id: '',
        ownerId: ownerId,
        name: 'Juan Pérez',
        salaryCents: 800000,
        frequency: PayFrequency.biweekly,
        photoPath: photoPath,
        photoUrl: photoUrl,
        createdAt: now,
        updatedAt: now,
      ),
    );
    return (result as Ok<Employee>).value;
  }

  test('con foto local y sin URL está por subir', () async {
    await givenEmployee(photoPath: '/tmp/juan.jpg');

    expect(await repository.pendingUploads(ownerId), hasLength(1));
    expect(await repository.pendingDownloads(ownerId), isEmpty);
  });

  test('con URL y sin foto local está por bajar — el dispositivo nuevo', () async {
    await givenEmployee(photoUrl: '$ownerId/e1.jpg');

    expect(await repository.pendingDownloads(ownerId), hasLength(1));
    expect(await repository.pendingUploads(ownerId), isEmpty);
  });

  test('un empleado dado de baja no arrastra su foto', () async {
    final employee = await givenEmployee(photoPath: '/tmp/juan.jpg');
    await repository.deleteEmployee(employee.id);

    expect(await repository.pendingUploads(ownerId), isEmpty);
  });

  test('anotar la subida encola el cambio y no mueve `updated_at`', () async {
    final employee = await givenEmployee(photoPath: '/tmp/juan.jpg');
    await database.syncQueueDao.clear();

    await repository.setPhotoUrl(id: employee.id, objectPath: '$ownerId/${employee.id}.jpg');

    final stored = await database.payrollDao.findEmployee(employee.id);
    expect(stored!.photoUrl, '$ownerId/${employee.id}.jpg');

    // Sin encolar, la foto se vería en este teléfono y en ninguno más.
    final pending = await database.syncQueueDao.pending(maxAttempts: AppConfig.maxSyncAttempts);
    expect(pending.map((task) => task.entityId), contains(employee.id));

    // `RS-09` resuelve por el `updated_at` más reciente: si subir una foto lo
    // moviera, esta fila ganaría contra una edición real hecha en otro
    // dispositivo mientras tanto.
    expect(stored.updatedAt, employee.updatedAt);
  });

  test('dar de baja conserva la foto y la fecha de entrada', () async {
    // `setActive` reconstruye el empleado entero: si olvidara un campo, darlo
    // de baja lo borraría sin que nada fallara.
    final employee = await repository.saveEmployee(
      Employee(
        id: '',
        ownerId: ownerId,
        name: 'Juan Pérez',
        salaryCents: 800000,
        frequency: PayFrequency.biweekly,
        photoPath: '/tmp/juan.jpg',
        startDate: DateTime(2026, 3),
        createdAt: now,
        updatedAt: now,
      ),
    );
    final id = (employee as Ok<Employee>).value.id;

    await repository.setActive(id, isActive: false);

    final stored = Employee.fromRow((await database.payrollDao.findEmployee(id))!);
    expect(stored.photoPath, '/tmp/juan.jpg');
    expect(stored.startDate, DateTime(2026, 3));
  });

  test('los dos tipos de foto van a buckets distintos', () {
    // Separados y no una carpeta dentro: la foto de una persona no es la de un
    // ave, y así se pueden borrar unas sin tocar las otras.
    expect(PhotoSyncService.employeeBucket, isNot(PhotoSyncService.birdBucket));
    expect(repository.bucket, PhotoSyncService.employeeBucket);
  });
}
