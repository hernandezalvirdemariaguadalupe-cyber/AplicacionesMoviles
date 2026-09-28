import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../data/models/file_item.dart';
import '../providers/file_manager_provider.dart';
import '../screens/image_viewer_screen.dart';
import '../screens/text_viewer_screen.dart';

class FileListTile extends StatelessWidget {
  final FileItem item;

  const FileListTile({super.key, required this.item});

  Widget _buildLeadingIcon(BuildContext context) {
    if (item.isDirectory) {
      return Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: AppColors.folderColor.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Icon(Icons.folder, color: AppColors.folderColor, size: 28),
      );
    }

    if (item.isImage) {
      return Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: AppColors.imageColor.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Icon(Icons.image, color: AppColors.imageColor, size: 28),
      );
    }

    if (item.isText) {
      return Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: AppColors.textColor.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Icon(Icons.description, color: AppColors.textColor, size: 28),
      );
    }

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: AppColors.defaultFileColor.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(10),
      ),
      child: const Icon(Icons.insert_drive_file, color: AppColors.defaultFileColor, size: 28),
    );
  }

  void _openItem(BuildContext context) {
    if (item.isDirectory) {
      context.read<FileManagerProvider>().navigateTo(item.path);
    } else if (item.isText) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => TextViewerScreen(fileItem: item),
        ),
      );
    } else if (item.isImage) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ImageViewerScreen(fileItem: item),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Tipo de archivo no soportado para vista previa: ${item.name}')),
      );
    }
  }

  void _showRenameDialog(BuildContext context) {
    final controller = TextEditingController(text: item.name);
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Renombrar'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Nuevo nombre',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () async {
              final newName = controller.text.trim();
              if (newName.isNotEmpty && newName != item.name) {
                final success = await context
                    .read<FileManagerProvider>()
                    .renameItem(item.path, newName);
                if (dialogCtx.mounted) Navigator.pop(dialogCtx);
                if (!success && context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Error al renombrar elemento')),
                  );
                }
              }
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  void _showDeleteDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Confirmar eliminación'),
        content: Text(
          '¿Estás seguro de eliminar ${item.isDirectory ? "la carpeta" : "el archivo"} "${item.name}"?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(dialogCtx);
              final success =
                  await context.read<FileManagerProvider>().deleteItem(item.path);
              if (!success && context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Error al eliminar elemento')),
                );
              }
            },
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<FileManagerProvider>();

    return Card(
      child: ListTile(
        onTap: () => _openItem(context),
        leading: _buildLeadingIcon(context),
        title: Text(
          item.name,
          style: const TextStyle(fontWeight: FontWeight.w600),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          '${item.formattedSize} • ${item.formattedDate}',
          style: TextStyle(
            fontSize: 12,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: Icon(
                item.isFavorite ? Icons.star : Icons.star_border,
                color: item.isFavorite ? Colors.amber : Colors.grey,
                size: 22,
              ),
              onPressed: () => provider.toggleFavorite(item),
              tooltip: item.isFavorite ? 'Quitar de favoritos' : 'Agregar a favoritos',
            ),
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, size: 22),
              onSelected: (action) {
                if (action == 'open') _openItem(context);
                if (action == 'rename') _showRenameDialog(context);
                if (action == 'delete') _showDeleteDialog(context);
              },
              itemBuilder: (_) => [
                const PopupMenuItem(
                  value: 'open',
                  child: Row(
                    children: [
                      Icon(Icons.open_in_new, size: 18),
                      SizedBox(width: 8),
                      Text('Abrir'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'rename',
                  child: Row(
                    children: [
                      Icon(Icons.edit, size: 18),
                      SizedBox(width: 8),
                      Text('Renombrar'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete, size: 18, color: Colors.red),
                      SizedBox(width: 8),
                      Text('Eliminar', style: TextStyle(color: Colors.red)),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
