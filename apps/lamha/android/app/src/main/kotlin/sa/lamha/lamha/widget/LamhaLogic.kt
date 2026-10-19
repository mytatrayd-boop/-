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

    /// حجم الساعة قبل معامل الخط: ٥٢ (clockSize في widget_preview.dart)، و٤٢ إذا كان أقل عرض
    /// للودجت أضيق من ٢٥٠dp. [minWidthDp] = 0 إذا لم يبلّغه المشغّل.
    fun clockSizeSp(minWidthDp: Int): Float = if (minWidthDp in 1 until 250) 42f else 52f

    /// أدنى حجم للساعة عند تصغيرها (clockMinSize).
    const val CLOCK_MIN_SP = 28f

    /// حجم خط يجعل نصاً عرضه [widthAtPreferred] بالحجم [preferredSp] يتسع في [maxWidth]،
    /// دون أن ينزل عن [minSp]. العرض يتناسب طردياً مع الحجم (fitTextSize في Dart).
    fun fitTextSize(preferredSp: Float, widthAtPreferred: Float, maxWidth: Float, minSp: Float): Float {
        if (widthAtPreferred <= 0f || widthAtPreferred <= maxWidth) return preferredSp
        return maxOf(minSp, preferredSp * maxWidth / widthAtPreferred)
    }

    /// عرض محتوى الصف العلوي (dp): حشوة الودجت ١٠+١٠ وحشوة الصف ٤+٤ (widget_lamha.xml).
    fun headContentDp(minWidthDp: Int): Float = minWidthDp - 28f

    /// العرض المتاح لأرقام الساعة: ما يبقى بعد العمود الأيسر [leftDp] وفاصل ٨، ولا يقل عن ٤٠٪
    /// من [contentDp]، ناقصاً «ص/م» [amPmDp] وفاصلها ٤ (clockAvailableWidth في Dart).
    fun clockAvailableDp(contentDp: Float, leftDp: Float, amPmDp: Float): Float =
        maxOf(contentDp - 8f - leftDp, contentDp * 0.4f) - amPmDp - 4f

    /// عرض العمود الأيسر: ما يبقى بعد عمود الساعة (الأعرض من سطر الساعة واليوم) وفاصل ٨.
    fun leftColumnDp(contentDp: Float, clockRowDp: Float, weekdayDp: Float): Float =
        contentDp - 8f - maxOf(clockRowDp, weekdayDp)

    /// عرض نصوص مربع (dp) داخل ودجت بعرض [minWidthDp]: حشوة الودجت ١٠+١٠ (widget_lamha.xml)،
    /// ثم نصيب المربع [flex] من [rowFlex]، ناقصاً حشوة widget_tile ٤+٤ والمحتوى ٩+٩.
    /// 0 أو أقل إذا لم يبلّغ المشغّل العرض.
    fun tileTextWidthDp(minWidthDp: Int, flex: Int, rowFlex: Int): Float {
        if (minWidthDp <= 0 || rowFlex <= 0) return 0f
        return (minWidthDp - 20f) * flex / rowFlex - 8f - 18f
    }

    /// ارتفاع محتوى المربع (dp) في ودجت بارتفاع [heightDp]: حشوة ١٤+١٤، والصف العلوي [headDp]،
    /// والفاصل ١+٨+٨، و٨ بين الصفوف، وحشوة المربع ٨+٨. 0 إذا لم يُعرف الارتفاع.
    fun tileInnerHeightDp(heightDp: Int, headDp: Float, rows: Int): Float {
        if (heightDp <= 0 || rows <= 0) return 0f
        return (heightDp - 28f - headDp - 17f - 8f * (rows - 1)) / rows - 16f
    }

    /// معامل خط المربعات: [fontScale]، أو أصغر منه إن لم تتسع أسطر المربع الأطول [lineSizes]
    /// (كل سطر [lineHeight] × حجمه، وبينها [gap]) في [innerHeight]. لا ينزل عن ٠٫٦.
    /// بلا ارتفاع معروف: [fontScale] (tileFitScale في Dart).
    fun tileFitScale(fontScale: Float, innerHeight: Float, lineSizes: List<Float>, lineHeight: Float, gap: Float): Float {
        if (innerHeight <= 0f || lineSizes.isEmpty()) return fontScale
        val gaps = gap * (lineSizes.size - 1)
        val base = lineSizes.sum() * lineHeight
        return minOf(fontScale, maxOf(0.6f, (innerHeight - gaps) / base))
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
    fun weatherText(w: Weather?, nowMillis: Long, maxAgeMinutes: Int, icons: Map<Int, String>): String? {
        if (w == null || nowMillis - w.fetchedAtMillis > maxAgeMinutes * 60_000L) return null
        return "${icons[w.code] ?: "🌡️"} ${temperatureText(w.temp)}"
    }

    /// «٣١°» أو «-٣°»، بتقريب النصف بعيداً عن الصفر كـ round() في Dart.
    fun temperatureText(temp: Double): String {
        val t = Math.floor(Math.abs(temp) + 0.5).toLong()
        val sign = if (temp < 0 && t > 0) "-" else ""
        return sign + arabicDigits(t.toString()) + "°"
    }

    /// الأرقام 0-9 إلى العربية الشرقية (arabicDigits في Dart).
    fun arabicDigits(s: String): String =
        buildString { for (ch in s) append(if (ch in '0'..'9') '٠' + (ch - '0') else ch) }

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
