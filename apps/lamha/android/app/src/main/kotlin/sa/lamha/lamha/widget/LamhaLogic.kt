package sa.lamha.lamha.widget

import java.util.Calendar
import java.util.GregorianCalendar
import java.util.Locale
import java.util.TimeZone

/// منطق الودجت النقي (بلا Android) ليُختبر بـ JUnit.
/// لا يحسب أوقاتاً ولا تواريخ: يختار اليوم والصلاة القادمة من الجدول الجاهز الذي يكتبه Dart
/// (lib/src/engine/schedule.dart)، ويوزّع المربعات كما في gridRows (lib/src/app/widget_preview.dart).
object LamhaLogic {

    /// مربعات الشبكة بترتيبها من اليمين (DESIGN: الشبكة ٣×٢)، بأسماء مفاتيح visible في الجدول.
    val gridElements = listOf("prayer", "qibla", "deposit", "season", "tradSeason")

    /// [text] وقت الصلاة جاهزاً للعرض من الجدول (مثل «٤:٣٥ ص»).
    data class Prayer(val key: String, val name: String, val atMillis: Long, val text: String = "")

    data class Cell(val element: String, val flex: Int)

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

    /// توزيع المربعات الظاهرة على صفوف (DESIGN: إعادة الترتيب عند الإخفاء)، مطابق لـ gridRows في Dart.
    fun gridRows(shown: List<String>): List<List<Cell>> {
        val n = shown.size
        if (n == 0) return emptyList()
        if (n <= 2) return listOf(shown.map { Cell(it, 1) })
        if (n == 5) {
            return listOf(
                shown.subList(0, 3).map { Cell(it, 1) },
                listOf(Cell(shown[3], 1), Cell(shown[4], 2)),
            )
        }
        return listOf(
            shown.subList(0, 2).map { Cell(it, 1) },
            shown.subList(2, n).map { Cell(it, 1) },
        )
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

    /// حجم خط يجعل نصاً عرضه [widthAtPreferred] بالحجم [preferredSp] يتسع في [maxWidth]،
    /// دون أن ينزل عن [minSp]. العرض يتناسب طردياً مع الحجم.
    fun fitTextSize(preferredSp: Float, widthAtPreferred: Float, maxWidth: Float, minSp: Float): Float {
        if (widthAtPreferred <= 0f || widthAtPreferred <= maxWidth) return preferredSp
        return maxOf(minSp, preferredSp * maxWidth / widthAtPreferred)
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
