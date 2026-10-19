package sa.lamha.lamha.widget

import android.content.Context
import android.content.res.Configuration
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
    private fun Head(ctx: Context, day: LamhaDay, p: Palette, big: Boolean, modifier: GlanceModifier) {
        val am = LamhaLogic.isAm(System.currentTimeMillis(), day.timeZone)
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
                    Text(
                        ctx.getString(if (am) R.string.am else R.string.pm),
                        style = TextStyle(
                            color = ColorProvider(p.text),
                            fontSize = (if (big) 26 else 20).sp, fontWeight = FontWeight.Bold,
                        ),
                    )
                    Spacer(GlanceModifier.width(3.dp))
                    AndroidRemoteViews(clockViews(ctx, big, p.text))
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

    private fun clockViews(ctx: Context, big: Boolean, color: Color): RemoteViews =
        RemoteViews(ctx.packageName, R.layout.widget_clock).apply {
            setTextViewTextSize(R.id.clock, TypedValue.COMPLEX_UNIT_SP, if (big) 60f else 44f)
            setTextColor(R.id.clock, color.toArgbInt())
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
        Column(
            modifier = GlanceModifier.fillMaxSize()
                .background(if (highlight) p.highlight else p.tile)
                .cornerRadius(14.dp).padding(horizontal = 9.dp, vertical = 8.dp),
            horizontalAlignment = Alignment.End,
        ) {
            val (title, emoji) = when (element) {
                "prayer" -> R.string.tile_prayer to "🕌"
                "qibla" -> R.string.tile_qibla to "🧭"
                "deposit" -> R.string.tile_deposit to "💰"
                "season" -> R.string.tile_season to (seasonEmoji[day.seasonId] ?: "🍂")
                else -> R.string.tile_trad_season to "🌾"
            }
            Row(modifier = GlanceModifier.fillMaxWidth(), verticalAlignment = Alignment.Top) {
                Text(emoji, style = TextStyle(fontSize = 18.sp))
                Text(
                    ctx.getString(title),
                    modifier = GlanceModifier.defaultWeight(),
                    maxLines = 2,
                    style = TextStyle(
                        color = ColorProvider(p.dim), fontSize = 11.sp,
                        fontWeight = FontWeight.Bold, textAlign = TextAlign.Right,
                    ),
                )
            }
            Spacer(GlanceModifier.defaultWeight())
            when (element) {
                "prayer" -> {
                    val next = day.nextPrayer
                    Value(next?.name ?: "", p)
                    if (next != null) AndroidRemoteViews(countdownViews(ctx, next.atMillis, p.dim))
                }
                "qibla" -> Value(day.qiblaText, p)
                "deposit" -> {
                    val first = day.deposits.firstOrNull()
                    Value(first?.first ?: "--", p)
                    if (first != null) Sub(first.second, 2, p)
                    day.deposits.getOrNull(1)?.let {
                        Sub(ctx.getString(R.string.value_with_suffix, it.first, it.second), 1, p, 9.5f)
                    }
                }
                "season" -> {
                    Value(day.seasonName, p)
                    Sub(ctx.getString(R.string.remaining_to_next, day.seasonRemaining,
                        LamhaLogic.withLam(day.seasonNext)), 2, p)
                }
                else -> {
                    val remaining = ctx.getString(R.string.remaining_to_next, day.tradRemaining,
                        LamhaLogic.withLam(day.tradNext))
                    Value(ctx.getString(R.string.value_with_suffix, day.tradName, remaining), p)
                    if (day.tradDescription.isNotEmpty()) Sub(day.tradDescription, 3, p)
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
                color = ColorProvider(p.text), fontSize = 15.sp,
                fontWeight = FontWeight.Bold, textAlign = TextAlign.Right,
            ),
        )
    }

    @Composable
    private fun Sub(s: String, lines: Int, p: Palette, size: Float = 11f) {
        Text(
            s,
            maxLines = lines,
            style = TextStyle(color = ColorProvider(p.dim), fontSize = size.sp, textAlign = TextAlign.Right),
        )
    }
}

private fun Color.toArgbInt(): Int =
    ((alpha * 255f + 0.5f).toInt() shl 24) or ((red * 255f + 0.5f).toInt() shl 16) or
        ((green * 255f + 0.5f).toInt() shl 8) or (blue * 255f + 0.5f).toInt()
