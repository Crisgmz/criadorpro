import 'package:criadorpro/core/config/app_config.dart';
import 'package:criadorpro/features/auth/model/profile.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Map<String, dynamic> remoteRow({Map<String, dynamic> overrides = const {}}) => {
    'id': 'owner-1',
    'email': 'criador@ejemplo.do',
    'full_name': 'Ramón Peña',
    'farm_name': 'Criadero Los Pinos',
    'location': 'Santiago, República Dominicana',
    'country_code': 'DO',
    'locale': 'es',
    'next_plate': 1687,
    'phone': '+18095551234',
    'avatar_url': 'https://ejemplo.do/avatar.jpg',
    'plan': 'pro',
    'plan_expires_at': '2027-01-01T00:00:00Z',
    'created_at': '2026-08-01T00:00:00Z',
    'updated_at': '2026-08-03T00:00:00Z',
    ...overrides,
  };

  group('lectura de la fila remota', () {
    test('mapea todos los campos del SRS', () {
      final profile = Profile.fromRemoteJson(remoteRow());

      expect(profile.id, 'owner-1');
      expect(profile.fullName, 'Ramón Peña');
      expect(profile.farmName, 'Criadero Los Pinos');
      expect(profile.location, 'Santiago, República Dominicana');
      expect(profile.countryCode, 'DO');
      expect(profile.locale, 'es');
      expect(profile.nextPlate, 1687);
      expect(profile.phone, '+18095551234');
      expect(profile.avatarUrl, 'https://ejemplo.do/avatar.jpg');
      expect(profile.plan, SubscriptionPlan.pro);
    });

    test('un perfil recién creado por el trigger arranca en la placa 1', () {
      final profile = Profile.fromRemoteJson(
        remoteRow(overrides: {'next_plate': 1, 'farm_name': null, 'plan': 'free'}),
      );

      expect(profile.nextPlate, 1);
      expect(profile.plan, SubscriptionPlan.free);
    });

    test('tolera que falte next_plate en una base sin migrar', () {
      final row = remoteRow()..remove('next_plate');

      expect(Profile.fromRemoteJson(row).nextPlate, 1);
    });
  });

  group('RF-ONB-01 · configuración pendiente', () {
    test('sin nombre de criadero el onboarding está pendiente', () {
      final profile = Profile.fromRemoteJson(remoteRow(overrides: {'farm_name': null}));

      expect(profile.isOnboardingComplete, isFalse);
    });

    test('un nombre en blanco no cuenta como completado', () {
      final profile = Profile.fromRemoteJson(remoteRow(overrides: {'farm_name': '   '}));

      expect(profile.isOnboardingComplete, isFalse);
    });

    test('con nombre de criadero está completo', () {
      expect(Profile.fromRemoteJson(remoteRow()).isOnboardingComplete, isTrue);
    });
  });

  group('escritura hacia el servidor', () {
    test('RS-12 · el cliente nunca manda su propio plan', () {
      final json = Profile.fromRemoteJson(remoteRow()).toRemoteJson();

      expect(json.containsKey('plan'), isFalse);
      expect(json.containsKey('plan_expires_at'), isFalse);
    });

    test('RS-01 · el contador de placas solo lo mueve la RPC del servidor', () {
      final json = Profile.fromRemoteJson(remoteRow()).toRemoteJson();

      expect(json.containsKey('next_plate'), isFalse);
    });

    test('manda los campos que el criador sí edita', () {
      final json = Profile.fromRemoteJson(remoteRow()).toRemoteJson();

      expect(json['farm_name'], 'Criadero Los Pinos');
      expect(json['location'], 'Santiago, República Dominicana');
      expect(json['country_code'], 'DO');
      expect(json['locale'], 'es');
      expect(json['phone'], '+18095551234');
    });

    test('updated_at viaja en UTC ISO 8601, que es la base de RS-09', () {
      final json = Profile.fromRemoteJson(remoteRow()).toRemoteJson();

      expect(DateTime.parse(json['updated_at'] as String).isUtc, isTrue);
    });
  });

  group('RS-12 · plan caducado', () {
    test('un plan de pago vencido se comporta como Gratis', () {
      final profile = Profile.fromRemoteJson(
        remoteRow(overrides: {'plan': 'elite', 'plan_expires_at': '2020-01-01T00:00:00Z'}),
      );

      expect(profile.plan, SubscriptionPlan.elite);
      expect(profile.effectivePlan, SubscriptionPlan.free);
    });

    test('el plan gratuito no caduca aunque no tenga fecha', () {
      final profile = Profile.fromRemoteJson(
        remoteRow(overrides: {'plan': 'free', 'plan_expires_at': null}),
      );

      expect(profile.effectivePlan, SubscriptionPlan.free);
    });
  });
}
