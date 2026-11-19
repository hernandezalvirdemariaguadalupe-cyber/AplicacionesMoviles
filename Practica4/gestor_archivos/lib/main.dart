import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'core/app_theme.dart';
import 'data/app_state.dart';
import 'ui/locations_page.dart';
import 'ui/settings_page.dart';

/// Práctica 4 — Parte 1: Gestor de archivos multiplataforma (Android e iOS).
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final state = await AppState.load();
  runApp(ChangeNotifierProvider.value(value: state, child: const GestorApp()));
}

class GestorApp extends StatelessWidget {
  const GestorApp({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    return MaterialApp(
      title: 'Gestor de Archivos',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.build(s.palette, Brightness.light),
      darkTheme: AppTheme.build(s.palette, Brightness.dark),
      themeMode: s.themeMode,
      home: const HomeShell(),
    );
  }
}

/// Navegación principal adaptable: barra inferior en teléfonos verticales y
/// NavigationRail lateral en pantallas anchas u horizontales.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> with WidgetsBindingObserver {
  int index = 0;
  final _navKeys = List.generate(4, (_) => GlobalKey<NavigatorState>());

  static const _pages = <Widget>[
    LocationsPage(),
    SavedListPage(favorites: false),
    SavedListPage(favorites: true),
    SettingsPage(),
  ];

  static const _dest = [
    (Icons.folder_outlined, Icons.folder, 'Explorar'),
    (Icons.history, Icons.history, 'Recientes'),
    (Icons.star_border, Icons.star, 'Favoritos'),
    (Icons.settings_outlined, Icons.settings, 'Ajustes'),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Al volver a la app se revisa si algún permiso fue revocado desde Ajustes del sistema.
  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    if (s == AppLifecycleState.resumed) context.read<AppState>().verifyLocations();
  }

  void _select(int i) {
    if (i == index) {
      _navKeys[i].currentState?.popUntil((r) => r.isFirst);
    } else {
      setState(() => index = i);
    }
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 640;
    // Cada pestaña tiene su propio Navigator para conservar la carpeta abierta.
    final body = IndexedStack(
      index: index,
      children: [
        for (var i = 0; i < _pages.length; i++)
          Navigator(
            key: _navKeys[i],
            onGenerateRoute: (_) => MaterialPageRoute(builder: (_) => _pages[i]),
          ),
      ],
    );

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final nav = _navKeys[index].currentState!;
        if (await nav.maybePop()) return;
        if (index != 0) {
          setState(() => index = 0);
        } else {
          SystemNavigator.pop(); // sale de la app
        }
      },
      child: Scaffold(
        body: wide
            ? Row(children: [
                SafeArea(
                  right: false,
                  child: NavigationRail(
                    selectedIndex: index,
                    onDestinationSelected: _select,
                    labelType: NavigationRailLabelType.all,
                    destinations: [
                      for (final d in _dest)
                        NavigationRailDestination(icon: Icon(d.$1), selectedIcon: Icon(d.$2), label: Text(d.$3)),
                    ],
                  ),
                ),
                const VerticalDivider(width: 1),
                Expanded(child: body),
              ])
            : body,
        bottomNavigationBar: wide
            ? null
            : NavigationBar(
                selectedIndex: index,
                onDestinationSelected: _select,
                destinations: [
                  for (final d in _dest) NavigationDestination(icon: Icon(d.$1), selectedIcon: Icon(d.$2), label: d.$3),
                ],
              ),
      ),
    );
  }
}
