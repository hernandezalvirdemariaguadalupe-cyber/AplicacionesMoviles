import 'dart:io';

import 'package:flutter/services.dart';

/// Tipos de fallo que la interfaz sabe explicar al usuario.
enum FsErrorKind {
  notFound,
  permissionDenied,
  noSpace,
  readFailed,
  writeFailed,
  alreadyExists,
  invalidName,
  unsupported,
  busy,
  unknown,
}

/// Error de archivos con un mensaje legible en español. Toda operación de la app
/// convierte las excepciones de plataforma a este tipo para nunca bloquear la UI.
class FsException implements Exception {
  final FsErrorKind kind;
  final String message;
  final String? detail;

  const FsException(this.kind, this.message, [this.detail]);

  @override
  String toString() => detail == null ? message : '$message\n($detail)';

  /// Traduce cualquier excepción conocida a [FsException].
  static FsException from(Object e, {String action = 'completar la operación'}) {
    if (e is FsException) return e;
    if (e is PlatformException) {
      switch (e.code) {
        case 'NOT_FOUND':
          return FsException(FsErrorKind.notFound,
              'El archivo o la carpeta ya no existe, o se movió.', e.message);
        case 'PERMISSION_DENIED':
          return FsException(FsErrorKind.permissionDenied,
              'No hay permiso para $action. Puede que el acceso se haya revocado; vuelve a autorizar la ubicación.',
              e.message);
        case 'NO_SPACE':
          return FsException(FsErrorKind.noSpace,
              'No hay espacio suficiente en el almacenamiento.', e.message);
        case 'UNSUPPORTED':
          return FsException(FsErrorKind.unsupported,
              'El proveedor de documentos no admite esta operación.', e.message);
        case 'BUSY':
          return FsException(FsErrorKind.busy, 'Espera a que termine la operación anterior.');
        default:
          return FsException(FsErrorKind.unknown, 'No se pudo $action.', e.message);
      }
    }
    if (e is PathNotFoundException) {
      return FsException(FsErrorKind.notFound, 'El archivo o la carpeta ya no existe.', e.path);
    }
    if (e is FileSystemException) {
      final code = e.osError?.errorCode;
      // EACCES=13, EPERM=1, ENOSPC=28, EEXIST=17 (POSIX; Android e iOS)
      if (code == 13 || code == 1) {
        return FsException(FsErrorKind.permissionDenied,
            'El sistema no permite $action en esta ubicación.', e.path);
      }
      if (code == 28) {
        return const FsException(FsErrorKind.noSpace, 'No hay espacio suficiente en el almacenamiento.');
      }
      if (code == 17) {
        return FsException(FsErrorKind.alreadyExists, 'Ya existe un elemento con ese nombre.', e.path);
      }
      return FsException(FsErrorKind.unknown, 'No se pudo $action.', e.message);
    }
    if (e is FormatException) {
      return FsException(FsErrorKind.readFailed, 'El contenido no se pudo interpretar.', e.message);
    }
    return FsException(FsErrorKind.unknown, 'No se pudo $action.', e.toString());
  }
}
