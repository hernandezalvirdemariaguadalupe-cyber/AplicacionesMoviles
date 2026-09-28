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
            child: RadioGroup<InstitutionalTheme>(
              groupValue: themeProvider.institutionalTheme,
              onChanged: (val) {
                if (val != null) themeProvider.setInstitutionalTheme(val);
              },
              child: const Column(
                children: [
                  RadioListTile<InstitutionalTheme>(
                    value: InstitutionalTheme.guindaIPN,
                    title: Text(
                      'Tema Guinda (IPN)',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text('Color institucional del Instituto Politécnico Nacional'),
                    secondary: CircleAvatar(
                      backgroundColor: AppColors.ipnGuinda,
                      radius: 16,
                    ),
                  ),
                  Divider(height: 1),
                  RadioListTile<InstitutionalTheme>(
                    value: InstitutionalTheme.azulESCOM,
                    title: Text(
                      'Tema Azul (ESCOM)',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text('Color institucional de la Escuela Superior de Cómputo'),
                    secondary: CircleAvatar(
                      backgroundColor: AppColors.escomAzul,
                      radius: 16,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Modo de Pantalla',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Card(
            child: RadioGroup<ThemeMode>(
              groupValue: themeProvider.themeMode,
              onChanged: (val) {
                if (val != null) themeProvider.setThemeMode(val);
              },
              child: const Column(
                children: [
                  RadioListTile<ThemeMode>(
                    value: ThemeMode.system,
                    title: Text('Automático (del sistema)'),
                    secondary: Icon(Icons.brightness_auto),
                  ),
                  Divider(height: 1),
                  RadioListTile<ThemeMode>(
                    value: ThemeMode.light,
                    title: Text('Modo Claro'),
                    secondary: Icon(Icons.light_mode),
                  ),
                  Divider(height: 1),
                  RadioListTile<ThemeMode>(
                    value: ThemeMode.dark,
                    title: Text('Modo Oscuro'),
                    secondary: Icon(Icons.dark_mode),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Información Académica',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Instituto Politécnico Nacional',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  Text('Escuela Superior de Cómputo (ESCOM)'),
                  SizedBox(height: 8),
                  Text('Unidad de Aprendizaje: Desarrollo de Aplicaciones Móviles Nativas'),
                  Text('Profesor: Gabriel Hurtado Avilés'),
                  Text('Grupo: 7CV4 | Semestre 2027-1'),
                  SizedBox(height: 12),
                  Divider(),
                  SizedBox(height: 8),
                  Text(
                    'Desarrollado por:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text('• Hernández Alvirde María Guadalupe (2022630105)'),
                  Text('• Aragón Martínez Manuel Alejandro'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
