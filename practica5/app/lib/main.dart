import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import 'app_state.dart';
import 'config.dart';
import 'core/tls.dart';
import 'data/local_db.dart';
import 'ui/screens/home_screen.dart';
import 'ui/screens/login_screen.dart';
import 'ui/widgets/common.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await installExtraRootCertificates();
  final configError = AppConfig.validateApiBaseUrl(releaseMode: kReleaseMode);
  if (configError != null) {
    runApp(ConfigErrorApp(message: configError));
    return;
  }
  final local = await LocalDb.open();
  final state = AppState(local: local, apiBaseUrl: AppConfig.apiBaseUrl);
  runApp(BibliotecaApp(state: state));
  await state.init();
}

ThemeData _theme(Brightness b) => ThemeData(
  colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF6D1D3C), brightness: b),
);

class BibliotecaApp extends StatelessWidget {
  const BibliotecaApp({super.key, required this.state});
  final AppState state;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: state,
      child: MaterialApp(
        title: 'Biblioteca ESCOM',
        debugShowCheckedModeBanner: false,
        theme: _theme(Brightness.light),
        darkTheme: _theme(Brightness.dark),
        home: const _Root(),
      ),
    );
  }
}

class _Root extends StatelessWidget {
  const _Root();

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    if (s.initializing) return const Scaffold(body: LoadingView(label: 'Restaurando sesión…'));
    // La clave por usuario reinicia el árbol al cambiar de cuenta: ningún estado de pantalla se comparte.
    return s.user == null ? const LoginScreen() : HomeScreen(key: ValueKey('home_${s.user!.id}'));
  }
}

class ConfigErrorApp extends StatelessWidget {
  const ConfigErrorApp({super.key, required this.message});
  final String message;

  @override
  Widget build(BuildContext context) => MaterialApp(
    home: Scaffold(
      body: EmptyView(icon: Icons.settings, title: 'Configuración incompleta', subtitle: message),
    ),
  );
}
