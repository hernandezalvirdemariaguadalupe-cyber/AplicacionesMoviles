import 'package:flutter/material.dart';

import '../save/codec.dart';

/// Muestra el contenido real del archivo de guardado con resaltado de sintaxis.
class SaveViewer extends StatelessWidget {
  const SaveViewer({super.key, required this.title, required this.content, required this.format, this.error});
  final String title;
  final String content;
  final SaveFormat format;
  final String? error;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final c = _Colors(dark);
    final lines = content.replaceAll('\r\n', '\n').split('\n');
    if (lines.isNotEmpty && lines.last.isEmpty) lines.removeLast();
    final mono = TextStyle(fontFamily: 'monospace', fontSize: 13, height: 1.45, color: c.plain);
    final scheme = Theme.of(context).colorScheme;
    final digits = '${lines.length}'.length;

    return Scaffold(
      appBar: AppBar(title: Text(title, overflow: TextOverflow.ellipsis)),
      body: Column(children: [
        Container(
          width: double.infinity,
          color: error == null ? scheme.secondaryContainer : scheme.errorContainer,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Text(
            error == null
                ? '${format.label} · ${lines.length} líneas · ${content.length} caracteres'
                : 'Archivo dañado: $error',
            style: TextStyle(color: error == null ? scheme.onSecondaryContainer : scheme.onErrorContainer),
          ),
        ),
        Expanded(
          child: content.trim().isEmpty
              ? const Center(child: Text('(archivo vacío)'))
              : SelectionArea(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: SizedBox(
                      width: 60.0 + 8.2 * lines.fold<int>(0, (m, l) => l.length > m ? l.length : m),
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        itemCount: lines.length,
                        itemBuilder: (_, i) => Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Container(
                            width: 10.0 * digits + 16,
                            padding: const EdgeInsets.only(right: 8),
                            child: Text('${i + 1}', textAlign: TextAlign.right, style: mono.copyWith(color: scheme.outline)),
                          ),
                          Text.rich(TextSpan(style: mono, children: _highlight(lines[i], c)), softWrap: false),
                        ]),
                      ),
                    ),
                  ),
                ),
        ),
      ]),
    );
  }

  List<TextSpan> _highlight(String line, _Colors c) => switch (format) {
        SaveFormat.json => _regex(line, _json, (m) {
            if (m.group(1) != null) return m.group(2) != null ? c.key : c.string;
            if (m.group(3) != null) return c.number;
            if (m.group(4) != null) return c.keyword;
            return c.punct;
          }),
        SaveFormat.xml => _regex(line, _xml, (m) {
            if (m.group(1) != null) return c.comment;
            if (m.group(2) != null) return c.keyword;
            if (m.group(3) != null) return c.tag;
            if (m.group(4) != null) return c.key;
            if (m.group(5) != null) return c.string;
            return c.punct;
          }),
        SaveFormat.txt => _txt(line, c),
      };

  static final _json = RegExp(r'("(?:[^"\\]|\\.)*")(\s*:)?|(-?\d+(?:\.\d+)?)|\b(true|false|null)\b|([{}\[\],:])');
  static final _xml = RegExp(r'(<!--.*?-->)|(<\?.*?\?>)|(</?[\w:.-]+|/?>)|([\w:.-]+)(?==)|("[^"]*")');

  static List<TextSpan> _regex(String s, RegExp re, Color Function(Match) color) {
    final out = <TextSpan>[];
    var last = 0;
    for (final m in re.allMatches(s)) {
      if (m.start > last) out.add(TextSpan(text: s.substring(last, m.start)));
      out.add(TextSpan(text: m.group(0), style: TextStyle(color: color(m))));
      last = m.end;
    }
    if (last < s.length) out.add(TextSpan(text: s.substring(last)));
    return out;
  }

  static List<TextSpan> _txt(String line, _Colors c) {
    if (RegExp(r'^\[[A-ZÁÉÍÓÚ]+\]$').hasMatch(line.trim())) {
      return [TextSpan(text: line, style: TextStyle(color: c.tag, fontWeight: FontWeight.bold))];
    }
    if (line.startsWith('# ')) return [TextSpan(text: line, style: TextStyle(color: c.comment, fontStyle: FontStyle.italic))];
    final i = line.indexOf('=');
    if (i > 0) {
      return [
        TextSpan(text: line.substring(0, i), style: TextStyle(color: c.key)),
        TextSpan(text: '=', style: TextStyle(color: c.punct)),
        TextSpan(text: line.substring(i + 1), style: TextStyle(color: c.string)),
      ];
    }
    if (line.contains(';')) {
      return [
        for (final (k, part) in line.split(';').indexed) ...[
          if (k > 0) TextSpan(text: ';', style: TextStyle(color: c.punct)),
          TextSpan(text: part, style: TextStyle(color: k == 1 ? c.keyword : (k == 4 ? c.string : c.number))),
        ]
      ];
    }
    return [TextSpan(text: line, style: TextStyle(color: c.tag))]; // filas del mapa
  }
}

class _Colors {
  final Color key, string, number, keyword, punct, tag, comment, plain;
  _Colors(bool dark)
      : key = dark ? const Color(0xFF9CDCFE) : const Color(0xFF6C1D45),
        string = dark ? const Color(0xFFCE9178) : const Color(0xFF0B7A0B),
        number = dark ? const Color(0xFFB5CEA8) : const Color(0xFF0550AE),
        keyword = dark ? const Color(0xFF569CD6) : const Color(0xFF8250DF),
        punct = dark ? const Color(0xFFD4D4D4) : const Color(0xFF57606A),
        tag = dark ? const Color(0xFF4EC9B0) : const Color(0xFF003366),
        comment = dark ? const Color(0xFF6A9955) : const Color(0xFF6E7781),
        plain = dark ? const Color(0xFFE0E0E0) : const Color(0xFF1F2328);
}
