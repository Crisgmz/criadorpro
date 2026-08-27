import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../theme/app_colors.dart';
import '../widgets/brand.dart';

/// Recursos y estilo común de los PDF — `RF-PED-08`, `RF-CON-07`, `RF-NOM-04`.
///
/// Los tres documentos son del mismo criadero y se imprimen juntos: comparten
/// tipografía, colores y cabecera para que se lean como una sola cosa y no como
/// tres exportaciones de tres programas.
///
/// Las fuentes se cargan **de los assets empaquetados**, no de la red: el
/// criador exporta dentro del galpón sin señal, y `pdf` caería a Helvetica —que
/// no tiene las tildes ni la eñe en su codificación por omisión y dejaría
/// «Genealogía» como «GenealogÃ­a».
class PdfTheme {
  const PdfTheme._({
    required this.regular,
    required this.semiBold,
    required this.bold,
    required this.symbol,
  });

  final pw.Font regular;
  final pw.Font semiBold;
  final pw.Font bold;

  /// Símbolo de marca para la cabecera.
  final pw.MemoryImage symbol;

  static PdfTheme? _cached;

  /// Carga las fuentes una vez por sesión. Decodificar tres TTF por cada
  /// exportación es medio segundo tirado en un teléfono de gama baja.
  static Future<PdfTheme> load() async {
    final cached = _cached;
    if (cached != null) return cached;

    Future<pw.Font> font(String name) async =>
        pw.Font.ttf(await rootBundle.load('assets/fonts/$name'));

    final theme = PdfTheme._(
      regular: await font('Inter-Regular.ttf'),
      semiBold: await font('Inter-SemiBold.ttf'),
      bold: await font('Inter-Bold.ttf'),
      symbol: pw.MemoryImage((await rootBundle.load(BrandAsset.symbolNavy)).buffer.asUint8List()),
    );
    return _cached = theme;
  }

  // Los colores del PRD §9, en el espacio de `pdf`.
  static const PdfColor navy = PdfColor.fromInt(0xFF0E2A47);
  static const PdfColor action = PdfColor.fromInt(0xFFC8102E);
  static const PdfColor male = PdfColor.fromInt(0xFF1E7A4C);
  static const PdfColor female = PdfColor.fromInt(0xFF2B6CB0);
  static const PdfColor muted = PdfColor.fromInt(0xFF6B7A8C);
  static const PdfColor border = PdfColor.fromInt(0xFFE7ECF2);
  static const PdfColor surface = PdfColor.fromInt(0xFFF4F6F9);

  pw.TextStyle get title => pw.TextStyle(font: bold, fontSize: 20, color: navy);

  pw.TextStyle get section =>
      pw.TextStyle(font: semiBold, fontSize: 8, color: muted, letterSpacing: 1.2);

  pw.TextStyle get body => pw.TextStyle(font: regular, fontSize: 10, color: navy);

  pw.TextStyle get bodyMuted => pw.TextStyle(font: regular, fontSize: 10, color: muted);

  pw.TextStyle get value => pw.TextStyle(font: semiBold, fontSize: 10, color: navy);

  pw.TextStyle get figure => pw.TextStyle(font: bold, fontSize: 16, color: navy);

  /// Cabecera común: símbolo, título y el criadero a la derecha.
  pw.Widget header({required String title, String? subtitle, required String farmName}) =>
      pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Image(symbol, width: 28, height: 28),
              pw.SizedBox(width: 10),
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(title, style: this.title),
                    if (subtitle != null) pw.Text(subtitle, style: bodyMuted),
                  ],
                ),
              ),
              pw.Text(farmName, style: value),
            ],
          ),
          pw.SizedBox(height: 12),
          pw.Divider(color: border, height: 1),
        ],
      );

  /// Pie con la fecha de emisión.
  ///
  /// Va en todas las páginas: un pedigrí impreso circula, y sin fecha no hay
  /// forma de saber si describe al criadero de hoy o al de hace dos años.
  pw.Widget footer({required String generatedOn, required pw.Context context}) => pw.Row(
    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
    children: [
      pw.Text(
        generatedOn,
        style: pw.TextStyle(font: regular, fontSize: 8, color: muted),
      ),
      pw.Text(
        '${context.pageNumber} / ${context.pagesCount}',
        style: pw.TextStyle(font: regular, fontSize: 8, color: muted),
      ),
    ],
  );

  /// Fila de etiqueta y valor, como las tarjetas de datos de la app.
  pw.Widget dataRow(String label, String text) => pw.Padding(
    padding: const pw.EdgeInsets.symmetric(vertical: 5),
    child: pw.Row(
      children: [
        pw.Expanded(child: pw.Text(label, style: bodyMuted)),
        pw.Text(text, style: value),
      ],
    ),
  );

  static pw.PageTheme page(PdfTheme theme) => pw.PageTheme(
    pageFormat: PdfPageFormat.a4,
    margin: const pw.EdgeInsets.fromLTRB(36, 32, 36, 28),
    theme: pw.ThemeData.withFont(base: theme.regular, bold: theme.bold),
  );
}

/// Colores del PRD que la app y el PDF comparten. Se comprueba aquí para que
/// cambiar la marca en un sitio y no en el otro se note.
bool pdfMatchesBrand() =>
    PdfTheme.navy.toInt() == AppColors.navy.toARGB32() &&
    PdfTheme.action.toInt() == AppColors.action.toARGB32() &&
    PdfTheme.male.toInt() == AppColors.male.toARGB32();
