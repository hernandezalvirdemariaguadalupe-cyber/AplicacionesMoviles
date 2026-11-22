import 'dart:math';

import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../game/model.dart';

/// Partícula de burbuja reventada (efecto visual).
class Pop {
  final Offset cell; // en coordenadas de casilla
  final double born; // segundos
  const Pop(this.cell, this.born);
}

/// Dibuja el canal, los elementos y al ajolote. Todo es vectorial (sin imágenes).
class BoardPainter extends CustomPainter {
  BoardPainter({
    required this.state,
    required this.player,
    required this.facing,
    required this.time,
    required this.pops,
    required this.colors,
    required this.flash,
    required this.repaintKey,
  });

  final GameState state;
  final Offset player; // posición animada del ajolote (en casillas)
  final Dir facing;
  final double time; // segundos, para animaciones continuas
  final List<Pop> pops;
  final BoardColors colors;
  final double flash; // 0..1 destello rojo de daño
  final int repaintKey;

  @override
  void paint(Canvas canvas, Size size) {
    final cs = size.width / state.width;
    final rect = Offset.zero & size;
    canvas.save();
    canvas.clipRRect(RRect.fromRectAndRadius(rect, Radius.circular(cs * 0.3)));

    // Agua con degradado y ondas
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [colors.water, colors.waterDeep],
        ).createShader(rect),
    );
    final wave = Paint()
      ..color = Colors.white.withValues(alpha: 0.08)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    for (var y = 0; y < state.height; y++) {
      final path = Path();
      for (var x = 0.0; x <= size.width; x += 8) {
        final yy = (y + 0.5) * cs + sin(x / 22 + time * 1.6 + y) * 3;
        x == 0 ? path.moveTo(x, yy) : path.lineTo(x, yy);
      }
      canvas.drawPath(path, wave);
    }

    // Cuadrícula opcional
    if (state.settings.showGrid) {
      final g = Paint()
        ..color = colors.grid
        ..strokeWidth = 1;
      for (var x = 1; x < state.width; x++) {
        canvas.drawLine(Offset(x * cs, 0), Offset(x * cs, size.height), g);
      }
      for (var y = 1; y < state.height; y++) {
        canvas.drawLine(Offset(0, y * cs), Offset(size.width, y * cs), g);
      }
    }

    for (var y = 0; y < state.height; y++) {
      for (var x = 0; x < state.width; x++) {
        final c = Offset((x + 0.5) * cs, (y + 0.5) * cs);
        switch (state.grid[y][x]) {
          case Tile.rock:
            _rock(canvas, Rect.fromLTWH(x * cs, y * cs, cs, cs), x, y);
          case Tile.bubble:
            _bubble(canvas, c + Offset(0, sin(time * 2.5 + x + y) * cs * 0.05), cs * 0.26);
          case Tile.whirlpool:
            _whirl(canvas, c, cs * 0.42);
          case Tile.exit:
            _exit(canvas, Rect.fromLTWH(x * cs, y * cs, cs, cs), state.bubblesLeft == 0);
          case Tile.currentUp || Tile.currentDown || Tile.currentLeft || Tile.currentRight:
            _current(canvas, c, cs, state.grid[y][x].push!);
          case Tile.empty:
            break;
        }
      }
    }

    // Marca del punto de inicio
    final st = Offset((state.start.x + 0.5) * cs, (state.start.y + 0.5) * cs);
    canvas.drawCircle(
        st,
        cs * 0.36,
        Paint()
          ..color = Colors.white.withValues(alpha: 0.25)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2);

    // Partículas
    for (final p in pops) {
      final age = time - p.born;
      if (age < 0 || age > 0.6) continue;
      final k = age / 0.6;
      final center = Offset((p.cell.dx + 0.5) * cs, (p.cell.dy + 0.5) * cs);
      final paint = Paint()..color = colors.bubble.withValues(alpha: 1 - k);
      for (var i = 0; i < 8; i++) {
        final a = i * pi / 4;
        canvas.drawCircle(center + Offset(cos(a), sin(a)) * (cs * 0.5 * k), cs * 0.07 * (1 - k) + 1, paint);
      }
      canvas.drawCircle(
          center,
          cs * 0.3 * (1 + k),
          Paint()
            ..color = colors.bubble.withValues(alpha: 0.6 * (1 - k))
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2);
    }

    // Ajolote
    _axolotl(canvas, Offset((player.dx + 0.5) * cs, (player.dy + 0.5) * cs), cs);

    // Destello de daño
    if (flash > 0) {
      canvas.drawRect(rect, Paint()..color = Colors.red.withValues(alpha: 0.35 * flash));
    }
    canvas.restore();
  }

  void _rock(Canvas c, Rect r, int x, int y) {
    final rr = RRect.fromRectAndRadius(r.deflate(1.5), Radius.circular(r.width * 0.28));
    c.drawRRect(rr, Paint()..color = colors.rockEdge);
    c.drawRRect(rr.deflate(r.width * 0.08), Paint()..color = colors.rock);
    // Musgo de chinampa
    if ((x * 7 + y * 3) % 3 == 0) {
      c.drawCircle(r.topLeft + Offset(r.width * 0.3, r.height * 0.3), r.width * 0.12,
          Paint()..color = const Color(0xFF7CB342).withValues(alpha: 0.8));
    }
  }

  void _bubble(Canvas c, Offset o, double r) {
    c.drawCircle(o, r, Paint()..color = colors.bubble.withValues(alpha: 0.35));
    c.drawCircle(
        o,
        r,
        Paint()
          ..color = colors.bubble
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2);
    c.drawCircle(o + Offset(-r * 0.35, -r * 0.35), r * 0.25, Paint()..color = Colors.white.withValues(alpha: 0.9));
  }

  void _whirl(Canvas c, Offset o, double r) {
    final paint = Paint()
      ..color = colors.whirl
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    for (var arm = 0; arm < 3; arm++) {
      final path = Path();
      for (var i = 0; i <= 24; i++) {
        final t = i / 24;
        final a = time * 4 + arm * 2 * pi / 3 + t * 2.5 * pi;
        final p = o + Offset(cos(a), sin(a)) * (r * (1 - t * 0.85));
        i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
      }
      c.drawPath(path, paint);
    }
  }

  void _current(Canvas c, Offset o, double cs, Dir d) {
    final paint = Paint()
      ..color = colors.current.withValues(alpha: 0.9)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    final dir = Offset(d.dx.toDouble(), d.dy.toDouble());
    final perp = Offset(-dir.dy, dir.dx);
    for (var i = 0; i < 2; i++) {
      final shift = ((time * 1.5 + i * 0.5) % 1.0 - 0.5) * cs * 0.6;
      final tip = o + dir * (shift + cs * 0.12);
      c.drawLine(tip, tip - dir * cs * 0.18 + perp * cs * 0.16, paint);
      c.drawLine(tip, tip - dir * cs * 0.18 - perp * cs * 0.16, paint);
    }
  }

  void _exit(Canvas c, Rect r, bool open) {
    final color = open ? colors.exitOpen : colors.exitClosed;
    final glow = open ? (0.5 + 0.5 * sin(time * 4)) : 0.0;
    if (open) {
      c.drawCircle(r.center, r.width * (0.45 + glow * 0.08), Paint()..color = color.withValues(alpha: 0.25));
    }
    final door = RRect.fromRectAndCorners(
      Rect.fromLTWH(r.left + r.width * 0.18, r.top + r.height * 0.12, r.width * 0.64, r.height * 0.76),
      topLeft: Radius.circular(r.width * 0.32),
      topRight: Radius.circular(r.width * 0.32),
    );
    c.drawRRect(door, Paint()..color = color);
    if (!open) {
      final bar = Paint()
        ..color = Colors.black.withValues(alpha: 0.35)
        ..strokeWidth = 3;
      for (var i = 1; i < 4; i++) {
        final x = door.left + door.width * i / 4;
        c.drawLine(Offset(x, door.top + 4), Offset(x, door.bottom - 2), bar);
      }
    } else {
      final tp = TextPainter(
        text: TextSpan(text: '★', style: TextStyle(color: Colors.white, fontSize: r.width * 0.38)),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(c, r.center - Offset(tp.width / 2, tp.height / 2));
    }
  }

  void _axolotl(Canvas c, Offset o, double cs) {
    final body = BoardColors.axolotl(state.settings.axolotlColor);
    final dark = Color.lerp(body, Colors.black, 0.35)!;
    final angle = switch (facing) { Dir.right => 0.0, Dir.down => pi / 2, Dir.left => pi, Dir.up => -pi / 2 };
    final wobble = sin(time * 6) * 0.08;
    c.save();
    c.translate(o.dx, o.dy);
    c.rotate(angle);
    final s = cs / 100;
    // Cola
    final tail = Path()
      ..moveTo(-18 * s, 0)
      ..quadraticBezierTo(-40 * s, (-10 + wobble * 60) * s, -46 * s, wobble * 80 * s)
      ..quadraticBezierTo(-40 * s, (10 + wobble * 60) * s, -18 * s, 0);
    c.drawPath(tail, Paint()..color = body);
    // Cuerpo y patas
    final legs = Paint()..color = dark;
    for (final sx in [-8.0, 10.0]) {
      for (final sy in [-1.0, 1.0]) {
        c.drawOval(Rect.fromCenter(center: Offset(sx * s, sy * (14 + wobble * 20) * s), width: 8 * s, height: 12 * s), legs);
      }
    }
    c.drawOval(Rect.fromCenter(center: Offset(0, 0), width: 44 * s, height: 26 * s), Paint()..color = body);
    // Cabeza
    final head = Offset(24 * s, 0);
    c.drawOval(Rect.fromCenter(center: head, width: 30 * s, height: 30 * s), Paint()..color = body);
    // Branquias (tres a cada lado)
    final gill = Paint()
      ..color = const Color(0xFFE04F7A)
      ..strokeWidth = 4 * s
      ..strokeCap = StrokeCap.round;
    for (final side in [-1.0, 1.0]) {
      for (var i = 0; i < 3; i++) {
        final a = side * (0.6 + i * 0.45) + wobble;
        final start = head + Offset(-4 * s, side * 10 * s);
        c.drawLine(start, start + Offset(cos(pi - a) * 16 * s, sin(a) * 16 * s * side.sign), gill);
      }
    }
    // Ojos y sonrisa
    for (final side in [-1.0, 1.0]) {
      c.drawCircle(head + Offset(6 * s, side * 7 * s), 3.2 * s, Paint()..color = Colors.black);
      c.drawCircle(head + Offset(7 * s, side * 6 * s), 1.1 * s, Paint()..color = Colors.white);
    }
    c.drawArc(Rect.fromCenter(center: head + Offset(9 * s, 0), width: 8 * s, height: 10 * s), -pi / 3, 2 * pi / 3, false,
        Paint()
          ..color = dark
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5 * s);
    c.restore();
  }

  @override
  bool shouldRepaint(covariant BoardPainter old) => true;
}
