import 'package:flutter_test/flutter_test.dart';
import 'package:gestor_archivos/core/format.dart';
import 'package:gestor_archivos/data/models.dart';
import 'package:gestor_archivos/ui/viewers/syntax.dart';

void main() {
  test('formato de tamaños', () {
    expect(formatSize(null), noDisponible);
    expect(formatSize(512), '512 B');
    expect(formatSize(1536), '1.5 KB');
  });

  test('validación de nombres', () {
    expect(validateFileName(''), isNotNull);
    expect(validateFileName('a/b'), isNotNull);
    expect(validateFileName('notas.txt'), isNull);
  });

  test('detección de visor por extensión', () {
    FsEntry f(String n) => FsEntry(ref: '/x/$n', name: n, isDir: false);
    expect(f('a.json').viewer, ViewerKind.json);
    expect(f('a.xml').viewer, ViewerKind.xml);
    expect(f('a.md').viewer, ViewerKind.markdown);
    expect(f('a.txt').viewer, ViewerKind.text);
    expect(f('a.PNG').viewer, ViewerKind.image);
    expect(f('a.pdf').viewer, ViewerKind.unsupported);
  });

  test('JSON y XML: formateo y detección de errores', () {
    expect(Syntax.prettyJson('{"a":1}').error, isNull);
    expect(Syntax.prettyJson('{"a":').error, isNotNull);
    expect(Syntax.prettyXml('<a><b/></a>').error, isNull);
    expect(Syntax.prettyXml('<a><b></a>').error, isNotNull);
  });
}
