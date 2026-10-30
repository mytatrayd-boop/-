import Flutter
import UIKit
import WidgetKit

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
        switch call.method {
        case "containerPath":
          guard let group = call.arguments as? String else {
            result(FlutterMethodNotImplemented)
            return
          }
          result(FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: group)?.path)
        case "saveAndReload":
          // الحفظ في App Group ثم إعادة تحميل كل الودجت، مباشرة من الطبقة الأصلية: الجدول، ومفتاح
          // الشفافية منفصلاً (يقرؤه الودجت قبل الجدول)، ثم synchronize فتراه عملية الودجت فوراً.
          guard let args = call.arguments as? [String: Any],
                let group = args["group"] as? String,
                let defaults = UserDefaults(suiteName: group) else {
            result(FlutterError(code: "no-group", message: "App Group unavailable", details: nil))
            return
          }
          if let schedule = args["schedule"] as? String { defaults.set(schedule, forKey: "schedule") }
          if let opacity = args["opacity"] as? Int { defaults.set(opacity, forKey: "opacity") }
          defaults.synchronize()
          WidgetCenter.shared.reloadAllTimelines()
          result(true)
        default:
          result(FlutterMethodNotImplemented)
        }
      }
    }
  }
}
