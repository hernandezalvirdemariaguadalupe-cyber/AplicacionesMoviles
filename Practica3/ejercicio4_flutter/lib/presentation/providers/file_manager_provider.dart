import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../data/models/file_item.dart';
import '../../data/repositories/file_repository.dart';

enum SortOption { name, date, size }

class FileManagerProvider extends ChangeNotifier {
  final FileRepository _repository = FileRepository();
  static const String _favoritesPrefKey = 'favorite_files_keys';

  String _rootPath = '';
  String _currentPath = '';
  List<FileItem> _items = [];
  bool _isLoading = false;
  String _searchQuery = '';
  SortOption _sortOption = SortOption.name;
  bool _sortAscending = true;
  final Set<String> _favoritePaths = {};
  String? _errorMessage;

  String get rootPath => _rootPath;
  String get currentPath => _currentPath;
  bool get isLoading => _isLoading;
  String get searchQuery => _searchQuery;
  SortOption get sortOption => _sortOption;
  bool get sortAscending => _sortAscending;
  String? get errorMessage => _errorMessage;

  bool get canNavigateUp => _currentPath.isNotEmpty && _currentPath != _rootPath;

  List<FileItem> get items {
    var filtered = _items;
    if (_searchQuery.isNotEmpty) {
      filtered = filtered
          .where((item) =>
              item.name.toLowerCase().contains(_searchQuery.toLowerCase()))
          .toList();
    }

    filtered.sort((a, b) {
      // Folders first
      if (a.isDirectory && !b.isDirectory) return -1;
      if (!a.isDirectory && b.isDirectory) return 1;

      int comparison;
      switch (_sortOption) {
        case SortOption.name:
          comparison = a.name.toLowerCase().compareTo(b.name.toLowerCase());
          break;
        case SortOption.date:
          comparison = a.modified.compareTo(b.modified);
          break;
        case SortOption.size:
          comparison = a.sizeInBytes.compareTo(b.sizeInBytes);
          break;
      }
      return _sortAscending ? comparison : -comparison;
    });

    return filtered;
  }

  Future<void> initialize() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      final savedFavorites = prefs.getStringList(_favoritesPrefKey) ?? [];
      _favoritePaths.addAll(savedFavorites);

      final rootDir = await _repository.getRootDirectory();
      _rootPath = rootDir.path;
      _currentPath = _rootPath;
      await _loadCurrentDirectory();
    } catch (e) {
      _errorMessage = 'Error al inicializar el gestor de archivos: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _loadCurrentDirectory() async {
    _items = await _repository.listDirectory(_currentPath, _favoritePaths);
  }

  Future<void> navigateTo(String path) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _currentPath = path;
      _searchQuery = '';
      await _loadCurrentDirectory();
    } catch (e) {
      _errorMessage = 'No se pudo abrir la carpeta: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> navigateUp() async {
    if (!canNavigateUp) return;
    final parentPath = _currentPath.substring(0, _currentPath.lastIndexOf('/'));
    await navigateTo(parentPath.isEmpty ? _rootPath : parentPath);
  }

  Future<void> refresh() async {
    _isLoading = true;
    notifyListeners();
    try {
      await _loadCurrentDirectory();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  void setSortOption(SortOption option) {
    if (_sortOption == option) {
      _sortAscending = !_sortAscending;
    } else {
      _sortOption = option;
      _sortAscending = true;
    }
    notifyListeners();
  }

  Future<void> toggleFavorite(FileItem item) async {
    if (_favoritePaths.contains(item.path)) {
      _favoritePaths.remove(item.path);
    } else {
      _favoritePaths.add(item.path);
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_favoritesPrefKey, _favoritePaths.toList());
    await _loadCurrentDirectory();
    notifyListeners();
  }

  Future<bool> createFolder(String name) async {
    try {
      await _repository.createFolder(_currentPath, name);
      await _loadCurrentDirectory();
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> createTextFile(String name, String content) async {
    try {
      await _repository.createTextFile(_currentPath, name, content);
      await _loadCurrentDirectory();
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteItem(String path) async {
    try {
      await _repository.deleteItem(path);
      _favoritePaths.remove(path);
      await _loadCurrentDirectory();
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Error al eliminar: $e';
      notifyListeners();
      return false;
    }
  }

  Future<bool> renameItem(String oldPath, String newName) async {
    try {
      await _repository.renameItem(oldPath, newName);
      await _loadCurrentDirectory();
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Error al renombrar: $e';
      notifyListeners();
      return false;
    }
  }

  Future<String> readTextFile(String path) async {
    return await _repository.readTextFile(path);
  }

  Future<void> saveTextFile(String path, String content) async {
    await _repository.saveTextFile(path, content);
    await _loadCurrentDirectory();
    notifyListeners();
  }
}
