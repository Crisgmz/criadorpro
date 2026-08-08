import 'package:criadorpro/core/utils/validators.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('RV-01 · correo', () {
    test('acepta un correo válido', () {
      expect(Validators.email('criador@ejemplo.do'), isNull);
    });

    test('rechaza el formato inválido', () {
      expect(Validators.email('criador'), ValidationError.email);
      expect(Validators.email('criador@'), ValidationError.email);
      expect(Validators.email('@ejemplo.do'), ValidationError.email);
    });

    test('rechaza vacío como campo obligatorio', () {
      expect(Validators.email('   '), ValidationError.required);
    });

    test('rechaza por encima de 254 caracteres', () {
      final long = '${'a' * 250}@ejemplo.do';
      expect(Validators.email(long), ValidationError.emailTooLong);
    });

    test('normaliza a minúsculas y recorta espacios antes de enviar', () {
      expect(Validators.normalizeEmail('  Criador@Ejemplo.DO '), 'criador@ejemplo.do');
    });

    test('valida sobre la forma normalizada, no sobre lo escrito', () {
      expect(Validators.email('  CRIADOR@EJEMPLO.DO  '), isNull);
    });
  });

  group('RV-02 · contraseña', () {
    test('acepta ocho caracteres con letra y número', () {
      expect(Validators.password('gallera1'), isNull);
    });

    test('rechaza menos de ocho caracteres', () {
      expect(Validators.password('gall1'), ValidationError.passwordTooShort);
    });

    test('rechaza sin número', () {
      expect(Validators.password('gallerita'), ValidationError.passwordNeedsLetterAndNumber);
    });

    test('rechaza sin letra', () {
      expect(Validators.password('12345678'), ValidationError.passwordNeedsLetterAndNumber);
    });
  });

  group('RV-03 · confirmación', () {
    test('exige coincidencia exacta', () {
      expect(Validators.passwordConfirmation('gallera1', 'gallera1'), isNull);
      expect(
        Validators.passwordConfirmation('gallera1', 'gallera2'),
        ValidationError.passwordMismatch,
      );
    });

    test('distingue mayúsculas', () {
      expect(
        Validators.passwordConfirmation('Gallera1', 'gallera1'),
        ValidationError.passwordMismatch,
      );
    });
  });

  group('RV-04 · código de verificación', () {
    test('acepta exactamente seis dígitos', () {
      expect(Validators.verificationCode('123456'), isNull);
    });

    test('rechaza longitudes distintas de seis', () {
      expect(Validators.verificationCode('12345'), ValidationError.codeIncomplete);
      expect(Validators.verificationCode('1234567'), ValidationError.codeIncomplete);
    });

    test('rechaza caracteres no numéricos', () {
      expect(Validators.verificationCode('12345a'), ValidationError.codeIncomplete);
    });
  });

  group('nombre completo · 2–80 caracteres', () {
    test('acepta dentro del rango', () {
      expect(Validators.fullName('Ramón Peña'), isNull);
    });

    test('rechaza fuera del rango', () {
      expect(Validators.fullName('R'), ValidationError.nameLength);
      expect(Validators.fullName('a' * 81), ValidationError.nameLength);
    });
  });

  group('teléfono opcional', () {
    test('acepta vacío: profiles.phone admite nulo', () {
      expect(Validators.optionalPhone(''), isNull);
      expect(Validators.optionalPhone(null), isNull);
    });

    test('acepta un número con formato de presentación', () {
      expect(Validators.optionalPhone('(809) 555-1234'), isNull);
    });

    test('rechaza cantidades de dígitos imposibles', () {
      expect(Validators.optionalPhone('123'), ValidationError.phoneInvalid);
      expect(Validators.optionalPhone('1' * 16), ValidationError.phoneInvalid);
    });
  });
}
