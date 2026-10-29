package sa.lamha.lamha.widget

import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.content.res.Configuration
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.Path
import android.graphics.RectF
import android.graphics.Typeface
import android.net.Uri
import android.os.Build
import android.text.style.StyleSpan
import android.text.style.RelativeSizeSpan
import android.text.Spanned
import android.text.SpannableString
import android.os.Bundle
import android.os.SystemClock
import android.text.StaticLayout
import android.text.TextPaint
import android.util.Log
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
        // بعد تحديث التطبيق: شجرة الإصدار السابق بمعرّفات موارد قديمة قد تظهر فارغة، فتُعاد الودجت فوراً.
        if (intent.action == Intent.ACTION_MY_PACKAGE_REPLACED) {
            updateAll(context)
            return
        }
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

        /// أحجام الميزة ٦ (widget_preview_tiles.dart).
        private const val DAY_WEEKDAY_SP = 22f
        private const val DAY_CITY_SP = 16f
        private const val DAY_CITY_MIN_SP = 13f
        private const val DAY_TEMP_SP = 24f
        private const val CAPSULE_SP = 16f
        private const val COLUMN_TITLE_SP = 11f
        private const val COLUMN_NAME_SP = 20f
        private const val COLUMN_SUB_SP = 14f
        /// شبكة الإيداعات (gridNameSize وgridDaysSize في Dart).
        /// الإيداعات (depositSize وحشوات المستطيل في Dart، وwidget_tile_grid.xml).
        private const val DEPOSIT_SP = 16f
        private const val DEPOSIT_PAD_H_DP = 10f
        private const val DEPOSIT_PAD_V_DP = 4f
        private const val DEPOSIT_ROW_GAP_DP = 4f
        /// هامش لكل صف: على المحاكي زاد تقريب البكسل في السطر والحشوة ٢dp تقريباً على ثلاثة صفوف فقُص الأخير.
        private const val DEPOSIT_ROW_SLACK_DP = 1.5f
        /// بين الاسم وعمود الأيام (gridDaysGap في Dart، layout_marginStart في widget_tile_grid.xml).
        private const val GRID_DAYS_GAP_DP = 6f
        private const val GRID_DAYS_SLACK_DP = 2f
        private const val QIBLA_TITLE_SP = 14f

        /// السطر الصغير تحت الزاوية (qiblaSubSize في Dart).
        private const val QIBLA_SUB_SP = 9f

        /// دائرة مربع القبلة (lamha_qibla_update.md): الألوان، والأبعاد نسبةً لضلع المربع كـ qiblaDial*
        /// في widget_preview_tiles.dart. أقصى ضلع للصورة بالبكسل (ذاكرة RemoteViews).
        private const val QIBLA_STAR = 0xFF3A3A3A.toInt()
        private const val QIBLA_ARROW = 0xFFE53935.toInt()
        private const val QIBLA_DIAL_RADIUS = 0.49f
        private const val QIBLA_TICK_OUTER = 0.46f
        private const val QIBLA_TICK_INNER = 0.41f
        private const val QIBLA_TICK_LONG = 0.38f
        private const val QIBLA_LETTER_AT = 0.36f
        private const val QIBLA_LETTER_SIZE = 0.13f
        private const val QIBLA_KAABA_AT = 0.36f
        private const val QIBLA_KAABA_SIZE = 0.18f
        private const val QIBLA_ARROW_LENGTH = 0.24f
        private const val QIBLA_ARROW_HALF = 0.07f
        private const val QIBLA_STAR_LENGTH = 0.2f
        private const val QIBLA_DIAL_MAX_PX = 360
        private const val QIBLA_ICON_DEFAULT_DP = 56f
        private const val POINT_SP = 10f
        private const val COLUMN_GAP_DP = 4f
        private const val LINE_GAP_DP = 2f

        /// حشوة الصناديق الجديدة: ٩ أفقياً و٥ رأسياً (boxPadV في Dart).
        private const val BOX_PAD_H = 18f
        private const val BOX_PAD_V = 4f

        /// حشوة مربعات المعلومات الرأسية (٦ + ٦، tilePadV في Dart).
        private const val INFO_PAD_V = 8f

        /// ما لا يصغر في دائرة القبلة (الكعبة)، كـ heights في _QiblaTile.
        /// بين دائرة القبلة والزاوية تحتها (qiblaIconGap في Dart، layout_marginTop في widget_tile_qibla.xml).
        private const val QIBLA_ICON_GAP_DP = 2f
        private const val INFO_FIT_SLACK_DP = 1f

        /// أعمدة مربع الأعمدة ونقاط وصف الموسم في تخطيطيهما.
        private val COLUMN_IDS = listOf(
            Triple(R.id.col0, R.id.col_name0, R.id.col_sub0), Triple(R.id.col1, R.id.col_name1, R.id.col_sub1),
            Triple(R.id.col2, R.id.col_name2, R.id.col_sub2), Triple(R.id.col3, R.id.col_name3, R.id.col_sub3),
            Triple(R.id.col4, R.id.col_name4, R.id.col_sub4),
        )
        private val POINT_IDS = listOf(R.id.point0, R.id.point1, R.id.point2, R.id.point3)
        private val GRID_ROW_IDS = listOf(R.id.grid_row0, R.id.grid_row1, R.id.grid_row2)
        private val GRID_CELL_IDS = listOf(
            Triple(R.id.grid_cell0, R.id.grid_name0, R.id.grid_days0), Triple(R.id.grid_cell1, R.id.grid_name1, R.id.grid_days1),
            Triple(R.id.grid_cell2, R.id.grid_name2, R.id.grid_days2), Triple(R.id.grid_cell3, R.id.grid_name3, R.id.grid_days3),
            Triple(R.id.grid_cell4, R.id.grid_name4, R.id.grid_days4), Triple(R.id.grid_cell5, R.id.grid_name5, R.id.grid_days5),
        )

        /// نص قياس ارتفاع السطر (lineDp): عربي وأرقام، والساعة.
        private const val LINE_SAMPLE = "الفجر ٣٢٤° أبها"
        private const val CLOCK_SAMPLE = "١٢:٥٨"
        private const val TILE_GAP_DP = 2f
        private const val FIT_MARGIN_DP = 2f

        /// أدنى تصغير للعنوان والقيمة (tileMinFit)، ولسطور العمود الأيسر.
        private const val TILE_MIN_FIT = 0.7f
        private const val HEAD_MIN_FIT = 0.75f

        /// أعرض نص للساعة (بالأرقام العربية أو اللاتينية حسب لغة الجهاز)، لتثبيت حجمها طوال اليوم.
        private val WIDEST_CLOCK = listOf("١٢:٥٨", "12:58")

        /// ما لا يصغر مع الساعة: الفاصل ٤dp قبل «ص/م» (widget_tile_clock.xml)، وهامش ٣dp لتقريب البكسل في
        /// TextClock وLinearLayout. يُطرح من العرض المتاح؛ لو أُضيف إلى عرض النص لصغر معه فتُضغط «ص/م»
        /// حين تكون الساعة بخانتين (١٠–١٢) في المربع الضيق.
        private const val CLOCK_FIXED_DP = 4f + 3f

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

        /// الودجت، وعند أي خطأ في البناء رسالة فيها نوع الخطأ بدل ودجت فارغة (للتشخيص على الجهاز).
        private fun views(context: Context, prefs: SharedPreferences, options: Bundle?): RemoteViews =
            try {
                buildViews(
                    context,
                    prefs.getString(SCHEDULE_KEY, null),
                    options?.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH, 0) ?: 0,
                    options?.getInt(AppWidgetManager.OPTION_APPWIDGET_MAX_HEIGHT, 0) ?: 0,
                    System.currentTimeMillis(),
                    prefs.getString(NATIVE_WEATHER_KEY, null),
                )
            } catch (e: Exception) {
                Log.e("LamhaWidget", "buildViews", e)
                errorViews(context, e)
            }

        fun errorViews(context: Context, e: Throwable): RemoteViews =
            RemoteViews(context.packageName, R.layout.widget_setup).apply {
                val where = e.stackTrace.firstOrNull { it.className.startsWith("sa.lamha") }?.let { "${it.fileName}:${it.lineNumber}" } ?: ""
                setTextViewText(R.id.setup_text, arabic(context).getString(R.string.widget_error, "${e.javaClass.simpleName} $where ${e.message.orEmpty()}".take(160)))
                setOnClickPendingIntent(R.id.root, openAppIntent(context))
            }

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
            val weatherText = LamhaLogic.weatherText(weather, now, day.weatherMaxAgeMinutes, day.weatherIcons, day.latinDigits)
                ?: ctx.getString(R.string.weather_unknown)
            val placed = rows.flatten().flatMap { LamhaLogic.cellElements(it.id) }.toSet()
            val fresh = LamhaLogic.freshWeather(weather, now, day.weatherMaxAgeMinutes)
            val env = Env(context, ctx, day, accent, now, minWidth, sys, weatherText, placed, fresh)
            fun scaleOf(id: String) = day.fontScale * (byId[id]?.fontScale ?: 1f)
            // الخانة المكدسة (التاريخان وتحتهما المدينة): مجموع ارتفاعيهما، وحشوة الخانة مرة.
            val parts = rows.map { r ->
                r.map { cell ->
                    LamhaLogic.cellElements(cell.id).map { heightsDp(env, LamhaLogic.Cell(it, cell.span), 1f, byId[it] ?: LamhaLogic.Tile(it)) }
                }
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
                    if (ids.all { it in CAPSULES }) {
                        // كبسولتا التاريخين (أو واحدة) تقتسمان الخانة بالوزن (widget_tile_capsule).
                        val stack = RemoteViews(context.packageName, R.layout.widget_tile_stack)
                        for (id in ids) {
                            val spec = byId[id] ?: LamhaLogic.Tile(id)
                            stack.addView(R.id.stack, tile(env, spec, cell.span, scaleOf(id), if (inner > 0f) inner / ids.size - 4f else 0f))
                        }
                        slot.addView(R.id.slot, stack)
                    } else if (ids.size == 1) {
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
        private val LINE_TILES = setOf("clock", "dates", "weather", "dayWeather", LamhaLogic.DATES_WEATHER)

        /// كبسولتا التاريخين (الميزة ٦).
        private val CAPSULES = setOf("hijri", "gregorian")

        /// ما يحتاجه كل مربع: السياقان (الأصلي وبالعربية)، واليوم، والتمييز، والعرض، وخط النظام.
        private class Env(
            val context: Context, val ctx: Context, val day: LamhaDay, val accent: Int, val now: Long,
            val widthDp: Int, val sys: Float, val weatherText: String,
            /// العناصر الظاهرة فعلاً، وقراءة الطقس الحديثة (أو null).
            val placed: Set<String>, val weather: LamhaLogic.Weather?,
        )

        /// ارتفاعا المربع (dp) بمعامله [scale] كـ heights في المعاينة: النص الذي يصغر مع معامل الملاءمة،
        /// وما لا يصغر (حشوة الخانة ٤+٤، ولمربعات المعلومات حشوتها ٨+٨ والفواصل ٣، والساعة إن صغّرها
        /// عرض مربعها).
        /// العنوان والسطر الفرعي المطفآن في [spec] لا يأخذان مكاناً (الميزة ٦: الساعة بلا يوم، والفصل
        /// والموسم بلا عناوين في الافتراضي).
        private fun heightsDp(env: Env, cell: LamhaLogic.Cell, scale: Float, spec: LamhaLogic.Tile): Pair<Float, Float> {
            val showTitle = spec.showTitle
            val showSub = spec.showSub
            return when (cell.id) {
                "clock" -> {
                    val (preferred, fitted) = clockSp(env, scale, LamhaLogic.slotInnerDp(env.widthDp, cell.span) - FIT_MARGIN_DP)
                    val weekday = if (showSub) lineDp(env.ctx, WEEKDAY_SP * scale, true, false) else 0f
                    val clock = lineDp(env.ctx, fitted, true, false, CLOCK_SAMPLE, fallback = false)
                    if (fitted < preferred) weekday to clock + 4f else clock + weekday to 4f
                }
                "dates" -> lineDp(env.ctx, HIJRI_SP * scale, true) + (if (showSub) lineDp(env.ctx, GREGORIAN_SP * scale, false) else 0f) to 10f
                "weather" -> lineDp(env.ctx, CITY_WEATHER_SP * scale, false) to 8f
                // الميزة ٦: المقاس بالأسطر الأساسية (كـ heights في widget_preview_tiles.dart)، والباقي إن اتسع.
                "dayWeather" -> tightDp(env.ctx, DAY_WEEKDAY_SP * scale, true) +
                    (if (showSub) tightDp(env.ctx, DAY_CITY_MIN_SP * scale, false) + tightDp(env.ctx, DAY_TEMP_SP * scale, true) else 0f) to 8f
                "hijri", "gregorian" -> tightDp(env.ctx, CAPSULE_SP * scale, true) to 8f + 6f
                // الأيقونة بأكبر ما تسمح به الخانة (طلب المالك).
                "qibla" -> (if (showTitle) lineDp(env.ctx, QIBLA_TITLE_SP * scale, true) + lineDp(env.ctx, QIBLA_SUB_SP * scale, false) else 0f) to
                    8f + LamhaLogic.qiblaIconTarget(LamhaLogic.slotInnerDp(env.widthDp, cell.span))
                // كل إيداع في مستطيل: الصفوف وحشواتها، بلا صندوق خارجي.
                "deposit" -> {
                    val rows = LamhaLogic.gridRows(depositCount(env, cell.span))
                    rows * tightDp(env.ctx, DEPOSIT_SP * scale, false) to
                        8f + rows * DEPOSIT_PAD_V_DP * 2 + DEPOSIT_ROW_GAP_DP * (rows - 1)
                }
                "prayerTimes" ->
                    tightDp(env.ctx, COLUMN_NAME_SP * scale, true) + (if (showSub) tightDp(env.ctx, COLUMN_SUB_SP * scale, false) + LINE_GAP_DP else 0f) to
                        8f + BOX_PAD_V
                // نقطتان بسطرين لكل منهما؛ العنوان إن اتسع.
                "tradPoints" ->
                    4 * tightDp(env.ctx, POINT_SP * scale, false) to 8f + BOX_PAD_V + LINE_GAP_DP
                // الثانوي الوحيد ذو السطرين (الفصل والموسم: «الشتاء بعد» ثم «٦٣ يوماً») يُحسب بسطريه.
                else -> (if (showTitle) tightDp(env.ctx, TILE_TITLE_SP * scale, true) else 0f) + tightDp(env.ctx, TILE_VALUE_SP * scale, true) +
                    (if (showSub) maxOf(subCount(env, cell.id), if (cell.id == "prayer") 0 else 2) else 0) * tightDp(env.ctx, TILE_SUB_SP * scale, false) to
                    8f + INFO_PAD_V + TILE_GAP_DP * ((if (showSub) subCount(env, cell.id) else 0) + 1)
            }
        }

        /// حجم الساعة (المطلوب، والفعلي): ٥٢ (أو ٤٢ للضيقة) × [scale]، وتصغر مع «ص/م» (كلمة واحدة) بأدنى
        /// تصغير ليتسع أعرض نص لها في [avail]. بلا عرض معروف: المطلوب.
        private fun clockSp(env: Env, scale: Float, avail: Float): Pair<Float, Float> {
            val preferred = LamhaLogic.clockSizeSp(env.widthDp) * scale
            val w = clockWidthDp(env, scale)
            val room = avail - CLOCK_FIXED_DP
            return preferred to if (avail > 0f && w > room) preferred * maxOf(room, 0f) / w else preferred
        }

        /// عرض أعرض نص للساعة و«ص/م» بجانبها، بالحجم المطلوب (بلا CLOCK_FIXED_DP).
        private fun clockWidthDp(env: Env, scale: Float): Float {
            val preferred = LamhaLogic.clockSizeSp(env.widthDp) * scale
            val amPm = env.ctx.getString(if (LamhaLogic.isAm(env.now, env.day.timeZone)) R.string.am else R.string.pm)
            return WIDEST_CLOCK.maxOf { textWidthDp(env.ctx, it, preferred, true) } +
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
        /// سطر في مربعات الميزة ٦ (includeFontPadding وfallbackLineSpacing مطفأان في تخطيطاتها).
        private fun tightDp(context: Context, sp: Float, bold: Boolean): Float = lineDp(context, sp, bold, false, fallback = false)

        private fun lineDp(
            context: Context, sp: Float, bold: Boolean, includePad: Boolean = true, sample: String = LINE_SAMPLE,
            fallback: Boolean = true,
        ): Float {
            val metrics = context.resources.displayMetrics
            val paint = TextPaint(Paint.ANTI_ALIAS_FLAG)
            paint.typeface = if (bold) Typeface.DEFAULT_BOLD else Typeface.DEFAULT
            paint.textSize = TypedValue.applyDimension(TypedValue.COMPLEX_UNIT_SP, sp, metrics)
            val b = StaticLayout.Builder.obtain(sample, 0, sample.length, paint, 100_000).setIncludePad(includePad)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) b.setUseLineSpacingFromFallbacks(fallback)
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
            "season" -> 1
            else -> if (day.tradDescription.isEmpty()) 0 else 1
        }

        /// كـ [subCount] مع مربع «وصف الموسم»: الموسم بلا وصف إن ظهر (الموسم القادم في سطر الاسم).
        private fun subCount(env: Env, element: String): Int =
            if (element == "tradSeason" && "tradPoints" in env.placed) 0 else subCount(env.day, element)

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
                    // CLOCK_FIXED_DP لا يصغر: يُكبَّر عرض النص بنسبة avail/(avail − الثابت) فيكون التصغير
                    // (avail − الثابت)/النص كما في clockSp، ويبقى عرض اليوم avail كاملاً.
                    val textW = clockWidthDp(env, scale)
                    val room = avail - CLOCK_FIXED_DP
                    val clockW = if (avail > 0f) textW * avail / maxOf(room, 1f) else textW
                    val fit = LamhaLogic.fitTile(
                        innerHeightDp, avail, 0f,
                        lineDp(ctx, preferred, true, false, CLOCK_SAMPLE, fallback = false), listOf(clockW),
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
                "dayWeather" -> dayWeatherTile(env, tile, scale, avail, innerHeightDp)
                "hijri", "gregorian" -> capsuleTile(env, tile, scale, if (inner > 0f) inner - 24f - FIT_MARGIN_DP else 0f, innerHeightDp - 2f)
                "qibla" -> qiblaTile(env, tile, scale, inner, innerHeightDp)
                "deposit" -> depositsTile(env, tile, span, scale, inner, innerHeightDp)
                "prayerTimes" -> columnsTile(env, tile, scale, if (inner > 0f) inner - BOX_PAD_H else 0f, innerHeightDp - BOX_PAD_V)
                "tradPoints" -> pointsTile(env, tile, scale, if (inner > 0f) inner - BOX_PAD_H - FIT_MARGIN_DP else 0f, innerHeightDp - BOX_PAD_V)
                else -> infoTile(env, tile, scale, if (inner > 0f) inner - 18f - FIT_MARGIN_DP else 0f, innerHeightDp - INFO_PAD_V).apply {
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
                    "season" -> R.string.tile_season
                    else -> R.string.tile_trad_season
                },
            )
            var value = ""
            // نص أصغر بعد القيمة في سطرها (مربع الموسم).
            var valueNote: String? = null
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
                "season" -> {
                    value = day.seasonName
                    sub3 = ctx.getString(R.string.next_after, day.seasonNext, day.seasonAfter)
                }
                else -> {
                    // تنسيق المالك: الاسم ثم «(الموسم القادم بعد … يوماً)» أصغر في سطره، وتحته الوصف
                    // (يبدأ باسم الموسم، descriptionLine في الجدول) إن لم يظهر مربع «وصف الموسم».
                    value = day.tradName
                    // مسافات غير قابلة للكسر: الملاحظة كتلة واحدة (في سطر الاسم أو تحته كاملة).
                    val note = ("(" + ctx.getString(R.string.next_after, day.tradNext, day.tradAfter) + ")").replace(' ', '\u00A0')
                    // في سطر الاسم إن اتسع بلا تصغير، وإلا أول سطر تحته (كالمعاينة).
                    if (availDp > 0f && textWidthDp(ctx, "$value ", valueSp, true) + textWidthDp(ctx, note, subSp, false) > availDp) {
                        sub1 = note
                    } else {
                        valueNote = note
                    }
                    if ("tradPoints" !in env.placed && day.tradDescription.isNotEmpty()) sub3 = day.tradDescription
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
            val subLine = tightDp(ctx, subSp, false)
            val (valueWords, space) = wordsDp(ctx, value, valueSp, true)
            val words = if (valueNote == null) valueWords else valueWords + wordsDp(ctx, valueNote, subSp, false).first
            // هامش ١dp: تقريب البكسل في أسطر TextView قد يزيد ١–٢px على القياس فيُقص آخر سطر حين يتسع
            // المحتوى بالضبط (الفصل والموسم في ٤×٤ مع ستة إيداعات).
            val fit = LamhaLogic.fitTile(
                if (innerHeightDp > 0f) maxOf(1f, innerHeightDp - INFO_FIT_SLACK_DP) else 0f, availDp,
                if (spec.showTitle && titleFits) tightDp(ctx, titleFit, true) else 0f,
                tightDp(ctx, valueSp, true), words, space,
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
            rv.setTextViewText(R.id.tile_value, if (valueNote == null) value else SpannableString("$value $valueNote").apply {
                // الملاحظة بحجم الثانوي ووزن عادي (تُصغَّر مع القيمة بنفس النسبة).
                setSpan(RelativeSizeSpan(subSp / valueSp), value.length, length, Spanned.SPAN_EXCLUSIVE_EXCLUSIVE)
                setSpan(StyleSpan(Typeface.NORMAL), value.length, length, Spanned.SPAN_EXCLUSIVE_EXCLUSIVE)
            })
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

        /// اليوم والطقس (الميزة ٦، _DayWeatherTile): اليوم، ثم «📍 المدينة ☀️» باللون الفرعي (يصغر حتى ١٣ ثم
        /// «…»، ولا يُخفى)، ثم الحرارة بحجم اليوم تقريباً. إن ضاق الارتفاع تُخفى الحرارة (fitTile).
        private fun dayWeatherTile(env: Env, spec: LamhaLogic.Tile, scale: Float, avail: Float, innerHeightDp: Float): RemoteViews {
            val ctx = env.ctx
            val day = env.day
            val rv = RemoteViews(env.context.packageName, R.layout.widget_tile_dayweather)
            val weekdaySp = DAY_WEEKDAY_SP * scale
            val tempSp = DAY_TEMP_SP * scale
            val w = env.weather
            val city = ctx.getString(R.string.city_icon, day.cityName, if (w == null) "" else LamhaLogic.weatherIcon(w, day.weatherIcons)).trim()
            val temp = if (w == null) ctx.getString(R.string.weather_unknown) else LamhaLogic.temperatureText(w.temp, day.latinDigits)
            val cityPreferred = DAY_CITY_SP * scale
            val cityWidth = textWidthDp(ctx, city, cityPreferred, false)
            var citySp = cityPreferred * if (avail > 0f && cityWidth > avail) maxOf(DAY_CITY_MIN_SP / DAY_CITY_SP, avail / cityWidth) else 1f
            // وإن لم تتسع الأسطر الثلاثة رأسياً تصغر المدينة إلى ١٣ قبل إخفاء الحرارة.
            if (innerHeightDp > 0f && tightDp(ctx, weekdaySp, true) + tightDp(ctx, citySp, false) + tightDp(ctx, tempSp, true) > innerHeightDp) {
                citySp = minOf(citySp, DAY_CITY_MIN_SP * scale)
            }
            val (words, space) = wordsDp(ctx, day.weekday, weekdaySp, true)
            val fit = LamhaLogic.fitTile(
                innerHeightDp, avail, 0f, tightDp(ctx, weekdaySp, true), words, space,
                subs = if (spec.showSub) {
                    listOf(
                        LamhaLogic.SubLine(tightDp(ctx, citySp, false), 1, 0f),
                        LamhaLogic.SubLine(tightDp(ctx, tempSp, true), 1, textWidthDp(ctx, temp, tempSp, true)),
                    )
                } else emptyList(),
                minSubFit = HEAD_MIN_FIT,
            )
            rv.setTextViewText(R.id.day_weekday, day.weekday)
            rv.setTextViewTextSize(R.id.day_weekday, TypedValue.COMPLEX_UNIT_SP, weekdaySp * fit.valueScale)
            rv.setInt(R.id.day_weekday, "setMaxLines", fit.valueLines)
            for ((i, line) in listOf(Triple(R.id.day_city, city, citySp), Triple(R.id.day_temp, temp, tempSp)).withIndex()) {
                val j = fit.subs.indexOf(i)
                if (j < 0) {
                    rv.setViewVisibility(line.first, View.GONE)
                } else {
                    rv.setTextViewText(line.first, line.second)
                    rv.setTextViewTextSize(line.first, TypedValue.COMPLEX_UNIT_SP, line.third * fit.subScales[j])
                }
            }
            spec.primaryColor?.let { rv.setTextColor(R.id.day_weekday, it) }
            spec.secondaryColor?.let {
                rv.setTextColor(R.id.day_city, it)
                rv.setTextColor(R.id.day_temp, it)
            }
            return rv
        }

        /// تاريخ في كبسولة (الميزة ٦، _CapsuleTile): يلتفّ عند المسافات ولا يصغر إلا لضيق (fitTile).
        private fun capsuleTile(env: Env, spec: LamhaLogic.Tile, scale: Float, avail: Float, innerHeightDp: Float): RemoteViews {
            val ctx = env.ctx
            val rv = RemoteViews(env.context.packageName, R.layout.widget_tile_capsule)
            val text = if (spec.id == "hijri") {
                ctx.getString(R.string.hijri_date, env.day.hijriText)
            } else {
                ctx.getString(R.string.gregorian_date, env.day.gregorianText)
            }
            val sp = CAPSULE_SP * scale
            val (words, space) = wordsDp(ctx, text, sp, true)
            val fit = LamhaLogic.fitTile(innerHeightDp, avail, 0f, tightDp(ctx, sp, true), words, space)
            rv.setTextViewText(R.id.capsule_text, text)
            rv.setTextViewTextSize(R.id.capsule_text, TypedValue.COMPLEX_UNIT_SP, sp * fit.valueScale)
            rv.setInt(R.id.capsule_text, "setMaxLines", fit.valueLines)
            spec.primaryColor?.let { rv.setTextColor(R.id.capsule_text, it) }
            return rv
        }

        /// القبلة (lamha_qibla_update.md، _QiblaTile): خلفية أيقونة القبلة وفوقها دائرة الاتجاه الثابت (صورة
        /// يرسمها drawQiblaDial)، وتحتها الزاوية بخط كبير ثم «من الشمال · الاتجاه». الضغط يفتح البوصلة.
        /// مقاس المربع يُضبط في أندرويد ١٢+ (وإلا ٥٦dp).
        private fun qiblaTile(env: Env, spec: LamhaLogic.Tile, scale: Float, inner: Float, innerHeightDp: Float): RemoteViews {
            val ctx = env.ctx
            val rv = RemoteViews(env.context.packageName, R.layout.widget_tile_qibla)
            rv.setOnClickPendingIntent(
                R.id.tile_box,
                HomeWidgetLaunchIntent.getActivity(env.context, MainActivity::class.java, Uri.parse(QIBLA_URI)),
            )
            rv.setContentDescription(R.id.tile_box, ctx.getString(R.string.tile_qibla))
            // الدائرة أكبر مربع يتسع مع السطرين تحتها، والسطران يصغران ليتسعا عرض المربع (_QiblaTile).
            fun fit(text: String, preferred: Float, bold: Boolean) = if (inner > 0f) {
                LamhaLogic.fitTextSize(preferred, textWidthDp(ctx, text, preferred, bold), inner - FIT_MARGIN_DP, preferred * 0.6f)
            } else preferred
            val angle = env.day.qiblaDegrees
            val sub = ctx.getString(R.string.qibla_tile_sub, env.day.qiblaDirection)
            val angleSp = fit(angle, QIBLA_TITLE_SP * scale, true)
            val subSp = fit(sub, QIBLA_SUB_SP * scale, false)
            val textLines = if (spec.showTitle) {
                tightDp(ctx, angleSp, true) + tightDp(ctx, subSp, false) + QIBLA_ICON_GAP_DP
            } else 0f
            if (spec.showTitle) {
                rv.setTextViewText(R.id.qibla_title, angle)
                rv.setTextViewTextSize(R.id.qibla_title, TypedValue.COMPLEX_UNIT_SP, angleSp)
                spec.primaryColor?.let { rv.setTextColor(R.id.qibla_title, it) }
                rv.setTextViewText(R.id.qibla_sub, sub)
                rv.setTextViewTextSize(R.id.qibla_sub, TypedValue.COMPLEX_UNIT_SP, subSp)
                spec.secondaryColor?.let { rv.setTextColor(R.id.qibla_sub, it) }
            } else {
                rv.setViewVisibility(R.id.qibla_title, View.GONE)
                rv.setViewVisibility(R.id.qibla_sub, View.GONE)
            }
            // البوصلة السوداء ترسم خلفيتها بنفسها (صورة المالك)، فلا شكل خلفها.
            rv.setViewVisibility(R.id.qibla_shape, View.GONE)
            val icon = listOf(inner, if (innerHeightDp > 0f) innerHeightDp - textLines else 0f).filter { it > 0f }.minOrNull() ?: 0f
            val resizable = icon > 0f && Build.VERSION.SDK_INT >= Build.VERSION_CODES.S
            if (resizable) {
                rv.setViewLayoutWidth(R.id.qibla_icon, icon, TypedValue.COMPLEX_UNIT_DIP)
                rv.setViewLayoutHeight(R.id.qibla_icon, icon, TypedValue.COMPLEX_UNIT_DIP)
            }
            val px = ((if (resizable) icon else QIBLA_ICON_DEFAULT_DP) * ctx.resources.displayMetrics.density)
                .toInt().coerceIn(48, QIBLA_DIAL_MAX_PX)
            rv.setImageViewBitmap(R.id.qibla_dial, drawQiblaDial(ctx, px, env.day.qiblaAngle))
            return rv
        }

        /// قرص مربع القبلة بضلع [px] (صورة المالك، QiblaTileDialPainter في Dart): دائرة سوداء، وتدريج أبيض
        /// كل ١٠° (أطول كل ٣٠°)، وحروف N وE وS وW، ونجمة داكنة، وسهم أحمر من المركز بزاوية [degrees] من
        /// الشمال ثم خط منقّط إلى الكعبة على المحيط. رسم فقط، لا حساب.
        internal fun drawQiblaDial(context: Context, px: Int, degrees: Float): Bitmap {
            val bmp = Bitmap.createBitmap(px, px, Bitmap.Config.ARGB_8888)
            val canvas = Canvas(bmp)
            val side = px.toFloat()
            val c = side / 2
            canvas.drawCircle(c, c, side * QIBLA_DIAL_RADIUS, Paint(Paint.ANTI_ALIAS_FLAG).apply { color = Color.BLACK })
            val tick = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = Color.WHITE; strokeCap = Paint.Cap.ROUND }
            for (d in 0 until 360 step 10) {
                if (d % 90 == 0) continue
                val a = Math.toRadians(d.toDouble())
                val sx = Math.sin(a).toFloat()
                val cy = -Math.cos(a).toFloat()
                val long = d % 30 == 0
                tick.strokeWidth = side * if (long) 0.022f else 0.014f
                val inner = side * if (long) QIBLA_TICK_LONG else QIBLA_TICK_INNER
                canvas.drawLine(c + sx * inner, c + cy * inner, c + sx * side * QIBLA_TICK_OUTER, c + cy * side * QIBLA_TICK_OUTER, tick)
            }
            val letters = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                color = Color.WHITE
                textSize = side * QIBLA_LETTER_SIZE
                typeface = Typeface.DEFAULT_BOLD
                textAlign = Paint.Align.CENTER
            }
            for ((d, label) in listOf(0 to "N", 90 to "E", 180 to "S", 270 to "W")) {
                val a = Math.toRadians(d.toDouble())
                val x = c + Math.sin(a).toFloat() * side * QIBLA_LETTER_AT
                val y = c - Math.cos(a).toFloat() * side * QIBLA_LETTER_AT
                canvas.drawText(label, x, y - (letters.ascent() + letters.descent()) / 2, letters)
            }
            val star = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = QIBLA_STAR }
            for (i in 0 until 8) {
                val a = i * Math.PI / 4
                val len = side * QIBLA_STAR_LENGTH * if (i % 2 == 0) 1f else 0.6f
                val w = side * 0.035f
                val tx = c + Math.sin(a).toFloat() * len
                val ty = c - Math.cos(a).toFloat() * len
                val nx = Math.cos(a).toFloat() * w
                val ny = Math.sin(a).toFloat() * w
                canvas.drawPath(Path().apply { moveTo(c + nx, c + ny); lineTo(tx, ty); lineTo(c - nx, c - ny); close() }, star)
            }
            canvas.save()
            canvas.rotate(degrees, c, c)
            val red = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = QIBLA_ARROW }
            canvas.drawPath(Path().apply {
                moveTo(c, c - side * QIBLA_ARROW_LENGTH)
                lineTo(c + side * QIBLA_ARROW_HALF, c + side * 0.03f)
                lineTo(c, c - side * 0.02f)
                lineTo(c - side * QIBLA_ARROW_HALF, c + side * 0.03f)
                close()
            }, red)
            red.strokeWidth = side * 0.018f
            red.strokeCap = Paint.Cap.ROUND
            var t = QIBLA_ARROW_LENGTH + 0.02f
            while (t < QIBLA_KAABA_AT - QIBLA_KAABA_SIZE / 2.6f) {
                canvas.drawLine(c, c - side * t, c, c - side * (t + 0.012f), red)
                t += 0.035f
            }
            canvas.restore()
            // الكعبة على المحيط بزاوية القبلة (qiblaKaabaCenter في Dart).
            val a = Math.toRadians(degrees.toDouble())
            val kx = c + Math.sin(a).toFloat() * side * QIBLA_KAABA_AT
            val ky = c - Math.cos(a).toFloat() * side * QIBLA_KAABA_AT
            val k = side * QIBLA_KAABA_SIZE / 2
            BitmapFactory.decodeResource(context.resources, R.drawable.kaaba)?.let { kaaba ->
                canvas.drawBitmap(kaaba, null, RectF(kx - k, ky - k, kx + k, ky + k), Paint(Paint.FILTER_BITMAP_FLAG))
                kaaba.recycle()
            }
            return bmp
        }

        /// مربع أعمدة (الميزة ٦، _ColumnsTile): مواقيت الصلاة (خمسة أعمدة تدور فتبدأ بالقادمة المميَّزة
        /// بلون التمييز، rotatePrayers) أو الإيداعات (حتى ثلاثة بلا عنوان، عمود لكل وحدة عرض).
        /// الأعمدة تصغر بالتساوي ولا يُخفى عمود (fitColumns).
        private fun columnsTile(env: Env, spec: LamhaLogic.Tile, scale: Float, availDp: Float, innerHeightDp: Float): RemoteViews {
            val ctx = env.ctx
            val day = env.day
            val rv = RemoteViews(env.context.packageName, R.layout.widget_tile_columns)
            val items = LamhaLogic.rotatePrayers(day.prayersToday, day.prayersTomorrow, env.now).map { it.name to it.text }
            rv.setImageViewResource(R.id.tile_bg, R.drawable.tile_bg_light)
            val nameSp = COLUMN_NAME_SP * scale
            val subSp = COLUMN_SUB_SP * scale
            val n = maxOf(1, items.size)
            val colWidth = if (availDp > 0f) (availDp - COLUMN_GAP_DP * (n - 1)) / n - FIT_MARGIN_DP else 0f
            val fit = LamhaLogic.fitColumns(
                innerHeightDp, colWidth,
                0f, // بلا عنوان: المواقيت دائماً، والإيداعات بطلب المالك (حُذف «متبقي على:»).
                tightDp(ctx, nameSp, true), items.maxOfOrNull { textWidthDp(ctx, it.first, nameSp, true) } ?: 0f,
                if (spec.showSub) tightDp(ctx, subSp, false) else 0f,
                items.maxOfOrNull { textWidthDp(ctx, it.second, subSp, false) } ?: 0f,
                LINE_GAP_DP,
            )
            rv.setViewVisibility(R.id.columns_title, View.GONE)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) rv.setViewLayoutMargin(R.id.columns, RemoteViews.MARGIN_TOP, 0f, TypedValue.COMPLEX_UNIT_DIP)
            for ((i, ids) in COLUMN_IDS.withIndex()) {
                val (col, name, sub) = ids
                val item = items.getOrNull(i)
                if (item == null) {
                    rv.setViewVisibility(col, View.GONE)
                    continue
                }
                rv.setTextViewText(name, item.first)
                rv.setTextViewTextSize(name, TypedValue.COMPLEX_UNIT_SP, nameSp * fit.nameScale)
                if (fit.sub) {
                    rv.setTextViewText(sub, item.second)
                    rv.setTextViewTextSize(sub, TypedValue.COMPLEX_UNIT_SP, subSp * fit.subScale)
                } else {
                    rv.setViewVisibility(sub, View.GONE)
                }
                // الصلاة القادمة (أول عمود) بلون التمييز.
                val highlight = i == 0
                (if (highlight) env.accent else spec.primaryColor)?.let { rv.setTextColor(name, it) }
                (if (highlight) env.accent else spec.secondaryColor)?.let { rv.setTextColor(sub, it) }
            }
            return rv
        }

        /// الإيداعات الظاهرة في مربع بعرض [span] (maxDeposits).
        private fun depositCount(env: Env, span: Int) = minOf(env.day.deposits.size, LamhaLogic.maxDeposits(span))

        /// الإيداعات (_DepositsTile، طلب المالك): كل إيداع في مستطيل، الاسم وبجانبه الأيام بحجم واحد في
        /// عمود بعرض أعرضها (كجدول)، الأقرب أولاً من اليمين. عمود حتى ثلاثة وعمودان بعدها. الخانات تصغر
        /// بالتساوي، وإن ضاق الارتفاع تصغر الصفوف (fitGrid).
        private fun depositsTile(env: Env, spec: LamhaLogic.Tile, span: Int, scale: Float, inner: Float, innerHeightDp: Float): RemoteViews {
            val ctx = env.ctx
            val rv = RemoteViews(env.context.packageName, R.layout.widget_tile_grid)
            val items = env.day.deposits.take(depositCount(env, span)).map { it.label to it.days }
            val cols = LamhaLogic.depositColumns(items.size)
            val rows = LamhaLogic.gridRows(items.size)
            val sp = DEPOSIT_SP * scale
            val cellWidth = if (inner > 0f) (inner - COLUMN_GAP_DP * (cols - 1)) / cols - DEPOSIT_PAD_H_DP * 2 - FIT_MARGIN_DP else 0f
            val nameW = items.maxOfOrNull { textWidthDp(ctx, it.first, sp, false) } ?: 0f
            val daysW = if (spec.showSub) items.maxOfOrNull { textWidthDp(ctx, it.second, sp, false) } ?: 0f else 0f
            // الفاصل وهامش عمود الأيام وحشوات المستطيلات لا تصغر مع النص، فتُطرح.
            val fixed = if (spec.showSub) GRID_DAYS_GAP_DP + GRID_DAYS_SLACK_DP else 0f
            val fit = LamhaLogic.fitGrid(
                if (innerHeightDp > 0f) innerHeightDp - rows * (DEPOSIT_PAD_V_DP * 2 + DEPOSIT_ROW_SLACK_DP) else 0f,
                if (cellWidth > 0f) maxOf(1f, cellWidth - fixed) else 0f, 0f,
                tightDp(ctx, sp, false), nameW + daysW, rows, DEPOSIT_ROW_GAP_DP,
            )
            // عمود الأيام بعرض أعرضها بعد التصغير (+ هامش للتقريب). قبل أندرويد ١٢ لا يُضبط العرض فيبقى بعرض نصه.
            val daysColumn = daysW * fit.scale + GRID_DAYS_SLACK_DP
            for ((r, row) in GRID_ROW_IDS.withIndex()) {
                if (r >= rows) rv.setViewVisibility(row, View.GONE)
            }
            for ((k, ids) in GRID_CELL_IDS.withIndex()) {
                val (cell, name, days) = ids
                val r = k / 2
                val c = k % 2
                // الخلية رقم c في الصف r هي الإيداع r × الأعمدة + c؛ والعمود الثاني يُخفى في العمود الواحد.
                val item = if (c < cols) items.getOrNull(r * cols + c) else null
                if (item == null) {
                    // الخانة الأخيرة في صف ناقص تبقى بعرضها فلا تتمدد جارتها.
                    rv.setViewVisibility(cell, if (r < rows && c < cols) View.INVISIBLE else View.GONE)
                    continue
                }
                rv.setTextViewText(name, item.first)
                rv.setTextViewTextSize(name, TypedValue.COMPLEX_UNIT_SP, sp * fit.scale)
                spec.primaryColor?.let { rv.setTextColor(name, it) }
                if (spec.showSub) {
                    rv.setTextViewText(days, item.second)
                    rv.setTextViewTextSize(days, TypedValue.COMPLEX_UNIT_SP, sp * fit.scale)
                    spec.secondaryColor?.let { rv.setTextColor(days, it) }
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) rv.setViewLayoutWidth(days, daysColumn, TypedValue.COMPLEX_UNIT_DIP)
                } else {
                    rv.setViewVisibility(days, View.GONE)
                }
            }
            return rv
        }

        /// وصف الموسم (الميزة ٦، _PointsTile): «في الوسم:» ثم النقاط، لكل نقطة سطران حداً (ثم «…»). إن ضاق
        /// الارتفاع يُخفى العنوان أولاً، ثم النقاط من الآخر (fitPoints).
        private fun pointsTile(env: Env, spec: LamhaLogic.Tile, scale: Float, availDp: Float, innerHeightDp: Float): RemoteViews {
            val ctx = env.ctx
            val rv = RemoteViews(env.context.packageName, R.layout.widget_tile_points)
            val title = ctx.getString(R.string.trad_points_title, env.day.tradName)
            val all = env.day.tradPoints.take(POINT_IDS.size).map { ctx.getString(R.string.point_text, it) }
            val points = if (spec.showSub) all else all.take(1)
            val titleSp = COLUMN_TITLE_SP * scale
            val sp = POINT_SP * scale
            val line = tightDp(ctx, sp, false)
            val lines = points.map { p ->
                val (w, space) = wordsDp(ctx, p, sp, false)
                if (availDp > 0f) LamhaLogic.wrapLines(w, space, availDp) else 1
            }
            val titleFits = spec.showTitle && (availDp <= 0f || textWidthDp(ctx, title, titleSp) <= availDp)
            val fit = LamhaLogic.fitPoints(innerHeightDp, if (titleFits) tightDp(ctx, titleSp, true) else 0f, line, lines, LINE_GAP_DP)
            rv.setViewVisibility(R.id.points_title, if (fit.first) View.VISIBLE else View.GONE)
            rv.setTextViewText(R.id.points_title, title)
            rv.setTextViewTextSize(R.id.points_title, TypedValue.COMPLEX_UNIT_SP, titleSp)
            for ((i, id) in POINT_IDS.withIndex()) {
                val max = fit.second.getOrNull(i)
                if (max == null || i >= points.size) {
                    rv.setViewVisibility(id, View.GONE)
                    continue
                }
                rv.setTextViewText(id, points[i])
                rv.setTextViewTextSize(id, TypedValue.COMPLEX_UNIT_SP, sp)
                rv.setInt(id, "setMaxLines", max)
                spec.primaryColor?.let { rv.setTextColor(id, it) }
            }
            if (!fit.first && Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) rv.setViewLayoutMargin(R.id.point0, RemoteViews.MARGIN_TOP, 0f, TypedValue.COMPLEX_UNIT_DIP)
            spec.secondaryColor?.let { rv.setTextColor(R.id.points_title, it) }
            return rv
        }
    }
}
