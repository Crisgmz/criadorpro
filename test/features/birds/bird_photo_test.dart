import 'dart:io';

import 'package:criadorpro/core/db/app_database.dart';
import 'package:criadorpro/core/media/photo_service.dart';
import 'package:criadorpro/core/network/supabase_service.dart';
import 'package:criadorpro/features/birds/repository/birds_repository.dart';
import 'package:criadorpro/features/birds/viewmodel/bird_form_viewmodel.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

/// `RF-REG-15` — foto por ejemplar. El servicio real abre la cámara, así que
/// aquí se sustituye por un doble: lo que se prueba es qué hace el formulario
/// con la ruta que recibe, que es donde están las decisiones.
class _FakePhotoService implements PhotoService {
  _FakePhotoService(this.directory);

  final Directory directory;

  /// Rutas que devolverá `capture`, en orden. `null` simula que el criador
  /// canceló.
  final List<String?> results = [];
  final List<String> deleted = [];
  int captureCalls = 0;
  PhotoSource? lastSource;

  String givenPhoto(String name) {
    final file = File('${directory.path}/$name')..writeAsBytesSync([1, 2, 3]);
    return file.path;
  }

  @override
  Future<String?> capture(PhotoSource source) async {
    captureCalls++;
    lastSource = source;
    return results.isEmpty ? null : results.removeAt(0);
  }

  @override
  Future<void> deleteFile(String? path) async {
    if (path != null) deleted.add(path);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late AppDatabase database;
  late BirdsRepository repository;
  late _FakePhotoService photos;
  late Directory temp;

  const ownerId = 'owner-1';
  final now = DateTime(2026, 8, 5);

  setUp(() {
    temp = Directory.systemTemp.createTempSync('criadorpro_photos');
    database = AppDatabase(NativeDatabase.memory());
    repository = BirdsRepository(
      database: database,
      birdsDao: database.birdsDao,
      profilesDao: database.profilesDao,
      syncQueue: database.syncQueueDao,
      supabase: SupabaseService(null),
      clock: () => now,
    );
    photos = _FakePhotoService(temp);
  });

  tearDown(() async {
    await database.close();
    if (temp.existsSync()) temp.deleteSync(recursive: true);
  });

  BirdFormViewModel viewModelFor({String? birdId}) => BirdFormViewModel(
    repository: repository,
    photoService: photos,
    ownerId: ownerId,
    birdId: birdId,
  );

  group('RF-REG-15 · captura', () {
    test('la foto tomada queda en el borrador', () async {
      final path = photos.givenPhoto('a.jpg');
      photos.results.add(path);
      final viewModel = viewModelFor();
      await viewModel.load();

      await viewModel.capturePhoto(PhotoSource.camera);

      expect(viewModel.photoPath, path);
      expect(photos.lastSource, PhotoSource.camera);
      viewModel.dispose();
    });

    test('cancelar no cambia la foto que ya había', () async {
      final first = photos.givenPhoto('a.jpg');
      photos.results.add(first);
      final viewModel = viewModelFor();
      await viewModel.load();
      await viewModel.capturePhoto(PhotoSource.gallery);

      // La segunda captura se cancela.
      await viewModel.capturePhoto(PhotoSource.gallery);

      expect(viewModel.photoPath, first);
      expect(photos.deleted, isEmpty);
      viewModel.dispose();
    });

    test('sustituir una foto borra el archivo anterior', () async {
      final first = photos.givenPhoto('a.jpg');
      final second = photos.givenPhoto('b.jpg');
      photos.results.addAll([first, second]);
      final viewModel = viewModelFor();
      await viewModel.load();

      await viewModel.capturePhoto(PhotoSource.camera);
      await viewModel.capturePhoto(PhotoSource.camera);

      expect(viewModel.photoPath, second);
      // Sin esto, cada cambio de foto dejaría basura en el dispositivo.
      expect(photos.deleted, [first]);
      viewModel.dispose();
    });

    test('el indicador de ocupado se levanta y se baja', () async {
      photos.results.add(photos.givenPhoto('a.jpg'));
      final viewModel = viewModelFor();
      await viewModel.load();

      expect(viewModel.isCapturingPhoto, isFalse);
      final pending = viewModel.capturePhoto(PhotoSource.camera);
      expect(viewModel.isCapturingPhoto, isTrue);
      await pending;
      expect(viewModel.isCapturingPhoto, isFalse);
      viewModel.dispose();
    });
  });

  group('persistencia', () {
    test('la ruta se guarda con el ejemplar', () async {
      photos.results.add(photos.givenPhoto('a.jpg'));
      final viewModel = viewModelFor();
      await viewModel.load();
      viewModel.setPlate('7');
      await viewModel.capturePhoto(PhotoSource.camera);

      final saved = await viewModel.submit();

      expect(saved, isNotNull);
      expect(saved!.photoPath, viewModel.photoPath);

      final row = await database.birdsDao.findById(saved.id);
      expect(row!.photoPath, isNotNull);
      viewModel.dispose();
    });

    test('la foto no viaja en el payload de sincronización', () async {
      photos.results.add(photos.givenPhoto('a.jpg'));
      final viewModel = viewModelFor();
      await viewModel.load();
      viewModel.setPlate('7');
      await viewModel.capturePhoto(PhotoSource.camera);
      final saved = (await viewModel.submit())!;

      // `photo_path` es local: la ruta de este dispositivo no significa nada en
      // otro, y el binario sube por su cuenta a Storage.
      expect(saved.toRemoteJson().containsKey('photo_path'), isFalse);
      expect(saved.toRemoteJson()['photo_url'], isNull);
      viewModel.dispose();
    });

    test('editar un ejemplar recupera su foto', () async {
      photos.results.add(photos.givenPhoto('a.jpg'));
      final creator = viewModelFor();
      await creator.load();
      creator.setPlate('7');
      await creator.capturePhoto(PhotoSource.camera);
      final saved = (await creator.submit())!;
      creator.dispose();

      final editor = viewModelFor(birdId: saved.id);
      await editor.load();

      expect(editor.photoPath, saved.photoPath);
      editor.dispose();
    });

    test('quitar la foto la borra del ejemplar al guardar', () async {
      photos.results.add(photos.givenPhoto('a.jpg'));
      final viewModel = viewModelFor();
      await viewModel.load();
      viewModel.setPlate('7');
      await viewModel.capturePhoto(PhotoSource.camera);
      await viewModel.submit();

      viewModel.removePhoto();
      final updated = await viewModel.submit();

      expect(viewModel.photoPath, isNull);
      expect(updated!.photoPath, isNull);
      viewModel.dispose();
    });
  });

  test('RV-19 · los topes son los del SRS', () {
    expect(PhotoService.maxSide, 1600);
    expect(PhotoService.maxBytes, 2 * 1024 * 1024);
  });
}
