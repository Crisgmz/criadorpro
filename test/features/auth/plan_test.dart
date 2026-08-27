import 'package:criadorpro/core/config/app_config.dart';
import 'package:criadorpro/features/auth/model/profile.dart';
import 'package:flutter_test/flutter_test.dart';

/// `RS-12` — qué plan vale ahora mismo.
///
/// Es la regla que decide si un criadero puede crear ejemplares, abrir la
/// contabilidad o pagar la nómina. Equivocarla por un lado le cobra a quien no
/// paga; por el otro, le quita a quien sí pagó lo que acaba de comprar.
void main() {
  final now = DateTime(2026, 8, 27, 10);

  Profile profile({required SubscriptionPlan plan, DateTime? expiresAt}) => Profile(
    id: 'o1',
    plan: plan,
    nextPlate: 1,
    planExpiresAt: expiresAt,
    createdAt: now,
    updatedAt: now,
  );

  test('Free no vence nunca', () {
    final free = profile(plan: SubscriptionPlan.free);
    expect(free.effectivePlanAt(now.add(const Duration(days: 3650))), SubscriptionPlan.free);
  });

  test('un plan de pago sin vencimiento se respeta', () {
    // Es el caso de una cuenta puesta a mano para pruebas o soporte: sin fecha
    // no hay nada que caducar.
    final elite = profile(plan: SubscriptionPlan.elite);
    expect(elite.effectivePlanAt(now), SubscriptionPlan.elite);
  });

  test('vigente vale', () {
    final pro = profile(plan: SubscriptionPlan.pro, expiresAt: now.add(const Duration(days: 5)));
    expect(pro.effectivePlanAt(now), SubscriptionPlan.pro);
  });

  group('margen de 72 horas', () {
    final expiry = now.subtract(const Duration(hours: 1));
    final pro = profile(plan: SubscriptionPlan.pro, expiresAt: expiry);

    test('recién vencido sigue valiendo', () {
      // Una suscripción que se renueva sola vence antes de que llegue el recibo
      // nuevo: la tienda cobra y confirma con horas de retraso. Sin margen, el
      // criador pierde la contabilidad a media mañana y la recupera por la
      // tarde sin haber hecho nada.
      expect(pro.effectivePlanAt(now), SubscriptionPlan.pro);
    });

    test('justo antes de agotarse el margen todavía vale', () {
      final almost = expiry.add(AppConfig.planGracePeriod).subtract(const Duration(minutes: 1));
      expect(pro.effectivePlanAt(almost), SubscriptionPlan.pro);
    });

    test('pasado el margen degrada', () {
      final after = expiry.add(AppConfig.planGracePeriod).add(const Duration(minutes: 1));
      expect(pro.effectivePlanAt(after), SubscriptionPlan.free);
    });

    test('el margen son 72 horas, no las que salgan', () {
      expect(AppConfig.planGracePeriod, const Duration(hours: 72));
    });
  });

  test('el plan no viaja en el payload que manda el cliente', () {
    // `RS-12`: el plan lo escribe el servidor tras validar el recibo. Que el
    // cliente lo omita es la mitad; la otra es el disparador `lock_plan_columns`
    // en Postgres, porque la clave publicable es pública por diseño.
    final json = profile(
      plan: SubscriptionPlan.elite,
      expiresAt: now.add(const Duration(days: 30)),
    ).toRemoteJson();

    expect(json.containsKey('plan'), isFalse);
    expect(json.containsKey('plan_expires_at'), isFalse);
    expect(json.containsKey('next_plate'), isFalse);
  });
}
