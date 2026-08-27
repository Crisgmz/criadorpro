import 'package:intl/intl.dart';

/// Edad descompuesta, lista para pasar a las cadenas de `AppL10n`.
class Age {
  const Age({required this.years, required this.months, required this.totalDays});

  final int years;
  final int months;

  /// Días vividos en total. Es lo que se muestra en las primeras semanas.
  final int totalDays;

  /// `true` cuando aún no cumple un mes: conviene mostrar días.
  bool get isNewborn => years == 0 && months == 0;
  bool get isUnderOneYear => years == 0;
}

abstract final class Formatters {
  /// Placa del ejemplar — SRS §4: sin ceros a la izquierda y precedida de `#`.
  ///
  /// Sin separador de miles a propósito: es un identificador, no una cantidad,
  /// y el criador la lee dígito a dígito.
  static String plate(int value) => '#$value';

  static String date(DateTime value, String locale) => DateFormat.yMMMd(locale).format(value);

  static String shortDate(DateTime value, String locale) => DateFormat.yMd(locale).format(value);

  static String number(num value, String locale) =>
      NumberFormat.decimalPattern(locale).format(value);

  /// Moneda con símbolo del país del perfil, separador de miles y dos
  /// decimales — PRD §9: `RD$ 12,450.00`.
  ///
  /// El símbolo se pasa desde fuera y no se deduce del idioma: la app se puede
  /// usar en inglés en República Dominicana, y el dinero seguiría siendo pesos.
  ///
  /// El **patrón numérico sí sale del país**, no del idioma. El español
  /// genérico agrupa a la europea —`45.000,00`— y en República Dominicana se
  /// escribe al revés: `45,000.00`. Con `es` a secas el balance sale con los
  /// separadores cambiados, que es peor que no formatear.
  static String currency(num value, String locale, {String symbol = r'RD$'}) {
    // El signo va delante del símbolo: «RD$ -1,280.00» se lee como si el
    // símbolo fuera parte del importe, y un balance en pérdidas tiene que
    // cantar a la primera (`RF-CON-04`).
    final sign = value.isNegative ? '-' : '';
    return '$sign$symbol ${_moneyPattern.format(value.abs())}';
  }

  /// Patrón fijo `12,450.00`, **no el del idioma de la interfaz**.
  ///
  /// El PRD §9 especifica la forma exacta, y delegarla al locale la rompe: el
  /// español genérico agrupa a la europea —`45.000,00`— y además coloca el
  /// símbolo detrás. En República Dominicana se escribe al revés, y el criador
  /// leyendo «45.000,00» entiende cuarenta y cinco pesos con mil.
  ///
  /// Va contra `en_US` porque es la única tabla de símbolos que `intl` trae
  /// siempre cargada; `es_DO` no existe en sus datos y cae a `es`.
  ///
  /// Cuando se cierre la moneda fuera de República Dominicana (§13 de las
  /// decisiones abiertas), esto es lo que hay que hacer variable.
  static final NumberFormat _moneyPattern = NumberFormat('#,##0.00', 'en_US');

  /// Nombre del mes y año, para la navegación del cierre contable.
  static String monthYear(DateTime value, String locale) => DateFormat.yMMMM(locale).format(value);

  /// Un solo decimal, para promedios como la condición del criadero
  /// (`RF-PRU-03`): «7,4» dice lo suficiente y «7,3999» no dice más.
  static String decimal(num value, String locale) => NumberFormat('0.0', locale).format(value);

  /// Edad a partir de la fecha de nacimiento. [now] se inyecta para poder
  /// testearlo sin depender del reloj.
  static Age age(DateTime birthDate, {DateTime? now}) {
    final today = now ?? DateTime.now();
    var years = today.year - birthDate.year;
    var months = today.month - birthDate.month;

    // Todavía no ha llegado el día del mes: ese mes no cuenta como cumplido.
    if (today.day < birthDate.day) months -= 1;

    if (months < 0) {
      years -= 1;
      months += 12;
    }
    final totalDays = today.difference(birthDate).inDays;
    if (totalDays < 0) return const Age(years: 0, months: 0, totalDays: 0);
    return Age(years: years, months: months, totalDays: totalDays);
  }
}
