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

/// الودجت الكبيرة (٤×٤) بـ RemoteViews عادية (الميزة ٣ج، DECISIONS ١٣)، ومربعاتها من `layout` (الميزة ٥). تقرأ الجدول ولا تحسب
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

            // الميزة ٥: المربعات الظاهرة من layout تُرصّ في صفوف (packRows)، وارتفاع كل صف بوزن
            // أطول مربع فيه (rowHeights)، ومعامل واحد يصغر به النص كله إن لم يتسع (تقديراً).
            val sys = ctx.resources.configuration.fontScale
            val byId = day.layout.associateBy { it.id }
            val rows = LamhaLogic.packRows(day.layout.filter { it.visible }.map { LamhaLogic.Cell(it.id, it.span) })
            val weather = LamhaLogic.newestWeather(
                day.weather, LamhaSchedule.weatherOf(nativeWeather),
                day.latitude, day.longitude,
            )
            val weatherText = LamhaLogic.weatherText(weather, now, day.weatherMaxAgeMinutes, day.weatherIcons)
                ?: ctx.getString(R.string.weather_unknown)
            val env = Env(context, ctx, day, accent, now, minWidth, sys, weatherText)
            fun scaleOf(id: String) = day.fontScale * (byId[id]?.fontScale ?: 1f)
            val sizes = rows.map { r -> r.map { heightsDp(env, it, scaleOf(it.id)) } }
            val text = sizes.map { r -> r.maxOf { it.first } }
            val pads = sizes.map { r -> r.maxOf { it.second } }
            // أندرويد ١٢+ يضبط ارتفاع الصف (setViewLayoutHeight)، والأقدم صفوف متساوية.
            val exact = Build.VERSION.SDK_INT >= Build.VERSION_CODES.S && maxHeight > 0
            val (fit, heights) = LamhaLogic.rowHeights(
                text, pads, if (maxHeight > 0) maxHeight - 20f else 0f, 0f, equal = !exact,
                squeezable = rows.map { r -> r.none { it.id in FIXED_TILES } },
            )
            rv.removeAllViews(R.id.grid)
            rows.forEachIndexed { r, row ->
                val rowViews = RemoteViews(context.packageName, R.layout.widget_row)
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S && exact) {
                    rowViews.setViewLayoutHeight(R.id.row, heights[r], TypedValue.COMPLEX_UNIT_DIP)
                }
                for (cell in row) {
                    val slot = RemoteViews(
                        context.packageName,
                        when (cell.span) {
                            1 -> R.layout.widget_tile
                            2 -> R.layout.widget_tile_wide
                            else -> R.layout.widget_tile_full
                        },
                    )
                    val spec = byId[cell.id] ?: LamhaLogic.Tile(cell.id)
                    val inner = if (maxHeight > 0) heights[r] - 8f else 0f
                    slot.addView(R.id.slot, tile(env, spec, cell.span, scaleOf(cell.id) * fit, inner))
                    rowViews.addView(R.id.row, slot)
                }
                rv.addView(R.id.grid, rowViews)
            }
            return rv
        }

        /// مربعات لا تُخفي أسطرها إن ضاق صفها (rowHeights: squeezable).
        private val FIXED_TILES = setOf("clock", "weather")

        /// ما يحتاجه كل مربع: السياقان (الأصلي وبالعربية)، واليوم، والتمييز، والعرض، وخط النظام.
        private class Env(
            val context: Context, val ctx: Context, val day: LamhaDay, val accent: Int, val now: Long,
            val widthDp: Int, val sys: Float, val weatherText: String,
        )

        /// ارتفاعا المربع (dp) بمعامله [scale] كـ heights في المعاينة: النص الذي يصغر مع معامل الملاءمة،
        /// وما لا يصغر (حشوة الخانة ٤+٤، ولمربعات المعلومات حشوتها ٨+٨ والفواصل ٣، والساعة إن صغّرها
        /// عرض مربعها).
        private fun heightsDp(env: Env, cell: LamhaLogic.Cell, scale: Float): Pair<Float, Float> {
            val s = scale * env.sys
            return when (cell.id) {
                "clock" -> {
                    val (preferred, fitted) = clockSp(env, scale, LamhaLogic.slotInnerDp(env.widthDp, cell.span) - FIT_MARGIN_DP)
                    val weekday = WEEKDAY_SP * LINE_HEIGHT * s
                    val clock = fitted * CLOCK_LINE_HEIGHT * env.sys
                    if (fitted < preferred) weekday to clock + 4f else clock + weekday to 4f
                }
                "dates" -> (HIJRI_SP + GREGORIAN_SP) * LINE_HEIGHT * s to 10f
                "weather" -> CITY_WEATHER_SP * LINE_HEIGHT * s to 8f
                else -> (TILE_TITLE_SP + TILE_VALUE_SP + subCount(env.day, cell.id) * TILE_SUB_SP) * LINE_HEIGHT * s to
                    8f + 16f + TILE_GAP_DP * (subCount(env.day, cell.id) + 1)
            }
        }

        /// حجم الساعة (المطلوب، والفعلي): ٥٢ (أو ٤٢ للضيقة) × [scale]، ويصغر (حتى ٢٨) ليتسع أعرض نص لها
        /// مع «ص/م» في [avail]. بلا عرض معروف: المطلوب.
        private fun clockSp(env: Env, scale: Float, avail: Float): Pair<Float, Float> {
            val preferred = LamhaLogic.clockSizeSp(env.widthDp) * scale
            if (avail <= 0f) return preferred to preferred
            val amPm = env.ctx.getString(if (LamhaLogic.isAm(env.now, env.day.timeZone)) R.string.am else R.string.pm)
            val fitted = LamhaLogic.fitTextSize(
                preferred, WIDEST_CLOCK.maxOf { textWidthDp(env.ctx, it, preferred, true) },
                avail - 4f - textWidthDp(env.ctx, amPm, AM_PM_SP * scale, true), LamhaLogic.CLOCK_MIN_SP,
            )
            return preferred to fitted
        }

        /// عرض [text] بالـ dp بخط النظام (عريض إن [bold]) بحجم [sp] (كـ TextPainter في المعاينة).
        private fun textWidthDp(context: Context, text: String, sp: Float, bold: Boolean = true): Float {
            val metrics = context.resources.displayMetrics
            val paint = Paint(Paint.ANTI_ALIAS_FLAG)
            paint.typeface = if (bold) Typeface.DEFAULT_BOLD else Typeface.DEFAULT
            paint.textSize = TypedValue.applyDimension(TypedValue.COMPLEX_UNIT_SP, sp, metrics)
            return paint.measureText(text) / metrics.density
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

        /// محتوى مربع [tile] بعرض [span] ومعامل خطه الفعلي [scale]، و[innerHeightDp] ارتفاع خانته.
        private fun tile(env: Env, tile: LamhaLogic.Tile, span: Int, scale: Float, innerHeightDp: Float): RemoteViews {
            val ctx = env.ctx
            val day = env.day
            val inner = LamhaLogic.slotInnerDp(env.widthDp, span)
            fun w(text: String, sp: Float, bold: Boolean) = textWidthDp(ctx, text, sp, bold)
            // سطر يصغر (حتى [minFit]) ليتسع في [avail]، ثم «…». بلا عرض معروف: كما هو.
            fun fit(text: String, sp: Float, bold: Boolean, avail: Float, minFit: Float) =
                if (avail > 0f) LamhaLogic.fitTextSize(sp, w(text, sp, bold), avail, sp * minFit) else sp
            fun color(rv: RemoteViews, id: Int, c: Int?) { if (c != null) rv.setTextColor(id, c) }
            val primary = tile.primaryColor
            val secondary = tile.secondaryColor
            val avail = if (inner > 0f) inner - FIT_MARGIN_DP else 0f
            return when (tile.id) {
                "clock" -> RemoteViews(env.context.packageName, R.layout.widget_tile_clock).apply {
                    // الساعة بتوقيت المدينة لتطابق «ص/م» واليوم (DECISIONS ٨)، وتصغر (حتى ٢٨) لتتسع.
                    val amPm = ctx.getString(if (LamhaLogic.isAm(env.now, day.timeZone)) R.string.am else R.string.pm)
                    val amPmSp = AM_PM_SP * scale
                    val clockSp = clockSp(env, scale, avail).second
                    setTextViewTextSize(R.id.clock, TypedValue.COMPLEX_UNIT_SP, clockSp)
                    setString(R.id.clock, "setTimeZone", day.timeZone)
                    setTextViewText(R.id.am_pm, amPm)
                    setTextViewTextSize(R.id.am_pm, TypedValue.COMPLEX_UNIT_SP, amPmSp)
                    setTextViewText(R.id.weekday, day.weekday)
                    setTextViewTextSize(
                        R.id.weekday, TypedValue.COMPLEX_UNIT_SP,
                        fit(day.weekday, WEEKDAY_SP * scale, true, avail, HEAD_MIN_FIT),
                    )
                    setTextColor(R.id.weekday, secondary ?: env.accent)
                    color(this, R.id.clock, primary)
                    color(this, R.id.am_pm, primary)
                }
                "dates" -> RemoteViews(env.context.packageName, R.layout.widget_tile_dates).apply {
                    val hijri = ctx.getString(R.string.hijri_date, day.hijriText)
                    val gregorian = ctx.getString(R.string.gregorian_date, day.gregorianText)
                    setTextViewText(R.id.hijri, hijri)
                    setTextViewTextSize(R.id.hijri, TypedValue.COMPLEX_UNIT_SP, fit(hijri, HIJRI_SP * scale, true, avail, HEAD_MIN_FIT))
                    setTextViewText(R.id.gregorian, gregorian)
                    setTextViewTextSize(
                        R.id.gregorian, TypedValue.COMPLEX_UNIT_SP, fit(gregorian, GREGORIAN_SP * scale, false, avail, HEAD_MIN_FIT),
                    )
                    color(this, R.id.hijri, primary)
                    color(this, R.id.gregorian, secondary)
                    // الميلادي يُخفى إن لم يتسع تحت الهجري (تقديراً)، فلا يُقص.
                    if (innerHeightDp > 0f && (HIJRI_SP + GREGORIAN_SP) * scale * env.sys * LINE_HEIGHT + 2f > innerHeightDp) {
                        setViewVisibility(R.id.gregorian, View.GONE)
                    }
                }
                "weather" -> RemoteViews(env.context.packageName, R.layout.widget_tile_weather).apply {
                    val line = ctx.getString(R.string.city_weather, day.cityName, env.weatherText)
                    setTextViewText(R.id.weather, line)
                    setTextViewTextSize(
                        R.id.weather, TypedValue.COMPLEX_UNIT_SP, fit(line, CITY_WEATHER_SP * scale, false, avail, HEAD_MIN_FIT),
                    )
                    color(this, R.id.weather, primary)
                }
                else -> infoTile(env, tile.id, scale, if (inner > 0f) inner - 18f - FIT_MARGIN_DP else 0f, innerHeightDp - 16f).apply {
                    color(this, R.id.tile_value, primary)
                    for (id in intArrayOf(R.id.tile_title, R.id.tile_sub1, R.id.tile_countdown, R.id.tile_sub2, R.id.tile_sub3)) {
                        color(this, id, secondary)
                    }
                }
            }
        }

        /// مربع معلومات بلا رموز (الميزة ٣د). الثانويات: sub1 سطر، ثم العدّاد، ثم sub2 سطر، ثم sub3
        /// (حتى سطرين بقدر ما يتسع). كل حجم × [scale]، والعنوان والقيمة يصغران ليتسعا في [availDp].
        private fun infoTile(env: Env, element: String, scale: Float, availDp: Float, innerHeightDp: Float): RemoteViews {
            val context = env.context
            val ctx = env.ctx
            val day = env.day
            val sys = env.sys
            val rv = RemoteViews(context.packageName, R.layout.widget_tile_content)
            val titleSp = TILE_TITLE_SP * scale
            val valueSp = TILE_VALUE_SP * scale
            val subSp = TILE_SUB_SP * scale
            var title = ctx.getString(
                when (element) {
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
            when (element) {
                "prayer" -> {
                    rv.setImageViewResource(R.id.tile_bg, R.drawable.tile_bg_accent)
                    rv.setInt(R.id.tile_bg, "setColorFilter", env.accent)
                    rv.setInt(R.id.tile_bg, "setImageAlpha", HIGHLIGHT_ALPHA)
                    val next = day.nextPrayer
                    value = next?.name ?: ""
                    sub1 = next?.text
                    if (next != null) {
                        // عدّاد النظام التنازلي حتى الصلاة («باقي ٦:٠٤:١٩»)، فلا يحتاج تحديثاً كل ثانية.
                        val base = SystemClock.elapsedRealtime() + (next.atMillis - env.now)
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
            // الثانويات بالترتيب ما اتسع منها (تقديراً)، وما بعده يُخفى فلا يُقص سطر في منتصفه.
            val subLine = subSp * sys * LINE_HEIGHT
            var used = (titleFit + valueFit) * sys * LINE_HEIGHT + TILE_GAP_DP
            var room = true
            fun fits(): Boolean {
                room = room && (innerHeightDp <= 0f || used + TILE_GAP_DP + subLine <= innerHeightDp)
                if (room) used += TILE_GAP_DP + subLine
                return room
            }
            sub(rv, R.id.tile_sub1, sub1.takeIf { !it.isNullOrEmpty() && fits() })
            if (element == "prayer" && day.nextPrayer != null && !fits()) rv.setViewVisibility(R.id.tile_countdown, View.GONE)
            sub(rv, R.id.tile_sub2, sub2.takeIf { !it.isNullOrEmpty() && fits() })
            sub(rv, R.id.tile_sub3, sub3.takeIf { !it.isNullOrEmpty() && fits() })
            if (!sub3.isNullOrEmpty() && room && innerHeightDp > 0f) {
                // sub3 يأخذ سطراً ثانياً إن اتسع بعد بقية المحتوى (fittingLines كالمعاينة).
                rv.setInt(R.id.tile_sub3, "setMaxLines", LamhaLogic.fittingLines(innerHeightDp - used, subLine, 2))
            }
            return rv
        }
    }
}
