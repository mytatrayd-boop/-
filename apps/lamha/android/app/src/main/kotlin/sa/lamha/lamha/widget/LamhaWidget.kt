package sa.lamha.lamha.widget

import android.content.Context
import android.content.res.Configuration
import android.graphics.Paint
import android.graphics.Typeface
import android.net.Uri
import android.os.SystemClock
import android.util.TypedValue
import android.widget.RemoteViews
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.glance.GlanceId
import androidx.glance.GlanceModifier
import androidx.glance.LocalContext
import androidx.glance.LocalSize
import androidx.glance.action.clickable
import androidx.glance.appwidget.AndroidRemoteViews
import androidx.glance.appwidget.GlanceAppWidget
import androidx.glance.appwidget.SizeMode
import androidx.glance.appwidget.appWidgetBackground
import androidx.glance.appwidget.cornerRadius
import androidx.glance.appwidget.provideContent
import androidx.glance.background
import androidx.glance.currentState
import androidx.glance.layout.Alignment
import androidx.glance.layout.Box
import androidx.glance.layout.Column
import androidx.glance.layout.Row
import androidx.glance.layout.Spacer
import androidx.glance.layout.fillMaxHeight
import androidx.glance.layout.fillMaxSize
import androidx.glance.layout.fillMaxWidth
import androidx.glance.layout.height
import androidx.glance.layout.padding
import androidx.glance.layout.width
import androidx.glance.state.GlanceStateDefinition
import androidx.glance.text.FontWeight
import androidx.glance.text.Text
import androidx.glance.text.TextAlign
import androidx.glance.text.TextStyle
import androidx.glance.unit.ColorProvider
import es.antonborri.home_widget.HomeWidgetGlanceState
import es.antonborri.home_widget.HomeWidgetGlanceStateDefinition
import es.antonborri.home_widget.actionStartActivity
import java.util.Locale
import sa.lamha.lamha.MainActivity
import sa.lamha.lamha.R

/// الودجت الكبيرة (٤×٤) بـ Glance. تقرأ الجدول ولا تحسب (CLAUDE.md)، والشكل يطابق
/// lib/src/app/widget_preview.dart. التخطيط يُبنى بالترتيب المرئي من اليسار لأن التطبيق بلا
/// supportsRtl، فالعنصر الأول في كل صف يقع أقصى اليمين (DECISIONS ١٠).
class LamhaWidget : GlanceAppWidget() {

    override val stateDefinition: GlanceStateDefinition<*> = HomeWidgetGlanceStateDefinition()

    override val sizeMode: SizeMode = SizeMode.Exact

    override suspend fun provideGlance(context: Context, id: GlanceId) {
        provideContent {
            val prefs = currentState<HomeWidgetGlanceState>().preferences
            val day = LamhaSchedule.read(prefs.getString(SCHEDULE_KEY, null), System.currentTimeMillis())
            Content(arabic(LocalContext.current), day)
        }
    }

    companion object {
        /// مفتاح الجدول في HomeWidgetPreferences (scheduleKey في lib/src/app/services.dart).
        const val SCHEDULE_KEY = "schedule"

        /// مربع القبلة يفتح شاشة «اتجاه القبلة» (qiblaLaunchUri في lib/src/app/services.dart).
        const val QIBLA_URI = "lamha://qibla"

        /// أحجام المربعات الموحدة (tileTitleSize وtileValueSize وtileSubSize وtileGap في widget_preview.dart).
        private const val TITLE_SP = 12f
        private const val VALUE_SP = 17f
        private const val SUB_SP = 12f
        private val tileGap = 3.dp

        /// أعرض نص ممكن للساعة بصيغة h:mm، بالأرقام اللاتينية والعربية (تتبع لغة الجهاز).
        private val clockSamples = listOf("12:59", "10:08", "١٢:٥٩", "١٠:٠٨")

        private val accent = Color(0xFF78BE96)
        private val bg = Color(0xFF212A24)
        private val text = Color(0xFFF4EFE6)
        private val muted = Color(0xFFCFC6B8)
        private val dim = Color(0xFFB9B0A2)

        private val seasonEmoji = mapOf(
            "spring" to "🌸", "summer" to "☀️", "autumn" to "🍂", "winter" to "❄️",
        )

        /// التطبيق عربي فقط (main.dart: locale ar)، فنصوص الودجت بالعربية أياً كانت لغة الجهاز.
        fun arabic(context: Context): Context {
            val config = Configuration(context.resources.configuration)
            config.setLocale(Locale.forLanguageTag("ar"))
            return context.createConfigurationContext(config)
        }
    }

    /// ألوان النص والمربعات؛ تباين أعلى إذا كانت الخلفية شفافة أكثر من ٦٠٪ (opacity < 40).
    private class Palette(highContrast: Boolean) {
        val text = if (highContrast) Color.White else LamhaWidget.text
        val muted = if (highContrast) Color.White else LamhaWidget.muted
        val dim = if (highContrast) Color(0xFFEDE7DD) else LamhaWidget.dim
        val tile = if (highContrast) Color(0x66000000) else Color(0x0FFFFFFF)
        val highlight = if (highContrast) accent.copy(alpha = 0.45f) else accent.copy(alpha = 0.18f)
    }

    @Composable
    private fun Content(ctx: Context, day: LamhaDay?) {
        val open = actionStartActivity<MainActivity>(ctx)
        if (day == null) {
            Box(
                modifier = GlanceModifier.fillMaxSize().appWidgetBackground()
                    .background(bg.copy(alpha = 0.92f)).cornerRadius(28.dp).padding(16.dp)
                    .clickable(open),
                contentAlignment = Alignment.Center,
            ) {
                Text(
                    ctx.getString(R.string.widget_setup),
                    style = TextStyle(
                        color = ColorProvider(text), fontSize = 16.sp,
                        fontWeight = FontWeight.Bold, textAlign = TextAlign.Center,
                    ),
                )
            }
            return
        }

        val alpha = day.opacity.coerceIn(0, 100) / 100f
        val p = Palette(day.opacity < 40)
        val shown = LamhaLogic.gridElements.filter { it in day.visible }
        val rows = LamhaLogic.gridRows(shown)
        val size = LocalSize.current
        val pad = 14.dp
        val gap = 8.dp

        Column(
            modifier = GlanceModifier.fillMaxSize().appWidgetBackground()
                .background(bg.copy(alpha = alpha)).cornerRadius(28.dp).padding(pad)
                .clickable(open),
        ) {
            // إذا أُخفي الطقس والتاريخان يكبر صف الساعة (DESIGN).
            Head(ctx, day, p, big = day.visible.none { it == "hijri" || it == "gregorian" || it == "weather" },
                width = size.width - pad * 2,
                modifier = if (rows.isEmpty()) GlanceModifier.fillMaxWidth().defaultWeight()
                else GlanceModifier.fillMaxWidth())
            if (rows.isNotEmpty()) {
                Spacer(GlanceModifier.height(8.dp))
                Box(GlanceModifier.fillMaxWidth().height(1.dp).background(Color(0x14FFFFFF))) {}
                Spacer(GlanceModifier.height(8.dp))
                Column(GlanceModifier.fillMaxWidth().defaultWeight()) {
                    rows.forEachIndexed { r, row ->
                        if (r > 0) Spacer(GlanceModifier.height(gap))
                        val rowWidth = size.width - pad * 2
                        val totalFlex = row.sumOf { it.flex }
                        val unit: Dp = (rowWidth - gap * (row.size - 1)) / totalFlex
                        val equal = row.all { it.flex == 1 }
                        Row(GlanceModifier.fillMaxWidth().defaultWeight()) {
                            // بالترتيب المرئي: آخر عنصر يساراً، والأول يميناً.
                            row.asReversed().forEachIndexed { i, cell ->
                                if (i > 0) Spacer(GlanceModifier.width(gap))
                                val m = if (equal || cell.flex != 1) GlanceModifier.defaultWeight()
                                else GlanceModifier.width(unit)
                                Box(m.fillMaxHeight()) { Tile(ctx, day, p, cell.element) }
                            }
                        }
                    }
                }
            }
        }
    }

    @Composable
    private fun Head(ctx: Context, day: LamhaDay, p: Palette, big: Boolean, width: Dp, modifier: GlanceModifier) {
        val am = LamhaLogic.isAm(System.currentTimeMillis(), day.timeZone)
        val amPm = ctx.getString(if (am) R.string.am else R.string.pm)
        // الساعة و«ص/م» لا تتجاوز ٦٠٪ من عرض الودجت، ويأخذ عنصر الساعة عرض أعرض نص ممكن
        // فلا تُقص الأرقام ولا تتداخل مع «ص/م» (الميزة ٣ب).
        val clockSp = if (big) 60f else 44f
        val amSp = if (big) 26f else 20f
        val gap = 4f
        val natural = clockSamples.maxOf { textWidthDp(ctx, it, clockSp) } + gap + textWidthDp(ctx, amPm, amSp)
        val fitted = LamhaLogic.fitTextSize(clockSp, natural, width.value * 0.6f, 28f)
        val scale = fitted / clockSp
        val clockWidth = clockSamples.maxOf { textWidthDp(ctx, it, fitted) } * 1.08f + 4f
        Row(modifier = modifier, verticalAlignment = Alignment.Top) {
            // يسار: التاريخان ثم المدينة والطقس، والنص محاذى لليمين.
            Column(
                modifier = GlanceModifier.defaultWeight(),
                horizontalAlignment = Alignment.End,
            ) {
                if ("hijri" in day.visible) {
                    Line(ctx.getString(R.string.hijri_date, day.hijriText), 14, FontWeight.Bold, p.text)
                }
                if ("gregorian" in day.visible) {
                    Line(ctx.getString(R.string.gregorian_date, day.gregorianText), 13, FontWeight.Normal, p.muted)
                }
                if ("weather" in day.visible) {
                    Line(ctx.getString(R.string.city_weather, day.cityName), 12, FontWeight.Normal, p.muted)
                }
            }
            Spacer(GlanceModifier.width(8.dp))
            // يمين: الساعة (ساعة النظام) و«ص/م»، وتحتها اليوم بلون التمييز.
            Column(horizontalAlignment = Alignment.End) {
                Row(verticalAlignment = Alignment.Bottom) {
                    // بالترتيب المرئي: «ص/م» يساراً ثم الساعة يميناً، فتُقرأ «٨:٠١ م».
                    Text(
                        amPm,
                        maxLines = 1,
                        style = TextStyle(
                            color = ColorProvider(p.text),
                            fontSize = (amSp * scale).sp, fontWeight = FontWeight.Bold,
                        ),
                    )
                    Spacer(GlanceModifier.width(gap.dp))
                    AndroidRemoteViews(
                        clockViews(ctx, fitted, p.text, day.timeZone),
                        modifier = GlanceModifier.width(clockWidth.dp),
                    )
                }
                Spacer(GlanceModifier.height(4.dp))
                Text(
                    day.weekday,
                    style = TextStyle(
                        color = ColorProvider(accent),
                        fontSize = (if (big) 19 else 15).sp, fontWeight = FontWeight.Bold,
                        textAlign = TextAlign.Right,
                    ),
                )
            }
        }
    }

    /// الساعة بتوقيت المدينة (DECISIONS ٨) لتطابق «ص/م» واليوم، ولو اختلف توقيت الجهاز.
    private fun clockViews(ctx: Context, sizeSp: Float, color: Color, timeZone: String): RemoteViews =
        RemoteViews(ctx.packageName, R.layout.widget_clock).apply {
            setString(R.id.clock, "setTimeZone", timeZone)
            setTextViewTextSize(R.id.clock, TypedValue.COMPLEX_UNIT_SP, sizeSp)
            setTextColor(R.id.clock, color.toArgbInt())
        }

    /// عرض النص [s] بالـ dp بخط النظام العريض وحجم [sp] (كما يرسمه TextClock).
    private fun textWidthDp(ctx: Context, s: String, sp: Float): Float {
        val dm = ctx.resources.displayMetrics
        val paint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            textSize = TypedValue.applyDimension(TypedValue.COMPLEX_UNIT_SP, sp, dm)
            typeface = Typeface.DEFAULT_BOLD
        }
        return paint.measureText(s) / dm.density
    }

    /// عدّاد تنازلي من النظام حتى [atMillis]، فلا يحتاج تحديثاً كل دقيقة.
    private fun countdownViews(ctx: Context, atMillis: Long, color: Color): RemoteViews =
        RemoteViews(ctx.packageName, R.layout.widget_countdown).apply {
            val base = SystemClock.elapsedRealtime() + (atMillis - System.currentTimeMillis())
            setChronometer(R.id.countdown, base, ctx.getString(R.string.countdown_format), true)
            setChronometerCountDown(R.id.countdown, true)
            setTextColor(R.id.countdown, color.toArgbInt())
        }

    @Composable
    private fun Line(s: String, size: Int, weight: FontWeight, color: Color) {
        Text(
            s,
            maxLines = 1,
            style = TextStyle(
                color = ColorProvider(color), fontSize = size.sp, fontWeight = weight,
                textAlign = TextAlign.Right,
            ),
        )
    }

    @Composable
    private fun Tile(ctx: Context, day: LamhaDay, p: Palette, element: String) {
        val highlight = element == "prayer"
        var modifier = GlanceModifier.fillMaxSize()
            .background(if (highlight) p.highlight else p.tile)
            .cornerRadius(14.dp).padding(horizontal = 9.dp, vertical = 8.dp)
        // مربع القبلة وحده يفتح شاشة البوصلة؛ بقية الودجت تفتح الإعدادات.
        if (element == "qibla") {
            modifier = modifier.clickable(actionStartActivity<MainActivity>(ctx, Uri.parse(QIBLA_URI)))
        }
        Column(modifier = modifier, horizontalAlignment = Alignment.End) {
            val (title, emoji) = when (element) {
                "prayer" -> R.string.tile_prayer to "🕌"
                "qibla" -> R.string.tile_qibla to "🧭"
                "deposit" -> R.string.tile_deposit to "💰"
                "season" -> R.string.tile_season to (seasonEmoji[day.seasonId] ?: "🍂")
                else -> R.string.tile_trad_season to "🌾"
            }
            Row(modifier = GlanceModifier.fillMaxWidth(), verticalAlignment = Alignment.Top) {
                Text(emoji, style = TextStyle(fontSize = 16.sp))
                Text(
                    ctx.getString(title),
                    modifier = GlanceModifier.defaultWeight(),
                    maxLines = 2,
                    style = TextStyle(
                        color = ColorProvider(p.dim), fontSize = TITLE_SP.sp,
                        fontWeight = FontWeight.Bold, textAlign = TextAlign.Right,
                    ),
                )
            }
            // العنوان ثم القيمة ثم الثانوي متتابعة من الأعلى بتباعد ثابت (الميزة ٣ب).
            Spacer(GlanceModifier.height(tileGap))
            when (element) {
                "prayer" -> {
                    val next = day.nextPrayer
                    Value(next?.name ?: "", p)
                    if (next != null) {
                        if (next.text.isNotEmpty()) Sub(next.text, 1, p)
                        Spacer(GlanceModifier.height(tileGap))
                        AndroidRemoteViews(countdownViews(ctx, next.atMillis, p.dim))
                    }
                }
                "qibla" -> {
                    Value(day.qiblaDegrees, p)
                    if (day.qiblaDirection.isNotEmpty()) Sub(day.qiblaDirection, 1, p)
                }
                "deposit" -> {
                    val first = day.deposits.firstOrNull()
                    val second = day.deposits.getOrNull(1)
                    Value(first?.first ?: "--", p)
                    if (first != null) Sub(first.second, if (second != null) 1 else 2, p)
                    second?.let {
                        Sub(ctx.getString(R.string.value_with_suffix, it.first, it.second), 1, p)
                    }
                }
                "season" -> {
                    Value(day.seasonName, p)
                    Sub(ctx.getString(R.string.remaining_to_next, day.seasonRemaining,
                        LamhaLogic.withLam(day.seasonNext)), 2, p)
                }
                else -> {
                    Value(day.tradName, p)
                    Sub(ctx.getString(R.string.remaining_to_next, day.tradRemaining,
                        LamhaLogic.withLam(day.tradNext)), 1, p)
                    if (day.tradDescription.isNotEmpty()) Sub(day.tradDescription, 2, p)
                }
            }
        }
    }

    @Composable
    private fun Value(s: String, p: Palette) {
        Text(
            s,
            maxLines = 2,
            style = TextStyle(
                color = ColorProvider(p.text), fontSize = VALUE_SP.sp,
                fontWeight = FontWeight.Bold, textAlign = TextAlign.Right,
            ),
        )
    }

    @Composable
    private fun Sub(s: String, lines: Int, p: Palette) {
        Spacer(GlanceModifier.height(tileGap))
        Text(
            s,
            maxLines = lines,
            style = TextStyle(color = ColorProvider(p.dim), fontSize = SUB_SP.sp, textAlign = TextAlign.Right),
        )
    }
}

private fun Color.toArgbInt(): Int =
    ((alpha * 255f + 0.5f).toInt() shl 24) or ((red * 255f + 0.5f).toInt() shl 16) or
        ((green * 255f + 0.5f).toInt() shl 8) or (blue * 255f + 0.5f).toInt()
