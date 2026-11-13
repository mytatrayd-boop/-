import SwiftUI
import WidgetKit

// ودجت «لمحة» لآيفون (الميزة ٤): كبيرة ومتوسطة وصغيرة للشاشة الرئيسية، ومستطيلة وسطر لشاشة القفل.
// النوع "LamhaWidget" كما في services.dart (widgetName)، فيعيد التطبيق تحميلها بعد كل حفظ.
// لا ساعة دقيقة بدقيقة في ودجت آيفون، فمكانها الصلاة القادمة (واسمها ووقتها). لا عدّاد تنازلي (حُذف نهائياً).

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
        // الساعة في آيفون (طلب المالك ١١/١١/٢٠٢٦): مدخل كل دقيقة لـ٩٠ دقيقة ثم إعادة تحميل، فتتقدم الساعة.
        let clock = snap.map { $0.isVisible("clock") } ?? false
        if clock {
            let minute = Date(timeIntervalSince1970: (now.timeIntervalSince1970 / 60).rounded(.down) * 60)
            times += (1...90).map { minute.addingTimeInterval(Double($0) * 60) }
        }
        let limit = now.addingTimeInterval(clock ? 90 * 60 : 24 * 3600)
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
    var style = TileStyle()
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            if let p = prayer {
                Text(p.name).font(.system(size: style.size(big ? 26 : 20), weight: .bold))
                    .foregroundStyle(style.main(accent)).lineLimit(1).minimumScaleFactor(0.6)
                Text(p.text).font(.system(size: style.size(big ? 16 : 13), weight: .medium))
                    .foregroundStyle(style.main(textColor)).lineLimit(1).minimumScaleFactor(0.6)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// الساعة بتوقيت المدينة مع «ص/م» (مكان الصلاة القادمة سابقاً؛ الصلاة القادمة أولى صف المواقيت).
struct ClockView: View {
    let text: (time: String, period: String)
    var big = true
    var style = TileStyle()
    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 4) {
            Text(text.time).font(.system(size: style.size(big ? 40 : 28), weight: .bold))
                .foregroundStyle(style.main(textColor))
            Text(text.period).font(.system(size: style.size(big ? 16 : 13), weight: .medium))
                .foregroundStyle(style.sub(dimColor))
        }
        .lineLimit(1).minimumScaleFactor(0.5)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct PrayerRow: View {
    let prayers: [Prayer]
    let accent: Color
    /// يتمدد رأسياً ليملأ ما تركته النوافذ المخفية.
    var stretch = false
    var style = TileStyle()
    var body: some View {
        HStack(spacing: 4) {
            ForEach(Array(prayers.enumerated()), id: \.offset) { i, p in
                VStack(spacing: 2) {
                    Text(p.name).font(.system(size: style.size(14), weight: .bold))
                        .foregroundStyle(style.main(i == 0 ? accent : textColor))
                    if style.showSub {
                        Text(p.text).font(.system(size: style.size(11), weight: .medium))
                            .foregroundStyle(style.sub(i == 0 ? accent : textColor))
                    }
                }
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
    var style = TileStyle()
    var body: some View {
        let cols = deposits.count > 3 ? 2 : 1
        let rows = stride(from: 0, to: deposits.count, by: cols).map { Array(deposits[$0..<min($0 + cols, deposits.count)]) }
        VStack(spacing: 3) {
            ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                HStack(spacing: 3) {
                    ForEach(row) { d in
                        HStack(spacing: 4) {
                            Text(d.label).foregroundStyle(style.main(textColor)).lineLimit(1)
                            Spacer(minLength: 2)
                            if style.showSub { Text(d.days).foregroundStyle(style.sub(dimColor)).lineLimit(1) }
                        }
                        .font(.system(size: style.size(12)))
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
    var style = TileStyle()
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.system(size: style.size(15), weight: .bold)).foregroundStyle(style.main(textColor))
                .lineLimit(1).minimumScaleFactor(0.7)
            if style.showSub {
                Text(sub).font(.system(size: style.size(11))).foregroundStyle(style.sub(dimColor)).lineLimit(2)
                    .minimumScaleFactor(0.7)
            }
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
    var style = TileStyle()
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            (Text(name).font(.system(size: style.size(15), weight: .bold)).foregroundColor(style.main(textColor))
                + Text(" (" + after + ")").font(.system(size: style.size(11))).foregroundColor(style.sub(dimColor)))
                .lineLimit(1).minimumScaleFactor(0.7)
            if style.showSub && !line.isEmpty {
                Text(line).font(.system(size: style.size(11))).foregroundStyle(style.sub(dimColor)).lineLimit(3)
                    .minimumScaleFactor(0.7)
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
                default: large(s, day).overlay(floatTiles(s, day))
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

    /// المربعات العائمة (DECISIONS ٢٩): كل مربع له `float` فوق المربعات بموضعه ومقاسه (كسور من الودجت كلها،
    /// كالمعاينة وأندرويد)، بحشوة الخانة نفسها (٤). الطبقة تمتد ١٤ نقطة خارج المحتوى لتطابق حاشية المعاينة،
    /// فيقاس الموضع من حافة الودجت.
    @ViewBuilder
    private func floatTiles(_ s: LamhaSnapshot, _ day: LamhaDay) -> some View {
        let floats = s.tiles.filter { $0.visible && $0.float != nil }
        if !floats.isEmpty {
            GeometryReader { g in
                let w = g.size.width, h = g.size.height
                ForEach(Array(floats.enumerated()), id: \.offset) { _, t in
                    let f = t.float!
                    let width = min(max(CGFloat(f[2]), 0.12), 1) * w
                    let height = min(max(CGFloat(f[3]), 0.06), 1) * h
                    let right = min(max(CGFloat(f[0]) * w, 0), max(0, w - width))
                    let top = min(max(CGFloat(f[1]) * h, 0), max(0, h - height))
                    tile(t.id, s, day)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .padding(4)
                        .frame(width: width, height: height)
                        // x من اليسار (position لا يتبع اتجاه اللغة)، والبعد من اليمين.
                        .position(x: w - right - width / 2, y: top + height / 2)
                }
            }
            .padding(-14)
        }
    }

    private func next(_ s: LamhaSnapshot) -> Prayer? { s.upcomingPrayers(from: entry.date).first }

    /// [centered]: في التخطيط الحر يتوسط النص مربعه (طلب المالك ١١/١١/٢٠٢٦)، وفي الترتيب القديم يبقى عند البداية.
    private func header(_ s: LamhaSnapshot, _ day: LamhaDay, centered: Bool = false) -> some View {
        let st = s.style(["dayWeather", "weather"])
        return VStack(alignment: centered ? .center : .leading, spacing: 1) {
            Text(day.weekday).font(.system(size: st.size(18), weight: .bold)).foregroundStyle(st.main(textColor))
                .lineLimit(1).minimumScaleFactor(0.7)
            if st.showSub {
                Text("📍 " + s.city + (s.weather.map { " " + $0 } ?? ""))
                    .font(.system(size: st.size(12))).foregroundStyle(st.sub(dimColor)).lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
        }
        .multilineTextAlignment(centered ? .center : .leading)
        .frame(maxWidth: centered ? .infinity : nil)
    }

    /// كبسولتا التاريخين حسب ما فُعّل: الهجري والميلادي كلٌّ على حدة (أو «التاريخان» القديمة).
    private func dates(_ s: LamhaSnapshot, _ day: LamhaDay) -> some View {
        let both = s.isVisible("dates")
        let hijri: (String, TileStyle)? = (both || s.isVisible("hijri")) ? (day.hijri, s.style(both ? ["dates"] : ["hijri"])) : nil
        let gregorian: (String, TileStyle)? = (both || s.isVisible("gregorian")) ? (day.gregorian, s.style(both ? ["dates"] : ["gregorian"])) : nil
        let items: [(String, TileStyle)] = [hijri, gregorian].compactMap { $0 }
        return VStack(alignment: .leading, spacing: 3) {
            ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                Text(item.0).font(.system(size: item.1.size(13), weight: .bold)).foregroundStyle(item.1.main(textColor))
                    .lineLimit(1).minimumScaleFactor(0.7)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 8).padding(.vertical, 5)
                    .background(Capsule().fill(boxColor))
            }
        }
    }

    private func qibla(_ s: LamhaSnapshot, width: CGFloat) -> some View {
        let st = s.style(["qibla"])
        return Link(destination: qiblaURL) {
            VStack(spacing: 1) {
                QiblaIcon(degrees: s.qiblaDegrees, dark: s.iconBackground, faceOpacity: s.opacity)
                if st.showTitle {
                    Text(s.qiblaAngleText).font(.system(size: st.size(14), weight: .bold)).foregroundStyle(st.main(textColor))
                        .lineLimit(1).minimumScaleFactor(0.6)
                    Text("من الشمال · " + s.qiblaDirection).font(.system(size: st.size(9), weight: .medium))
                        .foregroundStyle(st.sub(dimColor)).lineLimit(1).minimumScaleFactor(0.6)
                }
            }
        }
        .frame(width: width)
    }

    /// الودجت الكبيرة (طلب المالك ٣٠/١٠/٢٠٢٦): تتبع تخطيط التطبيق. كل كتلة بترتيب أول نافذة لها
    /// فيه، والنافذة الموقوفة تختفي والباقية تتمدد لتملأ الودجت (كما تفعل المعاينة وأندرويد).
    private func large(_ s: LamhaSnapshot, _ day: LamhaDay) -> some View {
        Group {
            if let tree = s.tree {
                // التخطيط الحر: شجرة التطبيق نفسها، وحول كل مربع نصف التباعد (كالمعاينة: tileSpacing / 2).
                node(tree, s, day).padding(-4)
            } else {
                let blocks = largeBlocks(s, day).sorted { $0.position < $1.position }
                VStack(spacing: 8) {
                    ForEach(blocks) { b in b.view }
                }
            }
        }
    }

    /// ورقة أو تقسيم: كل جزء بنسبة وزنه من المقاس المتاح.
    private func node(_ n: CutTree, _ s: LamhaSnapshot, _ day: LamhaDay) -> AnyView {
        switch n {
        case .empty:
            return AnyView(Color.clear)
        case .tile(let id):
            return AnyView(tile(id, s, day).frame(maxWidth: .infinity, maxHeight: .infinity).padding(4))
        case .split(let vertical, let children):
            let total = CGFloat(children.reduce(0) { $0 + $1.weight })
            return AnyView(GeometryReader { g in
                if vertical {
                    VStack(spacing: 0) {
                        ForEach(Array(children.enumerated()), id: \.offset) { _, c in
                            node(c.node, s, day).frame(width: g.size.width, height: g.size.height * CGFloat(c.weight) / total)
                        }
                    }
                } else {
                    HStack(spacing: 0) {
                        ForEach(Array(children.enumerated()), id: \.offset) { _, c in
                            node(c.node, s, day).frame(width: g.size.width * CGFloat(c.weight) / total, height: g.size.height)
                        }
                    }
                }
            })
        }
    }

    /// عنصر واحد في مستطيله (أسماء WidgetElement في Dart).
    @ViewBuilder
    private func tile(_ id: String, _ s: LamhaSnapshot, _ day: LamhaDay) -> some View {
        switch id {
        case "clock":
            ClockView(text: s.clockText(at: entry.date), style: s.style(["clock"]))
        case "prayer":
            NextPrayerView(prayer: next(s), accent: s.accent, style: s.style(["prayer"]))
        case "dayWeather", "weather":
            header(s, day, centered: true)
        case "weekday":
            // اليوم وحده في مربعه (طلب المالك ١٣ نوفمبر: فصله عن الموقع والحرارة).
            let st = s.style(["weekday"])
            Text(day.weekday).font(.system(size: st.size(20), weight: .bold)).foregroundStyle(st.main(textColor))
                .lineLimit(1).minimumScaleFactor(0.6)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        case "cityTemp":
            // الموقع والحرارة وحدهما في مربعهما.
            let st = s.style(["cityTemp"])
            Text("📍 " + s.city + (s.weather.map { " " + $0 } ?? ""))
                .font(.system(size: st.size(15), weight: .semibold)).foregroundStyle(st.main(textColor))
                .lineLimit(2).minimumScaleFactor(0.6)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        case "hijri", "gregorian":
            let st = s.style([id])
            Text(id == "hijri" ? day.hijri : day.gregorian)
                .font(.system(size: st.size(13), weight: .bold)).foregroundStyle(st.main(textColor))
                .lineLimit(1).minimumScaleFactor(0.6)
                .padding(.horizontal, 8)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                .background(Capsule().fill(boxColor))
        case "dates":
            dates(s, day)
        case "qibla":
            GeometryReader { g in
                let st = s.style(["qibla"])
                // الأيقونة تملأ مربعها (بحجمها المختار ٠٫٥–١٫٦ من ٦٢٪ من أصغر بُعديه) وتحتها الزاوية والاتجاه.
                let text: CGFloat = st.showTitle ? 30 : 0
                let room = min(g.size.width, g.size.height - text)
                // الشريط حتى ٥٠٠٪: ما فوق المربع يُقصّ إلى المربع نفسه (الدائرة تصل حوافه بلا هوامش).
                let side = max(min(room, room * CGFloat(0.62 * s.qiblaIconScale)), 20)
                qibla(s, width: min(side, g.size.width))
                    .frame(width: g.size.width, height: g.size.height)
            }
        case "prayerTimes":
            PrayerRow(prayers: s.rotatedPrayers(at: entry.date), accent: s.accent, stretch: true, style: s.style(["prayerTimes"]))
        case "deposit":
            DepositsGrid(deposits: Array(day.deposits.prefix(6)), stretch: true, style: s.style(["deposit"]))
        case "season":
            SeasonBox(title: day.seasonName, sub: day.seasonAfter, stretch: true, style: s.style(["season"]))
        case "tradSeason":
            TradSeasonBox(name: day.tradName, after: day.tradAfter, line: day.tradLine, stretch: true, style: s.style(["tradSeason"]))
        case "tradPoints":
            let st = s.style(["tradPoints"])
            Text(day.tradLine).font(.system(size: st.size(12))).foregroundStyle(st.main(textColor))
                .minimumScaleFactor(0.6)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .padding(8)
                .background(RoundedRectangle(cornerRadius: 12).fill(boxColor))
        default:
            Color.clear
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
                        if s.isVisible("clock") {
                            ClockView(text: s.clockText(at: entry.date), style: s.style(["clock"]))
                        } else if showPrayer {
                            NextPrayerView(prayer: next(s), accent: s.accent, style: s.style(["prayer"]))
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
                    // ارتفاع أدنى يتبع حجم أيقونة القبلة (وإلا قيّدها الارتفاع المتاح فلم يستجب التكبير).
                    .frame(minHeight: showQibla ? CGFloat(70 * s.qiblaIconScale) + 34 : 0, maxHeight: CGFloat.infinity)
                )
            ))
        }
        if s.isVisible("prayerTimes") {
            blocks.append(LamhaBlock(
                id: "prayerTimes",
                position: s.position(["prayerTimes"]),
                view: AnyView(PrayerRow(prayers: s.rotatedPrayers(at: entry.date), accent: s.accent, stretch: true, style: s.style(["prayerTimes"])))
            ))
        }
        if s.isVisible("deposit") {
            blocks.append(LamhaBlock(
                id: "deposit",
                position: s.position(["deposit"]),
                view: AnyView(DepositsGrid(deposits: Array(day.deposits.prefix(6)), stretch: true, style: s.style(["deposit"])))
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
                        if showSeason { SeasonBox(title: day.seasonName, sub: day.seasonAfter, stretch: true, style: s.style(["season"])) }
                        if showTrad {
                            TradSeasonBox(name: day.tradName, after: day.tradAfter, line: day.tradLine, stretch: true, style: s.style(["tradSeason"]))
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
                if s.isVisible("clock") {
                    ClockView(text: s.clockText(at: entry.date), big: false, style: s.style(["clock"]))
                } else {
                    NextPrayerView(prayer: next(s), accent: s.accent, big: false, style: s.style(["clock", "prayer"]))
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(day.weekday).font(.system(size: 15, weight: .bold)).foregroundStyle(textColor)
                    Text(day.hijri).font(.system(size: 11)).foregroundStyle(dimColor).lineLimit(1)
                }
                if s.isVisible("qibla") { qibla(s, width: CGFloat(52 * s.qiblaIconScale)) }
            }
            if s.isVisible("prayerTimes") {
                PrayerRow(prayers: s.rotatedPrayers(at: entry.date), accent: s.accent, style: s.style(["prayerTimes"]))
            }
        }
    }

    private func small(_ s: LamhaSnapshot, _ day: LamhaDay) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            NextPrayerView(prayer: next(s), accent: s.accent, big: false, style: s.style(["clock", "prayer"]))
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
            }
            Text("القبلة " + s.qiblaText).font(.system(size: 12)).lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func inline(_ s: LamhaSnapshot) -> some View {
        Text(next(s).map { $0.name + " " + $0.text } ?? "لمحة")
    }
}

/// لوحة الخلفية (DECISIONS ٣٠): تملأ الودجت، أو تقع في إطارها الحر (كسور من الودجت كلها) دون أن يتأثر شيء من
/// العناصر فوقها.
@ViewBuilder
func frameBackground(_ s: LamhaSnapshot?) -> some View {
    let color = (s?.background ?? .black).opacity(s?.opacity ?? 1)
    if let f = s?.frame {
        GeometryReader { g in
            let w = g.size.width
            let h = g.size.height
            let width = min(max(CGFloat(f[2]), 0.12), 1) * w
            let height = min(max(CGFloat(f[3]), 0.06), 1) * h
            let right = min(max(CGFloat(f[0]) * w, 0), max(0, w - width))
            let top = min(max(CGFloat(f[1]) * h, 0), max(0, h - height))
            color
                .clipShape(RoundedRectangle(cornerRadius: 22))
                .frame(width: width, height: height)
                .position(x: w - right - width / 2, y: top + height / 2)
        }
    } else {
        color
    }
}

struct LamhaWidget: Widget {
    let kind = "LamhaWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: LamhaProvider()) { entry in
            let s = entry.snapshot
            LamhaWidgetView(entry: entry)
                .containerBackground(for: .widget) {
                    // صورة الخلفية (إن اختيرت) ثم لون السمة بالشفافية فوقها.
                    ZStack {
                        if let img = s?.wallpaper {
                            Image(uiImage: img).resizable().scaledToFill()
                        }
                        frameBackground(s)
                    }
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
