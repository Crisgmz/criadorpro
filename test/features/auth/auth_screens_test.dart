import 'package:criadorpro/app.dart';
import 'package:criadorpro/core/config/app_config.dart';
import 'package:criadorpro/core/db/app_database.dart';
import 'package:criadorpro/core/network/supabase_service.dart';
import 'package:criadorpro/core/providers/providers.dart';
import 'package:criadorpro/core/router/app_router.dart';
import 'package:criadorpro/core/router/routes.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/still.dart';

/// Recorre las pantallas de `RF-AUT` navegando con el router real y con el
/// árbol de semántica activo.
///
/// Cubre lo que las pruebas de ViewModel no ven: fallos de layout, asserts del
/// árbol de accesibilidad y pantallas que se quedan en blanco porque el `build`
/// reventó antes de dibujar. Se navega de verdad —no se monta cada pantalla
/// suelta— porque varios de esos fallos solo aparecen con la transición.
void main() {
  late AppDatabase database;

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
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      still(UncontrolledProviderScope(container: container, child: const CriadorProApp())),
    );
    await tester.pump(AppConfig.splashDuration);
    await tester.pumpAndSettle();
    return container;
  }

  Future<void> goTo(WidgetTester tester, ProviderContainer container, String route) async {
    container.read(routerProvider).go(route);
    await tester.pumpAndSettle();
  }

  void expectNotBlank() {
    expect(find.byType(Text), findsWidgets, reason: 'la pantalla salió en blanco');
  }

  testWidgets('el recorrido completo de RF-AUT se pinta sin excepciones', (tester) async {
    // Con la semántica activa se evalúa el árbol de accesibilidad en cada
    // frame; sin esto, un assert como `!semantics.parentDataDirty` no salta.
    final handle = tester.ensureSemantics();
    final container = await pumpApp(tester);

    final rutas = <String, String>{
      Routes.welcome: 'Bienvenido a Criador Pro',
      Routes.login: 'Recordarme',
      Routes.signUp: 'Nombre completo',
      Routes.recover: 'La recuperación es gratis, siempre.',
      Routes.recoverPassword: 'Guardar contraseña',
      Routes.verifyEmailFor('criador@ejemplo.do'): 'Verificar',
      Routes.recoverCodeFor('criador@ejemplo.do'): 'Verificar',
      Routes.onboarding: 'Saltar',
    };

    for (final entry in rutas.entries) {
      await goTo(tester, container, entry.key);
      expectNotBlank();
      expect(
        find.text(entry.value),
        findsWidgets,
        reason: 'no se pintó «${entry.value}» en ${entry.key}',
      );
    }

    handle.dispose();
  });

  testWidgets('se puede ir y volver entre bienvenida, login y recuperación', (tester) async {
    final handle = tester.ensureSemantics();
    final container = await pumpApp(tester);

    // Ida y vuelta repetida: es donde aparecen los fallos de árbol semántico
    // que un solo montaje no destapa.
    for (var i = 0; i < 3; i++) {
      await goTo(tester, container, Routes.login);
      expect(find.text('Recordarme'), findsOneWidget);

      await goTo(tester, container, Routes.recover);
      expect(find.text('Enviar código'), findsOneWidget);

      await goTo(tester, container, Routes.welcome);
      expect(find.text('Bienvenido a Criador Pro'), findsOneWidget);
    }

    handle.dispose();
  });

  testWidgets('las seis casillas aceptan el código con la semántica activa', (tester) async {
    final handle = tester.ensureSemantics();
    final container = await pumpApp(tester);

    await goTo(tester, container, Routes.verifyEmailFor('criador@ejemplo.do'));

    // Cinco dígitos, no seis: al completarlo se dispara la verificación, que
    // sin backend falla y limpia las casillas — correcto, pero aquí lo que se
    // comprueba es el pintado.
    await tester.enterText(find.byType(TextField).first, '12345');
    await tester.pumpAndSettle();

    for (final digit in ['1', '2', '3', '4', '5']) {
      expect(find.text(digit), findsOneWidget);
    }

    // Salir de la pantalla libera el ViewModel y con él la cuenta regresiva del
    // reenvío. Comprobarlo aquí vale por sí mismo: un temporizador que
    // sobrevive al widget es una fuga.
    await goTo(tester, container, Routes.welcome);

    handle.dispose();
  });
}
