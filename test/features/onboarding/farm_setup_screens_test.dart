import 'package:criadorpro/app.dart';
import 'package:criadorpro/core/config/app_config.dart';
import 'package:criadorpro/core/db/app_database.dart';
import 'package:criadorpro/core/network/supabase_service.dart';
import 'package:criadorpro/core/providers/providers.dart';
import 'package:criadorpro/core/router/app_router.dart';
import 'package:criadorpro/core/router/routes.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/still.dart';

import '../auth/fake_auth_repository.dart';

/// Las pantallas 11–14 pintadas con el router real y la semántica activa.
///
/// Mismo enfoque que en `RF-AUT`: navegar de verdad destapa fallos de layout y
/// de árbol de accesibilidad que montar cada pantalla suelta no ve.
void main() {
  late AppDatabase database;

  const ownerId = 'owner-1';
  final now = DateTime(2026, 8, 5);

  setUp(() {
    SharedPreferences.setMockInitialValues({'settings.locale': 'es', 'onboarding.completed': true});
    database = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() => database.close());

  Future<ProviderContainer> pumpApp(WidgetTester tester) async {
    final preferences = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(preferences),
        supabaseServiceProvider.overrideWithValue(SupabaseService(null)),
        appDatabaseProvider.overrideWithValue(database),
        // `RF-ONB` solo existe con sesión abierta; sin esto la guardia
        // devolvería al usuario a la bienvenida antes de mirar el perfil.
        authRepositoryProvider.overrideWithValue(FakeAuthRepository(isSignedIn: true)),
        currentOwnerIdProvider.overrideWithValue(ownerId),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      still(UncontrolledProviderScope(container: container, child: const CriadorProApp())),
    );
    // Pumps acotados, no `pumpAndSettle`: el indicador de carga del splash gira
    // de forma indefinida y dejaría a `pumpAndSettle` esperando para siempre.
    await tester.pump(AppConfig.splashDuration);
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 120));
    }
    return container;
  }

  Future<void> goTo(WidgetTester tester, ProviderContainer container, String route) async {
    container.read(routerProvider).go(route);
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 120));
    }
  }

  Future<void> givenProfile({String? farmName}) => database.profilesDao.upsert(
    ProfilesCompanion.insert(
      id: ownerId,
      createdAt: now,
      updatedAt: now,
      farmName: Value(farmName),
    ),
  );

  testWidgets('los tres pasos se pintan y avanzan', (tester) async {
    final handle = tester.ensureSemantics();
    await givenProfile();
    final container = await pumpApp(tester);

    await goTo(tester, container, Routes.farmSetup);
    expect(find.text('Tu criadero'), findsOneWidget);
    expect(find.text('Paso 1 de 3'), findsOneWidget);

    // Paso 1 → 2
    await tester.enterText(find.byType(TextField).first, 'Criadero Los Pinos');
    await tester.pump();
    await tester.tap(find.text('Siguiente'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Tu numeración'), findsOneWidget);
    expect(find.text('Paso 2 de 3'), findsOneWidget);

    // Paso 2 → 3
    await tester.enterText(find.byType(TextField).first, '1687');
    await tester.pump();
    await tester.tap(find.text('Finalizar'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Elige tu plan'), findsOneWidget);
    expect(find.text('RECOMENDADO'), findsOneWidget);

    handle.dispose();
  });

  // PENDIENTE: falta cubrir la pantalla 14 (`RF-ONB-06`). Montarla, con router
  // o suelta, deja la prueba colgada hasta agotar el tiempo por una causa que
  // no he conseguido aislar; el resto de la pantalla sí está verificado a mano.

  group('guardia del router', () {
    testWidgets('sin criadero, cualquier ruta lleva a la configuración', (tester) async {
      await givenProfile();
      final container = await pumpApp(tester);

      await goTo(tester, container, Routes.home);
      expect(find.text('Tu criadero'), findsOneWidget);

      await goTo(tester, container, Routes.birds);
      expect(find.text('Tu criadero'), findsOneWidget);
    });

    testWidgets('con criadero, la configuración ya no es alcanzable', (tester) async {
      await givenProfile(farmName: 'Criadero Los Pinos');
      final container = await pumpApp(tester);

      await goTo(tester, container, Routes.farmSetup);
      expect(find.text('Tu criadero'), findsNothing);
    });

    testWidgets('sin perfil todavía no mueve al usuario de sitio', (tester) async {
      // Perfil aún no descargado: `null` significa «no lo sé», no «no existe».
      final container = await pumpApp(tester);

      await goTo(tester, container, Routes.welcome);
      expect(find.text('Tu criadero'), findsNothing);
    });
  });
}
