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
import android.text.StaticLayout
import android.text.TextPaint
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

        /// نص قياس ارتفاع السطر (lineDp): عربي وأرقام، والساعة.
        private const val LINE_SAMPLE = "الفجر ٣٢٤° أبها"
        private const val CLOCK_SAMPLE = "١٢:٥٨"
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
            // أطول مربع فيه (rowHeights) بالحجم الأساسي، فلا يتغير مقاس المربع بحجم الخط (الميزة ٥ب).
            // ثم يلائم كل مربع نصه بحجمه المطلوب داخل مقاسه (LamhaLogic.fitTile).
            val sys = ctx.resources.configuration.fontScale
            val byId = day.layout.associateBy { it.id }
            val rows = LamhaLogic.packRows(
                LamhaLogic.stackCells(day.layout.filter { it.visible }.map { LamhaLogic.Cell(it.id, it.span) }),
            )
            val weather = LamhaLogic.newestWeather(
                day.weather, LamhaSchedule.weatherOf(nativeWeather),
                day.latitude, day.longitude,
            )
            val weatherText = LamhaLogic.weatherText(weather, now, day.weatherMaxAgeMinutes, day.weatherIcons)
                ?: ctx.getString(R.string.weather_unknown)
            val env = Env(context, ctx, day, accent, now, minWidth, sys, weatherText)
            fun scaleOf(id: String) = day.fontScale * (byId[id]?.fontScale ?: 1f)
            // الخانة المكدسة (التاريخان وتحتهما المدينة): مجموع ارتفاعيهما، وحشوة الخانة مرة.
            val parts = rows.map { r ->
                r.map { cell -> LamhaLogic.cellElements(cell.id).map { heightsDp(env, LamhaLogic.Cell(it, cell.span), 1f) } }
            }
            val sizes = parts.map { r ->
                r.map { p ->
                    p.sumOf { it.first.toDouble() }.toFloat() to (p.sumOf { it.second.toDouble() }.toFloat() - 8f * (p.size - 1))
                }
            }
            // كل صف بأطول خانة فيه (نصها وحشوتها معاً، لا أكبر نص وأكبر حشوة من خانتين).
            val tallest = sizes.map { r -> r.maxBy { it.first + it.second } }
            val text = tallest.map { it.first }
            val pads = tallest.map { it.second }
            // أندرويد ١٢+ يضبط ارتفاع الصف (setViewLayoutHeight)، والأقدم صفوف متساوية.
            val exact = Build.VERSION.SDK_INT >= Build.VERSION_CODES.S && maxHeight > 0
            val (_, heights) = LamhaLogic.rowHeights(
                text, pads, if (maxHeight > 0) maxHeight - 20f else 0f, 0f, equal = !exact,
                // صفوف المربعات تقتسم الباقي، وصفوف الساعة والتاريخين والمدينة بقدر محتواها.
                flexible = rows.map { r -> r.any { it.id !in LINE_TILES } },
            )
            rv.removeAllViews(R.id.grid)
            rows.forEachIndexed { r, row ->
                val rowViews = RemoteViews(context.packageName, R.layout.widget_row)
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S && exact) {
                    rowViews.setViewLayoutHeight(R.id.row, heights[r], TypedValue.COMPLEX_UNIT_DIP)
                }
                for ((c, cell) in row.withIndex()) {
                    val slot = RemoteViews(
                        context.packageName,
                        when (cell.span) {
                            1 -> R.layout.widget_tile
                            2 -> R.layout.widget_tile_wide
                            else -> R.layout.widget_tile_full
                        },
                    )
                    val inner = if (maxHeight > 0) heights[r] - 8f else 0f
                    val ids = LamhaLogic.cellElements(cell.id)
                    if (ids.size == 1) {
                        val spec = byId[cell.id] ?: LamhaLogic.Tile(cell.id)
                        slot.addView(R.id.slot, tile(env, spec, cell.span, scaleOf(cell.id), inner))
                    } else {
                        // عمود: التاريخان ثم المدينة والطقس تحتهما، متوسطان رأسياً، ولكل منهما ارتفاعه
                        // الأساسي (بنسبته إن ضاقت الخانة).
                        val stack = RemoteViews(context.packageName, R.layout.widget_tile_stack)
                        val own = parts[r][c].map { it.first + it.second - 8f }
                        val ratio = if (inner > 0f && own.sum() > inner) inner / own.sum() else 1f
                        for ((k, id) in ids.withIndex()) {
                            val spec = byId[id] ?: LamhaLogic.Tile(id)
                            stack.addView(R.id.stack, tile(env, spec, cell.span, scaleOf(id), if (inner > 0f) own[k] * ratio else 0f))
                        }
                        slot.addView(R.id.slot, stack)
                    }
                    rowViews.addView(R.id.row, slot)
                }
                rv.addView(R.id.grid, rowViews)
            }
            return rv
        }

        /// خانات بلا صندوق: صفوفها بقدر محتواها (rowHeights: flexible، _lineTiles في المعاينة).
        private val LINE_TILES = setOf("clock", "dates", "weather", LamhaLogic.DATES_WEATHER)

        /// ما يحتاجه كل مربع: السياقان (الأصلي وبالعربية)، واليوم، والتمييز، والعرض، وخط النظام.
        private class Env(
            val context: Context, val ctx: Context, val day: LamhaDay, val accent: Int, val now: Long,
            val widthDp: Int, val sys: Float, val weatherText: String,
        )

        /// ارتفاعا المربع (dp) بمعامله [scale] كـ heights في المعاينة: النص الذي يصغر مع معامل الملاءمة،
        /// وما لا يصغر (حشوة الخانة ٤+٤، ولمربعات المعلومات حشوتها ٨+٨ والفواصل ٣، والساعة إن صغّرها
        /// عرض مربعها).
        private fun heightsDp(env: Env, cell: LamhaLogic.Cell, scale: Float): Pair<Float, Float> {
            return when (cell.id) {
                "clock" -> {
                    val (preferred, fitted) = clockSp(env, scale, LamhaLogic.slotInnerDp(env.widthDp, cell.span) - FIT_MARGIN_DP)
                    val weekday = lineDp(env.ctx, WEEKDAY_SP * scale, true, false)
                    val clock = lineDp(env.ctx, fitted, true, false, CLOCK_SAMPLE)
                    if (fitted < preferred) weekday to clock + 4f else clock + weekday to 4f
                }
                "dates" -> lineDp(env.ctx, HIJRI_SP * scale, true) + lineDp(env.ctx, GREGORIAN_SP * scale, false) to 10f
                "weather" -> lineDp(env.ctx, CITY_WEATHER_SP * scale, false) to 8f
                else -> lineDp(env.ctx, TILE_TITLE_SP * scale, true) + lineDp(env.ctx, TILE_VALUE_SP * scale, true) +
                    subCount(env.day, cell.id) * lineDp(env.ctx, TILE_SUB_SP * scale, false) to
                    8f + 16f + TILE_GAP_DP * (subCount(env.day, cell.id) + 1)
            }
        }

        /// حجم الساعة (المطلوب، والفعلي): ٥٢ (أو ٤٢ للضيقة) × [scale]، وتصغر مع «ص/م» (كلمة واحدة) بأدنى
        /// تصغير ليتسع أعرض نص لها في [avail]. بلا عرض معروف: المطلوب.
        private fun clockSp(env: Env, scale: Float, avail: Float): Pair<Float, Float> {
            val preferred = LamhaLogic.clockSizeSp(env.widthDp) * scale
            val w = clockWidthDp(env, scale)
            return preferred to if (avail > 0f && w > avail) preferred * avail / w else preferred
        }

        /// عرض أعرض نص للساعة و«ص/م» بجانبها، بالحجم المطلوب.
        private fun clockWidthDp(env: Env, scale: Float): Float {
            val preferred = LamhaLogic.clockSizeSp(env.widthDp) * scale
            val amPm = env.ctx.getString(if (LamhaLogic.isAm(env.now, env.day.timeZone)) R.string.am else R.string.pm)
            return WIDEST_CLOCK.maxOf { textWidthDp(env.ctx, it, preferred, true) } + 4f +
                textWidthDp(env.ctx, amPm, AM_PM_SP * scale, true)
        }

        /// عرض كلمات [text] (للالتفاف عند المسافات فقط) والمسافة بينها.
        private fun wordsDp(ctx: Context, text: String, sp: Float, bold: Boolean): Pair<List<Float>, Float> {
            val parts = text.split(' ').filter { it.isNotEmpty() }
            val words = parts.map { textWidthDp(ctx, it, sp, bold) }
            val space = if (parts.size > 1) {
                maxOf(0f, textWidthDp(ctx, parts.joinToString(" "), sp, bold) - words.sum()) / (parts.size - 1)
            } else 0f
            return words to space
        }

        /// ارتفاع سطر واحد (dp) بخط النظام بحجم [sp] كما يرسمه TextView، مع خطوط الاحتياط (العربية)
        /// و[includePad] كـ includeFontPadding. قياس لا تقدير (الميزة ٥ب).
        private fun lineDp(context: Context, sp: Float, bold: Boolean, includePad: Boolean = true, sample: String = LINE_SAMPLE): Float {
            val metrics = context.resources.displayMetrics
            val paint = TextPaint(Paint.ANTI_ALIAS_FLAG)
            paint.typeface = if (bold) Typeface.DEFAULT_BOLD else Typeface.DEFAULT
            paint.textSize = TypedValue.applyDimension(TypedValue.COMPLEX_UNIT_SP, sp, metrics)
            val b = StaticLayout.Builder.obtain(sample, 0, sample.length, paint, 100_000).setIncludePad(includePad)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) b.setUseLineSpacingFromFallbacks(true)
            return b.build().height / metrics.density
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
            fun color(rv: RemoteViews, id: Int, c: Int?) { if (c != null) rv.setTextColor(id, c) }
            val primary = tile.primaryColor
            val secondary = tile.secondaryColor
            val avail = if (inner > 0f) inner - FIT_MARGIN_DP else 0f
            return when (tile.id) {
                "clock" -> RemoteViews(env.context.packageName, R.layout.widget_tile_clock).apply {
                    // الساعة بتوقيت المدينة لتطابق «ص/م» واليوم (DECISIONS ٨). كلمة واحدة: تصغر فقط إن لم
                    // يتسع عرضها، واليوم يُخفى قبل أن تصغر لضيق الارتفاع (fitTile).
                    val amPm = ctx.getString(if (LamhaLogic.isAm(env.now, day.timeZone)) R.string.am else R.string.pm)
                    val preferred = LamhaLogic.clockSizeSp(env.widthDp) * scale
                    val weekdaySp = WEEKDAY_SP * scale
                    val fit = LamhaLogic.fitTile(
                        innerHeightDp, avail, 0f, lineDp(ctx, preferred, true, false, CLOCK_SAMPLE), listOf(clockWidthDp(env, scale)),
                        subs = if (tile.showSub) {
                            listOf(LamhaLogic.SubLine(lineDp(ctx, weekdaySp, true, false), 1, w(day.weekday, weekdaySp, true)))
                        } else emptyList(),
                        minSubFit = HEAD_MIN_FIT,
                    )
                    setTextViewTextSize(R.id.clock, TypedValue.COMPLEX_UNIT_SP, preferred * fit.valueScale)
                    setString(R.id.clock, "setTimeZone", day.timeZone)
                    setTextViewText(R.id.am_pm, amPm)
                    setTextViewTextSize(R.id.am_pm, TypedValue.COMPLEX_UNIT_SP, AM_PM_SP * scale * fit.valueScale)
                    setTextViewText(R.id.weekday, day.weekday)
                    if (fit.subs.isEmpty()) {
                        setViewVisibility(R.id.weekday, View.GONE)
                    } else {
                        setTextViewTextSize(R.id.weekday, TypedValue.COMPLEX_UNIT_SP, weekdaySp * fit.subScales[0])
                    }
                    setTextColor(R.id.weekday, secondary ?: env.accent)
                    color(this, R.id.clock, primary)
                    color(this, R.id.am_pm, primary)
                }
                "dates" -> RemoteViews(env.context.packageName, R.layout.widget_tile_dates).apply {
                    val hijri = ctx.getString(R.string.hijri_date, day.hijriText)
                    val gregorian = ctx.getString(R.string.gregorian_date, day.gregorianText)
                    val hijriSp = HIJRI_SP * scale
                    val gregorianSp = GREGORIAN_SP * scale
                    // الهجري قيمة تلتفّ عند المسافات، والميلادي يُخفى إن لم يتسع (fitTile).
                    val (words, space) = wordsDp(ctx, hijri, hijriSp, true)
                    val fit = LamhaLogic.fitTile(
                        innerHeightDp, avail, 0f, lineDp(ctx, hijriSp, true), words, space,
                        subs = if (tile.showSub) {
                            listOf(LamhaLogic.SubLine(lineDp(ctx, gregorianSp, false), 1, w(gregorian, gregorianSp, false)))
                        } else emptyList(),
                        gap = 2f, minSubFit = HEAD_MIN_FIT,
                    )
                    setTextViewText(R.id.hijri, hijri)
                    setTextViewTextSize(R.id.hijri, TypedValue.COMPLEX_UNIT_SP, hijriSp * fit.valueScale)
                    setInt(R.id.hijri, "setMaxLines", fit.valueLines)
                    setTextViewText(R.id.gregorian, gregorian)
                    if (fit.subs.isEmpty()) {
                        setViewVisibility(R.id.gregorian, View.GONE)
                    } else {
                        setTextViewTextSize(R.id.gregorian, TypedValue.COMPLEX_UNIT_SP, gregorianSp * fit.subScales[0])
                    }
                    color(this, R.id.hijri, primary)
                    color(this, R.id.gregorian, secondary)
                }
                "weather" -> RemoteViews(env.context.packageName, R.layout.widget_tile_weather).apply {
                    val line = ctx.getString(R.string.city_weather, day.cityName, env.weatherText)
                    val sp = CITY_WEATHER_SP * scale
                    val (words, space) = wordsDp(ctx, line, sp, false)
                    val fit = LamhaLogic.fitTile(innerHeightDp, avail, 0f, lineDp(ctx, sp, false), words, space)
                    setTextViewText(R.id.weather, line)
                    setTextViewTextSize(R.id.weather, TypedValue.COMPLEX_UNIT_SP, sp * fit.valueScale)
                    setInt(R.id.weather, "setMaxLines", fit.valueLines)
                    color(this, R.id.weather, primary)
                }
                else -> infoTile(env, tile, scale, if (inner > 0f) inner - 18f - FIT_MARGIN_DP else 0f, innerHeightDp - 16f).apply {
                    color(this, R.id.tile_value, primary)
                    for (id in intArrayOf(R.id.tile_title, R.id.tile_sub1, R.id.tile_countdown, R.id.tile_sub2, R.id.tile_sub3)) {
                        color(this, id, secondary)
                    }
                }
            }
        }

        /// مربع معلومات بلا رموز (الميزة ٣د). الثانويات: sub1 سطر، ثم العدّاد، ثم sub2 سطر، ثم sub3
        /// (حتى سطرين بقدر ما يتسع). الحجم المطلوب × [scale] يُحترم داخل المربع (fitTile، الميزة ٥ب):
        /// القيمة تلتفّ عند المسافات، وإن ضاق الارتفاع تُخفى الثانويات بأولويتها ثم العنوان.
        private fun infoTile(env: Env, spec: LamhaLogic.Tile, scale: Float, availDp: Float, innerHeightDp: Float): RemoteViews {
            val element = spec.id
            val context = env.context
            val ctx = env.ctx
            val day = env.day
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
            // عرض العدّاد الذي لا يُختصر (0 = بلا عدّاد).
            var countWidth = 0f
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
                        // في المربع الضيق: بلا «باقي»، ثم يصغر قليلاً (fitTile)، وإلا يُخفى.
                        var format = ctx.getString(R.string.countdown_format)
                        if (availDp > 0f && textWidthDp(ctx, String.format(format, "00:00:00"), subSp, false) > availDp) format = "%s"
                        countWidth = textWidthDp(ctx, String.format(format, "00:00:00"), subSp, false)
                        rv.setChronometer(R.id.tile_countdown, base, format, true)
                        rv.setChronometerCountDown(R.id.tile_countdown, true)
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
            // العنوان سطر واحد: يصغر الخط (حتى ٧٠٪) إن لم يتسع، ثم «…». بلا عرض معروف: كما هو.
            // وإن لم يتسع حتى بأدنى حجم يُخفى (لا «…»).
            val titleFit = if (availDp > 0f) {
                LamhaLogic.fitTextSize(titleSp, textWidthDp(ctx, title, titleSp), availDp, titleSp * TILE_MIN_FIT)
            } else titleSp
            val titleFits = availDp <= 0f || textWidthDp(ctx, title, titleFit) <= availDp
            // الثانويات بترتيب عرضها، والإخفاء من الآخر (الإيداع: الثاني قبل «باقي»؛ الموسم: الوصف قبل
            // «باقي»)، إلا الصلاة: الوقت أولاً والعدّاد آخراً.
            val countdown = if (countWidth > 0f) "countdown" else null
            val lines = listOf(R.id.tile_sub1 to sub1, R.id.tile_countdown to countdown, R.id.tile_sub2 to sub2, R.id.tile_sub3 to sub3)
                .filter { !it.second.isNullOrEmpty() && spec.showSub }
            val subLine = lineDp(ctx, subSp, false)
            val (words, space) = wordsDp(ctx, value, valueSp, true)
            val fit = LamhaLogic.fitTile(
                innerHeightDp, availDp,
                if (spec.showTitle && titleFits) lineDp(ctx, titleFit, true) else 0f,
                lineDp(ctx, valueSp, true), words, space,
                subs = lines.map { (id, _) ->
                    LamhaLogic.SubLine(subLine, if (id == R.id.tile_sub3) 2 else 1, if (id == R.id.tile_countdown) countWidth else 0f)
                },
                hideFromStart = element == "prayer", gap = TILE_GAP_DP,
            )
            // العنوان والقيمة صراحةً (لا اعتماداً على حالة شجرة سابقة).
            rv.setViewVisibility(R.id.tile_title, if (fit.title) View.VISIBLE else View.GONE)
            rv.setViewVisibility(R.id.tile_value, View.VISIBLE)
            rv.setTextViewText(R.id.tile_title, title)
            rv.setTextViewTextSize(R.id.tile_title, TypedValue.COMPLEX_UNIT_SP, titleFit)
            rv.setTextViewText(R.id.tile_value, value)
            rv.setTextViewTextSize(R.id.tile_value, TypedValue.COMPLEX_UNIT_SP, valueSp * fit.valueScale)
            rv.setInt(R.id.tile_value, "setMaxLines", fit.valueLines)
            // القيمة بلا هامش علوي إن خفي العنوان.
            if (!fit.title && Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) rv.setViewLayoutMargin(R.id.tile_value, RemoteViews.MARGIN_TOP, 0f, TypedValue.COMPLEX_UNIT_DIP)
            val kept = fit.subs.map { lines[it].first }
            for ((j, i) in fit.subs.withIndex()) {
                val id = lines[i].first
                rv.setTextViewTextSize(id, TypedValue.COMPLEX_UNIT_SP, subSp * fit.subScales[j])
            }
            sub(rv, R.id.tile_sub1, sub1.takeIf { R.id.tile_sub1 in kept })
            rv.setViewVisibility(R.id.tile_countdown, if (R.id.tile_countdown in kept) View.VISIBLE else View.GONE)
            sub(rv, R.id.tile_sub2, sub2.takeIf { R.id.tile_sub2 in kept })
            sub(rv, R.id.tile_sub3, sub3.takeIf { R.id.tile_sub3 in kept })
            if (R.id.tile_sub3 in kept && innerHeightDp > 0f) rv.setInt(R.id.tile_sub3, "setMaxLines", fit.lastSubLines)
            return rv
        }
    }
}
