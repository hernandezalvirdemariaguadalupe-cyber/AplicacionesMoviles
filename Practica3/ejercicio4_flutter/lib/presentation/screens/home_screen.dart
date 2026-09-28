import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/file_manager_provider.dart';
import '../widgets/breadcrumb_bar.dart';
import '../widgets/create_item_dialog.dart';
import '../widgets/file_list_tile.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<FileManagerProvider>().initialize();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showCreateDialog() {
    showDialog(
      context: context,
      builder: (_) => const CreateItemDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<FileManagerProvider>();

    return PopScope(
      canPop: !provider.canNavigateUp,
      onPopInvoked: (didPop) {
        if (!didPop && provider.canNavigateUp) {
          provider.navigateUp();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          leading: provider.canNavigateUp
              ? IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () => provider.navigateUp(),
                  tooltip: 'Subir un nivel',
                )
              : const Padding(
                  padding: EdgeInsets.all(12),
                  child: Icon(Icons.folder_shared, size: 28),
                ),
          title: _isSearching
              ? TextField(
                  controller: _searchController,
                  autofocus: true,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    hintText: 'Buscar en la carpeta actual...',
                    hintStyle: TextStyle(color: Colors.white70),
                    border: InputBorder.none,
                  ),
                  onChanged: (query) => provider.setSearchQuery(query),
                )
              : Text(
                  provider.currentPath == provider.rootPath
                      ? 'Archivos'
                      : provider.currentPath.split('/').last,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
          actions: [
            IconButton(
              icon: Icon(_isSearching ? Icons.close : Icons.search),
              onPressed: () {
                setState(() {
                  _isSearching = !_isSearching;
                  if (!_isSearching) {
                    _searchController.clear();
                    provider.setSearchQuery('');
                  }
                });
              },
              tooltip: _isSearching ? 'Cerrar búsqueda' : 'Buscar',
            ),
            PopupMenuButton<SortOption>(
              icon: const Icon(Icons.sort),
              tooltip: 'Ordenar por',
              onSelected: (option) => provider.setSortOption(option),
              itemBuilder: (_) => [
                PopupMenuItem(
                  value: SortOption.name,
                  child: Row(
                    children: [
                      Icon(
                        provider.sortOption == SortOption.name
                            ? (provider.sortAscending
                                ? Icons.arrow_upward
                                : Icons.arrow_downward)
                            : Icons.sort_by_alpha,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      const Text('Nombre'),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: SortOption.date,
                  child: Row(
                    children: [
                      Icon(
                        provider.sortOption == SortOption.date
                            ? (provider.sortAscending
                                ? Icons.arrow_upward
                                : Icons.arrow_downward)
                            : Icons.calendar_today,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      const Text('Fecha'),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: SortOption.size,
                  child: Row(
                    children: [
                      Icon(
                        provider.sortOption == SortOption.size
                            ? (provider.sortAscending
                                ? Icons.arrow_upward
                                : Icons.arrow_downward)
                            : Icons.data_usage,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      const Text('Tamaño'),
                    ],
                  ),
                ),
              ],
            ),
            IconButton(
              icon: const Icon(Icons.palette_outlined),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SettingsScreen()),
                );
              },
              tooltip: 'Temas y Configuración',
            ),
          ],
        ),
        body: Column(
          children: [
            const BreadcrumbBar(),
            Expanded(
              child: provider.isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : provider.errorMessage != null
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.error_outline,
                                    size: 48, color: Colors.red),
                                const SizedBox(height: 12),
                                Text(
                                  provider.errorMessage!,
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 12),
                                FilledButton(
                                  onPressed: () => provider.refresh(),
                                  child: const Text('Reintentar'),
                                ),
                              ],
                            ),
                          ),
                        )
                      : provider.items.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    _isSearching
                                        ? Icons.search_off
                                        : Icons.folder_open,
                                    size: 64,
                                    color: Colors.grey.shade400,
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    _isSearching
                                        ? 'No se encontraron coincidencias'
                                        : 'Esta carpeta está vacía',
                                    style: TextStyle(
                                      fontSize: 16,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  if (!_isSearching)
                                    OutlinedButton.icon(
                                      onPressed: _showCreateDialog,
                                      icon: const Icon(Icons.add),
                                      label: const Text('Crear elemento'),
                                    ),
                                ],
                              ),
                            )
                          : RefreshIndicator(
                              onRefresh: () => provider.refresh(),
                              child: ListView.builder(
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                itemCount: provider.items.length,
                                itemBuilder: (context, index) {
                                  final item = provider.items[index];
                                  return FileListTile(item: item);
                                },
                              ),
                            ),
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _showCreateDialog,
          icon: const Icon(Icons.add),
          label: const Text('Nuevo'),
        ),
      ),
    );
  }
}
