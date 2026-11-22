import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Efectos de sonido sintetizados al iniciar la app (WAV PCM 16 bits) y guardados en
/// la caché: no requieren assets ni conexión a Internet.
enum Sfx { move, bubble, hurt, blocked, win, lose, newMap }

class SoundService {
  final _players = <Sfx, AudioPlayer>{};
  final _files = <Sfx, String>{};
  bool _ready = false;

  Future<void> init() async {
    try {
      final dir = Directory(p.join((await getTemporaryDirectory()).path, 'sfx'));
      await dir.create(recursive: true);
      for (final s in Sfx.values) {
        final f = File(p.join(dir.path, '${s.name}.wav'));
        if (!await f.exists()) await f.writeAsBytes(_wav(_notes(s)));
        _files[s] = f.path;
        final player = AudioPlayer();
        await player.setPlayerMode(PlayerMode.lowLatency);
        await player.setReleaseMode(ReleaseMode.stop);
        _players[s] = player;
      }
      _ready = true;
    } catch (_) {
      _ready = false; // sin sonido no se bloquea el juego
    }
  }

  Future<void> play(Sfx s, {required bool enabled, bool vibrate = false}) async {
    if (vibrate) {
      if (s == Sfx.hurt || s == Sfx.lose) {
        HapticFeedback.heavyImpact();
      } else if (s == Sfx.bubble || s == Sfx.win) {
        HapticFeedback.lightImpact();
      }
    }
    if (!enabled || !_ready) return;
    try {
      final pl = _players[s]!;
      await pl.stop();
      await pl.play(DeviceFileSource(_files[s]!), volume: 0.7);
    } catch (_) {}
  }

  // Cada sonido es una secuencia de (frecuencia inicial, final, duración ms, forma).
  static List<(double, double, int, String)> _notes(Sfx s) => switch (s) {
        Sfx.move => [(520, 600, 45, 'sine')],
        Sfx.bubble => [(660, 990, 90, 'sine'), (990, 1320, 70, 'sine')],
        Sfx.hurt => [(220, 110, 220, 'square')],
        Sfx.blocked => [(160, 140, 70, 'square')],
        Sfx.win => [(523, 523, 110, 'sine'), (659, 659, 110, 'sine'), (784, 784, 110, 'sine'), (1046, 1046, 260, 'sine')],
        Sfx.lose => [(392, 392, 160, 'triangle'), (330, 330, 160, 'triangle'), (262, 220, 320, 'triangle')],
        Sfx.newMap => [(784, 1175, 120, 'sine'), (1175, 1568, 120, 'sine')],
      };

  static Uint8List _wav(List<(double, double, int, String)> notes) {
    const rate = 22050;
    final samples = <int>[];
    for (final (f0, f1, ms, wave) in notes) {
      final n = rate * ms ~/ 1000;
      var phase = 0.0;
      for (var i = 0; i < n; i++) {
        final t = i / n;
        final f = f0 + (f1 - f0) * t;
        phase += 2 * pi * f / rate;
        final v = switch (wave) {
          'square' => sin(phase) >= 0 ? 0.5 : -0.5,
          'triangle' => 2 / pi * asin(sin(phase)),
          _ => sin(phase),
        };
        // Envolvente: ataque y caída cortos para evitar chasquidos.
        final env = min(1.0, min(i / (rate * 0.005), (n - i) / (rate * 0.02)));
        samples.add((v * env * 0.6 * 32767).round());
      }
    }
    final data = ByteData(44 + samples.length * 2);
    void str(int o, String s) {
      for (var i = 0; i < s.length; i++) {
        data.setUint8(o + i, s.codeUnitAt(i));
      }
    }

    str(0, 'RIFF');
    data.setUint32(4, 36 + samples.length * 2, Endian.little);
    str(8, 'WAVE');
    str(12, 'fmt ');
    data.setUint32(16, 16, Endian.little);
    data.setUint16(20, 1, Endian.little); // PCM
    data.setUint16(22, 1, Endian.little); // mono
    data.setUint32(24, rate, Endian.little);
    data.setUint32(28, rate * 2, Endian.little);
    data.setUint16(32, 2, Endian.little);
    data.setUint16(34, 16, Endian.little);
    str(36, 'data');
    data.setUint32(40, samples.length * 2, Endian.little);
    for (var i = 0; i < samples.length; i++) {
      data.setInt16(44 + i * 2, samples[i], Endian.little);
    }
    return data.buffer.asUint8List();
  }
}
