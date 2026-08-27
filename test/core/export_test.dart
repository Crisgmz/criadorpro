import 'dart:typed_data';

import 'package:criadorpro/core/domain/sex.dart';
import 'package:criadorpro/core/export/export_service.dart';
import 'package:criadorpro/core/export/exporters.dart';
import 'package:criadorpro/core/export/pdf_theme.dart';
import 'package:criadorpro/core/utils/formatters.dart';
import 'package:criadorpro/features/accounting/model/transaction.dart';
import 'package:criadorpro/features/birds/model/bird.dart';
import 'package:criadorpro/features/payroll/model/employee.dart';
import 'package:criadorpro/features/payroll/model/payroll_payment.dart';
import 'package:criadorpro/features/pedigree/model/pedigree_node.dart';
import 'package:criadorpro/l10n/generated/app_l10n.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

/// `RF-PED-08` · `RF-CON-07` · `RF-NOM-04` — exportación a PDF.
///
/// Un PDF no se puede mirar con `expect`, así que lo que se comprueba es lo que
/// se rompe en silencio: que el documento se genere de verdad —no un archivo de
/// cero bytes—, que el nombre no lleve nada que impida compartirlo, y que los
/// colores de marca no se separen entre la app y el papel.
void main() {
  late AppL10n l10n;
  late _RecordingTarget target;
  late Exporters exporters;

  final now = DateTime(2026, 8, 27);
  const farmName = 'Criadero Los Pinos';

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    // `intl` no trae los datos de ningún idioma cargados: sin esto, cualquier
    // fecha formateada revienta. La app los carga al arrancar.
    await initializeDateFormatting('es');
    l10n = await AppL10n.delegate.load(const Locale('es'));
  });

  setUp(() {
    target = _RecordingTarget();
    exporters = Exporters(target: target);
  });

  Bird bird(int plate, String name, Sex sex, {String? line}) => Bird(
    id: 'b$plate',
    ownerId: 'o1',
    plate: plate,
    name: name,
    line: line,
    sex: sex,
    status: BirdStatus.active,
    createdAt: now,
    updatedAt: now,
  );

  group('RF-PED-08 · pedigrí', () {
    final root = PedigreeNode(
      bird: bird(1188, 'Giro Colorado', Sex.male, line: 'Línea Sabanera'),
      father: PedigreeNode(
        bird: bird(912, 'Giro Real', Sex.male),
        father: PedigreeNode(bird: bird(640, 'Giro Bravo', Sex.male)),
      ),
      mother: PedigreeNode(bird: bird(944, 'Pinta Vieja', Sex.female)),
    );

    test('genera un PDF con contenido', () async {
      await exporters.pedigree(
        l10n: l10n,
        locale: 'es',
        farmName: farmName,
        root: root,
        depth: 2,
        now: now,
      );

      expect(target.bytes, isNotNull);
      // Un PDF vacío pesa poco más de 700 bytes; con dos generaciones dentro
      // tiene que pasar holgadamente de ahí.
      expect(target.bytes!.length, greaterThan(2000));
      expect(String.fromCharCodes(target.bytes!.take(5)), '%PDF-');
    });

    test('el nombre del archivo sale del ejemplar y no lleva tildes', () async {
      await exporters.pedigree(
        l10n: l10n,
        locale: 'es',
        farmName: farmName,
        root: PedigreeNode(bird: bird(1, 'Ceniza Bonita', Sex.female)),
        depth: 1,
        now: now,
      );

      expect(target.fileName, 'ceniza-bonita-pedigri.pdf');
    });

    test('un pedigrí sin ascendencia también se exporta', () async {
      // El criador vende un pollito recién registrado: el documento tiene que
      // salir con las casillas vacías, no fallar.
      await exporters.pedigree(
        l10n: l10n,
        locale: 'es',
        farmName: farmName,
        root: PedigreeNode(bird: bird(1, 'Solo', Sex.male)),
        depth: 4,
        now: now,
      );

      expect(target.bytes, isNotNull);
    });
  });

  group('RF-CON-07 · reporte mensual', () {
    Transaction movement(TransactionType type, TransactionCategory category, int cents) =>
        Transaction(
          id: 't-$cents',
          ownerId: 'o1',
          type: type,
          category: category,
          amountCents: cents,
          date: DateTime(2026, 8, 10),
          createdAt: now,
          updatedAt: now,
        );

    test('genera el mes con sus movimientos', () async {
      await exporters.monthlyReport(
        l10n: l10n,
        locale: 'es',
        farmName: farmName,
        balance: MonthlyBalance(
          month: DateTime(2026, 8),
          incomeCents: 500000,
          expenseCents: 320000,
          byCategory: const {
            TransactionCategory.birdSale: 500000,
            TransactionCategory.feed: 320000,
          },
        ),
        transactions: [
          movement(TransactionType.income, TransactionCategory.birdSale, 500000),
          movement(TransactionType.expense, TransactionCategory.feed, 320000),
        ],
        now: now,
      );

      expect(target.bytes!.length, greaterThan(2000));
    });

    test('un mes vacío se exporta igual, no falla', () async {
      // Cerrar un mes sin movimientos es un resultado, no un error.
      await exporters.monthlyReport(
        l10n: l10n,
        locale: 'es',
        farmName: farmName,
        balance: MonthlyBalance.emptyFor(DateTime(2026, 8)),
        transactions: const [],
        now: now,
      );

      expect(target.bytes, isNotNull);
    });

    test('un mes en pérdidas se exporta sin tratarlo como error', () async {
      await exporters.monthlyReport(
        l10n: l10n,
        locale: 'es',
        farmName: farmName,
        balance: MonthlyBalance(
          month: DateTime(2026, 8),
          incomeCents: 10000,
          expenseCents: 90000,
          byCategory: const {TransactionCategory.feed: 90000},
        ),
        transactions: [movement(TransactionType.expense, TransactionCategory.feed, 90000)],
        now: now,
      );

      expect(target.bytes, isNotNull);
    });
  });

  group('RF-NOM-04 · recibo de nómina', () {
    final employee = Employee(
      id: 'e1',
      ownerId: 'o1',
      name: 'Juan Pérez',
      role: 'Encargado',
      document: '00101000008',
      salaryCents: 800000,
      frequency: PayFrequency.biweekly,
      createdAt: now,
      updatedAt: now,
    );

    PayrollPayment payment({int bonus = 50000, int deductions = 30000}) => PayrollPayment(
      id: 'p1',
      ownerId: 'o1',
      employeeId: 'e1',
      periodStart: DateTime(2026, 8),
      periodEnd: DateTime(2026, 8, 15),
      baseCents: 800000,
      bonusCents: bonus,
      deductionsCents: deductions,
      method: PaymentMethod.cash,
      createdAt: now,
      updatedAt: now,
    );

    test('genera el recibo', () async {
      await exporters.payrollReceipt(
        l10n: l10n,
        locale: 'es',
        farmName: farmName,
        employee: employee,
        payment: payment(),
        now: now,
      );

      expect(target.bytes!.length, greaterThan(2000));
      // El nombre del empleado, sin tildes ni espacios: con ellos, compartir
      // el archivo falla en algunos destinos.
      expect(target.fileName, 'juan-perez-recibo.pdf');
    });

    test('sin bonificación ni deducciones el recibo sigue saliendo', () async {
      await exporters.payrollReceipt(
        l10n: l10n,
        locale: 'es',
        farmName: farmName,
        employee: employee,
        payment: payment(bonus: 0, deductions: 0),
        now: now,
      );

      expect(target.bytes, isNotNull);
    });
  });

  group('nombre de archivo', () {
    test('quita tildes, eñes y todo lo que no sea seguro en una ruta', () {
      expect(pdfFileName('Criadero Peña / Año 2026'), 'criadero-pena-ano-2026.pdf');
    });

    test('un nombre que se queda vacío cae a uno por omisión', () {
      // Un ejemplar sin nombre da un archivo sin nombre, y eso no se comparte.
      expect(pdfFileName('¿¿¿'), 'criadorpro.pdf');
    });

    test('no deja guiones sueltos en los extremos', () {
      expect(pdfFileName('  Giro  '), 'giro.pdf');
    });
  });

  group('moneda · PRD §9', () {
    // Salió al mirar un PDF, no de una prueba: la interpolación estaba
    // escapada y la app entera imprimía «$symbol» en lugar de «RD$».
    test('lleva el símbolo, no el nombre de la variable', () {
      expect(Formatters.currency(12450, 'es'), 'RD\$ 12,450.00');
    });

    test('agrupa a la dominicana, no a la europea, sea cual sea el idioma', () {
      // Con `es` a secas, `intl` da «45.000,00» y el criador lee cuarenta y
      // cinco pesos con mil.
      expect(Formatters.currency(45000, 'es'), 'RD\$ 45,000.00');
      expect(Formatters.currency(45000, 'en'), 'RD\$ 45,000.00');
    });

    test('el negativo lleva el signo delante del símbolo', () {
      // `RF-CON-04`: un mes en pérdidas tiene que cantar a la primera.
      expect(Formatters.currency(-1280, 'es'), '-RD\$ 1,280.00');
    });

    test('redondea a dos decimales', () {
      expect(Formatters.currency(12.456, 'es'), 'RD\$ 12.46');
    });
  });

  test('los colores de marca del PDF y de la app no se separan', () {
    // Cambiar el navy en `AppColors` y olvidarse del PDF dejaría el papel con
    // la marca vieja durante meses sin que nada fallara.
    expect(pdfMatchesBrand(), isTrue);
  });
}

/// Captura el documento en lugar de abrir la hoja de compartir del sistema,
/// que en un test dejaría la prueba esperando a un humano.
class _RecordingTarget implements ExportTarget {
  Uint8List? bytes;
  String? fileName;

  @override
  Future<void> share({required Uint8List bytes, required String fileName}) async {
    this.bytes = bytes;
    this.fileName = fileName;
  }
}
