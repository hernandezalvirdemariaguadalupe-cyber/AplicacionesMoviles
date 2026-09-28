import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/theme/theme_provider.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Configuración y Temas'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Temas Institucionales',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                RadioListTile<InstitutionalTheme>(
                  value: InstitutionalTheme.guindaIPN,
                  groupValue: themeProvider.institutionalTheme,
                  onChanged: (val) {
                    if (val != null) themeProvider.setInstitutionalTheme(val);
                  },
                  title: const Text(
                    'Tema Guinda (IPN)',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: const Text('Color institucional del Instituto Politécnico Nacional'),
                  secondary: CircleAvatar(
                    backgroundColor: AppColors.ipnGuinda,
                    radius: 16,
                  ),
                ),
                const Divider(height: 1),
                RadioListTile<InstitutionalTheme>(
                  value: InstitutionalTheme.azulESCOM,
                  groupValue: themeProvider.institutionalTheme,
                  onChanged: (val) {
                    if (val != null) themeProvider.setInstitutionalTheme(val);
                  },
                  title: const Text(
                    'Tema Azul (ESCOM)',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: const Text('Color institucional de la Escuela Superior de Cómputo'),
                  secondary: CircleAvatar(
                    backgroundColor: AppColors.escomAzul,
                    radius: 16,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Modo de Pantalla',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                RadioListTile<ThemeMode>(
                  value: ThemeMode.system,
                  groupValue: themeProvider.themeMode,
                  onChanged: (val) {
                    if (val != null) themeProvider.setThemeMode(val);
                  },
                  title: const Text('Automático (del sistema)'),
                  secondary: const Icon(Icons.brightness_auto),
                ),
                const Divider(height: 1),
                RadioListTile<ThemeMode>(
                  value: ThemeMode.light,
                  groupValue: themeProvider.themeMode,
                  onChanged: (val) {
                    if (val != null) themeProvider.setThemeMode(val);
                  },
                  title: const Text('Modo Claro'),
                  secondary: const Icon(Icons.light_mode),
                ),
                const Divider(height: 1),
                RadioListTile<ThemeMode>(
                  value: ThemeMode.dark,
                  groupValue: themeProvider.themeMode,
                  onChanged: (val) {
                    if (val != null) themeProvider.setThemeMode(val);
                  },
                  title: const Text('Modo Oscuro'),
                  secondary: const Icon(Icons.dark_mode),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Información Académica',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Instituto Politécnico Nacional',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  const Text('Escuela Superior de Cómputo (ESCOM)'),
                  const SizedBox(height: 8),
                  const Text('Unidad de Aprendizaje: Desarrollo de Aplicaciones Móviles Nativas'),
                  const Text('Profesor: Gabriel Hurtado Avilés'),
                  const Text('Grupo: 7CV4 | Semestre 2027-1'),
                  const SizedBox(height: 12),
                  const Divider(),
                  const SizedBox(height: 8),
                  const Text(
                    'Desarrollado por:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const Text('• Hernández Alvirde María Guadalupe (2022630105)'),
                  const Text('• Aragón Martínez Manuel Alejandro'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
