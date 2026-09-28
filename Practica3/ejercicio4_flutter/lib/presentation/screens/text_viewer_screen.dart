import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../data/models/file_item.dart';
import '../providers/file_manager_provider.dart';

class TextViewerScreen extends StatefulWidget {
  final FileItem fileItem;

  const TextViewerScreen({super.key, required this.fileItem});

  @override
  State<TextViewerScreen> createState() => _TextViewerScreenState();
}

class _TextViewerScreenState extends State<TextViewerScreen> {
  final _controller = TextEditingController();
  bool _isLoading = true;
  bool _isSaving = false;
  bool _hasChanges = false;

  @override
  void initState() {
    super.initState();
    _loadFile();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _loadFile() async {
    final provider = context.read<FileManagerProvider>();
    final content = await provider.readTextFile(widget.fileItem.path);
    if (mounted) {
      setState(() {
        _controller.text = content;
        _isLoading = false;
      });
    }
  }

  Future<void> _saveFile() async {
    setState(() => _isSaving = true);
    final provider = context.read<FileManagerProvider>();
    await provider.saveTextFile(widget.fileItem.path, _controller.text);
    if (mounted) {
      setState(() {
        _isSaving = false;
        _hasChanges = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Archivo guardado correctamente.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.fileItem.name,
          style: const TextStyle(fontSize: 18),
        ),
        actions: [
          IconButton(
            icon: _isSaving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : const Icon(Icons.save),
            onPressed: (_isLoading || _isSaving) ? null : _saveFile,
            tooltip: 'Guardar cambios',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  color: Theme.of(context)
                      .colorScheme
                      .surfaceVariant
                      .withOpacity(0.5),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Ruta: ${widget.fileItem.name}',
                        style: const TextStyle(fontSize: 12),
                      ),
                      Text(
                        _hasChanges ? '• Modificado' : 'Guardado',
                        style: TextStyle(
                          fontSize: 12,
                          color: _hasChanges ? Colors.orange : Colors.green,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: TextField(
                      controller: _controller,
                      maxLines: null,
                      expands: true,
                      onChanged: (_) {
                        if (!_hasChanges) {
                          setState(() => _hasChanges = true);
                        }
                      },
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 14,
                        height: 1.4,
                      ),
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        hintText: 'El archivo está vacío...',
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
