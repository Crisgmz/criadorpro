/// Una foto pendiente de subir o de bajar.
class PendingPhoto {
  const PendingPhoto({required this.id, this.localPath, this.objectPath});

  final String id;

  /// Ruta en el sistema de archivos del teléfono. `null` cuando falta por bajar.
  final String? localPath;

  /// Ruta dentro del bucket. `null` cuando falta por subir.
  final String? objectPath;
}

/// Un tipo de registro que lleva foto — `RF-REG-15` y pantalla 30.
///
/// Empezó siendo solo el ejemplar. Al añadir la del empleado, copiar el
/// recorrido entero habría dejado dos sitios donde arreglar el mismo fallo, y
/// el recorrido no es trivial: deduce el trabajo pendiente del estado, sustituye
/// en lugar de acumular, y no puede mover `updated_at`.
///
/// Vive en `core/` porque lo implementan dos features distintos y ninguno puede
/// importar del otro. Mismo patrón que `PayrollExpenseSink` y `WeightLog`.
abstract interface class PhotoSubject {
  /// Bucket de Storage donde viven estas fotos.
  String get bucket;

  /// Con foto local y sin URL: falta subirla.
  Future<List<PendingPhoto>> pendingUploads(String ownerId);

  /// Con URL y sin foto local: falta bajarla — el caso del dispositivo nuevo.
  Future<List<PendingPhoto>> pendingDownloads(String ownerId);

  /// Anota la foto ya subida. Lo hace el repositorio porque es quien encola el
  /// cambio: sin encolarlo, la foto se vería en este teléfono y en ninguno más.
  Future<void> setPhotoUrl({required String id, required String objectPath});

  /// Guarda la ruta local. **No se sincroniza**: una ruta de este teléfono no
  /// significa nada en otro, así que se escribe sin marcar la fila como sucia.
  Future<void> setPhotoPath(String id, String? path);
}
