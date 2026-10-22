package sa.lamha.lamha.widget

import java.util.Calendar
import java.util.GregorianCalendar
import java.util.Locale
import java.util.TimeZone

/// منطق الودجت النقي (بلا Android) ليُختبر بـ JUnit.
/// لا يحسب أوقاتاً ولا تواريخ: يختار اليوم والصلاة القادمة من الجدول الجاهز الذي يكتبه Dart
/// (lib/src/engine/schedule.dart)، ويوزّع المربعات كما في packRows وrowHeights (lib/src/engine/widget_layout.dart).
object LamhaLogic {

    /// عرض الشبكة بالوحدات وأقصى عدد صفوف (الميزة ٥، gridColumns وmaxGridRows في Dart).
    const val GRID_COLUMNS = 3
    const val MAX_GRID_ROWS = 5

    /// مربع من `layout` في الجدول: [fontScale] معامل المربع (× العام)، واللونان ARGB أو null (تلقائي).
    data class Tile(
        val id: String,
        val visible: Boolean = true,
        val span: Int = 1,
        val fontScale: Float = 1f,
        val showTitle: Boolean = true,
        val showSub: Boolean = true,
        val primaryColor: Int? = null,
        val secondaryColor: Int? = null,
    )

    /// الترتيب الافتراضي (defaultLayout في Dart، الميزة ٦: تصميم المالك ٣). القديمة في آخره مخفية.
    val DEFAULT_LAYOUT = listOf(
        Tile("clock", span = 2, fontScale = 2f, showSub = false),
        Tile("dayWeather"),
        Tile("hijri", span = 2),
        Tile("gregorian", span = 2),
        Tile("qibla"),
        Tile("prayerTimes", span = 3),
        Tile("deposit", span = 3),
        Tile("season", showTitle = false),
        Tile("tradSeason", showTitle = false),
        Tile("tradPoints"),
        Tile("dates", visible = false, span = 2),
        Tile("weather", visible = false, span = 2),
        Tile("prayer", visible = false),
    )

    /// تخطيط جدول أقدم بلا `layout`: الترتيب الافتراضي والإظهار من مفاتيح visible القديمة
    /// (layoutFromVisible في Dart). الساعة ثابتة، والعناصر القديمة مخفية.
    fun defaultLayout(visible: Set<String>): List<Tile> = DEFAULT_LAYOUT.map { t ->
        val on = when (t.id) {
            "clock" -> true
            "hijri" -> "hijri" in visible
            "gregorian" -> "gregorian" in visible
            "dayWeather" -> "weather" in visible
            "prayerTimes" -> "prayer" in visible
            "tradPoints" -> "tradSeason" in visible
            "dates", "weather", "prayer" -> false
            else -> t.id in visible
        }
        t.copy(visible = on)
    }

    data class Cell(val id: String, val span: Int)

    /// توزيع المربعات الظاهرة على صفوف بعرض [columns] (packRows في Dart): كل مربع في صف السابق
    /// إن اتسع وإلا في صف جديد، وآخر مربع في كل صف ناقص يتمدد ليملأه. ما بعد [maxRows] لا يظهر.
    fun packRows(shown: List<Cell>, columns: Int = GRID_COLUMNS, maxRows: Int = MAX_GRID_ROWS): List<List<Cell>> {
        val rows = ArrayList<MutableList<Cell>>()
        var used = columns
        for (c in shown) {
            val span = c.span.coerceIn(1, columns)
            if (used + span > columns) {
                if (rows.size == maxRows) break
                rows.add(ArrayList())
                used = 0
            }
            rows.last().add(Cell(c.id, span))
            used += span
        }
        for (r in rows) {
            val total = r.sumOf { it.span }
            if (total < columns) r[r.size - 1] = r.last().copy(span = r.last().span + columns - total)
        }
        return rows
    }

    /// ارتفاعات الصفوف بوزن المحتوى (rowHeights في Dart): [text] نص أطول مربع في كل صف، و[pads]
    /// ما لا يصغر، و[gap] بين الصفوف. معامل واحد للنص (حتى [minScale]) إن لم يتسع في [available].
    /// الصفوف غير [flexible] بارتفاعها الطبيعي، وصفوف المربعات تقتسم الباقي بالتساوي (ومن يحتاج أكثر
    /// يأخذ حاجته؛ وإن نقص: بنسبتها). بلا صف مرن: الكل بنسبته. [equal]: صفوف متساوية والمعامل من
    /// أضيقها. بلا ارتفاع: الطبيعي.
    fun rowHeights(
        text: List<Float>, pads: List<Float>, available: Float, gap: Float,
        equal: Boolean = false, minScale: Float = 0.6f, flexible: List<Boolean>? = null,
    ): Pair<Float, List<Float>> {
        val n = text.size
        if (n == 0) return 1f to emptyList()
        val space = available - gap * (n - 1)
        if (available <= 0f) return 1f to List(n) { text[it] + pads[it] }
        if (equal) {
            val h = space / n
            var s = 1f
            for (i in 0 until n) if (text[i] > 0f) s = minOf(s, (h - pads[i]) / text[i])
            return s.coerceIn(minScale, 1f) to List(n) { h }
        }
        val sumText = text.sum()
        val s = if (sumText <= 0f) 1f else ((space - pads.sum()) / sumText).coerceIn(minScale, 1f)
        val natural = List(n) { text[it] * s + pads[it] }
        val sum = natural.sum()
        val flex = List(n) { flexible != null && flexible[it] }
        val fixed = (0 until n).filter { !flex[it] }.sumOf { natural[it].toDouble() }.toFloat()
        val soft = (0 until n).filter { flex[it] }.sumOf { natural[it].toDouble() }.toFloat()
        val rest = space - fixed
        if (flex.any { it } && rest > 0f) {
            val h = natural.toMutableList()
            if (soft > rest) {
                for (i in 0 until n) if (flex[i]) h[i] = natural[i] * rest / soft
            } else {
                var open = (0 until n).filter { flex[it] }
                var left = rest
                while (open.isNotEmpty()) {
                    val share = left / open.size
                    val big = open.filter { natural[it] > share }
                    if (big.isEmpty()) {
                        for (i in open) h[i] = share
                        break
                    }
                    for (i in big) {
                        h[i] = natural[i]
                        left -= natural[i]
                    }
                    open = open.filter { it !in big }
                }
            }
            return s to h
        }
        return s to natural.map { it * space / sum }
    }

    /// سطر ثانوي (SubLine في Dart): ارتفاعه بالحجم المطلوب، وحده، وعرضه إن كان لا يُختصر (0 = يُختصر).
    data class SubLine(val height: Float, val maxLines: Int = 1, val fitWidth: Float = 0f)

    /// نتيجة fitTile: العنوان ظاهر؟ ومعامل القيمة (≤ ١) وأسطرها، والثانويات الظاهرة ومعاملاتها، وأسطر آخرها.
    data class TileFit(
        val title: Boolean, val valueScale: Float, val valueLines: Int,
        val subs: List<Int>, val subScales: List<Float>, val lastSubLines: Int,
    )

    /// أسطر نص كلماته بعرض [words] (ومسافته [space]) في [width]، بالتفاف عند المسافات فقط (wrapLines في Dart).
    fun wrapLines(words: List<Float>, space: Float, width: Float): Int {
        if (words.isEmpty()) return 1
        var lines = 1
        var line = words[0]
        for (w in words.drop(1)) {
            if (line + space + w <= width) {
                line += space + w
            } else {
                lines++
                line = w
            }
        }
        return lines
    }

    /// ملاءمة مربع (الميزة ٥ب، fitTile في Dart): الحجم المطلوب يُحترم ومقاس المربع ثابت. القيمة تلتفّ
    /// عند المسافات ولا تصغر عرضياً إلا إذا لم تتسع أعرض كلمة؛ وإن ضاق الارتفاع تُخفى الثانويات
    /// بأولويتها ثم العنوان، وآخراً تصغر القيمة بأدنى تصغير لتظهر كاملة. بلا مقاس (0): كما هي.
    fun fitTile(
        height: Float, width: Float, titleHeight: Float, valueLineHeight: Float,
        valueWords: List<Float>, valueSpace: Float = 0f, subs: List<SubLine> = emptyList(),
        hideFromStart: Boolean = false, gap: Float = 0f, minSubFit: Float = 0.7f,
    ): TileFit {
        var k = 1f
        val widest = valueWords.maxOrNull() ?: 0f
        if (width > 0f && widest > width) k = width / widest
        var lines = if (width > 0f) wrapLines(valueWords.map { it * k }, valueSpace * k, width) else 1
        val scales = LinkedHashMap<Int, Float>()
        for (i in subs.indices) {
            val f = subs[i].fitWidth
            val s = if (width > 0f && f > width) width / f else 1f
            if (s >= minSubFit) scales[i] = s
        }
        val kept = scales.keys.toMutableList()
        var title = titleHeight > 0f
        fun used(): Float {
            val items = (if (title) 1 else 0) + 1 + kept.size
            return (if (title) titleHeight else 0f) + lines * valueLineHeight * k +
                kept.sumOf { (subs[it].height * scales[it]!!).toDouble() }.toFloat() + gap * (items - 1)
        }
        var lastLines = if (kept.isEmpty()) 1 else subs[kept.last()].maxLines
        if (height > 0f) {
            while (used() > height && kept.isNotEmpty()) {
                if (hideFromStart) kept.removeAt(0) else kept.removeAt(kept.size - 1)
            }
            if (used() > height && title) title = false
            if (used() > height && valueLineHeight > 0f) {
                // القيمة كاملة بأدنى تصغير: أكبر معامل تتسع به أسطرها (بعد الالتفاف) في الارتفاع.
                fun linesAt(f: Float) = if (width > 0f) wrapLines(valueWords, valueSpace, width / f) else 1
                var lo = 0f
                var hi = k
                repeat(40) {
                    val mid = (lo + hi) / 2
                    if (linesAt(mid) * valueLineHeight * mid <= height) lo = mid else hi = mid
                }
                k = lo
                lines = linesAt(k)
            }
            if (kept.isNotEmpty()) {
                val last = subs[kept.last()]
                val line = last.height * scales[kept.last()]!!
                lastLines = if (line <= 0f) last.maxLines
                else (1 + Math.floor(((height - used()) / line + 1e-6f).toDouble()).toInt()).coerceIn(1, last.maxLines)
            }
        }
        return TileFit(title, k, lines, kept.toList(), kept.map { scales[it]!! }, lastLines)
    }

    /// خانة التاريخين وتحتهما المدينة والطقس (datesWeatherCell في Dart)، والهجري وتحته الميلادي.
    const val DATES_WEATHER = "dates+weather"
    const val HIJRI_GREGORIAN = "hijri+gregorian"

    private val STACK_PAIRS = mapOf("dates" to "weather", "hijri" to "gregorian")

    /// الثاني من زوج بعد الأول مباشرة وبعرضه يُكدَّس تحته في خانة واحدة (stackCells في Dart).
    fun stackCells(shown: List<Cell>): List<Cell> {
        val out = ArrayList<Cell>()
        var i = 0
        while (i < shown.size) {
            val c = shown[i]
            val second = STACK_PAIRS[c.id]
            if (second != null && i + 1 < shown.size && shown[i + 1].id == second && shown[i + 1].span == c.span) {
                out += Cell("${c.id}+$second", c.span)
                i += 2
            } else {
                out += c
                i++
            }
        }
        return out
    }

    /// معرّفات العناصر في خانة.
    fun cellElements(cellId: String): List<String> = cellId.split("+")

    /// نتيجة fitColumns: العنوان ظاهر؟ ومعامل الأسماء، والسطر الفرعي ظاهر؟ ومعامله.
    data class ColumnsFit(val title: Boolean, val nameScale: Float, val sub: Boolean, val subScale: Float)

    /// ملاءمة مربع أعمدة (fitColumns في Dart، الميزة ٦): الأعمدة تصغر بالتساوي إن لم يتسع أعرضها (لا
    /// يُخفى عمود)، والسطر الفرعي يصغر حتى [minSubFit] وإلا يُخفى. إن ضاق الارتفاع: العنوان أولاً، ثم
    /// يصغر السطران معاً حتى [minShrink]، ثم يُخفى السطر الفرعي، وآخراً يصغر الاسم.
    fun fitColumns(
        height: Float, width: Float, titleHeight: Float, nameLine: Float, nameWidth: Float,
        subLine: Float = 0f, subWidth: Float = 0f, gap: Float = 0f, minSubFit: Float = 0.6f,
        minShrink: Float = 0.8f,
    ): ColumnsFit {
        var kName = if (width > 0f && nameWidth > width) width / nameWidth else 1f
        var kSub = if (width > 0f && subWidth > width) width / subWidth else 1f
        var title = titleHeight > 0f
        var sub = subLine > 0f && kSub >= minSubFit
        fun used() = (if (title) titleHeight + gap else 0f) + nameLine * kName + (if (sub) gap + subLine * kSub else 0f)
        if (height > 0f) {
            if (used() > height && title) title = false
            if (used() > height && sub) {
                val f = (height - gap) / (nameLine * kName + subLine * kSub)
                if (f >= minShrink) {
                    kName *= f
                    kSub *= f
                } else {
                    sub = false
                }
            }
            if (used() > height && nameLine > 0f) kName = minOf(kName, height / nameLine)
        }
        return ColumnsFit(title, kName, sub, kSub)
    }

    /// أقصى عدد إيداعات في مربعها (maxDeposits في Dart): عمود لكل وحدة عرض، وبعرض ٣ حتى ستة في شبكة.
    fun maxDeposits(span: Int): Int = if (span >= 3) 6 else span

    /// أكثر من ثلاثة إيداعات: شبكة عمودين، لكل خانة «الاسم الأيام» في سطر.
    fun depositsAsGrid(count: Int): Boolean = count > 3

    fun gridRows(count: Int): Int = (count + 1) / 2

    data class GridFit(val title: Boolean, val scale: Float)

    /// ملاءمة شبكة الإيداعات (fitGrid في Dart): الخانات تصغر بالتساوي إن لم يتسع أعرضها، وإن ضاق
    /// الارتفاع يُخفى العنوان أولاً ثم تصغر الصفوف لتتسع.
    fun fitGrid(height: Float, width: Float, titleHeight: Float, line: Float, cellWidth: Float, rows: Int, gap: Float = 0f): GridFit {
        var k = if (width > 0f && cellWidth > width) width / cellWidth else 1f
        var title = titleHeight > 0f
        val gaps = gap * maxOf(0, rows - 1)
        fun used() = (if (title) titleHeight + gap else 0f) + rows * line * k + gaps
        if (height > 0f && rows > 0 && line > 0f) {
            if (used() > height && title) title = false
            if (used() > height) k = maxOf(0f, minOf(k, (height - gaps) / (rows * line)))
        }
        return GridFit(title, k)
    }

    /// نقاط وصف الموسم (fitPoints في Dart): لكل نقطة أسطرها حتى [maxLines]. إن ضاق [height]: يُخفى
    /// العنوان ([titleHeight]) أولاً، ثم النقاط من الآخر، وآخراً تُقلَّل أسطر الأولى (حتى سطر). يعيد
    /// (العنوان ظاهر؟، أسطر كل نقطة ظاهرة).
    fun fitPoints(height: Float, titleHeight: Float, line: Float, lines: List<Int>, gap: Float = 0f, maxLines: Int = 3): Pair<Boolean, List<Int>> {
        val kept = lines.map { it.coerceIn(1, maxLines) }.toMutableList()
        fun used() = kept.sum() * line + gap * maxOf(0, kept.size - 1)
        if (height <= 0f) return (titleHeight > 0f) to kept
        while (kept.size > 1 && used() > height) kept.removeAt(kept.size - 1)
        while (kept.isNotEmpty() && kept[0] > 1 && used() > height) kept[0] = kept[0] - 1
        val title = titleHeight > 0f && used() + titleHeight + (if (kept.isEmpty()) 0f else gap) <= height
        return title to kept
    }

    /// الصلوات الخمس بترتيبها (fivePrayers في Dart).
    val FIVE_PRAYERS = listOf("fajr", "dhuhr", "asr", "maghrib", "isha")

    /// مواقيت الصلاة تدور (rotatePrayers في Dart): القادمة أولاً، ثم البقية بترتيبها الدوري، وما يقع
    /// منها غداً بأوقات [tomorrow] (أو أوقات اليوم إن لم يوجد). بعد العشاء: فجر الغد أولاً.
    fun rotatePrayers(today: List<Prayer>, tomorrow: List<Prayer>?, nowMillis: Long): List<Prayer> {
        fun five(l: List<Prayer>) = FIVE_PRAYERS.mapNotNull { k -> l.firstOrNull { it.key == k } }
        val t = five(today)
        val n = if (tomorrow == null) t else five(tomorrow)
        var i = t.indexOfFirst { it.atMillis > nowMillis }
        if (i < 0) i = t.size
        return t.drop(i) + n.take(i)
    }

    /// [text] وقت الصلاة جاهزاً للعرض من الجدول (مثل «٤:٣٥ ص»).
    data class Prayer(val key: String, val name: String, val atMillis: Long, val text: String = "")

    /// يحوّل نص ISO من Dart (مثل 2026-10-19T04:35:00.000+0300 أو ...Z) إلى epoch millis.
    fun parseIsoMillis(s: String): Long {
        val y = s.substring(0, 4).toInt()
        val mo = s.substring(5, 7).toInt()
        val d = s.substring(8, 10).toInt()
        val h = s.substring(11, 13).toInt()
        val mi = s.substring(14, 16).toInt()
        val sec = s.substring(17, 19).toInt()
        var i = 19
        var ms = 0
        if (i < s.length && s[i] == '.') {
            i++
            val start = i
            while (i < s.length && s[i].isDigit()) i++
            ms = (s.substring(start, i) + "000").substring(0, 3).toInt()
        }
        var offsetMinutes = 0
        if (i < s.length && s[i] != 'Z') {
            val sign = if (s[i] == '-') -1 else 1
            val digits = s.substring(i + 1).replace(":", "")
            offsetMinutes = sign * (digits.substring(0, 2).toInt() * 60 + digits.substring(2, 4).toInt())
        }
        val days = daysFromCivil(y, mo, d)
        val localMillis = ((days * 24 + h) * 60 + mi) * 60_000L + sec * 1000L + ms
        return localMillis - offsetMinutes * 60_000L
    }

    /// أيام منذ 1970-01-01 (خوارزمية Howard Hinnant).
    private fun daysFromCivil(year: Int, month: Int, day: Int): Long {
        val y = if (month <= 2) year - 1 else year
        val era = (if (y >= 0) y else y - 399) / 400
        val yoe = y - era * 400
        val mp = (month + 9) % 12
        val doy = (153 * mp + 2) / 5 + day - 1
        val doe = yoe * 365 + yoe / 4 - yoe / 100 + doy
        return era * 146097L + doe - 719468L
    }

    /// تاريخ اللحظة [nowMillis] في المنطقة [timeZoneId] بصيغة YYYY-MM-DD (كـ isoDate في Dart).
    /// بـ Locale.ROOT لتبقى الأرقام لاتينية كما في الجدول، أياً كانت لغة الجهاز.
    fun localDate(nowMillis: Long, timeZoneId: String): String {
        val c = GregorianCalendar(TimeZone.getTimeZone(timeZoneId), Locale.ROOT)
        c.timeInMillis = nowMillis
        return String.format(
            Locale.ROOT, "%04d-%02d-%02d",
            c.get(Calendar.YEAR), c.get(Calendar.MONTH) + 1, c.get(Calendar.DAY_OF_MONTH),
        )
    }

    /// قبل الظهر في المنطقة [timeZoneId]؟ (لـ «ص» و«م» بجانب الساعة).
    fun isAm(nowMillis: Long, timeZoneId: String): Boolean {
        val c = GregorianCalendar(TimeZone.getTimeZone(timeZoneId), Locale.ROOT)
        c.timeInMillis = nowMillis
        return c.get(Calendar.HOUR_OF_DAY) < 12
    }

    /// موضع اليوم الحالي في days، وإلا الأول (كما في المعاينة).
    fun dayIndex(dates: List<String>, today: String): Int {
        val i = dates.indexOf(today)
        return if (i < 0) 0 else i
    }

    /// أول صلاة وقتها بعد الآن (بلا الشروق)، وإلا فجر اليوم التالي.
    fun nextPrayer(today: List<Prayer>, tomorrow: List<Prayer>?, nowMillis: Long): Prayer? {
        val next = today
            .filter { it.key != "sunrise" }
            .sortedBy { it.atMillis }
            .firstOrNull { it.atMillis > nowMillis }
        return next ?: tomorrow?.firstOrNull { it.key == "fajr" }
    }

    /// اسم مسبوق بلام الجر: «الشتاء» ← «للشتاء»، «سهيل» ← «لسهيل» (كـ withLam في Dart).
    fun withLam(name: String): String =
        if (name.startsWith("ال")) "لل" + name.substring(2) else "ل$name"

    /// يقسم نص القبلة من الجدول («٣٢٤° شمال غرب») إلى الزاوية («٣٢٤°») والاتجاه («شمال غرب»).
    fun splitQibla(text: String): Pair<String, String> {
        val i = text.indexOf('°')
        if (i < 0) return text.trim() to ""
        return text.substring(0, i + 1).trim() to text.substring(i + 1).trim()
    }

    /// حجم الساعة قبل معامل الخط: ٥٢ (clockSize في widget_preview.dart)، و٤٢ إذا كان أقل عرض
    /// للودجت أضيق من ٢٥٠dp. [minWidthDp] = 0 إذا لم يبلّغه المشغّل.
    fun clockSizeSp(minWidthDp: Int): Float = if (minWidthDp in 1 until 250) 42f else 52f

    /// حجم خط يجعل نصاً عرضه [widthAtPreferred] بالحجم [preferredSp] يتسع في [maxWidth]،
    /// دون أن ينزل عن [minSp]. العرض يتناسب طردياً مع الحجم (fitTextSize في Dart).
    fun fitTextSize(preferredSp: Float, widthAtPreferred: Float, maxWidth: Float, minSp: Float): Float {
        if (widthAtPreferred <= 0f || widthAtPreferred <= maxWidth) return preferredSp
        return maxOf(minSp, preferredSp * maxWidth / widthAtPreferred)
    }

    /// حجم عنوان دائرة القبلة (qiblaTitleFit في Dart): المطلوب، حتى ١٦٪ من القطر [d]، وعرضه حتى ٧٠٪ منه.
    fun qiblaTitleFit(preferredSp: Float, widthAtPreferred: Float, d: Float): Float {
        val byHeight = minOf(preferredSp, d * 0.16f)
        return fitTextSize(byHeight, widthAtPreferred * byHeight / preferredSp, d * 0.7f, 0f)
    }

    /// عرض داخل خانة مربع (dp) بعرض [span] في ودجت بعرض [widthDp]: حشوة الشبكة ١٠+١٠
    /// (widget_lamha.xml)، ثم نصيب المربع من ٣، ناقصاً حشوة الخانة ٤+٤. 0 إذا لم يبلّغ المشغّل العرض.
    fun slotInnerDp(widthDp: Int, span: Int): Float {
        if (widthDp <= 0) return 0f
        return (widthDp - 20f) * span / GRID_COLUMNS - 8f
    }

    /// أسطر الثانوي الأخير بحد [maxLines]: ما يتسع في [remaining] بعد بقية المحتوى، ولا يقل عن ١.
    fun fittingLines(remaining: Float, lineHeight: Float, maxLines: Int): Int {
        if (lineHeight <= 0f) return maxLines
        return (1 + Math.floor((remaining / lineHeight).toDouble()).toInt()).coerceIn(1, maxLines)
    }

    /// العنوان الكامل إن اتسع سطراً واحداً ([fullWidthDp] ≤ [availableDp])، وإلا القصير
    /// («الإيداع القادم» ← «الإيداع»). بلا عرض معروف: القصير، كي لا يُقص.
    fun fittingTitle(full: String, short: String, fullWidthDp: Float, availableDp: Float): String =
        if (availableDp > 0f && fullWidthDp <= availableDp) full else short

    /// هل يجلب LamhaWeatherWorker الطقس؟ فقط إذا كان عنصر الطقس ظاهراً، وعلى الشاشة ودجت
    /// أو الإشعار مفعّل. وإلا لا طلب شبكة.
    fun shouldFetchWeather(weatherVisible: Boolean, widgetCount: Int, notificationEnabled: Boolean): Boolean =
        weatherVisible && (widgetCount > 0 || notificationEnabled)

    /// ألفا خلفية الودجت ٠–٢٥٥ من قيمة الشريط (ألفا = opacity ÷ ١٠٠، DECISIONS ٨).
    fun backgroundAlpha255(opacity: Int): Int = (opacity.coerceIn(0, 100) * 255 + 50) / 100

    /// لونا الودجت (التمييز، الخلفية): للسمة "system" ألوان النظام إن توفرت (أندرويد ١٢+، [sdkInt] ≥ 31)،
    /// وإلا لونا الجدول (وهما للسمة system ألوان الذهبي الاحتياطية من Dart).
    fun themeColors(
        themeId: String, accent: Int, background: Int, sdkInt: Int,
        systemAccent: Int?, systemBackground: Int?,
    ): Pair<Int, Int> =
        if (themeId == "system" && sdkInt >= 31 && systemAccent != null && systemBackground != null) {
            systemAccent to systemBackground
        } else {
            accent to background
        }

    /// قراءة طقس: من Dart في الجدول، أو من LamhaWeatherWorker.
    data class Weather(
        val temp: Double, val code: Int, val fetchedAtMillis: Long,
        val latitude: Double, val longitude: Double,
    ) {
        /// للمكان نفسه؟ (فرق أقل من ٠٫٠٥°، كـ isFor في weather.dart)
        fun isFor(lat: Double, lon: Double) =
            Math.abs(latitude - lat) < 0.05 && Math.abs(longitude - lon) < 0.05
    }

    /// الأحدث من القراءتين للمكان ([lat]، [lon]) فقط.
    fun newestWeather(a: Weather?, b: Weather?, lat: Double, lon: Double): Weather? =
        listOfNotNull(a, b).filter { it.isFor(lat, lon) }.maxByOrNull { it.fetchedAtMillis }

    /// «☀️ ٣١°» إذا كان عمر القراءة ≤ [maxAgeMinutes]، وإلا null (تُعرض «--°»).
    /// الرمز من جدول [icons] الذي يكتبه Dart (weatherScheduleJson).
    fun weatherText(w: Weather?, nowMillis: Long, maxAgeMinutes: Int, icons: Map<Int, String>, latin: Boolean = false): String? {
        val f = freshWeather(w, nowMillis, maxAgeMinutes) ?: return null
        return "${weatherIcon(f, icons)} ${temperatureText(f.temp, latin)}"
    }

    /// القراءة إن كان عمرها ≤ [maxAgeMinutes]، وإلا null.
    fun freshWeather(w: Weather?, nowMillis: Long, maxAgeMinutes: Int): Weather? =
        if (w == null || nowMillis - w.fetchedAtMillis > maxAgeMinutes * 60_000L) null else w

    /// رمز الطقس من جدول [icons]، أو ميزان حرارة لرمز غير معروف.
    fun weatherIcon(w: Weather, icons: Map<Int, String>): String = icons[w.code] ?: "🌡️"

    /// «٣١°» أو «-٣°» (أو «31°» مع [latin]) معزولاً باتجاه LTR، بتقريب النصف بعيداً عن الصفر كـ round() في Dart.
    fun temperatureText(temp: Double, latin: Boolean = false): String {
        val t = Math.floor(Math.abs(temp) + 0.5).toLong()
        val sign = if (temp < 0 && t > 0) "-" else ""
        // معزول باتجاه LTR (LRI…PDI) فتبقى الدرجة يمين الرقم داخل نص عربي (temperatureText في Dart).
        return "\u2066" + sign + formatDigits(t.toString(), latin) + "°\u2069"
    }

    /// الأرقام إلى العربية الشرقية، أو إلى اللاتينية مع [latin] (formatDigits في Dart، الميزة ٦).
    fun formatDigits(s: String, latin: Boolean = false): String = buildString {
        for (ch in s) {
            append(
                when {
                    !latin && ch in '0'..'9' -> '٠' + (ch - '0')
                    latin && ch in '٠'..'٩' -> '0' + (ch - '٠')
                    else -> ch
                },
            )
        }
    }

    /// سطرا إشعار شاشة القفل: «الفجر · ٤:٣٥ ص» و«القبلة ٣٢٤° · راتب أكتوبر بعد ٨ أيام».
    /// الصيغ من strings.xml: [titleFormat] (الاسم، الوقت)، [qiblaFormat] (الزاوية)،
    /// [depositFormat] (الإيداع، بعد كم)، [joinFormat] (الجزءان).
    fun notificationLines(
        prayer: Prayer, qiblaDegrees: String, depositLabel: String?, depositAfter: String?,
        titleFormat: String, qiblaFormat: String, depositFormat: String, joinFormat: String,
    ): Pair<String, String> {
        val title = if (prayer.text.isEmpty()) prayer.name else String.format(titleFormat, prayer.name, prayer.text)
        val qibla = String.format(qiblaFormat, qiblaDegrees)
        val text = if (depositLabel.isNullOrEmpty()) qibla
        else String.format(joinFormat, qibla, String.format(depositFormat, depositLabel, depositAfter ?: "").trim())
        return title to text
    }

    /// لحظات تحديث الودجت: كل صلاة، وكل منتصف ليل وظهر (لتغيّر «ص/م») في منطقة المدينة، بعد [nowMillis].
    fun updateTimes(
        dates: List<String>,
        prayerMillis: List<Long>,
        timeZoneId: String,
        nowMillis: Long,
    ): List<Long> {
        val tz = TimeZone.getTimeZone(timeZoneId)
        val out = ArrayList<Long>(prayerMillis)
        for (date in dates + nextDate(dates.lastOrNull())) {
            if (date == null) continue
            for (hour in intArrayOf(0, 12)) {
                val c = GregorianCalendar(tz, Locale.ROOT)
                c.clear()
                c.set(date.substring(0, 4).toInt(), date.substring(5, 7).toInt() - 1,
                    date.substring(8, 10).toInt(), hour, 0, 0)
                out.add(c.timeInMillis)
            }
        }
        return out.filter { it > nowMillis }.distinct().sorted()
    }

    private fun nextDate(date: String?): String? {
        if (date == null) return null
        val c = GregorianCalendar(TimeZone.getTimeZone("UTC"), Locale.ROOT)
        c.clear()
        c.set(date.substring(0, 4).toInt(), date.substring(5, 7).toInt() - 1, date.substring(8, 10).toInt())
        c.add(Calendar.DAY_OF_MONTH, 1)
        return String.format(
            Locale.ROOT, "%04d-%02d-%02d",
            c.get(Calendar.YEAR), c.get(Calendar.MONTH) + 1, c.get(Calendar.DAY_OF_MONTH),
        )
    }
}
