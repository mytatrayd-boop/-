package sa.lamha.lamha.widget

import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.content.res.Configuration
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.SystemClock
import android.util.TypedValue
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetPlugin
import es.antonborri.home_widget.HomeWidgetProvider
import es.antonborri.home_widget.HomeWidgetScheduler
import java.util.Locale
import sa.lamha.lamha.MainActivity
import sa.lamha.lamha.R

/// الودجت الكبيرة (٤×٤) بـ RemoteViews عادية (الميزة ٣ج، DECISIONS ١٣). تقرأ الجدول ولا تحسب
/// (CLAUDE.md)، والتخطيط res/layout/widget_lamha.xml مطابق للمعاينة في widget_preview.dart.
/// Dart يطلب التحديث بالاسم الكامل (androidWidgetReceiver في services.dart)، فبقي اسم الصنف كما هو.
/// بعد كل تحديث: إعادة جدولة التحديثات القادمة (كل صلاة ومنتصف الليل والظهر)، وتحديث إشعار
/// شاشة القفل، والتأكد من جدولة جلب الطقس كل ساعة.
class LamhaWidgetReceiver : HomeWidgetProvider() {

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        // بلا ودجت على الشاشة لا يُستدعى onUpdate، والإشعار يحتاج التحديث مع ذلك.
        if (intent.action == AppWidgetManager.ACTION_APPWIDGET_UPDATE &&
            (intent.getIntArrayExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS)?.isEmpty() != false)
        ) {
            afterUpdate(context, HomeWidgetPlugin.getData(context))
        }
    }

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        for (id in appWidgetIds) {
            appWidgetManager.updateAppWidget(id, views(context, widgetData, appWidgetManager.getAppWidgetOptions(id)))
        }
        afterUpdate(context, widgetData)
    }

    override fun onAppWidgetOptionsChanged(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetId: Int,
        newOptions: Bundle,
    ) {
        super.onAppWidgetOptionsChanged(context, appWidgetManager, appWidgetId, newOptions)
        appWidgetManager.updateAppWidget(appWidgetId, views(context, HomeWidgetPlugin.getData(context), newOptions))
    }

    private fun afterUpdate(context: Context, widgetData: SharedPreferences) {
        val json = widgetData.getString(SCHEDULE_KEY, null)
        val now = System.currentTimeMillis()
        HomeWidgetScheduler.schedule(context, LamhaWidgetReceiver::class.java.name, LamhaSchedule.updateTimes(json, now))
        LamhaNotification.refresh(context, LamhaSchedule.read(json, now))
        LamhaWeatherWorker.ensureScheduled(context)
    }

    companion object {
        /// مفتاح الجدول في HomeWidgetPreferences (scheduleKey في lib/src/app/services.dart).
        const val SCHEDULE_KEY = "schedule"

        /// آخر قراءة طقس جلبها LamhaWeatherWorker (بصيغة weather.dart).
        const val NATIVE_WEATHER_KEY = "weatherNative"

        /// مربع القبلة يفتح شاشة «اتجاه القبلة» (qiblaLaunchUri في lib/src/app/services.dart).
        const val QIBLA_URI = "lamha://qibla"

        /// ألفا مربع الصلاة بلون التمييز (٠٫١٨ في _Tile).
        private const val HIGHLIGHT_ALPHA = 46

        private val seasonEmoji = mapOf(
            "spring" to "🌸", "summer" to "☀️", "autumn" to "🍂", "winter" to "❄️",
        )

        /// التطبيق عربي فقط (main.dart: locale ar)، فنصوص الودجت بالعربية أياً كانت لغة الجهاز.
        fun arabic(context: Context): Context {
            val config = Configuration(context.resources.configuration)
            config.setLocale(Locale.forLanguageTag("ar"))
            return context.createConfigurationContext(config)
        }

        /// يعيد رسم كل نسخ الودجت (بعد جلب الطقس مثلاً).
        fun updateAll(context: Context) {
            val mgr = AppWidgetManager.getInstance(context)
            val ids = mgr.getAppWidgetIds(ComponentName(context, LamhaWidgetReceiver::class.java))
            val prefs = HomeWidgetPlugin.getData(context)
            for (id in ids) mgr.updateAppWidget(id, views(context, prefs, mgr.getAppWidgetOptions(id)))
            LamhaNotification.refresh(context, LamhaSchedule.read(prefs.getString(SCHEDULE_KEY, null), System.currentTimeMillis()))
        }

        /// لونا الودجت الفعليان (التمييز، الخلفية)، بألوان النظام لسمة «ألوان النظام» في أندرويد ١٢+.
        fun colors(context: Context, day: LamhaDay): Pair<Int, Int> {
            var sysAccent: Int? = null
            var sysBg: Int? = null
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                sysAccent = context.getColor(android.R.color.system_accent1_200)
                sysBg = context.getColor(android.R.color.system_neutral1_900)
            }
            return LamhaLogic.themeColors(day.themeId, day.accent, day.background, Build.VERSION.SDK_INT, sysAccent, sysBg)
        }

        fun openAppIntent(context: Context) =
            HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java)

        private fun views(context: Context, prefs: SharedPreferences, options: Bundle?): RemoteViews {
            val now = System.currentTimeMillis()
            val ctx = arabic(context)
            val day = LamhaSchedule.read(prefs.getString(SCHEDULE_KEY, null), now)
            if (day == null) {
                return RemoteViews(context.packageName, R.layout.widget_setup).apply {
                    setOnClickPendingIntent(R.id.root, openAppIntent(context))
                }
            }
            val (accent, background) = colors(context, day)
            val rv = RemoteViews(context.packageName, R.layout.widget_lamha)
            rv.setOnClickPendingIntent(R.id.root, openAppIntent(context))
            rv.setInt(R.id.bg, "setColorFilter", background)
            rv.setInt(R.id.bg, "setImageAlpha", LamhaLogic.backgroundAlpha255(day.opacity))

            // الصف العلوي. الساعة بتوقيت المدينة لتطابق «ص/م» واليوم (DECISIONS ٨).
            val minWidth = options?.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH, 0) ?: 0
            rv.setTextViewTextSize(R.id.clock, TypedValue.COMPLEX_UNIT_SP, LamhaLogic.clockSizeSp(minWidth))
            rv.setString(R.id.clock, "setTimeZone", day.timeZone)
            rv.setTextViewText(R.id.am_pm, ctx.getString(if (LamhaLogic.isAm(now, day.timeZone)) R.string.am else R.string.pm))
            rv.setTextViewText(R.id.weekday, day.weekday)
            rv.setTextColor(R.id.weekday, accent)
            line(rv, R.id.hijri, "hijri" in day.visible, ctx.getString(R.string.hijri_date, day.hijriText))
            line(rv, R.id.gregorian, "gregorian" in day.visible, ctx.getString(R.string.gregorian_date, day.gregorianText))
            val weather = LamhaLogic.newestWeather(
                day.weather, LamhaSchedule.weatherOf(prefs.getString(NATIVE_WEATHER_KEY, null)),
                day.latitude, day.longitude,
            )
            val weatherText = LamhaLogic.weatherText(weather, now, day.weatherMaxAgeMinutes, day.weatherIcons)
                ?: ctx.getString(R.string.weather_unknown)
            line(rv, R.id.weather, "weather" in day.visible, ctx.getString(R.string.city_weather, day.cityName, weatherText))

            // الشبكة: المربعات الظاهرة في صفين كما في gridRows (DESIGN: إعادة الترتيب عند الإخفاء).
            val rows = LamhaLogic.gridRows(LamhaLogic.gridElements.filter { it in day.visible })
            rv.removeAllViews(R.id.row1)
            rv.removeAllViews(R.id.row2)
            rows.forEachIndexed { r, row ->
                for (cell in row) rv.addView(if (r == 0) R.id.row1 else R.id.row2, tile(context, ctx, day, cell, accent, now))
            }
            rv.setViewVisibility(R.id.row2, if (rows.size > 1) View.VISIBLE else View.GONE)
            val grid = if (rows.isEmpty()) View.GONE else View.VISIBLE
            rv.setViewVisibility(R.id.grid, grid)
            rv.setViewVisibility(R.id.divider, grid)
            return rv
        }

        private fun line(rv: RemoteViews, id: Int, shown: Boolean, text: String) {
            rv.setViewVisibility(id, if (shown) View.VISIBLE else View.GONE)
            if (shown) rv.setTextViewText(id, text)
        }

        private fun sub(rv: RemoteViews, id: Int, text: String?) {
            if (text.isNullOrEmpty()) {
                rv.setViewVisibility(id, View.GONE)
            } else {
                rv.setViewVisibility(id, View.VISIBLE)
                rv.setTextViewText(id, text)
            }
        }

        /// مربع واحد. الثانويات: sub1 سطر، ثم العدّاد، ثم sub2 سطر، ثم sub3 سطران (widget_tile_content.xml).
        private fun tile(
            context: Context, ctx: Context, day: LamhaDay, cell: LamhaLogic.Cell, accent: Int, now: Long,
        ): RemoteViews {
            val rv = RemoteViews(context.packageName, if (cell.flex == 2) R.layout.widget_tile_wide else R.layout.widget_tile)
            val (title, emoji) = when (cell.element) {
                "prayer" -> R.string.tile_prayer to "🕌"
                "qibla" -> R.string.tile_qibla to "🧭"
                "deposit" -> R.string.tile_deposit to "💰"
                "season" -> R.string.tile_season to (seasonEmoji[day.seasonId] ?: "🍂")
                else -> R.string.tile_trad_season to "🌾"
            }
            rv.setTextViewText(R.id.tile_title, ctx.getString(title))
            rv.setTextViewText(R.id.tile_emoji, emoji)
            var sub1: String? = null
            var sub2: String? = null
            var sub3: String? = null
            when (cell.element) {
                "prayer" -> {
                    rv.setImageViewResource(R.id.tile_bg, R.drawable.tile_bg_accent)
                    rv.setInt(R.id.tile_bg, "setColorFilter", accent)
                    rv.setInt(R.id.tile_bg, "setImageAlpha", HIGHLIGHT_ALPHA)
                    val next = day.nextPrayer
                    rv.setTextViewText(R.id.tile_value, next?.name ?: "")
                    sub1 = next?.text
                    if (next != null) {
                        // عدّاد النظام التنازلي حتى الصلاة، فلا يحتاج تحديثاً كل دقيقة.
                        val base = SystemClock.elapsedRealtime() + (next.atMillis - now)
                        rv.setChronometer(R.id.tile_countdown, base, ctx.getString(R.string.countdown_format), true)
                        rv.setChronometerCountDown(R.id.tile_countdown, true)
                        rv.setViewVisibility(R.id.tile_countdown, View.VISIBLE)
                    }
                }
                "qibla" -> {
                    rv.setTextViewText(R.id.tile_value, day.qiblaDegrees)
                    sub1 = day.qiblaDirection
                    // مربع القبلة وحده يفتح شاشة البوصلة؛ بقية الودجت تفتح التطبيق.
                    rv.setOnClickPendingIntent(
                        R.id.tile_box,
                        HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java, Uri.parse(QIBLA_URI)),
                    )
                }
                "deposit" -> {
                    val first = day.deposits.firstOrNull()
                    val second = day.deposits.getOrNull(1)
                    rv.setTextViewText(R.id.tile_value, first?.label ?: "--")
                    if (second != null) {
                        sub1 = first?.remaining
                        sub2 = ctx.getString(R.string.value_with_suffix, second.label, second.remaining)
                    } else {
                        sub3 = first?.remaining
                    }
                }
                "season" -> {
                    rv.setTextViewText(R.id.tile_value, day.seasonName)
                    sub3 = ctx.getString(R.string.remaining_to_next, day.seasonRemaining, LamhaLogic.withLam(day.seasonNext))
                }
                else -> {
                    rv.setTextViewText(R.id.tile_value, day.tradName)
                    sub1 = ctx.getString(R.string.remaining_to_next, day.tradRemaining, LamhaLogic.withLam(day.tradNext))
                    sub3 = day.tradDescription
                }
            }
            sub(rv, R.id.tile_sub1, sub1)
            sub(rv, R.id.tile_sub2, sub2)
            sub(rv, R.id.tile_sub3, sub3)
            return rv
        }
    }
}
