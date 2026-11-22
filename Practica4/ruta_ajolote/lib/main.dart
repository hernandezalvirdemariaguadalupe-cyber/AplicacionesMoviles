import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app_state.dart';
import 'core/theme.dart';
import 'ui/home_screen.dart' show HomeScreen, routeObserver;

/// Práctica 4 — Parte 2: "Ruta del Ajolote", juego con gestión de archivos
/// (guardado en TXT, XML y JSON) para Android e iOS.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final app = await AppState.load();
  runApp(ChangeNotifierProvider.value(value: app, child: const RutaAjoloteApp()));
}

class RutaAjoloteApp extends StatelessWidget {
  const RutaAjoloteApp({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    return MaterialApp(
      title: 'Ruta del Ajolote',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.build(s.palette, Brightness.light),
      darkTheme: AppTheme.build(s.palette, Brightness.dark),
      themeMode: s.themeMode,
      navigatorObservers: [routeObserver],
      home: const HomeScreen(),
    );
  }
}
