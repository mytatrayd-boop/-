package sa.lamha.lamha.widget

import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.content.res.Configuration
import android.graphics.Paint
import android.graphics.Typeface
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

        /// أحجام الميزة ٣د قبل معامل الخط (widget_preview.dart): الصف العلوي والمربعات.
        private const val AM_PM_SP = 18f
        private const val WEEKDAY_SP = 18f
        private const val HIJRI_SP = 18f
        private const val GREGORIAN_SP = 16f
        private const val CITY_WEATHER_SP = 16f
        private const val TILE_TITLE_SP = 13f
        private const val TILE_VALUE_SP = 20f
        private const val TILE_SUB_SP = 14f

        /// تقدير ارتفاع سطر نص عربي بخط النظام (× الحجم)، وسطر الساعة (includeFontPadding=false).
        /// تقدير لا قياس: لم يُجرَّب على جهاز.
        private const val LINE_HEIGHT = 1.45f
        private const val CLOCK_LINE_HEIGHT = 1.17f
        private const val TILE_GAP_DP = 3f
        private const val FIT_MARGIN_DP = 2f

        /// أدنى تصغير للعنوان والقيمة (tileMinFit)، ولسطور العمود الأيسر.
        private const val TILE_MIN_FIT = 0.7f
        private const val HEAD_MIN_FIT = 0.75f

        /// أعرض نص للساعة (بالأرقام العربية أو اللاتينية حسب لغة الجهاز)، لتثبيت حجمها طوال اليوم.
        private val WIDEST_CLOCK = listOf("١٢:٥٨", "12:58")

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

        private fun views(context: Context, prefs: SharedPreferences, options: Bundle?): RemoteViews =
            buildViews(
                context,
                prefs.getString(SCHEDULE_KEY, null),
                options?.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH, 0) ?: 0,
                options?.getInt(AppWidgetManager.OPTION_APPWIDGET_MAX_HEIGHT, 0) ?: 0,
                System.currentTimeMillis(),
                prefs.getString(NATIVE_WEATHER_KEY, null),
            )

        /// RemoteViews الودجت من [schedule] (JSON الجدول) بمقاس [widthDp]×[heightDp] (0 = غير معروف)
        /// عند [nowMillis]. يستدعيها المستقبل واختبار اللقطات (androidTest/LamhaScreensTest) معاً.
        ///
        /// تُغلَّف في RemoteViews(أفقي، رأسي) بنسختين متطابقتين ليعيد المشغّل بناء الشجرة في كل
        /// تحديث بدل إعادة تطبيق الأوامر على شجرة قديمة (canRecycleView يرفض التخطيطات المتعددة).
        /// بعد تحديث التطبيق تتغير أرقام المعرّفات (R.id)، وإعادة التطبيق على شجرة الإصدار السابق
        /// تضع النصوص في عناصر غير عناصرها (تراجع الإصدار ١٦: عناوين مختفية وقيم مكسّرة).
        fun buildViews(
            context: Context,
            schedule: String?,
            widthDp: Int,
            heightDp: Int,
            nowMillis: Long,
            nativeWeather: String? = null,
        ): RemoteViews {
            val day = LamhaSchedule.read(schedule, nowMillis)
                ?: return RemoteViews(context.packageName, R.layout.widget_setup).apply {
                    setOnClickPendingIntent(R.id.root, openAppIntent(context))
                }
            fun one() = singleViews(context, day, widthDp, heightDp, nowMillis, nativeWeather)
            return RemoteViews(one(), one())
        }

        private fun singleViews(
            context: Context, day: LamhaDay, minWidth: Int, maxHeight: Int, now: Long, nativeWeather: String?,
        ): RemoteViews {
            val ctx = arabic(context)
            val (accent, background) = colors(context, day)
            val rv = RemoteViews(context.packageName, R.layout.widget_lamha)
            rv.setOnClickPendingIntent(R.id.root, openAppIntent(context))
            rv.setInt(R.id.bg, "setColorFilter", background)
            rv.setInt(R.id.bg, "setImageAlpha", LamhaLogic.backgroundAlpha255(day.opacity))

            // الصف العلوي (الميزة ٣د). الساعة بتوقيت المدينة لتطابق «ص/م» واليوم (DECISIONS ٨).
            // كل حجم × معامل الخط، والساعة تصغر إن لم تتسع بجانب العمود الأيسر، وسطور العمود الأيسر
            // تصغر قليلاً (حتى ٧٥٪) قبل «…» (كالمعاينة).
            val scale = day.fontScale
            val sys = ctx.resources.configuration.fontScale
            val content = if (minWidth > 0) LamhaLogic.headContentDp(minWidth) else 0f
            fun w(text: String, sp: Float, bold: Boolean) = textWidthDp(ctx, text, sp, bold)
            fun widestClock(sp: Float) = WIDEST_CLOCK.maxOf { w(it, sp, true) }

            val amPm = ctx.getString(if (LamhaLogic.isAm(now, day.timeZone)) R.string.am else R.string.pm)
            val weather = LamhaLogic.newestWeather(
                day.weather, LamhaSchedule.weatherOf(nativeWeather),
                day.latitude, day.longitude,
            )
            val weatherText = LamhaLogic.weatherText(weather, now, day.weatherMaxAgeMinutes, day.weatherIcons)
                ?: ctx.getString(R.string.weather_unknown)
            data class Line(val id: Int, val shown: Boolean, val text: String, val sp: Float, val bold: Boolean)
            val left = listOf(
                Line(R.id.hijri, "hijri" in day.visible, ctx.getString(R.string.hijri_date, day.hijriText), HIJRI_SP * scale, true),
                Line(R.id.gregorian, "gregorian" in day.visible, ctx.getString(R.string.gregorian_date, day.gregorianText), GREGORIAN_SP * scale, false),
                Line(R.id.weather, "weather" in day.visible, ctx.getString(R.string.city_weather, day.cityName, weatherText), CITY_WEATHER_SP * scale, false),
            )
            val shownLeft = left.filter { it.shown }
            val amPmSp = AM_PM_SP * scale
            val weekdaySp = WEEKDAY_SP * scale
            val clockPreferred = LamhaLogic.clockSizeSp(minWidth) * scale
            val clockSp = if (content > 0f) {
                val leftWidth = shownLeft.maxOfOrNull { w(it.text, it.sp, it.bold) } ?: 0f
                LamhaLogic.fitTextSize(
                    clockPreferred, widestClock(clockPreferred),
                    LamhaLogic.clockAvailableDp(content, leftWidth, w(amPm, amPmSp, true)), LamhaLogic.CLOCK_MIN_SP,
                )
            } else clockPreferred
            val leftAvailable = if (content > 0f) {
                LamhaLogic.leftColumnDp(
                    content, widestClock(clockSp) + 4f + w(amPm, amPmSp, true), w(day.weekday, weekdaySp, true),
                ) - FIT_MARGIN_DP
            } else 0f

            rv.setTextViewTextSize(R.id.clock, TypedValue.COMPLEX_UNIT_SP, clockSp)
            rv.setString(R.id.clock, "setTimeZone", day.timeZone)
            rv.setTextViewText(R.id.am_pm, amPm)
            rv.setTextViewTextSize(R.id.am_pm, TypedValue.COMPLEX_UNIT_SP, amPmSp)
            rv.setTextViewText(R.id.weekday, day.weekday)
            rv.setTextViewTextSize(R.id.weekday, TypedValue.COMPLEX_UNIT_SP, weekdaySp)
            rv.setTextColor(R.id.weekday, accent)
            val leftSizes = ArrayList<Float>()
            for (l in left) {
                line(rv, l.id, l.shown, l.text)
                if (!l.shown) continue
                val sp = if (leftAvailable > 0f) {
                    LamhaLogic.fitTextSize(l.sp, w(l.text, l.sp, l.bold), leftAvailable, l.sp * HEAD_MIN_FIT)
                } else l.sp
                rv.setTextViewTextSize(l.id, TypedValue.COMPLEX_UNIT_SP, sp)
                leftSizes.add(sp)
            }

            // الشبكة: المربعات الظاهرة في صفين كما في gridRows (DESIGN: إعادة الترتيب عند الإخفاء).
            // معامل المربعات واحد للشبكة، ويصغر إن لم يتسع المربع الأطول في ارتفاع الودجت (تقديراً).
            val rows = LamhaLogic.gridRows(LamhaLogic.gridElements.filter { it in day.visible })
            val headDp = maxOf(
                (clockSp * CLOCK_LINE_HEIGHT + weekdaySp * LINE_HEIGHT) * sys - 4f,
                leftSizes.sum() * sys * LINE_HEIGHT + 4f,
            )
            val inner = LamhaLogic.tileInnerHeightDp(maxHeight, headDp, rows.size)
            val tallest = rows.flatten().maxOfOrNull { subCount(day, it.element) } ?: 0
            val coreSizes = listOf(TILE_TITLE_SP, TILE_VALUE_SP) + List(tallest) { TILE_SUB_SP }
            val tileScale = LamhaLogic.tileFitScale(scale, inner, coreSizes.map { it * sys }, LINE_HEIGHT, TILE_GAP_DP)
            rv.removeAllViews(R.id.row1)
            rv.removeAllViews(R.id.row2)
            rows.forEachIndexed { r, row ->
                for (cell in row) {
                    val textWidth = LamhaLogic.tileTextWidthDp(minWidth, cell.flex, row.sumOf { it.flex }) - FIT_MARGIN_DP
                    rv.addView(
                        if (r == 0) R.id.row1 else R.id.row2,
                        tile(context, ctx, day, cell, accent, now, textWidth, inner, tileScale, sys),
                    )
                }
            }
            rv.setViewVisibility(R.id.row2, if (rows.size > 1) View.VISIBLE else View.GONE)
            val grid = if (rows.isEmpty()) View.GONE else View.VISIBLE
            rv.setViewVisibility(R.id.grid, grid)
            rv.setViewVisibility(R.id.divider, grid)
            return rv
        }

        /// عرض [text] بالـ dp بخط النظام (عريض إن [bold]) بحجم [sp] (كـ TextPainter في المعاينة).
        private fun textWidthDp(context: Context, text: String, sp: Float, bold: Boolean = true): Float {
            val metrics = context.resources.displayMetrics
            val paint = Paint(Paint.ANTI_ALIAS_FLAG)
            paint.typeface = if (bold) Typeface.DEFAULT_BOLD else Typeface.DEFAULT
            paint.textSize = TypedValue.applyDimension(TypedValue.COMPLEX_UNIT_SP, sp, metrics)
            return paint.measureText(text) / metrics.density
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

        /// عدد الأسطر الثانوية الأساسية (كل منها سطر واحد) لمربع [element]، كـ coreSizes في المعاينة.
        private fun subCount(day: LamhaDay, element: String): Int = when (element) {
            "prayer" -> if (day.nextPrayer != null) 2 else 0
            "qibla" -> 1
            "deposit" -> if (day.deposits.size > 1) 2 else 1
            "season" -> 1
            else -> if (day.tradDescription.isEmpty()) 1 else 2
        }

        /// مربع واحد بلا رموز (الميزة ٣د). الثانويات: sub1 سطر، ثم العدّاد، ثم sub2 سطر، ثم sub3
        /// (حتى سطرين بقدر ما يتسع). كل حجم × [scale]، والعنوان والقيمة يصغران ليتسعا في [availDp].
        private fun tile(
            context: Context, ctx: Context, day: LamhaDay, cell: LamhaLogic.Cell, accent: Int, now: Long,
            availDp: Float, innerHeightDp: Float, scale: Float, sys: Float,
        ): RemoteViews {
            val rv = RemoteViews(context.packageName, if (cell.flex == 2) R.layout.widget_tile_wide else R.layout.widget_tile)
            val titleSp = TILE_TITLE_SP * scale
            val valueSp = TILE_VALUE_SP * scale
            val subSp = TILE_SUB_SP * scale
            var title = ctx.getString(
                when (cell.element) {
                    "prayer" -> R.string.tile_prayer
                    "qibla" -> R.string.tile_qibla
                    "deposit" -> R.string.tile_deposit
                    "season" -> R.string.tile_season
                    else -> R.string.tile_trad_season
                },
            )
            var value = ""
            var sub1: String? = null
            var sub2: String? = null
            var sub3: String? = null
            when (cell.element) {
                "prayer" -> {
                    rv.setImageViewResource(R.id.tile_bg, R.drawable.tile_bg_accent)
                    rv.setInt(R.id.tile_bg, "setColorFilter", accent)
                    rv.setInt(R.id.tile_bg, "setImageAlpha", HIGHLIGHT_ALPHA)
                    val next = day.nextPrayer
                    value = next?.name ?: ""
                    sub1 = next?.text
                    if (next != null) {
                        // عدّاد النظام التنازلي حتى الصلاة («باقي ٦:٠٤:١٩»)، فلا يحتاج تحديثاً كل ثانية.
                        val base = SystemClock.elapsedRealtime() + (next.atMillis - now)
                        rv.setChronometer(R.id.tile_countdown, base, ctx.getString(R.string.countdown_format), true)
                        rv.setChronometerCountDown(R.id.tile_countdown, true)
                        rv.setTextViewTextSize(R.id.tile_countdown, TypedValue.COMPLEX_UNIT_SP, subSp)
                        rv.setViewVisibility(R.id.tile_countdown, View.VISIBLE)
                    }
                }
                "qibla" -> {
                    value = day.qiblaDegrees
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
                    // «الإيداع القادم» إن اتسع سطراً واحداً، وإلا «الإيداع» (كـ _depositTile).
                    title = LamhaLogic.fittingTitle(
                        title, ctx.getString(R.string.tile_deposit_short), textWidthDp(ctx, title, titleSp), availDp,
                    )
                    value = first?.label ?: "--"
                    if (second != null) {
                        // مع إيداعين: الاسم، ثم الباقي، ثم الثاني «راتب أكتوبر · باقي ٨ أيام» كاملاً إن اتسع وإلا «…».
                        sub1 = first?.remaining
                        sub2 = ctx.getString(R.string.value_with_suffix, second.label, second.remaining)
                    } else {
                        sub3 = first?.remaining
                    }
                }
                "season" -> {
                    value = day.seasonName
                    sub3 = ctx.getString(R.string.remaining_to_next, day.seasonRemaining, LamhaLogic.withLam(day.seasonNext))
                }
                else -> {
                    value = day.tradName
                    sub1 = ctx.getString(R.string.remaining_to_next, day.tradRemaining, LamhaLogic.withLam(day.tradNext))
                    sub3 = day.tradDescription
                }
            }
            // العنوان والقيمة سطر واحد: يصغر الخط (حتى ٧٠٪) إن لم يتسع، ثم «…». بلا عرض معروف: كما هو.
            fun fit(text: String, sp: Float) =
                if (availDp > 0f) LamhaLogic.fitTextSize(sp, textWidthDp(ctx, text, sp), availDp, sp * TILE_MIN_FIT) else sp
            val titleFit = fit(title, titleSp)
            val valueFit = fit(value, valueSp)
            // العنوان والقيمة ظاهران دائماً (صراحةً، لا اعتماداً على حالة شجرة سابقة).
            rv.setViewVisibility(R.id.tile_title, View.VISIBLE)
            rv.setViewVisibility(R.id.tile_value, View.VISIBLE)
            rv.setTextViewText(R.id.tile_title, title)
            rv.setTextViewTextSize(R.id.tile_title, TypedValue.COMPLEX_UNIT_SP, titleFit)
            rv.setTextViewText(R.id.tile_value, value)
            rv.setTextViewTextSize(R.id.tile_value, TypedValue.COMPLEX_UNIT_SP, valueFit)
            for (id in intArrayOf(R.id.tile_sub1, R.id.tile_sub2, R.id.tile_sub3)) {
                rv.setTextViewTextSize(id, TypedValue.COMPLEX_UNIT_SP, subSp)
            }
            sub(rv, R.id.tile_sub1, sub1)
            sub(rv, R.id.tile_sub2, sub2)
            sub(rv, R.id.tile_sub3, sub3)
            if (!sub3.isNullOrEmpty() && innerHeightDp > 0f) {
                // sub3 يأخذ سطراً ثانياً إن اتسع بعد بقية المحتوى (fittingLines كالمعاينة).
                val subLine = subSp * sys * LINE_HEIGHT
                val subs = subCount(day, cell.element)
                val used = (titleFit + valueFit) * sys * LINE_HEIGHT + subs * subLine + TILE_GAP_DP * (subs + 1)
                rv.setInt(R.id.tile_sub3, "setMaxLines", LamhaLogic.fittingLines(innerHeightDp - used, subLine, 2))
            }
            return rv
        }
    }
}
