import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

/// De dónde sale la foto del ejemplar — `RF-REG-15`.
enum PhotoSource { camera, gallery }

/// Captura y almacenamiento local de fotos.
///
/// La foto se guarda **en el sistema de archivos de la app**, nunca en la base:
/// meter dos megas de binario en SQLite hincharía cada consulta y cada copia.
/// En Drift solo viaja la ruta (`birds.photo_path`), y la subida a Storage es
/// una operación aparte para que una foto pesada no bloquee la cola de datos.
class PhotoService {
  PhotoService({ImagePicker? picker, Uuid uuid = const Uuid()})
    : _picker = picker ?? ImagePicker(),
      _uuid = uuid;

  final ImagePicker _picker;
  final Uuid _uuid;

  /// `RV-19` — 1.600 px en el lado mayor.
  static const double maxSide = 1600;

  /// `RV-19` — 2 MB por foto.
  static const int maxBytes = 2 * 1024 * 1024;

  /// Calidad inicial. Si aun así se pasa de [maxBytes] se vuelve a comprimir
  /// más bajo, en lugar de rechazar la foto: el criador ya la tomó y decirle
  /// que «pesa demasiado» sin más sería devolverle un problema que la app
  /// puede resolver sola.
  static const int _initialQuality = 85;
  static const int _fallbackQuality = 60;

  /// Carpeta de las fotos dentro del área privada de la app.
  static const String _folder = 'bird_photos';

  /// Abre la cámara o la galería y deja la foto lista en disco.
  ///
  /// Devuelve `null` si el usuario cancela — que no es un error y no debe
  /// mostrar mensaje alguno.
  Future<String?> capture(PhotoSource source) async {
    // El redimensionado lo hace el propio selector, en código nativo: es
    // órdenes de magnitud más rápido que recorrer los píxeles en Dart, y evita
    // cargar en memoria una foto de 12 megapíxeles en un teléfono de gama baja.
    final picked = await _picker.pickImage(
      source: source == PhotoSource.camera ? ImageSource.camera : ImageSource.gallery,
      maxWidth: maxSide,
      maxHeight: maxSide,
      imageQuality: _initialQuality,
    );
    if (picked == null) return null;

    return _persist(picked);
  }

  Future<String> _persist(XFile picked) async {
    final directory = Directory(p.join((await getApplicationDocumentsDirectory()).path, _folder));
    if (!directory.existsSync()) await directory.create(recursive: true);

    var bytes = await picked.readAsBytes();

    // Segunda pasada solo si hace falta. A 1.600 px y 85 % casi ninguna foto
    // llega a 2 MB, pero `RV-19` es un tope, no una expectativa: las que se
    // pasan se recomprimen en un isolate para no congelar la interfaz.
    if (bytes.length > maxBytes) {
      bytes = await compute(_recompress, bytes);
    }

    // Nombre propio y no el original: dos fotos de galería pueden llamarse
    // igual, y la extensión de origen puede no coincidir con lo que se guardó.
    final file = File(p.join(directory.path, '${_uuid.v4()}.jpg'));
    await file.writeAsBytes(bytes);
    return file.path;
  }

  /// Recodifica a menor calidad. Se ejecuta fuera del hilo de la interfaz:
  /// decodificar 2,5 megapíxeles en Dart tarda lo suficiente como para que se
  /// note un tirón en el desplazamiento.
  static Uint8List _recompress(Uint8List bytes) {
    final decoded = img.decodeImage(bytes);
    // Si no se puede decodificar se devuelve tal cual: perder la foto sería
    // peor que guardarla algo más pesada de la cuenta.
    if (decoded == null) return bytes;
    return img.encodeJpg(decoded, quality: _fallbackQuality);
  }

  /// Borra el archivo de una foto sustituida o retirada.
  ///
  /// Nunca lanza: perder el archivo es intrascendente comparado con perder el
  /// registro del ejemplar, y un fallo aquí no puede tumbar el guardado.
  Future<void> deleteFile(String? path) async {
    if (path == null) return;
    try {
      final file = File(path);
      if (file.existsSync()) await file.delete();
    } on FileSystemException {
      // Sin efecto: la fila ya no la referencia.
    }
  }
}
