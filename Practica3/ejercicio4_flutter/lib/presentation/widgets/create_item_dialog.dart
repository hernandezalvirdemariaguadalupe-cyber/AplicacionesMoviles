import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/file_manager_provider.dart';

class CreateItemDialog extends StatefulWidget {
  const CreateItemDialog({super.key});

  @override
  State<CreateItemDialog> createState() => _CreateItemDialogState();
}

class _CreateItemDialogState extends State<CreateItemDialog> {
  int _selectedType = 0; // 0: Carpeta, 1: Archivo de texto
  final _nameController = TextEditingController();
  final _contentController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor ingresa un nombre.')),
      );
      return;
    }

    setState(() => _isLoading = true);
    final provider = context.read<FileManagerProvider>();
    bool success = false;

    if (_selectedType == 0) {
      success = await provider.createFolder(name);
    } else {
      success = await provider.createTextFile(name, _contentController.text);
    }

    if (mounted) {
      setState(() => _isLoading = false);
      if (success) {
        Navigator.pop(context);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(provider.errorMessage ?? 'Error al crear elemento'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Crear Nuevo Elemento'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SegmentedButton<int>(
              segments: const [
                ButtonSegment(
                  value: 0,
                  label: Text('Carpeta'),
                  icon: Icon(Icons.create_new_folder),
                ),
                ButtonSegment(
                  value: 1,
                  label: Text('Archivo'),
                  icon: Icon(Icons.note_add),
                ),
              ],
              selected: {_selectedType},
              onSelectionChanged: (set) {
                setState(() => _selectedType = set.first);
              },
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _nameController,
              autofocus: true,
              decoration: InputDecoration(
                labelText: _selectedType == 0
                    ? 'Nombre de la carpeta'
                    : 'Nombre del archivo (ej. documento.txt)',
                border: const OutlineInputBorder(),
                prefixIcon: Icon(
                  _selectedType == 0 ? Icons.folder : Icons.description,
                ),
              ),
            ),
            if (_selectedType == 1) ...[
              const SizedBox(height: 12),
              TextField(
                controller: _contentController,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Contenido inicial (opcional)',
                  border: OutlineInputBorder(),
                  alignLabelWithHint: true,
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _isLoading ? null : _handleSubmit,
          child: _isLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Crear'),
        ),
      ],
    );
  }
}
