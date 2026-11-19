import Flutter
import UIKit
import UniformTypeIdentifiers

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "StoragePlugin") {
      StoragePlugin.register(with: registrar)
    }
  }
}

/// Código específico de iOS.
///
/// La app vive dentro de su sandbox. Para llegar a otras ubicaciones usa exclusivamente el
/// selector de documentos del sistema (app Archivos). Cada carpeta o archivo elegido es un
/// recurso "security-scoped": se abre con startAccessingSecurityScopedResource() y se guarda
/// un *bookmark* para recuperar el acceso en sesiones futuras sin volver a preguntar.
/// Si el usuario mueve o borra la ubicación, el bookmark deja de resolverse y Dart lo
/// muestra como "no disponible".
class StoragePlugin: NSObject, FlutterPlugin, UIDocumentPickerDelegate {
  private var pending: FlutterResult?
  private var mode = ""
  private var accessed: [String: URL] = [:]
  private var interaction: UIDocumentInteractionController?

  static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: "mx.ipn.escom/storage", binaryMessenger: registrar.messenger())
    registrar.addMethodCallDelegate(StoragePlugin(), channel: channel)
  }

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    let args = call.arguments as? [String: Any] ?? [:]
    switch call.method {
    case "pickDirectory":
      present(UIDocumentPickerViewController(forOpeningContentTypes: [.folder]), mode: "dir", result: result)
    case "pickFiles":
      let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.item])
      picker.allowsMultipleSelection = true
      present(picker, mode: "files", result: result)
    case "exportFile":
      let url = URL(fileURLWithPath: args["ref"] as! String)
      present(UIDocumentPickerViewController(forExporting: [url], asCopy: true), mode: "export", result: result)
    case "resolveBookmark":
      resolveBookmark(args["bookmark"] as! String, result: result)
    case "release":
      if let path = args["uri"] as? String, let url = accessed.removeValue(forKey: path) {
        url.stopAccessingSecurityScopedResource()
      }
      result(nil)
    case "localAttributes":
      localAttributes(args["path"] as! String, result: result)
    case "freeSpace":
      let url = URL(fileURLWithPath: (args["path"] as? String) ?? NSHomeDirectory())
      let values = try? url.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey])
      result(values?.volumeAvailableCapacityForImportantUsage.map { NSNumber(value: $0) })
    case "openWith":
      openWith(args["ref"] as! String, result: result)
    case "persistedRoots":
      result([])
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  // MARK: - Selector de documentos

  private func present(_ picker: UIDocumentPickerViewController, mode: String, result: @escaping FlutterResult) {
    guard pending == nil else {
      result(FlutterError(code: "BUSY", message: "Ya hay un selector abierto", details: nil))
      return
    }
    guard let top = topController() else {
      result(FlutterError(code: "UNSUPPORTED", message: "Sin ventana activa", details: nil))
      return
    }
    pending = result
    self.mode = mode
    picker.delegate = self
    top.present(picker, animated: true)
  }

  func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
    // Se respeta la cancelación del usuario.
    pending?(nil)
    pending = nil
  }

  func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
    guard let result = pending else { return }
    pending = nil
    if mode == "export" {
      result(urls.first?.path)
      return
    }
    var items: [[String: Any?]] = []
    for url in urls {
      guard url.startAccessingSecurityScopedResource() else { continue }
      accessed[url.path] = url
      var item = describe(url)
      if let data = try? url.bookmarkData(options: [], includingResourceValuesForKeys: nil, relativeTo: nil) {
        item["bookmark"] = data.base64EncodedString()
      }
      items.append(item)
    }
    if items.isEmpty {
      result(FlutterError(code: "PERMISSION_DENIED", message: "El sistema no concedió acceso", details: nil))
    } else if mode == "dir" {
      result(items[0])
    } else {
      result(items)
    }
  }

  private func resolveBookmark(_ base64: String, result: FlutterResult) {
    guard let data = Data(base64Encoded: base64) else {
      result(FlutterError(code: "NOT_FOUND", message: "Bookmark inválido", details: nil))
      return
    }
    var stale = false
    do {
      let url = try URL(resolvingBookmarkData: data, options: [], relativeTo: nil, bookmarkDataIsStale: &stale)
      guard url.startAccessingSecurityScopedResource() else {
        result(FlutterError(code: "PERMISSION_DENIED", message: "Acceso revocado", details: nil))
        return
      }
      accessed[url.path] = url
      var item = describe(url)
      if stale, let fresh = try? url.bookmarkData(options: [], includingResourceValuesForKeys: nil, relativeTo: nil) {
        item["bookmark"] = fresh.base64EncodedString()
      } else {
        item["bookmark"] = base64
      }
      result(item)
    } catch {
      result(FlutterError(code: "NOT_FOUND", message: error.localizedDescription, details: nil))
    }
  }

  // MARK: - Metadatos

  private func describe(_ url: URL) -> [String: Any?] {
    let keys: Set<URLResourceKey> = [.isDirectoryKey, .fileSizeKey, .contentModificationDateKey, .contentTypeKey]
    let v = try? url.resourceValues(forKeys: keys)
    let isDir = v?.isDirectory ?? false
    return [
      "ref": url.path,
      "name": url.lastPathComponent,
      "isDir": isDir,
      "size": isDir ? nil : v?.fileSize,
      "modified": v?.contentModificationDate.map { Int64($0.timeIntervalSince1970 * 1000) },
      "mime": v?.contentType?.preferredMIMEType,
    ]
  }

  private func localAttributes(_ path: String, result: FlutterResult) {
    do {
      let attrs = try FileManager.default.attributesOfItem(atPath: path)
      let isDir = (attrs[.type] as? FileAttributeType) == .typeDirectory
      let ext = (path as NSString).pathExtension
      let type = isDir ? UTType.folder : UTType(filenameExtension: ext)
      let out: [String: Any?] = [
        "created": (attrs[.creationDate] as? Date).map { Int64($0.timeIntervalSince1970 * 1000) },
        "modified": (attrs[.modificationDate] as? Date).map { Int64($0.timeIntervalSince1970 * 1000) },
        "size": isDir ? nil : (attrs[.size] as? NSNumber),
        "type": type?.identifier,
        "mime": type?.preferredMIMEType,
      ]
      result(out)
    } catch {
      result(FlutterError(code: "NOT_FOUND", message: error.localizedDescription, details: nil))
    }
  }

  // MARK: - Abrir con otra app

  private func openWith(_ path: String, result: FlutterResult) {
    guard let top = topController() else { result(false); return }
    let controller = UIDocumentInteractionController(url: URL(fileURLWithPath: path))
    interaction = controller
    let rect = CGRect(x: top.view.bounds.midX, y: top.view.bounds.midY, width: 1, height: 1)
    result(controller.presentOptionsMenu(from: rect, in: top.view, animated: true))
  }

  private func topController() -> UIViewController? {
    let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
    let window = scenes.flatMap { $0.windows }.first { $0.isKeyWindow } ?? scenes.first?.windows.first
    var top = window?.rootViewController
    while let presented = top?.presentedViewController { top = presented }
    return top
  }
}
