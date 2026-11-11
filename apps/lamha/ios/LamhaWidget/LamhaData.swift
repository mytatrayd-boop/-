import Foundation
import ImageIO
import SwiftUI
import UIKit

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

/// نافذة من `layout` في الجدول (TileLayout.toScheduleJson في Dart): ما يظهر وترتيبه وحجم أيقونة القبلة،
/// ومعها شكلها: معامل الخط، وإظهار العنوان والسطر الفرعي، واللونان (nil = تلقائي).
struct LamhaTile {
    let id: String
    let visible: Bool
    let span: Int
    let iconScale: Double
    let fontScale: Double
    let showTitle: Bool
    let showSub: Bool
    let primary: Color?
    let secondary: Color?
}

/// شكل نافذة كما اختاره المستخدم في التطبيق: يُضرب به كل حجم نص، ويستبدل الألوان التلقائية.
struct TileStyle {
    var scale: CGFloat = 1
    var showTitle = true
    var showSub = true
    var primary: Color? = nil
    var secondary: Color? = nil

    func size(_ v: CGFloat) -> CGFloat { v * scale }
    /// لون النص الرئيسي: المختار، وإلا [fallback].
    func main(_ fallback: Color) -> Color { primary ?? fallback }
    /// لون النص الفرعي: المختار، وإلا [fallback].
    func sub(_ fallback: Color) -> Color { secondary ?? fallback }
}

/// شجرة القص من الجدول (`tree`، free_layout.dart في Dart): الودجت مقسومة صفوفاً وأعمدة متداخلة
/// بأوزان صحيحة، وفي كل ورقة عنصر أو فراغ. الودجت ترسمها كما هي ولا تحسب.
indirect enum CutTree {
    case tile(String)
    case empty
    /// vertical: الأبناء من الأعلى للأسفل؛ وإلا من اليمين لليسار (RTL).
    case split(vertical: Bool, children: [(weight: Int, node: CutTree)])

    static func parse(_ j: Any?) -> CutTree? {
        guard let m = j as? [String: Any] else { return nil }
        if let t = m["tile"] as? String { return .tile(t) }
        if let ch = m["children"] as? [[String: Any]], !ch.isEmpty {
            return .split(vertical: (m["dir"] as? String) == "v", children: ch.map {
                (weight: max(($0["w"] as? NSNumber)?.intValue ?? 1, 1), node: CutTree.parse($0) ?? .empty)
            })
        }
        return .empty
    }
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
    /// صورة الخلفية التي اختارها المستخدم (لقطة شاشته الرئيسية) من حاوية App Group، مصغّرة لحدود ذاكرة الودجت.
    /// آيفون لا يسمح بودجت شفافة فعلاً: تحت اللون الشفاف تظهر لوحة النظام البيضاء، فالصورة تحاكي الشفافية.
    let wallpaper: UIImage?
    let weather: String?
    let days: [LamhaDay]
    /// معامل الخط العام (إعداد «حجم الخط»)، يُضرب به معامل كل نافذة.
    let fontScale: Double
    /// إعداد «شكل الأرقام»: true = 0123 (latin)، false = ٠١٢٣.
    let latinDigits: Bool
    /// التخطيط الحر؛ nil لجدول أقدم بلا شجرة (يُرسم بالكتل القديمة).
    let tree: CutTree?
    /// النوافذ بترتيبها في تخطيط التطبيق؛ فارغة لجدول أقدم بلا layout.
    let tiles: [LamhaTile]

    /// هل نافذة [id] ظاهرة؟ جدول أقدم بلا layout: كلها ظاهرة.
    func isVisible(_ id: String) -> Bool {
        if tiles.isEmpty { return true }
        return tiles.first { $0.id == id }?.visible ?? false
    }

    /// موضع أقدم عنصر من [ids] في الترتيب، وتُرتَّب الكتل به (غير الموجود آخراً).
    func position(_ ids: [String]) -> Int {
        ids.compactMap { id in tiles.firstIndex { $0.id == id } }.min() ?? Int.max
    }

    /// شكل أول نافذة ظاهرة من [ids] (وإلا أول موجودة، وإلا الافتراضي). الساعة تحلّ محلها الصلاة القادمة
    /// في آيفون، فمعاملها الافتراضي ٢ يُعدّ أساسًا (١×).
    func style(_ ids: [String]) -> TileStyle {
        guard let t = tiles.first(where: { ids.contains($0.id) && $0.visible })
            ?? tiles.first(where: { ids.contains($0.id) })
        else { return TileStyle(scale: CGFloat(fontScale)) }
        let base: Double = t.id == "clock" ? 2 : 1
        return TileStyle(
            scale: CGFloat(fontScale * t.fontScale / base),
            showTitle: t.showTitle,
            showSub: t.showSub,
            primary: t.primary,
            secondary: t.secondary
        )
    }

    /// حجم أيقونة القبلة (٠٫٥–١٫٦، ١ افتراضياً).
    var qiblaIconScale: Double {
        min(max(tiles.first { $0.id == "qibla" }?.iconScale ?? 1, 0.5), 1.6)
    }

    /// الساعة بتوقيت المدينة: «١٠:٣٥» و«ص» أو «م» (كساعة أندرويد وDart).
    func clockText(at date: Date) -> (time: String, period: String) {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: latinDigits ? "en_US_POSIX" : "ar")
        f.timeZone = timeZone
        f.dateFormat = "h:mm"
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = timeZone
        return (f.string(from: date), cal.component(.hour, from: date) < 12 ? "ص" : "م")
    }

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

/// يقرأ [name] من حاوية App Group مصغّرة إلى [maxPixel] (الودجت محدودة الذاكرة نحو ٣٠ ميغابايت).
private func loadWallpaper(_ name: String?, maxPixel: Int = 900) -> UIImage? {
    guard let name, !name.isEmpty, !name.contains("/"),
          let dir = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupId),
          let src = CGImageSourceCreateWithURL(dir.appendingPathComponent(name) as CFURL, nil)
    else { return nil }
    let opts: [CFString: Any] = [
        kCGImageSourceCreateThumbnailFromImageAlways: true,
        kCGImageSourceCreateThumbnailWithTransform: true,
        kCGImageSourceThumbnailMaxPixelSize: maxPixel,
    ]
    guard let cg = CGImageSourceCreateThumbnailAtIndex(src, 0, opts as CFDictionary) else { return nil }
    return UIImage(cgImage: cg)
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
    let tiles: [LamhaTile] = (root["layout"] as? [[String: Any]] ?? []).compactMap { t in
        guard let id = t["id"] as? String else { return nil }
        return LamhaTile(
            id: id,
            visible: t["visible"] as? Bool ?? true,
            span: (t["span"] as? NSNumber)?.intValue ?? 1,
            iconScale: (t["iconScale"] as? NSNumber)?.doubleValue ?? 1,
            fontScale: min(max((t["fontScale"] as? NSNumber)?.doubleValue ?? 1, 0.5), 3),
            showTitle: t["showTitle"] as? Bool ?? true,
            showSub: t["showSub"] as? Bool ?? true,
            primary: (t["primaryColor"] as? NSNumber).map { color($0, 0xFF000000) },
            secondary: (t["secondaryColor"] as? NSNumber).map { color($0, 0xFF000000) }
        )
    }
    // الشفافية من مفتاحها المنفصل في App Group أولاً (يكتبه التطبيق مع كل حفظ)، ثم من الجدول.
    let storedOpacity = (UserDefaults(suiteName: appGroupId)?.object(forKey: "opacity") as? NSNumber)?.intValue
    let opacityPercent = min(max(storedOpacity ?? (root["opacity"] as? NSNumber)?.intValue ?? 100, 0), 100)
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
        opacity: Double(opacityPercent) / 100,
        wallpaper: loadWallpaper(root["background"] as? String),
        weather: weatherText,
        days: days,
        fontScale: min(max((root["fontScale"] as? NSNumber)?.doubleValue ?? 1, 0.5), 3),
        latinDigits: (root["digits"] as? String) == "latin",
        tree: CutTree.parse(root["tree"]),
        tiles: tiles
    )
}
