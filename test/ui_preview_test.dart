import 'dart:io';

import 'package:criadorpro/core/domain/bird_traits.dart';
import 'package:criadorpro/core/domain/markings.dart';
import 'package:criadorpro/core/domain/sex.dart';
import 'package:criadorpro/core/providers/providers.dart';
import 'package:criadorpro/core/theme/app_theme.dart';
import 'package:criadorpro/core/widgets/cp_alert.dart';
import 'package:criadorpro/core/widgets/motion.dart';
import 'package:criadorpro/features/birds/model/bird.dart';
import 'package:criadorpro/features/birds/view/bird_detail_view.dart';
import 'package:criadorpro/features/birds/view/birds_list_view.dart';
import 'package:criadorpro/features/birds/view/widgets/marking_fields.dart';
import 'package:criadorpro/features/birds/view/widgets/trait_picker.dart';
import 'package:criadorpro/l10n/generated/app_l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Capturas de los controles nuevos, para revisarlos con el ojo y no solo con
/// `expect`. Se regeneran con `flutter test --update-goldens`.
///
/// No son pruebas de regresión visual: son el sustituto de abrir la app cuando
/// el widget vive detrás de autenticación y de una base con datos.
String _flutterRoot() {
  var dir = File(Platform.resolvedExecutable).parent;
  while (dir.path != dir.parent.path) {
    if (Directory('${dir.path}/bin/cache/artifacts/material_fonts').existsSync()) return dir.path;
    dir = dir.parent;
  }
  return '';
}

void main() {
  Widget host(Widget child, {Brightness brightness = Brightness.light}) => ProviderScope(
    overrides: [
      currentOwnerIdProvider.overrideWithValue('owner-1'),
      traitOptionsProvider.overrideWith(
        (ref, args) => Stream.value(
          buildTraitOptions(
            trait: args.trait,
            inUse: args.trait == BirdTrait.plumage
                ? const {'Cenizo': 211, 'Canelo': 23, 'Blanco': 9, 'Céspedes': 1}
                : const {'Rosa': 702, 'Peine': 644, 'Pava': 82, 'Motón': 46},
          ),
        ),
      ),
    ],
    child: MaterialApp(
      theme: brightness == Brightness.light ? AppTheme.light : AppTheme.dark,
      locale: const Locale('es'),
      localizationsDelegates: const [
        AppL10n.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppL10n.supportedLocales,
      home: Scaffold(
        body: SafeArea(
          child: SingleChildScrollView(padding: const EdgeInsets.all(16), child: child),
        ),
      ),
    ),
  );

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();

    // Sin esto, las capturas salen con la fuente de prueba —bloques negros— y
    // no sirven para juzgar el diseño, que es justo para lo que están.
    final loader = FontLoader('Inter');
    for (final weight in ['Regular', 'SemiBold', 'Bold']) {
      loader.addFont(
        File('assets/fonts/Inter-$weight.ttf').readAsBytes().then(ByteData.sublistView),
      );
    }
    await loader.load();

    // Y los iconos: sin ellos las capturas salen con cuadrados vacíos donde va
    // la equis de cerrar o el chevrón.
    final icons = Platform.environment['FLUTTER_ROOT'] ?? _flutterRoot();
    final iconFile = File('$icons/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf');
    if (iconFile.existsSync()) {
      await (FontLoader(
        'MaterialIcons',
      )..addFont(iconFile.readAsBytes().then(ByteData.sublistView))).load();
    }
  });

  testWidgets('marca de nacimiento · sin marcar', (tester) async {
    tester.view
      ..physicalSize = const Size(390 * 3, 700 * 3)
      ..devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(host(BirthMarkPicker(value: null, onChanged: (_) {})));
    await tester.pumpAndSettle();

    await expectLater(find.byType(BirthMarkPicker), matchesGoldenFile('goldens/marca_vacia.png'));
  });

  testWidgets('marca de nacimiento · con 1 y 4, como el prototipo', (tester) async {
    tester.view
      ..physicalSize = const Size(390 * 3, 700 * 3)
      ..devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(host(BirthMarkPicker(value: '1,4', onChanged: (_) {})));
    await tester.pumpAndSettle();

    await expectLater(find.byType(BirthMarkPicker), matchesGoldenFile('goldens/marca_1_4.png'));
  });

  testWidgets('cintas de ala', (tester) async {
    tester.view
      ..physicalSize = const Size(390 * 3, 500 * 3)
      ..devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      host(
        WingBandPicker(
          left: WingBand.red,
          right: WingBand.blue,
          onLeftChanged: (_) {},
          onRightChanged: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    await expectLater(find.byType(WingBandPicker), matchesGoldenFile('goldens/cintas.png'));
  });

  testWidgets('campos de plumaje y cresta', (tester) async {
    tester.view
      ..physicalSize = const Size(390 * 3, 400 * 3)
      ..devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      host(
        Column(
          children: [
            TraitField(trait: BirdTrait.plumage, value: 'Cenizo', onChanged: (_) {}),
            const SizedBox(height: 16),
            TraitField(trait: BirdTrait.comb, value: null, onChanged: (_) {}),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    await expectLater(find.byType(Column).first, matchesGoldenFile('goldens/campos_rasgos.png'));
  });

  testWidgets('hoja de selección de plumaje', (tester) async {
    tester.view
      ..physicalSize = const Size(390 * 3, 800 * 3)
      ..devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      host(TraitField(trait: BirdTrait.plumage, value: 'Cenizo', onChanged: (_) {})),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byType(TraitField));
    await tester.pumpAndSettle();

    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/hoja_plumaje.png'));
  });

  testWidgets('cabecera navy de la ficha', (tester) async {
    tester.view
      ..physicalSize = const Size(390 * 3, 320 * 3)
      ..devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    final bird = Bird(
      id: 'b1',
      ownerId: 'o1',
      plate: 1188,
      name: 'Giro Colorado',
      line: 'Línea Sabanera',
      sex: Sex.male,
      status: BirdStatus.active,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [currentOwnerIdProvider.overrideWithValue('o1')],
        child: MaterialApp(
          theme: AppTheme.light,
          locale: const Locale('es'),
          localizationsDelegates: const [
            AppL10n.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppL10n.supportedLocales,
          home: Scaffold(
            body: Column(
              children: [
                BirdRecordHeader(bird: bird, onClose: () {}, onEdit: () {}, onDelete: () {}),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    await expectLater(
      find.byType(BirdRecordHeader),
      matchesGoldenFile('goldens/ficha_cabecera.png'),
    );
  });

  testWidgets('marca de nacimiento en oscuro', (tester) async {
    tester.view
      ..physicalSize = const Size(390 * 3, 700 * 3)
      ..devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      host(
        BirthMarkPicker(value: '1,5', onChanged: (_) {}),
        brightness: Brightness.dark,
      ),
    );
    await tester.pumpAndSettle();

    await expectLater(find.byType(BirthMarkPicker), matchesGoldenFile('goldens/marca_oscuro.png'));
  });

  testWidgets('aviso en línea · los tres tonos', (tester) async {
    tester.view
      ..physicalSize = const Size(390 * 3, 320 * 3)
      ..devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      host(
        const Column(
          children: [
            CpAlert(message: 'Correo o contraseña incorrectos.'),
            CpAlert(
              message: 'Te quedan 5 ejemplares de los 25 de tu plan.',
              tone: CpAlertTone.warning,
            ),
            CpAlert(
              message: 'Sin conexión. Todo lo que registres se guarda igual.',
              tone: CpAlertTone.info,
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    await expectLater(find.byType(Column).first, matchesGoldenFile('goldens/aviso.png'));
  });

  testWidgets('confirmación · disco y palomita dibujada', (tester) async {
    tester.view
      ..physicalSize = const Size(390 * 3, 260 * 3)
      ..devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: const ColoredBox(
          color: Color(0xFF0E2A47),
          child: Center(
            child: CpPop(
              child: SizedBox(
                height: 110,
                width: 110,
                child: DecoratedBox(
                  decoration: BoxDecoration(color: Color(0x14FFFFFF), shape: BoxShape.circle),
                  child: Center(
                    child: SizedBox(
                      height: 78,
                      width: 78,
                      child: DecoratedBox(
                        decoration: BoxDecoration(color: Color(0xFF1E7A4C), shape: BoxShape.circle),
                        child: Center(child: CpDrawCheck(color: Colors.white, size: 40)),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await expectLater(find.byType(CpPop), matchesGoldenFile('goldens/confirmacion.png'));
  });

  testWidgets('lista de ejemplares · fila', (tester) async {
    tester.view
      ..physicalSize = const Size(390 * 3, 560 * 3)
      ..devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    Bird bird(int plate, String name, String line, Sex sex, BirdStatus status, String? band) =>
        Bird(
          id: 'b$plate',
          ownerId: 'o1',
          plate: plate,
          name: name,
          line: line,
          sex: sex,
          status: status,
          wingBandLeft: band,
          createdAt: DateTime(2026),
          updatedAt: DateTime(2026),
        );

    await tester.pumpWidget(
      host(
        BirdsListPreview(
          birds: [
            bird(1688, 'Giro Pinta', 'Criadero Los Pinos', Sex.male, BirdStatus.active, 'red'),
            bird(1687, 'Canela', 'Criadero Los Pinos', Sex.female, BirdStatus.active, 'blue'),
            bird(1402, 'Blanca Real', 'Criadero Los Pinos', Sex.female, BirdStatus.active, null),
            bird(1355, 'Cenizo', 'El Chino Domínguez', Sex.male, BirdStatus.sold, 'yellow'),
            bird(1301, 'Pinto Bravo', 'Criadero Pitón', Sex.male, BirdStatus.deceased, 'red'),
            bird(1290, 'Giro Colorado', 'Criadero Los Pinos', Sex.male, BirdStatus.loaned, 'green'),
            bird(1188, 'Sabanero', 'Criadero Los Pinos', Sex.male, BirdStatus.active, 'pink'),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(BirdsListPreview),
      matchesGoldenFile('goldens/lista_ejemplares.png'),
    );
  });
}
