import Flutter
import Foundation
import SwiftUI

#if canImport(AlarmKit)
import AlarmKit
#endif

/// جسر AlarmKit (آيفون ٢٦ فأحدث) للأذان الكامل: منبّه نظام يرنّ بصوت الأذان بلا ضغط، ويبقى حتى لو سحب المستخدم
/// التطبيق وأغلقه (DECISIONS ٣٨). على ما دون ٢٦ أو عند رفض الإذن يرجع Dart إلى إشعار المقطع القصير.
/// القناة `sa.lamha.lamha/adhan_alarm`: available، authorize، schedule(items، sound، stop)، cancelAll.
enum AdhanAlarmBridge {
  static func register(messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(name: "sa.lamha.lamha/adhan_alarm", binaryMessenger: messenger)
    channel.setMethodCallHandler { call, result in
      #if canImport(AlarmKit)
      if #available(iOS 26.0, *) {
        AdhanAlarms.handle(call, result)
        return
      }
      #endif
      switch call.method {
      case "available", "authorize": result(false)
      case "schedule", "cancelAll", "count": result(0)
      default: result(FlutterMethodNotImplemented)
      }
    }
  }
}

#if canImport(AlarmKit)
@available(iOS 26.0, *)
struct AdhanAlarmMetadata: AlarmMetadata {}

@available(iOS 26.0, *)
enum AdhanAlarms {
  static func handle(_ call: FlutterMethodCall, _ result: @escaping FlutterResult) {
    switch call.method {
    case "available":
      result(true)
    case "authorize":
      Task { result(await authorize()) }
    case "cancelAll":
      result(cancelAll())
    case "count":
      result(count())
    case "schedule":
      guard let args = call.arguments as? [String: Any],
            let items = args["items"] as? [[String: Any]],
            let sound = args["sound"] as? String,
            let stop = args["stop"] as? String else {
        result(FlutterError(code: "bad-args", message: "schedule needs items, sound, stop", details: nil))
        return
      }
      Task {
        do {
          result(try await schedule(items: items, sound: sound, stop: stop))
        } catch {
          result(FlutterError(code: "alarmkit", message: "\(error)", details: nil))
        }
      }
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  static func authorize() async -> Bool {
    switch AlarmManager.shared.authorizationState {
    case .authorized:
      return true
    case .notDetermined:
      let state = try? await AlarmManager.shared.requestAuthorization()
      return state == .authorized
    default:
      return false
    }
  }

  /// عدد منبّهات لمحة المجدولة فعلاً في النظام (للتحقق أن لا نسخ زائدة).
  static func count() -> Int {
    (try? AlarmManager.shared.alarms.count) ?? 0
  }

  /// معرّف ثابت للمنبّه من وقته (ثواني منذ ١٩٧٠): نفس الوقت = نفس المعرّف، فإعادة الجدولة تستبدل ولا تضيف نسخة
  /// (كان `UUID()` عشوائياً فتراكمت المنبّهات وتكرر الأذان ٢–٣ مرات).
  static func alarmId(_ seconds: Double) -> UUID {
    UUID(uuidString: String(format: "A11AAA11-0000-4000-8000-%012ld", Int(seconds.rounded())))!
  }

  /// يلغي كل منبّهات لمحة (كلها أذان) ويعيد عددها.
  static func cancelAll() -> Int {
    guard let alarms = try? AlarmManager.shared.alarms else { return 0 }
    for alarm in alarms { try? AlarmManager.shared.cancel(id: alarm.id) }
    return alarms.count
  }

  /// يجدول منبّهاً لكل عنصر {time: ثواني منذ ١٩٧٠، title}؛ يعيد عدد ما جُدول.
  static func schedule(items: [[String: Any]], sound: String, stop: String) async throws -> Int {
    var count = 0
    for item in items {
      guard let seconds = item["time"] as? Double, let title = item["title"] as? String else { continue }
      let date = Date(timeIntervalSince1970: seconds)
      guard date > Date() else { continue }
      let id = alarmId(seconds)
      try? AlarmManager.shared.cancel(id: id) // يستبدل منبّهاً بالمعرّف نفسه إن وُجد
      let alert = AlarmPresentation.Alert(
        title: LocalizedStringResource(stringLiteral: title),
        stopButton: AlarmButton(
          text: LocalizedStringResource(stringLiteral: stop),
          textColor: .white,
          systemImageName: "stop.circle"))
      let attributes = AlarmAttributes<AdhanAlarmMetadata>(
        presentation: AlarmPresentation(alert: alert),
        tintColor: Color(red: 0.88, green: 0.74, blue: 0.43))
      let configuration = AlarmManager.AlarmConfiguration<AdhanAlarmMetadata>.alarm(
        schedule: .fixed(date),
        attributes: attributes,
        sound: .named(sound))
      _ = try await AlarmManager.shared.schedule(id: id, configuration: configuration)
      count += 1
    }
    return count
  }
}
#endif
