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

/// مربع القبلة (صورة المالك، drawQiblaDial في أندرويد وQiblaTileDialPainter في Dart): بوصلة سوداء
/// بتدريج أبيض وحروف N وE وS وW، ونجمة داكنة، وسهم أحمر من المركز ثم خط منقّط إلى الكعبة على المحيط
/// بزاوية القبلة. الأبعاد نسبةً للضلع كما في widget_preview_tiles.dart. [dark] لم يعد يُستخدم.
struct QiblaIcon: View {
    let degrees: Double
    let dark: Color
    /// القرص الأسود يتبع شفافية خلفية الودجت، والتدريج والسهم يبقيان.
    var faceOpacity: Double = 1
    var body: some View {
        GeometryReader { g in
            let side = min(g.size.width, g.size.height)
            let a = degrees * .pi / 180
            ZStack {
                Circle().fill(Color.black.opacity(faceOpacity)).frame(width: side * 0.98, height: side * 0.98)
                QiblaTicks(side: side).frame(width: side, height: side)
                ForEach(Array([(0.0, "N"), (90.0, "E"), (180.0, "S"), (270.0, "W")].enumerated()), id: \.offset) { _, item in
                    let r = item.0 * .pi / 180
                    Text(item.1)
                        .font(.system(size: side * 0.13, weight: .bold))
                        .foregroundStyle(Color.white)
                        .offset(x: sin(r) * side * 0.36, y: -cos(r) * side * 0.36)
                }
                QiblaStar(side: side).fill(Color(white: 0.23)).frame(width: side, height: side)
                QiblaArrow(side: side)
                    .fill(Color(red: 229.0 / 255, green: 57.0 / 255, blue: 53.0 / 255))
                    .frame(width: side, height: side)
                    .rotationEffect(.degrees(degrees))
                Image("kaaba").resizable().aspectRatio(1, contentMode: .fit).frame(width: side * 0.18)
                    .offset(x: sin(a) * side * 0.36, y: -cos(a) * side * 0.36)
            }
            .frame(width: side, height: side)
            .position(x: g.size.width / 2, y: g.size.height / 2)
        }
        .aspectRatio(1, contentMode: .fit)
        .environment(\.layoutDirection, .leftToRight)
    }
}

/// التدريج: كل ١٠° (أطول كل ٣٠°)، بلا خطوط عند الجهات الأربع (مكان الحروف).
struct QiblaTicks: View {
    let side: CGFloat
    var body: some View {
        Canvas { ctx, size in
            let c = CGPoint(x: size.width / 2, y: size.height / 2)
            for d in stride(from: 0, to: 360, by: 10) where d % 90 != 0 {
                let a = Double(d) * .pi / 180
                let long = d % 30 == 0
                let inner = side * (long ? 0.38 : 0.41), outer = side * 0.46
                var p = Path()
                p.move(to: CGPoint(x: c.x + sin(a) * inner, y: c.y - cos(a) * inner))
                p.addLine(to: CGPoint(x: c.x + sin(a) * outer, y: c.y - cos(a) * outer))
                ctx.stroke(p, with: .color(.white), style: StrokeStyle(lineWidth: side * (long ? 0.022 : 0.014), lineCap: .round))
            }
        }
    }
}

/// نجمة ثمانية الرؤوس في الوسط (الطويلة للجهات الأربع).
struct QiblaStar: Shape {
    let side: CGFloat
    func path(in rect: CGRect) -> Path {
        let c = CGPoint(x: rect.midX, y: rect.midY)
        var p = Path()
        for i in 0..<8 {
            let a = Double(i) * .pi / 4
            let len = side * 0.2 * (i % 2 == 0 ? 1 : 0.6), w = side * 0.035
            p.move(to: CGPoint(x: c.x + cos(a) * w, y: c.y + sin(a) * w))
            p.addLine(to: CGPoint(x: c.x + sin(a) * len, y: c.y - cos(a) * len))
            p.addLine(to: CGPoint(x: c.x - cos(a) * w, y: c.y - sin(a) * w))
            p.closeSubpath()
        }
        return p
    }
}

/// السهم الأحمر متجهاً للأعلى من المركز، ثم نقاط حتى الكعبة.
struct QiblaArrow: Shape {
    let side: CGFloat
    func path(in rect: CGRect) -> Path {
        let c = CGPoint(x: rect.midX, y: rect.midY)
        var p = Path()
        p.move(to: CGPoint(x: c.x, y: c.y - side * 0.24))
        p.addLine(to: CGPoint(x: c.x + side * 0.07, y: c.y + side * 0.03))
        p.addLine(to: CGPoint(x: c.x, y: c.y - side * 0.02))
        p.addLine(to: CGPoint(x: c.x - side * 0.07, y: c.y + side * 0.03))
        p.closeSubpath()
        var t: CGFloat = 0.26
        while t < 0.36 - 0.18 / 2.6 {
            p.addEllipse(in: CGRect(x: c.x - side * 0.009, y: c.y - side * (t + 0.012), width: side * 0.018, height: side * 0.018))
            t += 0.035
        }
        return p
    }
}

struct NextPrayerView: View {
    let prayer: Prayer?
    let accent: Color
    var big = true
    /// العدّاد التنازلي تحت الوقت: اختياري ومطفأ افتراضياً (إعداد «العدّاد التنازلي للصلاة القادمة»).
    var countdown = false
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            if let p = prayer {
                Text(p.name).font(.system(size: big ? 26 : 20, weight: .bold)).foregroundStyle(accent)
                Text(p.text).font(.system(size: big ? 16 : 13, weight: .medium)).foregroundStyle(textColor)
                if countdown {
                    Text(p.time, style: .timer)
                        .font(.system(size: big ? 15 : 12, weight: .medium).monospacedDigit())
                        .foregroundStyle(dimColor)
                        .multilineTextAlignment(.leading)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct PrayerRow: View {
    let prayers: [Prayer]
    let accent: Color
    /// يتمدد رأسياً ليملأ ما تركته النوافذ المخفية.
    var stretch = false
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
        .frame(maxHeight: stretch ? CGFloat.infinity : nil)
        .background(RoundedRectangle(cornerRadius: 14).fill(boxColor))
    }
}

struct DepositsGrid: View {
    let deposits: [Deposit]
    var stretch = false
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
                        .frame(maxWidth: .infinity, maxHeight: stretch ? CGFloat.infinity : nil)
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
    var stretch = false
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.system(size: 15, weight: .bold)).foregroundStyle(textColor)
            Text(sub).font(.system(size: 11)).foregroundStyle(dimColor).lineLimit(2)
        }
        .frame(maxWidth: .infinity, maxHeight: stretch ? CGFloat.infinity : nil, alignment: .leading)
        .padding(6)
        .background(RoundedRectangle(cornerRadius: 12).fill(boxColor))
    }
}

/// مربع الموسم بتنسيق المالك: «الوسم (المربعانية بعد ٤٠ يوماً)» ثم الوصف يبدأ باسم الموسم.
struct TradSeasonBox: View {
    let name: String
    let after: String
    let line: String
    var stretch = false
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            (Text(name).font(.system(size: 15, weight: .bold)).foregroundColor(textColor)
                + Text(" (" + after + ")").font(.system(size: 11)).foregroundColor(dimColor))
                .lineLimit(1)
            if !line.isEmpty {
                Text(line).font(.system(size: 11)).foregroundStyle(dimColor).lineLimit(3)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: stretch ? CGFloat.infinity : nil, alignment: .leading)
        .padding(6)
        .background(RoundedRectangle(cornerRadius: 12).fill(boxColor))
    }
}

// MARK: - الأحجام

/// كتلة في الودجت الكبيرة: موضعها في ترتيب التطبيق وعرضها. المخفية لا تُبنى، والباقية تتمدد.
struct LamhaBlock: Identifiable {
    let id: String
    let position: Int
    let view: AnyView
}

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

    /// كبسولتا التاريخين حسب ما فُعّل: الهجري والميلادي كلٌّ على حدة (أو «التاريخان» القديمة).
    private func dates(_ s: LamhaSnapshot, _ day: LamhaDay) -> some View {
        let both = s.isVisible("dates")
        let hijri: String? = (both || s.isVisible("hijri")) ? day.hijri : nil
        let gregorian: String? = (both || s.isVisible("gregorian")) ? day.gregorian : nil
        let items: [String] = [hijri, gregorian].compactMap { $0 }
        return VStack(alignment: .leading, spacing: 3) {
            ForEach(items, id: \.self) { t in
                Text(t).font(.system(size: 13, weight: .bold)).foregroundStyle(textColor)
                    .lineLimit(1).minimumScaleFactor(0.7)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 8).padding(.vertical, 5)
                    .background(Capsule().fill(boxColor))
            }
        }
    }

    private func qibla(_ s: LamhaSnapshot, width: CGFloat) -> some View {
        Link(destination: qiblaURL) {
            VStack(spacing: 1) {
                QiblaIcon(degrees: s.qiblaDegrees, dark: s.iconBackground, faceOpacity: s.opacity)
                Text(s.qiblaAngleText).font(.system(size: 14, weight: .bold)).foregroundStyle(textColor)
                    .lineLimit(1).minimumScaleFactor(0.6)
                Text("من الشمال · " + s.qiblaDirection).font(.system(size: 9, weight: .medium))
                    .foregroundStyle(dimColor).lineLimit(1).minimumScaleFactor(0.6)
            }
        }
        .frame(width: width)
    }

    /// الودجت الكبيرة (طلب المالك ٣٠/١٠/٢٠٢٦): تتبع تخطيط التطبيق. كل كتلة بترتيب أول نافذة لها
    /// فيه، والنافذة الموقوفة تختفي والباقية تتمدد لتملأ الودجت (كما تفعل المعاينة وأندرويد).
    private func large(_ s: LamhaSnapshot, _ day: LamhaDay) -> some View {
        let blocks = largeBlocks(s, day).sorted { $0.position < $1.position }
        return VStack(spacing: 8) {
            ForEach(blocks) { b in b.view }
        }
    }

    private func largeBlocks(_ s: LamhaSnapshot, _ day: LamhaDay) -> [LamhaBlock] {
        var blocks: [LamhaBlock] = []
        // الصف العلوي: الصلاة القادمة (مكان الساعة) واليوم والطقس.
        let showPrayer = s.isVisible("clock") || s.isVisible("prayer")
        let showHeader = s.isVisible("dayWeather") || s.isVisible("weather")
        if showPrayer || showHeader {
            blocks.append(LamhaBlock(
                id: "top",
                position: s.position(["clock", "prayer", "dayWeather", "weather"]),
                view: AnyView(
                    HStack(alignment: .top) {
                        if showPrayer {
                            NextPrayerView(prayer: next(s), accent: s.accent, countdown: s.prayerCountdown)
                        }
                        if showHeader { header(s, day) }
                    }
                )
            ))
        }
        // التاريخان والقبلة (حجم أيقونتها من شريط التطبيق).
        let showDates = s.isVisible("dates") || s.isVisible("hijri") || s.isVisible("gregorian")
        let showQibla = s.isVisible("qibla")
        if showDates || showQibla {
            blocks.append(LamhaBlock(
                id: "dates",
                position: s.position(["dates", "hijri", "gregorian", "qibla"]),
                view: AnyView(
                    HStack(spacing: 8) {
                        if showDates { dates(s, day) }
                        if showQibla { qibla(s, width: CGFloat(70 * s.qiblaIconScale)) }
                    }
                    .frame(maxHeight: CGFloat.infinity)
                )
            ))
        }
        if s.isVisible("prayerTimes") {
            blocks.append(LamhaBlock(
                id: "prayerTimes",
                position: s.position(["prayerTimes"]),
                view: AnyView(PrayerRow(prayers: s.rotatedPrayers(at: entry.date), accent: s.accent, stretch: true))
            ))
        }
        if s.isVisible("deposit") {
            blocks.append(LamhaBlock(
                id: "deposit",
                position: s.position(["deposit"]),
                view: AnyView(DepositsGrid(deposits: Array(day.deposits.prefix(6)), stretch: true))
            ))
        }
        // الفصل والموسم في صف واحد: الموقوف منهما يختفي والآخر يملأ الصف.
        let showSeason = s.isVisible("season")
        let showTrad = s.isVisible("tradSeason")
        if showSeason || showTrad {
            blocks.append(LamhaBlock(
                id: "seasons",
                position: s.position(["season", "tradSeason"]),
                view: AnyView(
                    HStack(spacing: 6) {
                        if showSeason { SeasonBox(title: day.seasonName, sub: day.seasonAfter, stretch: true) }
                        if showTrad {
                            TradSeasonBox(name: day.tradName, after: day.tradAfter, line: day.tradLine, stretch: true)
                                .layoutPriority(1)
                        }
                    }
                )
            ))
        }
        return blocks
    }

    private func medium(_ s: LamhaSnapshot, _ day: LamhaDay) -> some View {
        VStack(spacing: 6) {
            HStack(alignment: .top, spacing: 8) {
                NextPrayerView(prayer: next(s), accent: s.accent, big: false, countdown: s.prayerCountdown)
                VStack(alignment: .leading, spacing: 2) {
                    Text(day.weekday).font(.system(size: 15, weight: .bold)).foregroundStyle(textColor)
                    Text(day.hijri).font(.system(size: 11)).foregroundStyle(dimColor).lineLimit(1)
                }
                if s.isVisible("qibla") { qibla(s, width: CGFloat(52 * s.qiblaIconScale)) }
            }
            if s.isVisible("prayerTimes") {
                PrayerRow(prayers: s.rotatedPrayers(at: entry.date), accent: s.accent)
            }
        }
    }

    private func small(_ s: LamhaSnapshot, _ day: LamhaDay) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            NextPrayerView(prayer: next(s), accent: s.accent, big: false, countdown: s.prayerCountdown)
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
