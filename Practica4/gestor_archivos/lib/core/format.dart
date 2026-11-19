/// Utilidades de formato para metadatos.
library;

const noDisponible = 'No disponible';

String formatSize(int? bytes) {
  if (bytes == null) return noDisponible;
  if (bytes < 1024) return '$bytes B';
  const units = ['KB', 'MB', 'GB', 'TB'];
  double v = bytes / 1024;
  var i = 0;
  while (v >= 1024 && i < units.length - 1) {
    v /= 1024;
    i++;
  }
  return '${v.toStringAsFixed(v < 10 ? 1 : 0)} ${units[i]}';
}

String two(int n) => n.toString().padLeft(2, '0');

String formatDate(DateTime? d) {
  if (d == null) return noDisponible;
  final l = d.toLocal();
  return '${two(l.day)}/${two(l.month)}/${l.year} ${two(l.hour)}:${two(l.minute)}';
}

/// Nombre válido en Android e iOS: no vacío, sin separadores ni caracteres reservados.
String? validateFileName(String? name) {
  final n = name?.trim() ?? '';
  if (n.isEmpty) return 'Escribe un nombre';
  if (n == '.' || n == '..') return 'Nombre no permitido';
  if (RegExp(r'[\\/:*?"<>|]').hasMatch(n)) return 'No uses \\ / : * ? " < > |';
  if (n.length > 200) return 'Nombre demasiado largo';
  return null;
}

/// Hash FNV-1a de 64 bits en hexadecimal (para nombres de caché sin dependencias).
String fnv1a(String input) {
  var hash = 0xcbf29ce484222325;
  const prime = 0x100000001b3;
  for (final c in input.codeUnits) {
    hash ^= c;
    hash = (hash * prime) & 0xFFFFFFFFFFFFFFFF;
  }
  return hash.toUnsigned(64).toRadixString(16);
}
