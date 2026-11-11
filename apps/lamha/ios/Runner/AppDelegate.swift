import CoreLocation
import Flutter
import UIKit
import WidgetKit

/// اتجاه البوصلة لشاشة القبلة (بدل flutter_compass في آيفون): الشمال الحقيقي إن عُرف الموقع، وإلا
/// المغناطيسي مع علامة [true] = false ليضيف Dart الانحراف. flutter_compass يرسل trueHeading وحده،
/// وهو -1 ما لم تعمل خدمة الموقع، فيقف القرص؛ ويُسقط القراءات أثناء المعايرة.
final class HeadingStream: NSObject, FlutterStreamHandler, CLLocationManagerDelegate {
  private let manager = CLLocationManager()
  private var sink: FlutterEventSink?

  override init() {
    super.init()
    manager.delegate = self
    manager.headingFilter = 1
    manager.headingOrientation = .portrait
    manager.desiredAccuracy = kCLLocationAccuracyKilometer
  }

  func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
    guard CLLocationManager.headingAvailable() else {
      return FlutterError(code: "no-heading", message: "Heading unavailable", details: nil)
    }
    sink = events
    // الموقع يجعل trueHeading صالحاً (لا يطلب إذناً: يعمل فقط إن كان الإذن ممنوحاً).
    switch manager.authorizationStatus {
    case .authorizedWhenInUse, .authorizedAlways: manager.startUpdatingLocation()
    default: break
    }
    manager.startUpdatingHeading()
    return nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    manager.stopUpdatingHeading()
    manager.stopUpdatingLocation()
    sink = nil
    return nil
  }

  func locationManager(_ manager: CLLocationManager, didUpdateHeading h: CLHeading) {
    let isTrue = h.trueHeading >= 0
    sink?([
      "heading": isTrue ? h.trueHeading : h.magneticHeading,
      "true": isTrue,
      "accuracy": h.headingAccuracy,
    ])
  }

  func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
    guard sink != nil else { return }
    switch manager.authorizationStatus {
    case .authorizedWhenInUse, .authorizedAlways: manager.startUpdatingLocation()
    default: break
    }
  }

  func locationManagerShouldDisplayHeadingCalibration(_ manager: CLLocationManager) -> Bool { true }
}

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private let heading = HeadingStream()

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "LamhaHeading") {
      FlutterEventChannel(name: "sa.lamha/heading", binaryMessenger: registrar.messenger())
        .setStreamHandler(heading)
    }
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
