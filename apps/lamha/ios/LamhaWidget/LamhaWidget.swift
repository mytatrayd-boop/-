import SwiftUI
import WidgetKit

// ودجت «لمحة» لآيفون (الميزة ٤): كبيرة ومتوسطة وصغيرة للشاشة الرئيسية، ومستطيلة وسطر لشاشة القفل.
// النوع "LamhaWidget" كما في services.dart (widgetName)، فيعيد التطبيق تحميلها بعد كل حفظ.
// لا ساعة دقيقة بدقيقة في ودجت آيفون، فمكانها الصلاة القادمة بعدّاد حي.

private let qiblaURL = URL(string: "lamha://qibla?homeWidget")!
private let appURL = URL(string: "lamha://open?homeWidget")!
private let textColor = Color(red: 0.957, green: 0.937, blue: 0.902)
private let dimColor = Color(red: 0.725, green: 0.690, blue: 0.635)
private let boxColor = Color(red: 0.588, green: 0.667, blue: 0.824).opacity(0.25)

struct LamhaEntry: TimelineEntry {
    let date: Date
    let snapshot: LamhaSnapshot?
}

struct LamhaProvider: TimelineProvider {
    func placeholder(in context: Context) -> LamhaEntry {
        LamhaEntry(date: Date(), snapshot: nil)
    }

    func getSnapshot(in context: Context, completion: @escaping (LamhaEntry) -> Void) {
        completion(LamhaEntry(date: Date(), snapshot: loadSnapshot()))
    }

    /// مدخل الآن، ثم عند كل صلاة قادمة (تتغير القادمة) وعند منتصف ليل المدينة، لـ٢٤ ساعة.
    func getTimeline(in context: Context, completion: @escaping (Timeline<LamhaEntry>) -> Void) {
        let now = Date()
        let snap = loadSnapshot()
        var times: [Date] = [now]
        if let s = snap {
            times += s.upcomingPrayers(from: now).map { $0.time.addingTimeInterval(1) }
            var cal = Calendar(identifier: .gregorian)
            cal.timeZone = s.timeZone
            if let midnight = cal.nextDate(after: now, matching: DateComponents(hour: 0, minute: 0, second: 5),
                                           matchingPolicy: .nextTime) {
                times.append(midnight)
            }
        }
        let limit = now.addingTimeInterval(24 * 3600)
        let entries = Array(Set(times)).filter { $0 <= limit }.sorted().map { LamhaEntry(date: $0, snapshot: snap) }
        completion(Timeline(entries: entries, policy: .after(entries.last?.date.addingTimeInterval(60) ?? limit)))
    }
}

// MARK: - العناصر

/// مربع القبلة (lamha_qibla_update.md، qiblaTile في أندرويد): خلفية أيقونة القبلة، وفوقها دائرة بإطار
/// أزرق فاتح وN أحمر أعلاها، والكعبة في الوسط، ورأس سهم أبيض على المحيط مُدار بزاوية القبلة. الأبعاد
/// نسبةً للضلع كـ qiblaDial* في widget_preview_tiles.dart.
struct QiblaIcon: View {
    let degrees: Double
    let dark: Color
    var body: some View {
        GeometryReader { g in
            let side = min(g.size.width, g.size.height)
            let r = side * 0.36
            ZStack {
                Image("qibla_shape").resizable().renderingMode(.template).foregroundStyle(dark)
                Circle()
                    .stroke(Color(red: 133.0 / 255, green: 183.0 / 255, blue: 235.0 / 255), lineWidth: side * 0.03)
                    .frame(width: r * 2, height: r * 2)
                Image("kaaba").resizable().aspectRatio(1, contentMode: .fit).frame(width: side * 0.34)
                Text("N")
                    .font(.system(size: side * 0.12, weight: .bold))
                    .foregroundStyle(Color(red: 240.0 / 255, green: 149.0 / 255, blue: 149.0 / 255))
                    .offset(y: -side * 0.265)
                QiblaArrow(radius: r, side: side)
                    .fill(Color.white)
                    .frame(width: side, height: side)
                    .rotationEffect(.degrees(degrees))
            }
            .frame(width: side, height: side)
            .position(x: g.size.width / 2, y: g.size.height / 2)
        }
        .aspectRatio(1, contentMode: .fit)
        .environment(\.layoutDirection, .leftToRight)
    }
}

/// رأس السهم متجهاً للأعلى على محيط الدائرة: طرفه خارجها وقاعدته داخلها.
struct QiblaArrow: Shape {
    let radius: CGFloat
    let side: CGFloat
    func path(in rect: CGRect) -> Path {
        let c = CGPoint(x: rect.midX, y: rect.midY)
        var p = Path()
        p.move(to: CGPoint(x: c.x, y: c.y - (radius + side * 0.09)))
        p.addLine(to: CGPoint(x: c.x + side * 0.065, y: c.y - (radius - side * 0.03)))
        p.addLine(to: CGPoint(x: c.x - side * 0.065, y: c.y - (radius - side * 0.03)))
        p.closeSubpath()
        return p
    }
}

struct NextPrayerView: View {
    let prayer: Prayer?
    let accent: Color
    var big = true
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            if let p = prayer {
                Text(p.name).font(.system(size: big ? 26 : 20, weight: .bold)).foregroundStyle(accent)
                Text(p.text).font(.system(size: big ? 16 : 13, weight: .medium)).foregroundStyle(textColor)
                Text(p.time, style: .timer)
                    .font(.system(size: big ? 15 : 12, weight: .medium).monospacedDigit())
                    .foregroundStyle(dimColor)
                    .multilineTextAlignment(.leading)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct PrayerRow: View {
    let prayers: [Prayer]
    let accent: Color
    var body: some View {
        HStack(spacing: 4) {
            ForEach(Array(prayers.enumerated()), id: \.offset) { i, p in
                VStack(spacing: 2) {
                    Text(p.name).font(.system(size: 14, weight: .bold))
                    Text(p.text).font(.system(size: 11, weight: .medium))
                }
                .foregroundStyle(i == 0 ? accent : textColor)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.vertical, 6)
        .background(RoundedRectangle(cornerRadius: 14).fill(boxColor))
    }
}

struct DepositsGrid: View {
    let deposits: [Deposit]
    var body: some View {
        let cols = deposits.count > 3 ? 2 : 1
        let rows = stride(from: 0, to: deposits.count, by: cols).map { Array(deposits[$0..<min($0 + cols, deposits.count)]) }
        VStack(spacing: 3) {
            ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                HStack(spacing: 3) {
                    ForEach(row) { d in
                        HStack(spacing: 4) {
                            Text(d.label).foregroundStyle(textColor).lineLimit(1)
                            Spacer(minLength: 2)
                            Text(d.days).foregroundStyle(dimColor).lineLimit(1)
                        }
                        .font(.system(size: 12))
                        .minimumScaleFactor(0.7)
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(RoundedRectangle(cornerRadius: 9).fill(boxColor))
                    }
                    if row.count < cols { Color.clear.frame(maxWidth: .infinity) }
                }
            }
        }
    }
}

struct SeasonBox: View {
    let title: String
    let sub: String
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.system(size: 15, weight: .bold)).foregroundStyle(textColor)
            Text(sub).font(.system(size: 11)).foregroundStyle(dimColor).lineLimit(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(6)
        .background(RoundedRectangle(cornerRadius: 12).fill(boxColor))
    }
}

// MARK: - الأحجام

struct LamhaWidgetView: View {
    @Environment(\.widgetFamily) var family
    let entry: LamhaEntry

    var body: some View {
        Group {
            if let s = entry.snapshot, let day = s.day(at: entry.date) {
                switch family {
                case .systemSmall: small(s, day)
                case .systemMedium: medium(s, day)
                case .accessoryRectangular: rectangular(s)
                case .accessoryInline: inline(s)
                default: large(s, day)
                }
            } else {
                Text("افتح لمحة لإعداد الودجت")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(textColor)
                    .multilineTextAlignment(.center)
            }
        }
        .environment(\.layoutDirection, .rightToLeft)
        .environment(\.locale, Locale(identifier: "ar"))
        .widgetURL(appURL)
    }

    private func next(_ s: LamhaSnapshot) -> Prayer? { s.upcomingPrayers(from: entry.date).first }

    private func header(_ s: LamhaSnapshot, _ day: LamhaDay) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(day.weekday).font(.system(size: 18, weight: .bold)).foregroundStyle(textColor)
            Text("📍 " + s.city + (s.weather.map { " " + $0 } ?? ""))
                .font(.system(size: 12)).foregroundStyle(dimColor).lineLimit(1)
        }
    }

    private func dates(_ day: LamhaDay) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            ForEach([day.hijri, day.gregorian], id: \.self) { t in
                Text(t).font(.system(size: 13, weight: .bold)).foregroundStyle(textColor)
                    .lineLimit(1).minimumScaleFactor(0.7)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 8).padding(.vertical, 5)
                    .background(Capsule().fill(boxColor))
            }
        }
    }

    private func qibla(_ s: LamhaSnapshot) -> some View {
        Link(destination: qiblaURL) {
            VStack(spacing: 1) {
                QiblaIcon(degrees: s.qiblaDegrees, dark: s.iconBackground)
                Text(s.qiblaAngleText).font(.system(size: 14, weight: .bold)).foregroundStyle(textColor)
                    .lineLimit(1).minimumScaleFactor(0.6)
                Text("من الشمال · " + s.qiblaDirection).font(.system(size: 9, weight: .medium))
                    .foregroundStyle(dimColor).lineLimit(1).minimumScaleFactor(0.6)
            }
        }
    }

    private func large(_ s: LamhaSnapshot, _ day: LamhaDay) -> some View {
        VStack(spacing: 8) {
            HStack(alignment: .top) {
                NextPrayerView(prayer: next(s), accent: s.accent)
                header(s, day)
            }
            HStack(spacing: 8) {
                dates(day)
                qibla(s).frame(width: 70)
            }
            PrayerRow(prayers: s.rotatedPrayers(at: entry.date), accent: s.accent)
            DepositsGrid(deposits: Array(day.deposits.prefix(6)))
            HStack(spacing: 6) {
                SeasonBox(title: day.seasonName, sub: day.seasonAfter)
                SeasonBox(title: day.tradName, sub: day.tradAfter)
            }
        }
    }

    private func medium(_ s: LamhaSnapshot, _ day: LamhaDay) -> some View {
        VStack(spacing: 6) {
            HStack(alignment: .top, spacing: 8) {
                NextPrayerView(prayer: next(s), accent: s.accent, big: false)
                VStack(alignment: .leading, spacing: 2) {
                    Text(day.weekday).font(.system(size: 15, weight: .bold)).foregroundStyle(textColor)
                    Text(day.hijri).font(.system(size: 11)).foregroundStyle(dimColor).lineLimit(1)
                }
                qibla(s).frame(width: 52)
            }
            PrayerRow(prayers: s.rotatedPrayers(at: entry.date), accent: s.accent)
        }
    }

    private func small(_ s: LamhaSnapshot, _ day: LamhaDay) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            NextPrayerView(prayer: next(s), accent: s.accent, big: false)
            Spacer(minLength: 0)
            Text(day.hijri).font(.system(size: 11, weight: .medium)).foregroundStyle(textColor)
                .lineLimit(1).minimumScaleFactor(0.7)
            if let d = day.deposits.first {
                Text(d.label + " " + d.days).font(.system(size: 11)).foregroundStyle(dimColor)
                    .lineLimit(1).minimumScaleFactor(0.7)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func rectangular(_ s: LamhaSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            if let p = next(s) {
                Text(p.name + " · " + p.text).font(.system(size: 15, weight: .bold))
                Text(p.time, style: .timer).font(.system(size: 13).monospacedDigit())
            }
            Text("القبلة " + s.qiblaText).font(.system(size: 12)).lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func inline(_ s: LamhaSnapshot) -> some View {
        Text(next(s).map { $0.name + " " + $0.text } ?? "لمحة")
    }
}

struct LamhaWidget: Widget {
    let kind = "LamhaWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: LamhaProvider()) { entry in
            let s = entry.snapshot
            LamhaWidgetView(entry: entry)
                .containerBackground(for: .widget) {
                    (s?.background ?? .black).opacity(s?.opacity ?? 1)
                }
        }
        .configurationDisplayName("لمحة")
        .description("الصلاة والقبلة والتاريخان والإيداعات والمواسم في لمحة.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge, .accessoryRectangular, .accessoryInline])
    }
}

@main
struct LamhaWidgetBundle: WidgetBundle {
    var body: some Widget {
        LamhaWidget()
    }
}
