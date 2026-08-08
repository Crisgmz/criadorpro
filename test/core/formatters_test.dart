import 'package:criadorpro/core/utils/formatters.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Formatters.age', () {
    test('cuenta años y meses cumplidos', () {
      final age = Formatters.age(DateTime(2023, 3, 10), now: DateTime(2026, 8, 1));
      expect(age.years, 3);
      expect(age.months, 4);
    });

    test('no cuenta el mes en curso hasta llegar al día', () {
      final age = Formatters.age(DateTime(2026, 1, 20), now: DateTime(2026, 8, 1));
      expect(age.years, 0);
      expect(age.months, 6);
      expect(age.isUnderOneYear, isTrue);
    });

    test('marca como recién nacido al que no llega al mes', () {
      final age = Formatters.age(DateTime(2026, 7, 20), now: DateTime(2026, 8, 1));
      expect(age.isNewborn, isTrue);
      expect(age.totalDays, 12);
    });

    test('devuelve cero ante una fecha futura en vez de números negativos', () {
      final age = Formatters.age(DateTime(2027), now: DateTime(2026, 8, 1));
      expect(age.years, 0);
      expect(age.months, 0);
      expect(age.totalDays, 0);
    });
  });
}
