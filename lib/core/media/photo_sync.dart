import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show FileOptions;

import '../network/supabase_service.dart';
import '../sync/sync_service.dart';
import 'photo_service.dart';
import 'photo_subject.dart';

/// Sube y baja las fotos — `RF-REG-15` (ejemplares) y pantalla 30 (empleados).
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
///
/// Sirve a varios tipos de registro por [PhotoSubject]: el recorrido es el
/// mismo y duplicarlo dejaría dos sitios donde arreglar el mismo fallo.
class PhotoSyncService implements MediaSyncer {
  PhotoSyncService({
    required PhotoService photos,
    required SupabaseService supabase,
    required List<PhotoSubject> subjects,
  }) : _photos = photos,
       _supabase = supabase,
       _subjects = subjects;

  final PhotoService _photos;
  final SupabaseService _supabase;
  final List<PhotoSubject> _subjects;

  /// Bucket de los ejemplares. Se crea con la migración
  /// `20260827000000_bird_photos.sql`.
  static const String birdBucket = 'bird-photos';

  /// Bucket de los empleados — `20260827600000_employee_photos.sql`.
  static const String employeeBucket = 'employee-photos';

  /// Cuántas fotos se mueven por ciclo y por tipo.
  ///
  /// Bajo a propósito: el ciclo se repite cada cinco minutos y al recuperar
  /// conexión, así que un criadero que acaba de fotografiar cincuenta aves las
  /// sube en varias pasadas en vez de ocupar la red entera de una vez.
  static const int batchSize = 10;

  /// Ruta determinista dentro del bucket: `{owner}/{id}.jpg`.
  ///
  /// Que sea determinista es lo que hace que volver a subir **sustituya** en
  /// lugar de acumular. Con nombres aleatorios, cambiar la foto de un registro
  /// cinco veces dejaría cuatro huérfanas que nadie borraría nunca.
  ///
  /// El primer segmento es el propietario porque la política de Storage lo
  /// exige: es lo que impide que un criadero lea las fotos de otro.
  static String objectPath({required String ownerId, required String id}) => '$ownerId/$id.jpg';

  @override
  Future<void> sync(String ownerId) async {
    if (!_supabase.isEnabled) return;

    for (final subject in _subjects) {
      await _uploadPending(subject, ownerId);
      await _downloadMissing(subject, ownerId);
    }
  }

  Future<void> _uploadPending(PhotoSubject subject, String ownerId) async {
    final pending = await subject.pendingUploads(ownerId);

    for (final photo in pending.take(batchSize)) {
      final path = photo.localPath;
      if (path == null) continue;

      final file = File(path);
      // El archivo se perdió —el sistema limpió la caché, o se restauró una
      // copia sin los documentos—. La ruta ya no sirve para nada: se suelta
      // para que la fila deje de aparecer en cada ciclo.
      if (!file.existsSync()) {
        await subject.setPhotoPath(photo.id, null);
        continue;
      }

      try {
        final object = objectPath(ownerId: ownerId, id: photo.id);
        await _supabase.client.storage
            .from(subject.bucket)
            .upload(object, file, fileOptions: const FileOptions(upsert: true));

        // La URL sí viaja: la escribe el repositorio para que la fila quede
        // sucia y el siguiente ciclo la propague a los demás dispositivos.
        await subject.setPhotoUrl(id: photo.id, objectPath: object);
      } catch (error, stackTrace) {
        // Una foto que falla no puede detener a las demás ni al resto de la
        // sincronización. El estado no cambia, así que el próximo ciclo
        // reintenta sin necesidad de contadores.
        debugPrint('Foto de ${photo.id} no subió: $error\n$stackTrace');
      }
    }
  }

  Future<void> _downloadMissing(PhotoSubject subject, String ownerId) async {
    final pending = await subject.pendingDownloads(ownerId);

    for (final photo in pending.take(batchSize)) {
      final object = photo.objectPath;
      if (object == null) continue;

      try {
        final bytes = await _supabase.client.storage.from(subject.bucket).download(object);
        final path = await _photos.saveDownloaded(bytes);
        await subject.setPhotoPath(photo.id, path);
      } catch (error, stackTrace) {
        debugPrint('Foto de ${photo.id} no bajó: $error\n$stackTrace');
      }
    }
  }
}
