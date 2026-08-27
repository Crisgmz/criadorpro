import 'dart:typed_data';

import 'package:printing/printing.dart';

/// Entrega el PDF ya armado — `RF-PED-08`, `RF-CON-07`, `RF-NOM-04`.
///
/// Se abre la hoja de compartir del sistema en lugar de guardar el archivo en
/// una carpeta: el criador manda el pedigrí por WhatsApp al comprador y el
/// recibo al empleado. Guardar en disco le obligaría a buscarlo después, y en
/// iOS ni siquiera hay una carpeta donde mirar.
///
/// Va detrás de una interfaz para poder sustituirlo en pruebas: abrir la hoja
/// del sistema en un test lo dejaría colgado esperando a un humano.
abstract interface class ExportTarget {
  Future<void> share({required Uint8List bytes, required String fileName});
}

class PrintingExportTarget implements ExportTarget {
  const PrintingExportTarget();

  @override
  Future<void> share({required Uint8List bytes, required String fileName}) =>
      Printing.sharePdf(bytes: bytes, filename: fileName);
}

/// Nombre de archivo seguro a partir de un texto del usuario.
///
/// El nombre del criadero puede llevar tildes, espacios y barras; una barra en
/// el nombre de archivo lo convierte en una ruta y la compartición falla.
String pdfFileName(String base, {String? suffix}) {
  final clean = base
      .toLowerCase()
      .replaceAll(RegExp('[áàä]'), 'a')
      .replaceAll(RegExp('[éèë]'), 'e')
      .replaceAll(RegExp('[íìï]'), 'i')
      .replaceAll(RegExp('[óòö]'), 'o')
      .replaceAll(RegExp('[úùü]'), 'u')
      .replaceAll('ñ', 'n')
      .replaceAll(RegExp('[^a-z0-9]+'), '-')
      .replaceAll(RegExp('^-+|-+\$'), '');

  final name = clean.isEmpty ? 'criadorpro' : clean;
  return suffix == null ? '$name.pdf' : '$name-$suffix.pdf';
}
