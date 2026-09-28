import 'package:intl/intl.dart';

class FileItem {
  final String path;
  final String name;
  final bool isDirectory;
  final int sizeInBytes;
  final DateTime modified;
  final String extension;
  final bool isFavorite;

  FileItem({
    required this.path,
    required this.name,
    required this.isDirectory,
    required this.sizeInBytes,
    required this.modified,
    required this.extension,
    this.isFavorite = false,
  });

  FileItem copyWith({
    String? path,
    String? name,
    bool? isDirectory,
    int? sizeInBytes,
    DateTime? modified,
    String? extension,
    bool? isFavorite,
  }) {
    return FileItem(
      path: path ?? this.path,
      name: name ?? this.name,
      isDirectory: isDirectory ?? this.isDirectory,
      sizeInBytes: sizeInBytes ?? this.sizeInBytes,
      modified: modified ?? this.modified,
      extension: extension ?? this.extension,
      isFavorite: isFavorite ?? this.isFavorite,
    );
  }

  String get formattedSize {
    if (isDirectory) return '--';
    if (sizeInBytes < 1024) return '$sizeInBytes B';
    if (sizeInBytes < 1024 * 1024) {
      return '${(sizeInBytes / 1024).toStringAsFixed(1)} KB';
    }
    if (sizeInBytes < 1024 * 1024 * 1024) {
      return '${(sizeInBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(sizeInBytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  String get formattedDate {
    return DateFormat('dd/MM/yyyy HH:mm').format(modified);
  }

  bool get isImage {
    final ext = extension.toLowerCase();
    return ext == 'png' ||
        ext == 'jpg' ||
        ext == 'jpeg' ||
        ext == 'webp' ||
        ext == 'gif';
  }

  bool get isText {
    final ext = extension.toLowerCase();
    return ext == 'txt' ||
        ext == 'md' ||
        ext == 'json' ||
        ext == 'dart' ||
        ext == 'xml' ||
        ext == 'yaml' ||
        ext == 'csv' ||
        ext == 'swift';
  }
}
