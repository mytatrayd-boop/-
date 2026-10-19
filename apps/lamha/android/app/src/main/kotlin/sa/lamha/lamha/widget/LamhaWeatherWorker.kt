package sa.lamha.lamha.widget

import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Context
import androidx.work.Constraints
import androidx.work.ExistingPeriodicWorkPolicy
import androidx.work.NetworkType
import androidx.work.PeriodicWorkRequest
import androidx.work.WorkManager
import androidx.work.Worker
import androidx.work.WorkerParameters
import es.antonborri.home_widget.HomeWidgetPlugin
import java.net.HttpURLConnection
import java.net.URL
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import java.util.TimeZone
import java.util.concurrent.TimeUnit
import org.json.JSONObject

/// جلب الطقس كل ساعة تقريباً بلا فتح التطبيق (الميزة ٣ج، DECISIONS ١٣): Open-Meteo بلا مفتاح،
/// بإحداثيات المدينة من الجدول. القراءة تُحفظ بمفتاح weatherNative بصيغة weather.dart، ثم تُرسم
/// الودجت من جديد. لا يجلب إذا كان الطقس مخفياً أو لا ودجت ولا إشعار (shouldFetchWeather). بلا إنترنت تبقى آخر قراءة، وبعد ٣ ساعات تُعرض «--°».
class LamhaWeatherWorker(context: Context, params: WorkerParameters) : Worker(context, params) {

    override fun doWork(): Result {
        val ctx = applicationContext
        val prefs = HomeWidgetPlugin.getData(ctx)
        val json = prefs.getString(LamhaWidgetReceiver.SCHEDULE_KEY, null)
        // الطقس مخفي، أو لا ودجت على الشاشة ولا إشعار: لا طلب شبكة.
        val day = LamhaSchedule.read(json, System.currentTimeMillis()) ?: return Result.success()
        val widgets = AppWidgetManager.getInstance(ctx)
            .getAppWidgetIds(ComponentName(ctx, LamhaWidgetReceiver::class.java)).size
        if (!LamhaLogic.shouldFetchWeather("weather" in day.visible, widgets, day.lockNotification)) {
            return Result.success()
        }
        val (lat, lon) = LamhaSchedule.coordinates(json) ?: return Result.success()
        try {
            val current = JSONObject(get(url(lat, lon))).getJSONObject("current")
            val reading = JSONObject()
                .put("temp", current.getDouble("temperature_2m"))
                .put("code", current.getInt("weather_code"))
                .put("fetchedAt", isoUtc(System.currentTimeMillis()))
                .put("latitude", lat)
                .put("longitude", lon)
            prefs.edit().putString(LamhaWidgetReceiver.NATIVE_WEATHER_KEY, reading.toString()).apply()
            LamhaWidgetReceiver.updateAll(ctx)
        } catch (e: Exception) {
            // بلا إنترنت أو رد غير صالح: تبقى آخر قراءة حتى المحاولة القادمة.
        }
        return Result.success()
    }

    private fun url(lat: Double, lon: Double) =
        "https://api.open-meteo.com/v1/forecast?latitude=$lat&longitude=$lon" +
            "&current=temperature_2m,weather_code&timezone=auto"

    private fun get(url: String): String {
        val c = URL(url).openConnection() as HttpURLConnection
        try {
            c.connectTimeout = 10_000
            c.readTimeout = 15_000
            c.requestMethod = "GET"
            if (c.responseCode != 200) throw java.io.IOException("HTTP ${c.responseCode}")
            return c.inputStream.bufferedReader(Charsets.UTF_8).use { it.readText() }
        } finally {
            c.disconnect()
        }
    }

    private fun isoUtc(millis: Long): String {
        val f = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss.SSS'Z'", Locale.ROOT)
        f.timeZone = TimeZone.getTimeZone("UTC")
        return f.format(Date(millis))
    }

    companion object {
        private const val WORK_NAME = "lamha_weather"

        /// جدولة دورية كل ساعة عند توفر الشبكة. KEEP: لا تُعاد إن كانت مجدولة.
        fun ensureScheduled(context: Context) {
            val request = PeriodicWorkRequest.Builder(LamhaWeatherWorker::class.java, 1, TimeUnit.HOURS)
                .setConstraints(Constraints.Builder().setRequiredNetworkType(NetworkType.CONNECTED).build())
                .build()
            WorkManager.getInstance(context.applicationContext)
                .enqueueUniquePeriodicWork(WORK_NAME, ExistingPeriodicWorkPolicy.KEEP, request)
        }
    }
}
