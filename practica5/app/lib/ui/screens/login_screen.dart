import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../app_state.dart';
import '../../config.dart';
import '../widgets/common.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _form = GlobalKey<FormState>();
  final _user = TextEditingController();
  final _pass = TextEditingController();
  bool _registerMode = false;
  bool _busy = false;
  bool _obscure = true;

  @override
  void dispose() {
    _user.dispose();
    _pass.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    final s = context.read<AppState>();
    await _run(
      () =>
          _registerMode ? s.register(_user.text.trim(), _pass.text) : s.login(_user.text.trim(), _pass.text),
    );
  }

  Future<void> _google() async {
    final s = context.read<AppState>();
    await _run(() async {
      final ok = await s.loginWithGoogle();
      if (!ok && mounted) showInfo(context, 'Inicio con Google cancelado');
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
                key: _form,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Icon(Icons.local_library, size: 72),
                    const SizedBox(height: 8),
                    Text(
                      'Biblioteca ESCOM',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    Text(_registerMode ? 'Crear cuenta' : 'Iniciar sesión', textAlign: TextAlign.center),
                    if (s.syncMessage != null && s.user == null) ...[
                      const SizedBox(height: 8),
                      Text(
                        s.syncMessage!,
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Theme.of(context).colorScheme.error),
                      ),
                    ],
                    if (!s.online) ...[
                      const SizedBox(height: 8),
                      const Text(
                        'Sin conexión: para iniciar sesión por primera vez se necesita Internet.',
                        textAlign: TextAlign.center,
                      ),
                    ],
                    const SizedBox(height: 24),
                    TextFormField(
                      key: const Key('username_field'),
                      controller: _user,
                      decoration: const InputDecoration(labelText: 'Usuario', border: OutlineInputBorder()),
                      textInputAction: TextInputAction.next,
                      autocorrect: false,
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Escribe tu usuario' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      key: const Key('password_field'),
                      controller: _pass,
                      obscureText: _obscure,
                      decoration: InputDecoration(
                        labelText: 'Contraseña',
                        border: const OutlineInputBorder(),
                        suffixIcon: IconButton(
                          onPressed: () => setState(() => _obscure = !_obscure),
                          icon: Icon(_obscure ? Icons.visibility : Icons.visibility_off),
                        ),
                      ),
                      onFieldSubmitted: (_) => _submit(),
                      validator: (v) => (v == null || v.length < 6) ? 'Mínimo 6 caracteres' : null,
                    ),
                    const SizedBox(height: 16),
                    FilledButton(
                      key: const Key('submit_button'),
                      onPressed: _busy ? null : _submit,
                      child: _busy
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(_registerMode ? 'Registrarme' : 'Entrar'),
                    ),
                    TextButton(
                      key: const Key('toggle_mode_button'),
                      onPressed: _busy ? null : () => setState(() => _registerMode = !_registerMode),
                      child: Text(
                        _registerMode ? '¿Ya tienes cuenta? Inicia sesión' : '¿No tienes cuenta? Regístrate',
                      ),
                    ),
                    const Row(
                      children: [
                        Expanded(child: Divider()),
                        Padding(padding: EdgeInsets.symmetric(horizontal: 8), child: Text('o')),
                        Expanded(child: Divider()),
                      ],
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      key: const Key('google_button'),
                      onPressed: _busy ? null : _google,
                      icon: const Icon(Icons.account_circle),
                      label: const Text('Continuar con Google'),
                    ),
                    if (!AppConfig.googleConfigured)
                      const Padding(
                        padding: EdgeInsets.only(top: 6),
                        child: Text(
                          '(Google aún no está configurado en esta compilación)',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 12),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
