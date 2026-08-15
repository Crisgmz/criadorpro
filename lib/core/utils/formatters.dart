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
