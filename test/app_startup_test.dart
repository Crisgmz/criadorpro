import 'package:criadorpro/app.dart';
import 'package:criadorpro/core/config/app_config.dart';
import 'package:criadorpro/core/db/app_database.dart';
import 'package:criadorpro/core/network/supabase_service.dart';
import 'package:criadorpro/core/providers/providers.dart';
import 'package:criadorpro/core/router/app_router.dart';
import 'package:criadorpro/core/router/routes.dart';
import 'package:criadorpro/core/widgets/brand.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Prueba de humo del arranque: valida que el árbol entero —tema, router,
/// traducciones y providers— se compone sin backend, y de paso comprueba las
/// tres derivaciones de `RF-AUT-01`.
void main() {
  late AppDatabase database;

  // El locale del entorno de pruebas es inglés; estas comprobaciones leen el
  // copy en español, que es el idioma origen del producto.
  const esLocale = {'settings.locale': 'es'};

  Future<ProviderScope> buildApp() async {
    final preferences = await SharedPreferences.getInstance();
    database = AppDatabase(NativeDatabase.memory());

    return ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(preferences),
        // Sin credenciales: la app debe arrancar igual en modo solo local.
        supabaseServiceProvider.overrideWithValue(SupabaseService(null)),
        appDatabaseProvider.overrideWithValue(database),
      ],
      child: const CriadorProApp(),
    );
  }

  tearDown(() => database.close());

  testWidgets('RF-AUT-01 · arranca en el splash', (tester) async {
    SharedPreferences.setMockInitialValues(esLocale);
    await tester.pumpWidget(await buildApp());

    // El nombre del producto va dentro del logotipo, no como texto suelto.
    expect(find.byType(BrandLockup), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    // Deja que el temporizador del splash termine antes de cerrar la prueba.
    await tester.pump(AppConfig.splashDuration);
    await tester.pumpAndSettle();
  });

  testWidgets('RF-AUT-01 · en el primer uso deriva al onboarding', (tester) async {
    SharedPreferences.setMockInitialValues(esLocale);
    await tester.pumpWidget(await buildApp());

    await tester.pump(AppConfig.splashDuration);
    await tester.pumpAndSettle();

    expect(find.text('Registra camadas completas en segundos'), findsOneWidget);
    expect(find.text('Saltar'), findsOneWidget);
  });

  testWidgets('RF-AUT-01 · con el onboarding visto deriva a bienvenida', (tester) async {
    SharedPreferences.setMockInitialValues({...esLocale, 'onboarding.completed': true});
    await tester.pumpWidget(await buildApp());

    await tester.pump(AppConfig.splashDuration);
    await tester.pumpAndSettle();

    expect(find.text('Bienvenido a Criador Pro'), findsOneWidget);
    // Sin backend configurado, el alta se bloquea con un aviso visible.
    expect(find.text('Crear cuenta'), findsOneWidget);
  });

  testWidgets('RF-AUT-02 · «Saltar» lleva a bienvenida y no vuelve a aparecer', (tester) async {
    SharedPreferences.setMockInitialValues(esLocale);
    await tester.pumpWidget(await buildApp());

    await tester.pump(AppConfig.splashDuration);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Saltar'));
    await tester.pumpAndSettle();

    expect(find.text('Bienvenido a Criador Pro'), findsOneWidget);

    final preferences = await SharedPreferences.getInstance();
    expect(preferences.getBool('onboarding.completed'), isTrue);
  });

  testWidgets('la guardia manda a bienvenida sin sesión', (tester) async {
    SharedPreferences.setMockInitialValues({...esLocale, 'onboarding.completed': true});
    await tester.pumpWidget(await buildApp());

    await tester.pump(AppConfig.splashDuration);
    await tester.pumpAndSettle();

    // Navegar a una ruta privada sin sesión debe rebotar a bienvenida.
    final context = tester.element(find.byType(Scaffold).first);
    ProviderScope.containerOf(context).read(routerProvider).go(Routes.home);
    await tester.pumpAndSettle();

    expect(find.text('Bienvenido a Criador Pro'), findsOneWidget);
  });
}
