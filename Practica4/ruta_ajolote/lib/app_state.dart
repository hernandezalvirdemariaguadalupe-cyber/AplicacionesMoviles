import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/sound.dart';
import 'core/theme.dart';
import 'game/levels.dart';
import 'game/model.dart';
import 'save/codec.dart';
import 'save/repository.dart';

/// Estado global: preferencias, configuración de juego y progreso del jugador.
/// Se persiste con SharedPreferences (Android) / NSUserDefaults (iOS).
class AppState extends ChangeNotifier {
  AppState(this._prefs);
  final SharedPreferences _prefs;
  final saves = SaveRepository();
  final sound = SoundService();

  AppPalette palette = AppPalette.guinda;
  ThemeMode themeMode = ThemeMode.system;
  SaveFormat saveFormat = SaveFormat.json;
  GameSettings settings = const GameSettings();

  /// Progreso: niveles desbloqueados, estrellas y mejores puntuaciones.
  int unlocked = 1;
  Map<int, int> stars = {};
  Map<int, int> bestScores = {};
  int bestTimeAttack = 0;

  static Future<AppState> load() async {
    final s = AppState(await SharedPreferences.getInstance());
    s._read();
    await s.sound.init();
    return s;
  }

  void _read() {
    palette = AppPalette.values.asNameMap()[_prefs.getString('palette')] ?? AppPalette.guinda;
    themeMode = ThemeMode.values.asNameMap()[_prefs.getString('themeMode')] ?? ThemeMode.system;
    saveFormat = SaveFormat.values.asNameMap()[_prefs.getString('saveFormat')] ?? SaveFormat.json;
    settings = GameSettings(
      sound: _prefs.getBool('sound') ?? true,
      vibration: _prefs.getBool('vibration') ?? true,
      axolotlColor: _prefs.getString('axolotlColor') ?? 'rosa',
      showGrid: _prefs.getBool('showGrid') ?? true,
      timeLimitSec: _prefs.getInt('timeLimit') ?? 90,
      difficulty: _prefs.getString('difficulty') ?? 'normal',
    );
    unlocked = (_prefs.getInt('unlocked') ?? 1).clamp(1, adventureLevels.length);
    stars = _intMap('stars');
    bestScores = _intMap('bestScores');
    bestTimeAttack = _prefs.getInt('bestTimeAttack') ?? 0;
  }

  Map<int, int> _intMap(String key) {
    try {
      final m = jsonDecode(_prefs.getString(key) ?? '{}') as Map<String, dynamic>;
      return m.map((k, v) => MapEntry(int.parse(k), v as int));
    } catch (_) {
      return {};
    }
  }

  void setPalette(AppPalette p) {
    palette = p;
    _prefs.setString('palette', p.name);
    notifyListeners();
  }

  void setThemeMode(ThemeMode m) {
    themeMode = m;
    _prefs.setString('themeMode', m.name);
    notifyListeners();
  }

  void setSaveFormat(SaveFormat f) {
    saveFormat = f;
    _prefs.setString('saveFormat', f.name);
    notifyListeners();
  }

  void setSettings(GameSettings s) {
    settings = s;
    _prefs
      ..setBool('sound', s.sound)
      ..setBool('vibration', s.vibration)
      ..setString('axolotlColor', s.axolotlColor)
      ..setBool('showGrid', s.showGrid)
      ..setInt('timeLimit', s.timeLimitSec)
      ..setString('difficulty', s.difficulty);
    notifyListeners();
  }

  /// Registra el resultado de un nivel o partida de contrarreloj.
  void recordResult(GameState g, int earnedStars) {
    if (g.mode == GameMode.aventura && g.status == GameStatus.ganada) {
      if (earnedStars > (stars[g.level] ?? 0)) stars[g.level] = earnedStars;
      if (g.score > (bestScores[g.level] ?? 0)) bestScores[g.level] = g.score;
      if (g.level + 2 > unlocked) unlocked = (g.level + 2).clamp(1, adventureLevels.length);
      _prefs
        ..setString('stars', jsonEncode(stars.map((k, v) => MapEntry('$k', v))))
        ..setString('bestScores', jsonEncode(bestScores.map((k, v) => MapEntry('$k', v))))
        ..setInt('unlocked', unlocked);
    } else if (g.mode == GameMode.contrarreloj && g.score > bestTimeAttack) {
      bestTimeAttack = g.score;
      _prefs.setInt('bestTimeAttack', bestTimeAttack);
    }
    notifyListeners();
  }

  void play(Sfx s, [GameSettings? override]) {
    final c = override ?? settings;
    sound.play(s, enabled: c.sound, vibrate: c.vibration);
  }
}
