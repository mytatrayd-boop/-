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
    /// الزاوية («٣٢٤°») والاتجاه («شمال غرب») سطران في المربع.
    val qiblaDegrees: String,
    val qiblaDirection: String,
    /// (الاسم، الباقي) بالترتيب: الأقرب ثم الذي بعده.
    val deposits: List<Pair<String, String>>,
    val seasonId: String,
    val seasonName: String,
    val seasonRemaining: String,
    val seasonNext: String,
    val tradName: String,
    val tradRemaining: String,
    val tradNext: String,
    val tradDescription: String,
)

object LamhaSchedule {

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

    private fun parse(root: JSONObject, nowMillis: Long): LamhaDay {
        val city = root.getJSONObject("city")
        val tz = timeZoneOf(root)
        val days: JSONArray = root.getJSONArray("days")
        val dates = (0 until days.length()).map { days.getJSONObject(it).getString("date") }
        val idx = LamhaLogic.dayIndex(dates, LamhaLogic.localDate(nowMillis, tz))
        val day = days.getJSONObject(idx)
        val tomorrow = if (idx + 1 < days.length()) prayersOf(days.getJSONObject(idx + 1)) else null

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
            d.getString("label") to d.getString("remainingText")
        }
        val (qiblaDegrees, qiblaDirection) = LamhaLogic.splitQibla(root.getJSONObject("qibla").getString("text"))
        val season = day.getJSONObject("season")
        val trad = day.getJSONObject("tradSeason")

        return LamhaDay(
            timeZone = tz,
            cityName = city.optString("name", ""),
            visible = visible,
            opacity = root.optInt("opacity", 100),
            weekday = day.getString("weekday"),
            hijriText = day.getJSONObject("hijri").getString("text"),
            gregorianText = day.getJSONObject("gregorian").getString("text"),
            nextPrayer = LamhaLogic.nextPrayer(prayersOf(day), tomorrow, nowMillis),
            qiblaDegrees = qiblaDegrees,
            qiblaDirection = qiblaDirection,
            deposits = deposits,
            seasonId = season.getString("id"),
            seasonName = season.getString("name"),
            seasonRemaining = season.getString("remainingText"),
            seasonNext = season.getJSONObject("next").getString("name"),
            tradName = trad.getString("name"),
            tradRemaining = trad.getString("remainingText"),
            tradNext = trad.getJSONObject("next").getString("name"),
            tradDescription = trad.optString("description", ""),
        )
    }
}
