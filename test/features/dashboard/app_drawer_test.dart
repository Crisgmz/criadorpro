import 'package:criadorpro/core/config/app_config.dart';
import 'package:criadorpro/core/providers/providers.dart';
import 'package:criadorpro/features/auth/model/profile.dart';
import 'package:criadorpro/features/dashboard/view/widgets/app_drawer.dart';
import 'package:criadorpro/l10n/generated/app_l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Panel lateral — pantalla 37.
///
/// El perfil se inyecta ya resuelto en vez de dejar que salga de Drift: un
/// stream de base de datos vivo mantiene la prueba esperando hasta agotar el
/// tiempo, y aquí lo que se comprueba es lo que se pinta.
void main() {
  final profile = Profile(
    id: 'owner-1',
    plan: SubscriptionPlan.pro,
    createdAt: DateTime(2026, 8, 6),
    updatedAt: DateTime(2026, 8, 6),
    fullName: 'Ramón Peña',
    farmName: 'Criadero Los Pinos',
    location: 'Santiago',
  );

  Future<void> pumpDrawer(WidgetTester tester, {Profile? withProfile}) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [currentProfileProvider.overrideWith((ref) => Stream.value(withProfile))],
        child: MaterialApp(
          localizationsDelegates: AppL10n.localizationsDelegates,
          supportedLocales: AppL10n.supportedLocales,
          locale: const Locale('es'),
          home: const Scaffold(drawer: AppDrawer(), body: SizedBox()),
        ),
      ),
    );
    tester.state<ScaffoldState>(find.byType(Scaffold)).openDrawer();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  testWidgets('muestra el criadero y su ubicación', (tester) async {
    await pumpDrawer(tester, withProfile: profile);

    expect(find.text('Criadero Los Pinos'), findsOneWidget);
    expect(find.text('Santiago'), findsOneWidget);
  });

  testWidgets('RF-CTA-01 · comunica el plan vigente en la tarjeta de membresía', (tester) async {
    await pumpDrawer(tester, withProfile: profile);

    expect(find.text('MEMBRESÍA'), findsOneWidget);
    expect(find.text('Pro'), findsOneWidget);
    expect(find.text('Hasta 500 ejemplares'), findsOneWidget);
  });

  testWidgets('agrupa las entradas como el PRD', (tester) async {
    await pumpDrawer(tester, withProfile: profile);

    expect(find.text('MI CUENTA'), findsOneWidget);
    expect(find.text('INFO DE LA APP'), findsOneWidget);
    expect(find.text('Datos del criadero'), findsOneWidget);
  });

  _hamburgerGroup();

  testWidgets('sin perfil cae al nombre del producto en vez de quedar vacío', (tester) async {
    await pumpDrawer(tester);

    expect(find.text('Criador Pro'), findsOneWidget);
    // El plan por omisión es el más restrictivo mientras no se sepa.
    expect(find.text('Gratis'), findsOneWidget);
  });
}

/// El ☰ solo se dibuja si el `AppBar` encuentra un `drawer` en el `Scaffold`
/// más cercano. Con el panel declarado en el shell no bastaba: cada pestaña
/// trae su propio `Scaffold`, y el del shell le quedaba por debajo.
void _hamburgerGroup() {
  testWidgets('el AppBar dibuja el ☰ cuando su propio Scaffold trae drawer', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [currentProfileProvider.overrideWith((ref) => Stream.value(null))],
        child: MaterialApp(
          localizationsDelegates: AppL10n.localizationsDelegates,
          supportedLocales: AppL10n.supportedLocales,
          locale: const Locale('es'),
          home: Scaffold(
            drawer: const AppDrawer(),
            appBar: AppBar(title: const Text('Inicio')),
            body: const SizedBox(),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byIcon(Icons.menu), findsOneWidget);
  });

  testWidgets('sin drawer en su Scaffold no hay ☰ — el fallo que tenía', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          appBar: AppBar(title: const Text('Inicio')),
          body: const SizedBox(),
        ),
      ),
    );
    await tester.pump();

    expect(find.byIcon(Icons.menu), findsNothing);
  });
}
