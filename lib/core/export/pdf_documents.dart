import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'pdf_theme.dart';

/// Datos ya formateados que necesita cada documento.
///
/// Los documentos reciben **texto**, no modelos: el formato de fecha, la moneda
/// y las traducciones son cosa de la capa que sabe del locale, y así estos
/// constructores se pueden probar sin montar `AppL10n` ni `intl`.

class PdfLabels {
  const PdfLabels({required this.farmName, required this.generatedOn, required this.title});

  final String farmName;

  /// «Emitido el 27/08/2026», ya traducido.
  final String generatedOn;
  final String title;
}

/// Un ejemplar dentro del pedigrí impreso.
class PdfBird {
  const PdfBird({required this.name, required this.plate, this.role, this.isMale});

  final String name;
  final String plate;
  final String? role;

  /// `null` en las casillas sin registrar.
  final bool? isMale;
}

/// `RF-PED-08` — pedigrí en PDF.
///
/// Se imprime en **rejilla de generaciones**, no como el árbol vertical de la
/// pantalla: en papel A4 hay anchura de sobra, y quien lo recibe con un ejemplar
/// vendido quiere ver la línea entera de un vistazo, no desplazándose.
pw.Document buildPedigreeDocument({
  required PdfTheme theme,
  required PdfLabels labels,
  required PdfBird subject,
  required String subjectLine,
  required List<List<PdfBird?>> generations,
  required List<String> generationTitles,
}) {
  final document = pw.Document();

  document.addPage(
    pw.MultiPage(
      pageTheme: PdfTheme.page(theme),
      header: (context) => theme.header(
        title: labels.title,
        subtitle: '${subject.name} · ${subject.plate}',
        farmName: labels.farmName,
      ),
      footer: (context) => theme.footer(generatedOn: labels.generatedOn, context: context),
      build: (context) => [
        pw.SizedBox(height: 16),
        _subjectBanner(theme, subject, subjectLine),
        for (var index = 0; index < generations.length; index++) ...[
          pw.SizedBox(height: 14),
          pw.Text(generationTitles[index].toUpperCase(), style: theme.section),
          pw.SizedBox(height: 6),
          _generationGrid(theme, generations[index]),
        ],
      ],
    ),
  );

  return document;
}

pw.Widget _subjectBanner(PdfTheme theme, PdfBird subject, String line) => pw.Container(
  width: double.infinity,
  padding: const pw.EdgeInsets.all(14),
  decoration: const pw.BoxDecoration(
    color: PdfTheme.navy,
    borderRadius: pw.BorderRadius.all(pw.Radius.circular(10)),
  ),
  child: pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Text(
        subject.name,
        style: pw.TextStyle(font: theme.bold, fontSize: 16, color: PdfTheme.surface),
      ),
      pw.Text(
        line,
        style: pw.TextStyle(font: theme.regular, fontSize: 10, color: PdfTheme.border),
      ),
    ],
  ),
);

/// Una generación en dos columnas: rama paterna a la izquierda, materna a la
/// derecha. Igual que en pantalla, para que el papel y la app se lean igual.
pw.Widget _generationGrid(PdfTheme theme, List<PdfBird?> nodes) {
  final half = nodes.length ~/ 2;

  return pw.Column(
    children: [
      for (var row = 0; row < half; row++)
        pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 6),
          // Sin `stretch` en el eje cruzado: en `pdf` la altura de la fila
          // sale de sus hijos, así que estirarlos a la altura de la fila es
          // circular y `MultiPage` se queda generando páginas hasta reventar.
          child: pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(child: _birdBox(theme, nodes[row])),
              pw.SizedBox(width: 6),
              pw.Expanded(child: _birdBox(theme, nodes[half + row])),
            ],
          ),
        ),
    ],
  );
}

pw.Widget _birdBox(PdfTheme theme, PdfBird? bird) {
  if (bird == null) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(8),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfTheme.border),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
      ),
      child: pw.Text('—', style: theme.bodyMuted),
    );
  }

  final accent = bird.isMale == null
      ? PdfTheme.muted
      : (bird.isMale! ? PdfTheme.male : PdfTheme.female);

  return pw.Container(
    padding: const pw.EdgeInsets.all(8),
    decoration: pw.BoxDecoration(
      border: pw.Border.all(color: accent, width: 0.8),
      borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
    ),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        if (bird.role != null)
          pw.Text(
            bird.role!.toUpperCase(),
            style: pw.TextStyle(font: theme.semiBold, fontSize: 7, color: accent, letterSpacing: 1),
          ),
        pw.Text(bird.name, style: theme.value),
        pw.Text(bird.plate, style: theme.bodyMuted),
      ],
    ),
  );
}

/// Una línea del reporte contable, ya formateada.
class PdfMoneyRow {
  const PdfMoneyRow({required this.label, required this.amount, this.detail});

  final String label;
  final String amount;
  final String? detail;
}

/// `RF-CON-07` — reporte mensual en PDF.
pw.Document buildMonthlyReportDocument({
  required PdfTheme theme,
  required PdfLabels labels,
  required String monthName,
  required String incomeTotal,
  required String expenseTotal,
  required String balanceTotal,
  required bool isNegative,
  required String incomeLabel,
  required String expenseLabel,
  required String balanceLabel,
  required String breakdownTitle,
  required List<PdfMoneyRow> breakdown,
  required String movementsTitle,
  required List<PdfMoneyRow> movements,
  required String emptyMessage,
}) {
  final document = pw.Document();

  document.addPage(
    pw.MultiPage(
      pageTheme: PdfTheme.page(theme),
      header: (context) =>
          theme.header(title: labels.title, subtitle: monthName, farmName: labels.farmName),
      footer: (context) => theme.footer(generatedOn: labels.generatedOn, context: context),
      build: (context) => [
        pw.SizedBox(height: 16),
        pw.Row(
          children: [
            pw.Expanded(child: _figure(theme, incomeLabel, incomeTotal, PdfTheme.male)),
            pw.Expanded(child: _figure(theme, expenseLabel, expenseTotal, PdfTheme.action)),
            pw.Expanded(
              child: _figure(
                theme,
                balanceLabel,
                balanceTotal,
                // `RF-CON-04`: el negativo va en rojo **y sin explicaciones**.
                // Un mes en pérdidas es información, no un error.
                isNegative ? PdfTheme.action : PdfTheme.navy,
              ),
            ),
          ],
        ),

        if (movements.isEmpty) ...[
          pw.SizedBox(height: 24),
          pw.Text(emptyMessage, style: theme.bodyMuted),
        ] else ...[
          pw.SizedBox(height: 20),
          pw.Text(breakdownTitle.toUpperCase(), style: theme.section),
          pw.SizedBox(height: 6),
          for (final row in breakdown) theme.dataRow(row.label, row.amount),

          pw.SizedBox(height: 18),
          pw.Text(movementsTitle.toUpperCase(), style: theme.section),
          pw.SizedBox(height: 6),
          for (final row in movements)
            pw.Padding(
              padding: const pw.EdgeInsets.symmetric(vertical: 4),
              child: pw.Row(
                children: [
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(row.label, style: theme.body),
                        if (row.detail != null) pw.Text(row.detail!, style: theme.bodyMuted),
                      ],
                    ),
                  ),
                  pw.Text(row.amount, style: theme.value),
                ],
              ),
            ),
        ],
      ],
    ),
  );

  return document;
}

pw.Widget _figure(PdfTheme theme, String label, String amount, PdfColor color) => pw.Column(
  crossAxisAlignment: pw.CrossAxisAlignment.start,
  children: [
    pw.Text(label.toUpperCase(), style: theme.section),
    pw.SizedBox(height: 2),
    pw.Text(
      amount,
      style: pw.TextStyle(font: theme.bold, fontSize: 15, color: color),
    ),
  ],
);

/// `RF-NOM-04` — recibo de pago de nómina.
///
/// Es el documento que el empleado se lleva, así que lleva su nombre, el
/// período, el desglose y el neto destacado. Lo que firma es el neto.
pw.Document buildPayrollReceiptDocument({
  required PdfTheme theme,
  required PdfLabels labels,
  required String employeeName,
  required String? employeeRole,
  required String? employeeDocument,
  required String period,
  required String method,
  required List<PdfMoneyRow> lines,
  required String netLabel,
  required String netAmount,
  required String signatureLabel,
}) {
  final document = pw.Document();

  document.addPage(
    pw.Page(
      pageTheme: PdfTheme.page(theme),
      build: (context) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          theme.header(title: labels.title, subtitle: period, farmName: labels.farmName),
          pw.SizedBox(height: 18),

          pw.Text(employeeName, style: pw.TextStyle(font: theme.bold, fontSize: 14)),
          if (employeeRole != null) pw.Text(employeeRole, style: theme.bodyMuted),
          if (employeeDocument != null) pw.Text(employeeDocument, style: theme.bodyMuted),

          pw.SizedBox(height: 18),
          for (final line in lines) theme.dataRow(line.label, line.amount),
          pw.Divider(color: PdfTheme.border),

          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(netLabel, style: theme.value),
              pw.Text(netAmount, style: theme.figure),
            ],
          ),
          pw.SizedBox(height: 6),
          theme.dataRow('', method),

          // Espacio para la firma: el recibo se imprime y se guarda en papel,
          // que es como se lleva la nómina en un criadero.
          pw.SizedBox(height: 56),
          pw.Container(width: 200, height: 0.8, color: PdfTheme.muted),
          pw.SizedBox(height: 4),
          pw.Text(signatureLabel, style: theme.bodyMuted),

          pw.Spacer(),
          pw.Text(
            labels.generatedOn,
            style: pw.TextStyle(font: theme.regular, fontSize: 8, color: PdfTheme.muted),
          ),
        ],
      ),
    ),
  );

  return document;
}
