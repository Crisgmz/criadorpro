import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show FileOptions;

import '../db/daos/birds_dao.dart';
import '../network/supabase_service.dart';
import '../sync/sync_service.dart';
import 'photo_service.dart';

/// Sube y baja las fotos de los ejemplares — `RF-REG-15`.
///
/// Va **fuera de la cola de datos** a propósito (§5 del proyecto): la cola es
/// FIFO estricta, y una foto de dos megas por una red de galpón bloquearía
/// detrás de sí el alta de un ejemplar que pesa dos kilobytes. Aquí los datos
/// viajan primero y las fotos después, en su propio recorrido.
///
/// No necesita cola propia: el trabajo pendiente **se deduce del estado**. Una
/// foto con ruta local y sin URL está por subir; una con URL y sin ruta, por
/// bajar. Así no hay nada que pueda desincronizarse entre la cola y los datos,
/// y reintentar es simplemente volver a pasar.
class PhotoSyncService implements MediaSyncer {
  PhotoSyncService({
    required BirdsDao birdsDao,
    required PhotoService photos,
    required SupabaseService supabase,
    required PhotoUrlSink birds,
  }) : _birdsDao = birdsDao,
       _photos = photos,
       _supabase = supabase,
       _birds = birds;

  final BirdsDao _birdsDao;
  final PhotoService _photos;
  final SupabaseService _supabase;
  final PhotoUrlSink _birds;

  /// Bucket privado. Se crea con la migración `20260827000000_bird_photos.sql`.
  static const String bucket = 'bird-photos';

  /// Cuántas fotos se mueven por ciclo.
  ///
  /// Bajo a propósito: el ciclo se repite cada cinco minutos y al recuperar
  /// conexión, así que un criadero que acaba de fotografiar cincuenta aves las
  /// sube en varias pasadas en vez de ocupar la red entera de una vez.
  static const int batchSize = 10;

  /// Ruta determinista dentro del bucket: `{owner}/{bird}.jpg`.
  ///
  /// Que sea determinista es lo que hace que volver a subir **sustituya** en
  /// lugar de acumular. Con nombres aleatorios, cambiar la foto de un ejemplar
  /// cinco veces dejaría cuatro huérfanas que nadie borraría nunca.
  ///
  /// El primer segmento es el propietario porque la política de Storage lo
  /// exige: es lo que impide que un criadero lea las fotos de otro.
  static String objectPath({required String ownerId, required String birdId}) =>
      '$ownerId/$birdId.jpg';

  @override
  Future<void> sync(String ownerId) async {
    if (!_supabase.isEnabled) return;

    await _uploadPending(ownerId);
    await _downloadMissing(ownerId);
  }

  Future<void> _uploadPending(String ownerId) async {
    final pending = await _birdsDao.photosPendingUpload(ownerId);

    for (final row in pending.take(batchSize)) {
      final path = row.photoPath;
      if (path == null) continue;

      final file = File(path);
      // El archivo se perdió —el sistema limpió la caché, o se restauró una
      // copia sin los documentos—. La ruta ya no sirve para nada: se suelta
      // para que la fila deje de aparecer en cada ciclo.
      if (!file.existsSync()) {
        await _birdsDao.setPhotoPath(row.id, null);
        continue;
      }

      try {
        final object = objectPath(ownerId: ownerId, birdId: row.id);
        await _supabase.client.storage
            .from(bucket)
            .upload(object, file, fileOptions: const FileOptions(upsert: true));

        // La URL sí viaja: la escribe el repositorio para que la fila quede
        // sucia y el siguiente ciclo la propague a los demás dispositivos.
        await _birds.setPhotoUrl(birdId: row.id, objectPath: object);
      } catch (error, stackTrace) {
        // Una foto que falla no puede detener a las demás ni al resto de la
        // sincronización. El estado no cambia, así que el próximo ciclo
        // reintenta sin necesidad de contadores.
        debugPrint('Foto de ${row.id} no subió: $error\n$stackTrace');
      }
    }
  }

  Future<void> _downloadMissing(String ownerId) async {
    final pending = await _birdsDao.photosPendingDownload(ownerId);

    for (final row in pending.take(batchSize)) {
      final object = row.photoUrl;
      if (object == null) continue;

      try {
        final bytes = await _supabase.client.storage.from(bucket).download(object);
        final path = await _photos.saveDownloaded(bytes);
        await _birdsDao.setPhotoPath(row.id, path);
      } catch (error, stackTrace) {
        debugPrint('Foto de ${row.id} no bajó: $error\n$stackTrace');
      }
    }
  }
}

/// Quién sabe guardar la URL de una foto ya subida.
///
/// La implementa el repositorio de ejemplares —es quien encola el cambio para
/// sincronizarlo—, pero `core/` no puede depender de un feature. Mismo patrón
/// que `PayrollExpenseSink`: la dependencia va por una interfaz de aquí.
abstract interface class PhotoUrlSink {
  Future<void> setPhotoUrl({required String birdId, required String objectPath});
}
