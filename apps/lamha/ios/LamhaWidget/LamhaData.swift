import Foundation
import SwiftUI

// قراءة جدول «لمحة» من حاوية App Group (يكتبه التطبيق بمفتاح schedule، كـ LamhaSchedule.kt).
// الودجت تقرأ ولا تحسب: كل النصوص جاهزة من محرك Dart.

let appGroupId = "group.sa.lamha.shared"
let scheduleKey = "schedule"

struct Prayer: Identifiable {
    let id: String
    let name: String
    let time: Date
    let text: String
}

struct Deposit: Identifiable {
    let id: String
    let label: String
    let days: String
}

struct LamhaDay {
    let date: String
    let weekday: String
    let hijri: String
    let gregorian: String
    let prayers: [Prayer]
    let deposits: [Deposit]
    let seasonName: String
    let seasonAfter: String
    let tradName: String
    let tradAfter: String
    /// وصف الموسم يبدأ باسمه (descriptionLine في الجدول).
    let tradLine: String
}

struct LamhaSnapshot {
    let city: String
    let timeZone: TimeZone
    let qiblaText: String
    /// الزاوية («٣٢٤°») والاتجاه («شمال غرب») تحت دائرة القبلة، والزاوية رقماً لتدوير السهم.
    let qiblaAngleText: String
    let qiblaDirection: String
    let qiblaDegrees: Double
    let accent: Color
    /// خلفية أيقونة القبلة: التمييز معتّماً إلى ٢٨٪ (qiblaIconBackground في Dart وKotlin).
    let iconBackground: Color
    let background: Color
    let opacity: Double
    let weather: String?
    let days: [LamhaDay]

    /// يوم [date] بتوقيت المدينة، وإلا أول يوم.
    func day(at date: Date) -> LamhaDay? {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = timeZone
        f.dateFormat = "yyyy-MM-dd"
        let key = f.string(from: date)
        return days.first { $0.date == key } ?? days.first
    }

    /// الصلوات الخمس من [date] فصاعداً (اليوم ثم الغد) بلا الشروق.
    func upcomingPrayers(from date: Date) -> [Prayer] {
        days.flatMap { $0.prayers }.filter { $0.id != "sunrise" && $0.time > date }
    }

    /// الصلوات الخمس لليوم تبدأ بالقادمة (rotatePrayers في Dart).
    func rotatedPrayers(at date: Date) -> [Prayer] {
        let next = upcomingPrayers(from: date)
        return Array(next.prefix(5))
    }
}

private let isoFormatter: DateFormatter = {
    let f = DateFormatter()
    f.locale = Locale(identifier: "en_US_POSIX")
    f.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZ"
    return f
}()

private func argb(_ value: Any?, _ fallback: UInt32) -> UInt32 {
    (value as? NSNumber)?.uint32Value ?? fallback
}

private func darkened(_ v: UInt32) -> UInt32 {
    func ch(_ shift: UInt32) -> UInt32 { UInt32((Double((v >> shift) & 0xFF) * 0.28).rounded()) }
    return 0xFF00_0000 | ch(16) << 16 | ch(8) << 8 | ch(0)
}

private func color(_ value: Any?, _ fallback: UInt32) -> Color {
    let v = argb(value, fallback)
    return Color(
        .sRGB,
        red: Double((v >> 16) & 0xFF) / 255,
        green: Double((v >> 8) & 0xFF) / 255,
        blue: Double(v & 0xFF) / 255,
        opacity: Double((v >> 24) & 0xFF) / 255
    )
}

func loadSnapshot() -> LamhaSnapshot? {
    guard let json = UserDefaults(suiteName: appGroupId)?.string(forKey: scheduleKey),
          let data = json.data(using: .utf8),
          let root = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
    else { return nil }
    let city = root["city"] as? [String: Any] ?? [:]
    let theme = root["theme"] as? [String: Any] ?? [:]
    let qibla = root["qibla"] as? [String: Any] ?? [:]
    let weather = root["weather"] as? [String: Any]
    var weatherText: String?
    if let w = weather, let temp = w["tempText"] as? String {
        weatherText = [w["emoji"] as? String, temp].compactMap { $0 }.joined(separator: " ")
    }
    let days: [LamhaDay] = (root["days"] as? [[String: Any]] ?? []).map { d in
        let prayersMap = d["prayers"] as? [String: [String: Any]] ?? [:]
        let order = ["fajr", "sunrise", "dhuhr", "asr", "maghrib", "isha"]
        let prayers: [Prayer] = order.compactMap { key in
            guard let p = prayersMap[key], let t = p["time"] as? String,
                  let time = isoFormatter.date(from: t) else { return nil }
            return Prayer(id: key, name: p["name"] as? String ?? key, time: time,
                          text: p["text"] as? String ?? "")
        }
        let deposits: [Deposit] = (d["deposits"] as? [[String: Any]] ?? []).map {
            Deposit(id: $0["id"] as? String ?? "", label: $0["label"] as? String ?? "",
                    days: $0["daysText"] as? String ?? "")
        }
        let season = d["season"] as? [String: Any] ?? [:]
        let trad = d["tradSeason"] as? [String: Any] ?? [:]
        let nextSeason = (season["next"] as? [String: Any])?["name"] as? String ?? ""
        let nextTrad = (trad["next"] as? [String: Any])?["name"] as? String ?? ""
        return LamhaDay(
            date: d["date"] as? String ?? "",
            weekday: d["weekday"] as? String ?? "",
            hijri: ((d["hijri"] as? [String: Any])?["text"] as? String).map { $0 + " هـ" } ?? "",
            gregorian: ((d["gregorian"] as? [String: Any])?["text"] as? String).map { $0 + " م" } ?? "",
            prayers: prayers,
            deposits: deposits,
            seasonName: season["name"] as? String ?? "",
            seasonAfter: [nextSeason, season["afterText"] as? String ?? ""].joined(separator: " "),
            tradName: trad["name"] as? String ?? "",
            tradAfter: [nextTrad, trad["afterText"] as? String ?? ""].joined(separator: " "),
            tradLine: trad["descriptionLine"] as? String ?? trad["description"] as? String ?? ""
        )
    }
    return LamhaSnapshot(
        city: city["name"] as? String ?? "",
        timeZone: TimeZone(identifier: city["timeZone"] as? String ?? "Asia/Riyadh") ?? .current,
        qiblaText: qibla["text"] as? String ?? "",
        qiblaAngleText: (qibla["text"] as? String ?? "").components(separatedBy: "°").first.map { $0 + "°" } ?? "",
        qiblaDirection: qibla["direction"] as? String ?? "",
        qiblaDegrees: (qibla["degrees"] as? NSNumber)?.doubleValue ?? 0,
        accent: color(theme["accent"], 0xFFD6AA5C),
        iconBackground: color(NSNumber(value: darkened(argb(theme["accent"], 0xFFD6AA5C))), 0xFF3C301A),
        background: color(theme["background"], 0xFF000000),
        opacity: Double((root["opacity"] as? NSNumber)?.intValue ?? 100) / 100,
        weather: weatherText,
        days: days
    )
}
