package sa.lamha.lamha.widget

import org.json.JSONArray
import org.json.JSONObject

/// ما تعرضه الودجت لليوم الحالي، مقروءاً من الجدول (مفتاح "schedule" في HomeWidgetPreferences).
data class LamhaDay(
    val timeZone: String,
    val cityName: String,
    val visible: Set<String>,
    val opacity: Int,
    val weekday: String,
    val hijriText: String,
    val gregorianText: String,
    val nextPrayer: LamhaLogic.Prayer?,
    /// الزاوية («٣٢٤°») والاتجاه («شمال غرب») سطران في المربع، والزاوية رقماً لتدوير السهم.
    val qiblaDegrees: String,
    val qiblaDirection: String,
    val qiblaAngle: Float,
    /// بالترتيب: الأقرب ثم الذي بعده.
    val deposits: List<Deposit>,
    val seasonId: String,
    val seasonName: String,
    val seasonRemaining: String,
    val seasonNext: String,
    val tradName: String,
    val tradRemaining: String,
    val tradNext: String,
    val tradDescription: String,
    val latitude: Double,
    val longitude: Double,
    val themeId: String,
    val accent: Int,
    val background: Int,
    val lockNotification: Boolean,
    /// آخر قراءة طقس كتبها Dart في الجدول، وجدول رموزها، وأقصى عمر لها.
    val weather: LamhaLogic.Weather?,
    val weatherIcons: Map<Int, String>,
    val weatherMaxAgeMinutes: Int,
    /// معامل حجم الخط (الميزة ٣د)؛ ١ لجدول أقدم بلاه.
    val fontScale: Float = 1f,
    /// تخطيط المربعات بترتيبه (الميزة ٥)؛ جدول أقدم بلاه: الافتراضي من visible.
    val layout: List<LamhaLogic.Tile> = LamhaLogic.defaultLayout(visible),
    /// الميزة ٦: الأرقام اللاتينية (إعداد «الأرقام»)، وصلوات اليوم والغد لمواقيت الصلاة، و«بعد ٦٠
    /// يوماً» للفصل والموسم، ونقاط وصف الموسم.
    val latinDigits: Boolean = false,
    val prayersToday: List<LamhaLogic.Prayer> = emptyList(),
    val prayersTomorrow: List<LamhaLogic.Prayer>? = null,
    val seasonAfter: String = "",
    val tradAfter: String = "",
    val tradPoints: List<String> = emptyList(),
    /// العدّاد التنازلي في مربع «الصلاة القادمة»: اختياري ومطفأ افتراضياً (prayerCountdown في الجدول).
    val prayerCountdown: Boolean = false,
)

/// [remaining] «باقي ٨ أيام»، و[after] «بعد ٨ أيام» للإشعار، و[days] «١٤ يوماً» لأعمدة الإيداعات.
data class Deposit(val label: String, val remaining: String, val after: String, val days: String = "")

object LamhaSchedule {

    /// الذهبي (WidgetTheme.gold في Dart) لجدول بلا سمة.
    private const val GOLD_ACCENT = 0xFFD6AA5CL
    private const val GOLD_BACKGROUND = 0xFF2A241DL

    /// يعيد null إذا لم يُحفظ جدول أو تعذّر قراءته.
    fun read(json: String?, nowMillis: Long): LamhaDay? {
        if (json.isNullOrEmpty()) return null
        return try {
            parse(JSONObject(json), nowMillis)
        } catch (e: Exception) {
            null
        }
    }

    /// لحظات التحديث القادمة من الجدول (صلوات، منتصف الليل، الظهر).
    fun updateTimes(json: String?, nowMillis: Long): List<Long> {
        if (json.isNullOrEmpty()) return emptyList()
        return try {
            val root = JSONObject(json)
            val days = root.getJSONArray("days")
            val dates = ArrayList<String>()
            val prayers = ArrayList<Long>()
            for (i in 0 until days.length()) {
                val day = days.getJSONObject(i)
                dates.add(day.getString("date"))
                prayers.addAll(prayersOf(day).map { it.atMillis })
            }
            LamhaLogic.updateTimes(dates, prayers, timeZoneOf(root), nowMillis)
        } catch (e: Exception) {
            emptyList()
        }
    }

    /// إحداثيات المدينة من الجدول (للطقس)، أو null.
    fun coordinates(json: String?): Pair<Double, Double>? {
        if (json.isNullOrEmpty()) return null
        return try {
            val c = JSONObject(json).getJSONObject("city")
            c.getDouble("latitude") to c.getDouble("longitude")
        } catch (e: Exception) {
            null
        }
    }

    /// قراءة طقس بصيغة weather.dart (temp، code، fetchedAt بصيغة ISO، latitude، longitude)، أو null.
    fun weatherOf(o: JSONObject?): LamhaLogic.Weather? {
        if (o == null || !o.has("temp") || !o.has("code") || !o.has("fetchedAt")) return null
        return try {
            LamhaLogic.Weather(
                o.getDouble("temp"), o.getInt("code"), LamhaLogic.parseIsoMillis(o.getString("fetchedAt")),
                o.getDouble("latitude"), o.getDouble("longitude"),
            )
        } catch (e: Exception) {
            null
        }
    }

    fun weatherOf(json: String?): LamhaLogic.Weather? =
        if (json.isNullOrEmpty()) null else try {
            weatherOf(JSONObject(json))
        } catch (e: Exception) {
            null
        }

    private fun timeZoneOf(root: JSONObject): String =
        root.getJSONObject("city").optString("timeZone", "Asia/Riyadh")

    private fun prayersOf(day: JSONObject): List<LamhaLogic.Prayer> {
        val p = day.getJSONObject("prayers")
        val out = ArrayList<LamhaLogic.Prayer>()
        val keys = p.keys()
        while (keys.hasNext()) {
            val key = keys.next()
            val e = p.getJSONObject(key)
            out.add(
                LamhaLogic.Prayer(
                    key, e.getString("name"), LamhaLogic.parseIsoMillis(e.getString("time")),
                    e.optString("text", ""),
                ),
            )
        }
        return out
    }

    /// `layout` من الجدول (TileLayout.toScheduleJson في Dart)، أو null لجدول أقدم.
    fun layoutOf(root: JSONObject): List<LamhaLogic.Tile>? {
        val a = root.optJSONArray("layout") ?: return null
        return (0 until a.length()).map {
            val t = a.getJSONObject(it)
            LamhaLogic.Tile(
                id = t.getString("id"),
                visible = t.optBoolean("visible", true),
                span = t.optInt("span", 1).coerceIn(1, LamhaLogic.GRID_COLUMNS),
                fontScale = t.optDouble("fontScale", 1.0).toFloat(),
                showTitle = t.optBoolean("showTitle", true),
                showSub = t.optBoolean("showSub", true),
                primaryColor = if (t.isNull("primaryColor")) null else t.getLong("primaryColor").toInt(),
                secondaryColor = if (t.isNull("secondaryColor")) null else t.getLong("secondaryColor").toInt(),
                iconScale = t.optDouble("iconScale", 1.0).toFloat().coerceIn(0.5f, 1.6f),
            )
        }
    }

    private fun parse(root: JSONObject, nowMillis: Long): LamhaDay {
        val city = root.getJSONObject("city")
        val tz = timeZoneOf(root)
        val days: JSONArray = root.getJSONArray("days")
        val dates = (0 until days.length()).map { days.getJSONObject(it).getString("date") }
        val idx = LamhaLogic.dayIndex(dates, LamhaLogic.localDate(nowMillis, tz))
        val day = days.getJSONObject(idx)
        val tomorrow = if (idx + 1 < days.length()) prayersOf(days.getJSONObject(idx + 1)) else null
        val today = prayersOf(day)

        val visibleJson = root.getJSONObject("visible")
        val visible = HashSet<String>()
        val vk = visibleJson.keys()
        while (vk.hasNext()) {
            val k = vk.next()
            if (visibleJson.optBoolean(k, false)) visible.add(k)
        }

        val deps = day.optJSONArray("deposits") ?: JSONArray()
        val deposits = (0 until deps.length()).map {
            val d = deps.getJSONObject(it)
            Deposit(
                d.getString("label"), d.getString("remainingText"), d.optString("afterText", ""),
                d.optString("daysText", d.getString("remainingText")),
            )
        }
        val qibla = root.getJSONObject("qibla")
        val (qiblaDegrees, qiblaDirection) = LamhaLogic.splitQibla(qibla.getString("text"))
        val season = day.getJSONObject("season")
        val trad = day.getJSONObject("tradSeason")
        // سمة وطقس (الميزة ٣ج)؛ جدول أقدم بلاهما يأخذ الذهبي وبلا طقس.
        val theme = root.optJSONObject("theme")
        val weather = root.optJSONObject("weather")
        val icons = HashMap<Int, String>()
        weather?.optJSONObject("icons")?.let { o ->
            val keys = o.keys()
            while (keys.hasNext()) {
                val k = keys.next()
                k.toIntOrNull()?.let { code -> icons[code] = o.getString(k) }
            }
        }

        return LamhaDay(
            timeZone = tz,
            cityName = city.optString("name", ""),
            visible = visible,
            opacity = root.optInt("opacity", 100),
            weekday = day.getString("weekday"),
            hijriText = day.getJSONObject("hijri").getString("text"),
            gregorianText = day.getJSONObject("gregorian").getString("text"),
            nextPrayer = LamhaLogic.nextPrayer(today, tomorrow, nowMillis),
            qiblaDegrees = qiblaDegrees,
            qiblaDirection = qiblaDirection,
            qiblaAngle = qibla.optDouble("degrees", 0.0).toFloat(),
            deposits = deposits,
            seasonId = season.getString("id"),
            seasonName = season.getString("name"),
            seasonRemaining = season.getString("remainingText"),
            seasonNext = season.getJSONObject("next").getString("name"),
            tradName = trad.getString("name"),
            tradRemaining = trad.getString("remainingText"),
            tradNext = trad.getJSONObject("next").getString("name"),
            tradDescription = trad.optString("descriptionLine", trad.optString("description", "")),
            latitude = city.optDouble("latitude", 0.0),
            longitude = city.optDouble("longitude", 0.0),
            themeId = theme?.optString("id", "gold") ?: "gold",
            accent = theme?.optLong("accent", GOLD_ACCENT)?.toInt() ?: GOLD_ACCENT.toInt(),
            background = theme?.optLong("background", GOLD_BACKGROUND)?.toInt() ?: GOLD_BACKGROUND.toInt(),
            lockNotification = root.optBoolean("lockNotification", false),
            weather = weatherOf(weather),
            weatherIcons = icons,
            weatherMaxAgeMinutes = weather?.optInt("maxAgeMinutes", 180) ?: 180,
            fontScale = root.optDouble("fontScale", 1.0).toFloat(),
            layout = layoutOf(root) ?: LamhaLogic.defaultLayout(visible),
            latinDigits = root.optString("digits", "arabic") == "latin",
            prayerCountdown = root.optBoolean("prayerCountdown", false),
            prayersToday = today,
            prayersTomorrow = tomorrow,
            seasonAfter = season.optString("afterText", ""),
            tradAfter = trad.optString("afterText", ""),
            tradPoints = trad.optJSONArray("points")?.let { a -> (0 until a.length()).map { a.getString(it) } } ?: emptyList(),
        )
    }
}
