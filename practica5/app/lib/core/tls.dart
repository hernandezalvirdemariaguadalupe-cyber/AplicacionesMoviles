import 'dart:io';

import 'package:flutter/services.dart';

/// Android 7.0 (API 24) no incluye la raíz "ISRG Root X1" de Let's Encrypt, que usan
/// openlibrary.org y covers.openlibrary.org: sin ella el handshake TLS falla y la app
/// muestra "Sin conexión". Se agrega esa raíz (pública, verificada por su huella SHA-256
/// 96:BC:EC:06:...:08:C6) al contexto TLS por defecto de Dart, que usan Dio e Image.network.
/// No se desactiva ninguna validación: sólo se amplía el conjunto de raíces de confianza.
Future<void> installExtraRootCertificates() async {
  if (!Platform.isAndroid) return;
  try {
    final pem = await rootBundle.load('assets/certs/isrg_root_x1.pem');
    SecurityContext.defaultContext.setTrustedCertificatesBytes(pem.buffer.asUint8List());
  } on TlsException {
    // En Android 7.1.1+ la raíz ya está instalada ("CERT_ALREADY_IN_HASH_TABLE"): no hay nada que hacer.
  }
}
