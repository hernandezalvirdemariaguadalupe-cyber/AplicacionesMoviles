import 'dart:io';

import 'package:integration_test/integration_test_driver_extended.dart';

/// Guarda cada captura de pantalla de la prueba E2E como PNG.
Future<void> main() => integrationDriver(
  onScreenshot: (name, bytes, [args]) async {
    final file = File('integration_test/screenshots/$name.png');
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes);
    return true;
  },
);
