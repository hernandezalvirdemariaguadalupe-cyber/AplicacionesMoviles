import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:gestor_archivos_flutter/core/theme/theme_provider.dart';
import 'package:gestor_archivos_flutter/presentation/providers/file_manager_provider.dart';
import 'package:gestor_archivos_flutter/main.dart';

void main() {
  testWidgets('Verifica que la app FileManagerApp carga correctamente', (WidgetTester tester) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => ThemeProvider()),
          ChangeNotifierProvider(create: (_) => FileManagerProvider()),
        ],
        child: const FileManagerApp(),
      ),
    );
    expect(find.byType(FileManagerApp), findsOneWidget);
  });
}
