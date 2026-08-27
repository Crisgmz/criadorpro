import '../../features/accounting/model/transaction.dart';
import '../../features/accounting/view/accounting_labels.dart';
import '../../features/payroll/model/employee.dart';
import '../../features/payroll/model/payroll_payment.dart';
import '../../features/payroll/view/payroll_labels.dart';
import '../../features/pedigree/model/pedigree_node.dart';
import '../../l10n/generated/app_l10n.dart';
import '../domain/sex.dart';
import '../utils/formatters.dart';
import 'export_service.dart';
import 'pdf_documents.dart';
import 'pdf_theme.dart';

/// Arma cada PDF a partir de los modelos y lo entrega.
///
/// Aquí —y no en los constructores de documento— vive todo lo que sabe de
/// idioma, moneda y fechas: los documentos reciben texto ya formateado, así que
/// se pueden probar sin montar `AppL10n`.
///
/// Vive en `core/` porque las tres exportaciones comparten cabecera, tipografía
/// y pie, y porque contabilidad, empleomanía y genealogía no pueden importarse
/// entre sí.
class Exporters {
  const Exporters({this.target = const PrintingExportTarget()});

  final ExportTarget target;

  /// `RF-PED-08`.
  Future<void> pedigree({
    required AppL10n l10n,
    required String locale,
    required String farmName,
    required PedigreeNode root,
    required int depth,
    required DateTime now,
  }) async {
    final theme = await PdfTheme.load();

    PdfBird? boxOf(PedigreeNode? node, {String? role}) => node == null
        ? null
        : PdfBird(
            name: node.bird.displayName,
            plate: Formatters.plate(node.bird.plate),
            role: role,
            isMale: node.bird.sex == Sex.male,
          );

    // Mismo emparejamiento que la pantalla: rama paterna a la izquierda,
    // materna a la derecha. El papel y la app tienen que leerse igual.
    final generations = <List<PdfBird?>>[];
    final titles = <String>[];
    for (var generation = 1; generation <= depth; generation++) {
      final level = _levelOf(root, generation);
      generations.add([
        for (var i = 0; i < level.length; i++)
          boxOf(
            level[i],
            role: generation != 1
                ? null
                : (i == 0 ? l10n.pedigreeRoleFather : l10n.pedigreeRoleMother),
          ),
      ]);
      titles.add(_generationTitle(l10n, generation));
    }

    // Una generación entera sin registrar no se imprime: ocho casillas con un
    // guion ocupan media página y hacen pensar que el documento salió mal. Se
    // recortan solo las del final —un hueco intermedio sí es información, dice
    // que de ese abuelo no se sabe nada pero del bisabuelo sí.
    while (generations.isNotEmpty && generations.last.every((box) => box == null)) {
      generations.removeLast();
      titles.removeLast();
    }

    final document = buildPedigreeDocument(
      theme: theme,
      labels: PdfLabels(
        farmName: farmName,
        title: l10n.exportPedigreeTitle,
        generatedOn: l10n.exportGeneratedOn(Formatters.date(now, locale)),
      ),
      subject: PdfBird(
        name: root.bird.displayName,
        plate: Formatters.plate(root.bird.plate),
        isMale: root.bird.sex == Sex.male,
      ),
      subjectLine: [
        l10n.birdsPlateLabel(Formatters.plate(root.bird.plate)),
        if ((root.bird.line ?? '').isNotEmpty) root.bird.line!,
      ].join(' · '),
      generations: generations,
      generationTitles: titles,
    );

    await target.share(
      bytes: await document.save(),
      fileName: pdfFileName(root.bird.displayName, suffix: 'pedigri'),
    );
  }

  /// `RF-CON-07`.
  Future<void> monthlyReport({
    required AppL10n l10n,
    required String locale,
    required String farmName,
    required MonthlyBalance balance,
    required List<Transaction> transactions,
    required DateTime now,
  }) async {
    final theme = await PdfTheme.load();
    String money(int cents) => Formatters.currency(cents / 100, locale);

    final document = buildMonthlyReportDocument(
      theme: theme,
      labels: PdfLabels(
        farmName: farmName,
        title: l10n.exportMonthTitle,
        generatedOn: l10n.exportGeneratedOn(Formatters.date(now, locale)),
      ),
      monthName: Formatters.monthYear(balance.month, locale),
      incomeLabel: l10n.accountingIncome,
      expenseLabel: l10n.accountingExpense,
      balanceLabel: l10n.accountingBalance,
      incomeTotal: money(balance.incomeCents),
      expenseTotal: money(balance.expenseCents),
      balanceTotal: money(balance.balanceCents),
      isNegative: balance.isNegative,
      breakdownTitle: l10n.accountingByCategory,
      breakdown: [
        for (final entry in balance.byCategory.entries)
          PdfMoneyRow(label: categoryLabel(l10n, entry.key), amount: money(entry.value)),
      ],
      movementsTitle: l10n.exportMovements,
      movements: [
        for (final transaction in transactions)
          PdfMoneyRow(
            label: transaction.description?.isNotEmpty ?? false
                ? transaction.description!
                : categoryLabel(l10n, transaction.category),
            detail: Formatters.shortDate(transaction.date, locale),
            // El signo lo pone el tipo, no el importe: en la base todo es
            // positivo, y en el reporte el gasto tiene que restar a la vista.
            amount:
                '${transaction.type == TransactionType.expense ? '−' : '+'}'
                '${money(transaction.amountCents)}',
          ),
      ],
      emptyMessage: l10n.accountingEmptyMessage,
    );

    await target.share(
      bytes: await document.save(),
      fileName: pdfFileName(Formatters.monthYear(balance.month, locale), suffix: 'reporte'),
    );
  }

  /// `RF-NOM-04`.
  Future<void> payrollReceipt({
    required AppL10n l10n,
    required String locale,
    required String farmName,
    required Employee employee,
    required PayrollPayment payment,
    required DateTime now,
  }) async {
    final theme = await PdfTheme.load();
    String money(int cents) => Formatters.currency(cents / 100, locale);

    final document = buildPayrollReceiptDocument(
      theme: theme,
      labels: PdfLabels(
        farmName: farmName,
        title: l10n.exportReceiptTitle,
        generatedOn: l10n.exportGeneratedOn(Formatters.date(now, locale)),
      ),
      employeeName: employee.name,
      employeeRole: employee.role,
      employeeDocument: employee.document == null
          ? null
          : '${l10n.payrollFieldDocument}: ${employee.document}',
      period: l10n.payrollPeriodRange(
        Formatters.shortDate(payment.periodStart, locale),
        Formatters.shortDate(payment.periodEnd, locale),
      ),
      method: methodLabel(l10n, payment.method),
      lines: [
        PdfMoneyRow(label: l10n.payrollFieldBase, amount: money(payment.baseCents)),
        if (payment.bonusCents > 0)
          PdfMoneyRow(label: l10n.payrollFieldBonus, amount: money(payment.bonusCents)),
        if (payment.deductionsCents > 0)
          PdfMoneyRow(
            label: l10n.payrollFieldDeductions,
            amount: '−${money(payment.deductionsCents)}',
          ),
      ],
      netLabel: l10n.payrollNet,
      netAmount: money(payment.netCents),
      signatureLabel: l10n.exportSignature,
    );

    await target.share(
      bytes: await document.save(),
      fileName: pdfFileName(employee.name, suffix: 'recibo'),
    );
  }

  static String _generationTitle(AppL10n l10n, int generation) => switch (generation) {
    1 => l10n.pedigreeGeneration1,
    2 => l10n.pedigreeGeneration2,
    3 => l10n.pedigreeGeneration3,
    _ => l10n.pedigreeGeneration4,
  };

  /// Los nodos de una generación, con los huecos incluidos.
  static List<PedigreeNode?> _levelOf(PedigreeNode? root, int generation) {
    var level = <PedigreeNode?>[root];
    for (var i = 0; i < generation; i++) {
      level = [
        for (final node in level) ...[node?.father, node?.mother],
      ];
    }
    return level;
  }
}
