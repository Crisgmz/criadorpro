import 'dart:async';

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

/// Pantalla 29 pintada con el router real.
///
/// Contabilidad y empleomanía no ocupan pestaña (PRD §7): se abren apiladas y
/// no tienen barra inferior con la que volver. Eso las hace sensibles a dos
/// cosas que aquí se fijan — cómo se entra y cómo se sale.
void main() {
  late AppDatabase database;

  const ownerId = 'owner-1';
  final now = DateTime(2026, 8, 27);

  setUp(() {
    SharedPreferences.setMockInitialValues({'settings.locale': 'es', 'onboarding.completed': true});
    database = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() => database.close());

  // El módulo es de Pro en adelante (`RF-CON`): con plan gratuito la pantalla
  // muestra su aviso en vez del cierre del mes.
  Future<void> givenProfile() => database.profilesDao.upsert(
    ProfilesCompanion.insert(
      id: ownerId,
      createdAt: now,
      updatedAt: now,
      farmName: const Value('Criadero Los Pinos'),
      plan: const Value('pro'),
    ),
  );

  Future<void> givenTransaction() => database
      .into(database.transactions)
      .insert(
        TransactionsCompanion.insert(
          id: 't1',
          ownerId: ownerId,
          type: 'expense',
          category: 'feed',
          amountCents: 245050,
          date: now,
          createdAt: now,
          updatedAt: now,
        ),
      );

  Future<ProviderContainer> pumpApp(WidgetTester tester) async {
    final preferences = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(preferences),
        supabaseServiceProvider.overrideWithValue(SupabaseService(null)),
        appDatabaseProvider.overrideWithValue(database),
        authRepositoryProvider.overrideWithValue(FakeAuthRepository(isSignedIn: true)),
        currentOwnerIdProvider.overrideWithValue(ownerId),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      still(UncontrolledProviderScope(container: container, child: const CriadorProApp())),
    );
    // Pumps acotados y no `pumpAndSettle`: el indicador del splash gira sin fin.
    await tester.pump(AppConfig.splashDuration);
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 120));
    }
    return container;
  }

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 120));
    }
  }

  testWidgets('el mes vacío no repite la acción en el flotante', (tester) async {
    await givenProfile();
    final container = await pumpApp(tester);

    unawaited(container.read(routerProvider).push(Routes.accounting));
    await settle(tester);

    // El estado vacío ya la ofrece en el centro: dos botones idénticos a un
    // dedo de distancia es lo que había antes.
    expect(find.text('Registrar movimiento'), findsOneWidget);
    expect(find.byType(FloatingActionButton), findsNothing);
  });

  testWidgets('con movimientos, el flotante vuelve', (tester) async {
    await givenProfile();
    await givenTransaction();
    final container = await pumpApp(tester);

    unawaited(container.read(routerProvider).push(Routes.accounting));
    await settle(tester);

    // Aquí sí hace falta: la lista ocupa el sitio donde estaría la acción.
    expect(find.byType(FloatingActionButton), findsOneWidget);
  });

  testWidgets('abrir contabilidad desde el panel deja por dónde salir', (tester) async {
    await givenProfile();
    await pumpApp(tester);

    // Por el icono y no por el tooltip: el tooltip está traducido y la prueba
    // corre en español.
    await tester.tap(find.byIcon(Icons.menu));
    await settle(tester);
    await tester.tap(find.text('Contabilidad').last);
    await settle(tester);

    expect(find.text('agosto de 2026'), findsOneWidget, reason: 'se abrió contabilidad');

    // El panel navegaba con `go`, que sustituye la pila entera: la pantalla se
    // quedaba sin flecha y sin barra inferior, es decir, sin salida.
    expect(find.byType(BackButton), findsOneWidget);

    await tester.tap(find.byType(BackButton));
    await settle(tester);
    expect(find.text('agosto de 2026'), findsNothing, reason: 'la flecha vuelve a Inicio');
  });
}
