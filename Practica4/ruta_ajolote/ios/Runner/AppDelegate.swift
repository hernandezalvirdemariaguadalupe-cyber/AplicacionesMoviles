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
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "ArchivosPlugin") {
      ArchivosPlugin.register(with: registrar)
    }
  }
}

/// Código específico de iOS para el juego.
/// Las partidas viven en el sandbox (Application Support). Para exportar o importar se
/// usa UIDocumentPickerViewController, que sólo da acceso a lo que el usuario elige.
class ArchivosPlugin: NSObject, FlutterPlugin, UIDocumentPickerDelegate {
  private var pending: FlutterResult?
  private var mode = ""

  static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: "mx.ipn.escom/archivos", binaryMessenger: registrar.messenger())
    registrar.addMethodCallDelegate(ArchivosPlugin(), channel: channel)
  }

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    let args = call.arguments as? [String: Any] ?? [:]
    switch call.method {
    case "exportFile":
      // Copia con el nombre deseado en temporales para que el destino lo reciba así.
      let src = URL(fileURLWithPath: args["path"] as! String)
      let name = (args["name"] as? String) ?? src.lastPathComponent
      let tmp = FileManager.default.temporaryDirectory.appendingPathComponent(name)
      try? FileManager.default.removeItem(at: tmp)
      do {
        try FileManager.default.copyItem(at: src, to: tmp)
      } catch {
        result(FlutterError(code: "IO_ERROR", message: error.localizedDescription, details: nil))
        return
      }
      present(UIDocumentPickerViewController(forExporting: [tmp], asCopy: true), mode: "export", result: result)
    case "pickFile":
      let types: [UTType] = [.json, .xml, .plainText, .text]
      present(UIDocumentPickerViewController(forOpeningContentTypes: types, asCopy: true), mode: "pick", result: result)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func present(_ picker: UIDocumentPickerViewController, mode: String, result: @escaping FlutterResult) {
    guard pending == nil else {
      result(FlutterError(code: "BUSY", message: "Ya hay un selector abierto", details: nil))
      return
    }
    let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
    var top = (scenes.flatMap { $0.windows }.first { $0.isKeyWindow })?.rootViewController
    while let presented = top?.presentedViewController { top = presented }
    guard let controller = top else {
      result(FlutterError(code: "UNSUPPORTED", message: "Sin ventana activa", details: nil))
      return
    }
    pending = result
    self.mode = mode
    picker.delegate = self
    controller.present(picker, animated: true)
  }

  func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
    pending?(nil)
    pending = nil
  }

  func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
    guard let result = pending, let url = urls.first else { return }
    pending = nil
    if mode == "export" {
      result(url.path)
    } else {
      // asCopy: true → el archivo ya es una copia dentro del sandbox de la app.
      let out: [String: Any] = ["name": url.lastPathComponent, "path": url.path]
      result(out)
    }
  }
}
