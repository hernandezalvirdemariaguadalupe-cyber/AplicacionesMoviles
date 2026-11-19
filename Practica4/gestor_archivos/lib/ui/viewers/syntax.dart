import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:xml/xml.dart';

/// Paleta del resaltado; cambia según modo claro/oscuro para mantener contraste.
class SyntaxColors {
  final Color key, string, number, keyword, punct, tag, attr, comment, plain;
  const SyntaxColors({
    required this.key,
    required this.string,
    required this.number,
    required this.keyword,
    required this.punct,
    required this.tag,
    required this.attr,
    required this.comment,
    required this.plain,
  });

  factory SyntaxColors.of(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return dark
        ? const SyntaxColors(
            key: Color(0xFF9CDCFE),
            string: Color(0xFFCE9178),
            number: Color(0xFFB5CEA8),
            keyword: Color(0xFF569CD6),
            punct: Color(0xFFD4D4D4),
            tag: Color(0xFF4EC9B0),
            attr: Color(0xFF9CDCFE),
            comment: Color(0xFF6A9955),
            plain: Color(0xFFE0E0E0))
        : const SyntaxColors(
            key: Color(0xFF6C1D45),
            string: Color(0xFF0B7A0B),
            number: Color(0xFF0550AE),
            keyword: Color(0xFF8250DF),
            punct: Color(0xFF57606A),
            tag: Color(0xFF003366),
            attr: Color(0xFF953800),
            comment: Color(0xFF6E7781),
            plain: Color(0xFF1F2328));
  }
}

/// Resultado de preparar un documento estructurado para mostrarlo.
class Formatted {
  final String text;
  final String? error; // null si el documento es válido
  const Formatted(this.text, this.error);
}

class Syntax {
  static Formatted prettyJson(String raw) {
    try {
      final obj = jsonDecode(raw);
      return Formatted(const JsonEncoder.withIndent('  ').convert(obj), null);
    } on FormatException catch (e) {
      return Formatted(raw, 'JSON no válido: ${e.message}${e.offset != null ? ' (posición ${e.offset})' : ''}');
    }
  }

  static Formatted prettyXml(String raw) {
    try {
      final doc = XmlDocument.parse(raw);
      return Formatted(doc.toXmlString(pretty: true, indent: '  '), null);
    } on XmlException catch (e) {
      return Formatted(raw, 'XML no válido: ${e.message}');
    }
  }

  // ------------------------------------------------------------------ JSON

  static final _jsonToken = RegExp(
    r'("(?:[^"\\]|\\.)*")(\s*:)?|(-?\d+(?:\.\d+)?(?:[eE][+-]?\d+)?)|\b(true|false|null)\b|([{}\[\],:])',
  );

  static List<TextSpan> json(String text, SyntaxColors c) {
    final spans = <TextSpan>[];
    var last = 0;
    for (final m in _jsonToken.allMatches(text)) {
      if (m.start > last) spans.add(TextSpan(text: text.substring(last, m.start)));
      if (m.group(1) != null) {
        final isKey = m.group(2) != null;
        spans.add(TextSpan(
            text: m.group(1),
            style: TextStyle(color: isKey ? c.key : c.string, fontWeight: isKey ? FontWeight.w600 : null)));
        if (isKey) spans.add(TextSpan(text: m.group(2), style: TextStyle(color: c.punct)));
      } else if (m.group(3) != null) {
        spans.add(TextSpan(text: m.group(3), style: TextStyle(color: c.number)));
      } else if (m.group(4) != null) {
        spans.add(TextSpan(text: m.group(4), style: TextStyle(color: c.keyword, fontWeight: FontWeight.w600)));
      } else {
        spans.add(TextSpan(text: m.group(5), style: TextStyle(color: c.punct)));
      }
      last = m.end;
    }
    if (last < text.length) spans.add(TextSpan(text: text.substring(last)));
    return spans;
  }

  // ------------------------------------------------------------------ XML

  static final _xmlToken = RegExp(
    r'(<!--[\s\S]*?-->)|(<!\[CDATA\[[\s\S]*?\]\]>)|(<\?[\s\S]*?\?>)|(<\/?)([\w:.-]+)([^>]*?)(\/?>)',
  );
  static final _attr = RegExp(r'''([\w:.-]+)(\s*=\s*)("[^"]*"|'[^']*')''');

  static List<TextSpan> xml(String text, SyntaxColors c) {
    final spans = <TextSpan>[];
    var last = 0;
    for (final m in _xmlToken.allMatches(text)) {
      if (m.start > last) {
        spans.add(TextSpan(text: text.substring(last, m.start), style: TextStyle(color: c.plain)));
      }
      if (m.group(1) != null) {
        spans.add(TextSpan(text: m.group(1), style: TextStyle(color: c.comment, fontStyle: FontStyle.italic)));
      } else if (m.group(2) != null) {
        spans.add(TextSpan(text: m.group(2), style: TextStyle(color: c.string)));
      } else if (m.group(3) != null) {
        spans.add(TextSpan(text: m.group(3), style: TextStyle(color: c.keyword)));
      } else {
        spans.add(TextSpan(text: m.group(4), style: TextStyle(color: c.punct)));
        spans.add(TextSpan(text: m.group(5), style: TextStyle(color: c.tag, fontWeight: FontWeight.w600)));
        final attrs = m.group(6)!;
        var a = 0;
        for (final am in _attr.allMatches(attrs)) {
          if (am.start > a) spans.add(TextSpan(text: attrs.substring(a, am.start)));
          spans.add(TextSpan(text: am.group(1), style: TextStyle(color: c.attr)));
          spans.add(TextSpan(text: am.group(2), style: TextStyle(color: c.punct)));
          spans.add(TextSpan(text: am.group(3), style: TextStyle(color: c.string)));
          a = am.end;
        }
        if (a < attrs.length) spans.add(TextSpan(text: attrs.substring(a)));
        spans.add(TextSpan(text: m.group(7), style: TextStyle(color: c.punct)));
      }
      last = m.end;
    }
    if (last < text.length) spans.add(TextSpan(text: text.substring(last), style: TextStyle(color: c.plain)));
    return spans;
  }

  // ------------------------------------------------------------------ Markdown (resaltado ligero)

  static List<TextSpan> markdown(String text, SyntaxColors c) {
    final spans = <TextSpan>[];
    for (final line in const LineSplitter().convert(text)) {
      if (line.startsWith('#')) {
        final level = line.indexOf(RegExp(r'[^#]'));
        spans.add(TextSpan(
            text: line,
            style: TextStyle(color: c.key, fontWeight: FontWeight.bold, fontSize: level <= 1 ? 20 : level == 2 ? 17 : 15)));
      } else if (line.startsWith('>')) {
        spans.add(TextSpan(text: line, style: TextStyle(color: c.comment, fontStyle: FontStyle.italic)));
      } else if (RegExp(r'^\s*([-*+]|\d+\.)\s').hasMatch(line)) {
        final m = RegExp(r'^(\s*(?:[-*+]|\d+\.)\s)(.*)$').firstMatch(line)!;
        spans.add(TextSpan(text: m.group(1), style: TextStyle(color: c.keyword, fontWeight: FontWeight.bold)));
        spans.addAll(_inlineMd(m.group(2)!, c));
      } else {
        spans.addAll(_inlineMd(line, c));
      }
      spans.add(const TextSpan(text: '\n'));
    }
    return spans;
  }

  static final _inline = RegExp(r'(\*\*[^*]+\*\*)|(`[^`]+`)|(\*[^*]+\*|_[^_]+_)');

  static List<TextSpan> _inlineMd(String s, SyntaxColors c) {
    final out = <TextSpan>[];
    var last = 0;
    for (final m in _inline.allMatches(s)) {
      if (m.start > last) out.add(TextSpan(text: s.substring(last, m.start)));
      if (m.group(1) != null) {
        out.add(TextSpan(text: m.group(1), style: const TextStyle(fontWeight: FontWeight.bold)));
      } else if (m.group(2) != null) {
        out.add(TextSpan(text: m.group(2), style: TextStyle(color: c.string, fontFamily: 'monospace')));
      } else {
        out.add(TextSpan(text: m.group(3), style: const TextStyle(fontStyle: FontStyle.italic)));
      }
      last = m.end;
    }
    if (last < s.length) out.add(TextSpan(text: s.substring(last)));
    return out;
  }
}
