import 'package:criadorpro/features/auth/view/widgets/otp_input.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late TextEditingController controller;
  late List<String> changes;
  late List<String> completions;

  setUp(() {
    controller = TextEditingController();
    changes = [];
    completions = [];
  });

  tearDown(() => controller.dispose());

  Future<void> pump(WidgetTester tester) => tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: OtpInput(
          controller: controller,
          semanticsLabel: 'Código de verificación de 6 dígitos',
          onChanged: changes.add,
          onCompleted: completions.add,
          autofocus: false,
        ),
      ),
    ),
  );

  testWidgets('pinta una casilla por dígito del código', (tester) async {
    await pump(tester);

    await tester.enterText(find.byType(TextField), '12');
    await tester.pump();

    expect(find.text('1'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
    // Las cuatro restantes siguen vacías.
    expect(find.text('3'), findsNothing);
  });

  testWidgets('RF-AUT-07 · pegar el código llena las seis casillas', (tester) async {
    await pump(tester);

    // `enterText` sustituye el contenido de golpe, que es justo lo que hace
    // pegar desde el portapapeles o el autorrelleno del sistema.
    await tester.enterText(find.byType(TextField), '123456');
    await tester.pump();

    for (final digit in ['1', '2', '3', '4', '5', '6']) {
      expect(find.text(digit), findsOneWidget);
    }
    expect(completions, ['123456']);
  });

  testWidgets('avisa del código completo una sola vez', (tester) async {
    await pump(tester);

    await tester.enterText(find.byType(TextField), '123456');
    await tester.pump();

    expect(completions, hasLength(1));
  });

  testWidgets('no admite más de seis dígitos', (tester) async {
    await pump(tester);

    await tester.enterText(find.byType(TextField), '12345678');
    await tester.pump();

    expect(controller.text, '123456');
  });

  testWidgets('descarta lo que no sean dígitos', (tester) async {
    await pump(tester);

    await tester.enterText(find.byType(TextField), '12a34b');
    await tester.pump();

    expect(controller.text, '1234');
    expect(completions, isEmpty);
  });

  testWidgets('borrar retira los dígitos y vuelve a notificar', (tester) async {
    await pump(tester);

    await tester.enterText(find.byType(TextField), '123456');
    await tester.pump();
    await tester.enterText(find.byType(TextField), '123');
    await tester.pump();

    expect(find.text('4'), findsNothing);
    expect(changes.last, '123');
  });

  testWidgets('expone la etiqueta accesible que recibe (RNF-26)', (tester) async {
    await pump(tester);

    expect(find.bySemanticsLabel('Código de verificación de 6 dígitos'), findsOneWidget);
  });
}
