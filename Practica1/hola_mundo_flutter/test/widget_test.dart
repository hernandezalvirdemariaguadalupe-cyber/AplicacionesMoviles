import 'package:flutter_test/flutter_test.dart';

import 'package:hola_mundo_flutter/main.dart';

void main() {
  testWidgets('Muestra el texto Hola Mundo', (WidgetTester tester) async {
    await tester.pumpWidget(const HolaMundoApp());

    expect(find.text('Hola Mundo'), findsOneWidget);
  });
}
