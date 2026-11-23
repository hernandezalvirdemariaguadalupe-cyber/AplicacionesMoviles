// Prueba funcional de extremo a extremo. Se ejecuta IGUAL en Android (emulador) e iOS (simulador):
//   flutter drive --driver=test_driver/integration_test.dart \
//     --target=integration_test/app_test.dart --dart-define-from-file=config/dev.json -d <dispositivo>
// Usa el backend real (API_BASE_URL) y Open Library. Guarda capturas en integration_test/screenshots/<plataforma>/.
import 'dart:io' show Platform;

import 'package:biblioteca_app/app_state.dart';
import 'package:biblioteca_app/config.dart';
import 'package:biblioteca_app/core/tls.dart';
import 'package:biblioteca_app/data/local_db.dart';
import 'package:biblioteca_app/main.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:material_ui/material_ui.dart';

const adminUser = String.fromEnvironment('ADMIN_USERNAME');
const adminPass = String.fromEnvironment('ADMIN_PASSWORD');

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  final platform = Platform.isIOS ? 'ios' : 'android';
  var shot = 0;
  var surfaceConverted = false;

  Future<void> capture(WidgetTester tester, String name) async {
    await tester.pumpAndSettle(const Duration(milliseconds: 300));
    if (Platform.isAndroid && !surfaceConverted) {
      // En Android la superficie debe convertirse una vez para poder capturarla.
      await binding.convertFlutterSurfaceToImage();
      surfaceConverted = true;
    }
    await tester.pump();
    shot++;
    await binding.takeScreenshot('$platform/${shot.toString().padLeft(2, '0')}_$name');
  }

  /// Espera hasta que aparezca [finder] (peticiones de red reales).
  Future<void> waitFor(WidgetTester tester, Finder finder, {int seconds = 60}) async {
    final end = DateTime.now().add(Duration(seconds: seconds));
    while (DateTime.now().isBefore(end)) {
      await tester.pump(const Duration(milliseconds: 250));
      if (finder.evaluate().isNotEmpty) return;
    }
    // Captura del estado real de la pantalla para diagnosticar el fallo.
    final visible = find.byType(Text).evaluate().map((e) => (e.widget as Text).data).whereType<String>();
    await capture(tester, 'FALLO');
    throw TestFailure('No apareció: $finder\nTextos en pantalla: ${visible.take(25).join(' | ')}');
  }

  /// Escribe en el buscador y pulsa el botón de búsqueda (sin depender del teclado del sistema).
  Future<void> search(WidgetTester tester, String text) async {
    tester.widget<TextField>(find.byKey(const Key('search_field'))).controller!.text = text;
    await tester.tap(find.byKey(const Key('search_button')));
    await tester.pump();
  }

  Future<AppState> launch(WidgetTester tester) async {
    await installExtraRootCertificates();
    final local = await LocalDb.open(name: 'e2e_${DateTime.now().millisecondsSinceEpoch}.db');
    final state = AppState(local: local, apiBaseUrl: AppConfig.apiBaseUrl);
    await tester.pumpWidget(BibliotecaApp(state: state));
    await state.init();
    await tester.pumpAndSettle();
    return state;
  }

  Future<void> loginForm(WidgetTester tester, String user, String pass, {bool register = false}) async {
    if (register) await tester.tap(find.byKey(const Key('toggle_mode_button')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('username_field')), user);
    await tester.enterText(find.byKey(const Key('password_field')), pass);
    await tester.tap(find.byKey(const Key('submit_button')));
    await waitFor(tester, find.byKey(const Key('nav_search')));
    await tester.pumpAndSettle(const Duration(seconds: 2));
  }

  testWidgets('Escenarios funcionales Práctica 5 ($platform)', (tester) async {
    final user = 'e2e_${platform}_${DateTime.now().millisecondsSinceEpoch % 1000000}';
    const pass = 'prueba123';
    final state = await launch(tester);

    // E1 · Registro/login (REST) --------------------------------------------------------------
    if (state.user != null) await state.logout();
    await tester.pumpAndSettle();
    await capture(tester, 'login');
    await loginForm(tester, user, pass, register: true);
    await capture(tester, 'sesion_iniciada');

    // E2 · CRUD de tareas (Práctica 2) ------------------------------------------------------
    await tester.tap(find.byKey(const Key('nav_tasks')));
    await waitFor(tester, find.byKey(const Key('tasks_empty')));
    await tester.tap(find.byKey(const Key('add_task_button')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('task_title_field')), 'Leer El Hobbit');
    await tester.tap(find.byKey(const Key('task_save_button')));
    await waitFor(tester, find.text('Leer El Hobbit'));
    await capture(tester, 'tareas_crud');

    // E3 · Búsqueda en API pública + historial ------------------------------------------------
    await tester.tap(find.byKey(const Key('nav_search')));
    await tester.pumpAndSettle();
    await search(tester, 'tolkien hobbit');
    await waitFor(tester, find.byKey(const Key('results_list')));
    await capture(tester, 'busqueda_open_library');

    // E4 · Estado vacío -------------------------------------------------------------------------
    await search(tester, 'zzqxwvkj sin resultados 9871');
    await waitFor(tester, find.byKey(const Key('empty_results')));
    await capture(tester, 'estado_vacio');

    // E5 · Detalle + favorito ------------------------------------------------------------------
    await search(tester, 'tolkien hobbit');
    await waitFor(tester, find.byKey(const Key('results_list')));
    await tester.tap(
      find.descendant(of: find.byKey(const Key('results_list')), matching: find.byType(ListTile)).first,
    );
    await waitFor(tester, find.byKey(const Key('detail_title')));
    await tester.pumpAndSettle(const Duration(seconds: 2));
    await tester.tap(find.byKey(const Key('favorite_button')));
    await tester.pumpAndSettle(const Duration(seconds: 2));
    await capture(tester, 'detalle_favorito');
    await tester.pageBack();
    await tester.pumpAndSettle();

    // E6 · Offline: favorito en cola + reconexión y sincronización ---------------------------------
    state.debugSetOnline(false);
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(of: find.byKey(const Key('results_list')), matching: find.byType(ListTile)).at(1),
    );
    await waitFor(tester, find.byKey(const Key('detail_title')));
    await tester.pumpAndSettle(const Duration(seconds: 1));
    await tester.tap(find.byKey(const Key('favorite_button')));
    await tester.pumpAndSettle(const Duration(seconds: 1));
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(state.pendingOps, greaterThan(0));
    await tester.tap(find.byKey(const Key('nav_favorites')));
    await tester.pumpAndSettle();
    await capture(tester, 'offline_favoritos_en_cola');
    state.debugSetOnline(true);
    final end = DateTime.now().add(const Duration(seconds: 30));
    while (state.pendingOps > 0 && DateTime.now().isBefore(end)) {
      await tester.pump(const Duration(milliseconds: 300));
    }
    expect(state.pendingOps, 0);
    await tester.pumpAndSettle();
    await capture(tester, 'reconexion_sincronizado');

    // E7 · Recomendaciones -----------------------------------------------------------------------
    await tester.tap(find.byKey(const Key('nav_recs')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('generate_recs_button')));
    await waitFor(tester, find.byKey(const Key('recs_criteria')), seconds: 60);
    await capture(tester, 'recomendaciones');

    // E8 · Acceso denegado (no admin) + historial --------------------------------------------------
    await tester.tap(find.byKey(const Key('nav_profile')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('probe_admin_tile')));
    await waitFor(tester, find.textContaining('Acceso denegado'));
    await capture(tester, 'admin_denegado');

    // E9 · Cierre de sesión y restauración ----------------------------------------------------------
    // Espera a que se cierre el aviso de "Acceso denegado": en pantallas como la del iPhone
    // cubre el botón de cerrar sesión y absorbería el toque.
    ScaffoldMessenger.of(tester.element(find.byKey(const Key('nav_profile')))).hideCurrentSnackBar();
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.byKey(const Key('logout_button')), 300);
    await tester.tap(find.byKey(const Key('logout_button')));
    await waitFor(tester, find.byKey(const Key('username_field')));
    await capture(tester, 'sesion_cerrada');

    // E10 · Rol administrador (si se proporcionan credenciales) ------------------------------------
    if (adminUser.isNotEmpty && adminPass.isNotEmpty) {
      await loginForm(tester, adminUser, adminPass);
      await tester.tap(find.byKey(const Key('nav_profile')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('admin_panel_tile')));
      await waitFor(tester, find.byKey(const Key('admin_users_list')));
      await tester.tap(find.textContaining(user).first);
      await waitFor(tester, find.text('tolkien hobbit'));
      await capture(tester, 'admin_historial_usuario');
    } else {
      debugPrint('ADMIN_USERNAME/ADMIN_PASSWORD no definidos: se omite el escenario de administrador.');
    }
  });
}
