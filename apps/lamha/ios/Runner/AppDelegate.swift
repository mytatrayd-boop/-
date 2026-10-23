import Flutter
import UIKit

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
    // مسار حاوية App Group لحفظ لقطة الخلفية حيث تقرؤها الودجت.
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "LamhaAppGroup") {
      let channel = FlutterMethodChannel(
        name: "sa.lamha/app_group", binaryMessenger: registrar.messenger())
      channel.setMethodCallHandler { call, result in
        guard call.method == "containerPath", let group = call.arguments as? String else {
          result(FlutterMethodNotImplemented)
          return
        }
        result(FileManager.default
          .containerURL(forSecurityApplicationGroupIdentifier: group)?.path)
      }
    }
  }
}
