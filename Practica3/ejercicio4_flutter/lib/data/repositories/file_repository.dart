import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../models/file_item.dart';

class FileRepository {
  Future<Directory> getRootDirectory() async {
    final docsDir = await getApplicationDocumentsDirectory();
    final appSandbox = Directory('${docsDir.path}/FileManager_Sandbox');
    if (!await appSandbox.exists()) {
      await appSandbox.create(recursive: true);
      await _createInitialSampleFiles(appSandbox.path);
    }
    return appSandbox;
  }

  Future<void> _createInitialSampleFiles(String rootPath) async {
    // 1. Welcome markdown file
    final welcomeFile = File('$rootPath/Bienvenida_ESCOM.md');
    await welcomeFile.writeAsString('''# Práctica 3: Aplicaciones Nativas
## ESCOM - Instituto Politécnico Nacional

¡Bienvenido al Gestor de Archivos Multiplataforma desarrollado en Flutter!

### Características implementadas:
- Exploración de directorios en el sandbox de la aplicación.
- Vistas personalizadas por tipo de archivo con íconos representativos.
- Visor y editor integrado para archivos de texto plano (.txt, .md, .json).
- Visor de imágenes con gestos interactivos (zoom con pinzas).
- Temas institucionales: **Guinda IPN** y **Azul ESCOM**.
- Soporte completo para modo claro y modo oscuro.
- Funcionamiento 100% autónomo y local (sin conexión a Internet).

*Desarrollado para el ciclo 2027-1.*
''');

    // 2. Sample text note
    final notesFile = File('$rootPath/notas_practica3.txt');
    await notesFile.writeAsString('''Instituto Politécnico Nacional
Escuela Superior de Cómputo
Unidad de aprendizaje: Desarrollo de Aplicaciones Móviles Nativas
Equipo:
- María Guadalupe Hernández Alvirde
- Manuel Alejandro Aragón Martínez
Grupo: 7CV4
''');

    // 3. Sample folder with subfiles
    final docsFolder = Directory('$rootPath/Documentos_Institucionales');
    await docsFolder.create();
    final configSample = File('${docsFolder.path}/configuracion_app.json');
    await configSample.writeAsString('''{
  "institucion": "IPN",
  "escuela": "ESCOM",
  "materia": "Desarrollo de Aplicaciones Móviles Nativas",
  "version": "1.0.0",
  "soporteOffline": true,
  "temas": ["Guinda IPN", "Azul ESCOM"]
}''');

    // 4. Another subfolder for media
    final imgFolder = Directory('$rootPath/Galeria_Local');
    await imgFolder.create();
    final readmeImg = File('${imgFolder.path}/acerca_de_la_galeria.txt');
    await readmeImg.writeAsString('Esta carpeta almacena recursos gráficos locales de la aplicación.');
  }

  Future<List<FileItem>> listDirectory(String directoryPath, Set<String> favorites) async {
    final dir = Directory(directoryPath);
    if (!await dir.exists()) {
      return [];
    }

    final entities = await dir.list().toList();
    final List<FileItem> items = [];

    for (final entity in entities) {
      final isDir = entity is Directory;
      final stat = await entity.stat();
      final name = entity.uri.pathSegments.isNotEmpty
          ? (entity.uri.pathSegments.length > 1 && entity.uri.pathSegments.last.isEmpty
              ? entity.uri.pathSegments[entity.uri.pathSegments.length - 2]
              : entity.uri.pathSegments.last)
          : entity.path.split(Platform.pathSeparator).last;

      String ext = '';
      if (!isDir && name.contains('.')) {
        ext = name.split('.').last;
      }

      items.add(
        FileItem(
          path: entity.path,
          name: name,
          isDirectory: isDir,
          sizeInBytes: isDir ? 0 : stat.size,
          modified: stat.modified,
          extension: ext,
          isFavorite: favorites.contains(entity.path),
        ),
      );
    }

    return items;
  }

  Future<void> createFolder(String parentPath, String folderName) async {
    final newDir = Directory('$parentPath/$folderName');
    if (await newDir.exists()) {
      throw Exception('La carpeta ya existe.');
    }
    await newDir.create();
  }

  Future<void> createTextFile(String parentPath, String fileName, String content) async {
    String finalName = fileName;
    if (!finalName.contains('.')) {
      finalName = '$finalName.txt';
    }
    final newFile = File('$parentPath/$finalName');
    if (await newFile.exists()) {
      throw Exception('El archivo ya existe.');
    }
    await newFile.writeAsString(content);
  }

  Future<void> deleteItem(String path) async {
    final file = File(path);
    if (await file.exists()) {
      await file.delete();
      return;
    }
    final dir = Directory(path);
    if (await dir.exists()) {
      await dir.delete(recursive: true);
    }
  }

  Future<void> renameItem(String oldPath, String newName) async {
    final isDir = await FileSystemEntity.isDirectory(oldPath);
    final parent = File(oldPath).parent.path;
    final newPath = '$parent/$newName';

    if (isDir) {
      await Directory(oldPath).rename(newPath);
    } else {
      await File(oldPath).rename(newPath);
    }
  }

  Future<String> readTextFile(String path) async {
    final file = File(path);
    return await file.readAsString();
  }

  Future<void> saveTextFile(String path, String content) async {
    final file = File(path);
    await file.writeAsString(content);
  }
}
