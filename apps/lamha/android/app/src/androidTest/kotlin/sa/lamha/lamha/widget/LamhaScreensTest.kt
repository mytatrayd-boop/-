package sa.lamha.lamha.widget

import android.content.Context
import android.content.res.Configuration
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Rect
import android.view.View
import android.view.ViewGroup
import android.widget.FrameLayout
import android.widget.TextView
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import java.io.File
import java.util.Locale
import org.json.JSONObject
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import sa.lamha.lamha.R

/// لقطات الودجت الحقيقية على المحاكي (job «screens» في lamha-android.yml): يبني RemoteViews بالدالة
/// نفسها التي يستخدمها المستقبل (LamhaWidgetReceiver.buildViews)، ويطبقها داخل FrameLayout بمقاس
/// الودجت بالعربية ومن اليمين لليسار، ويحفظ PNG في getExternalFilesDir("screens")، ثم يتحقق من
/// التخطيط: لا سطر فوق حده، ولا نص بعرض صفر، وكل عنوان مربع ظاهر، والترتيب الرأسي داخل المربعات.
@RunWith(AndroidJUnit4::class)
class LamhaScreensTest {

    companion object {
        /// ٣:٠٠ ص بتوقيت أبها في ١٩ أكتوبر ٢٠٢٦، قبل الفجر (fixtureNow في test/app/android_fixture_test.dart).
        const val NOW_MILLIS = 1792368000000L

        /// الجدولان مولّدان من المحرك (android_fixture_test.dart) في androidTest/assets.
        val THEMES = listOf("gold", "blue")
        val SIZES = listOf(Triple("wide", 338, 354), Triple("narrow", 290, 320))
        val FONT_SCALES = listOf(0.9, 1.0, 1.3)

        /// خلفية «الشاشة الرئيسية» خلف الودجت (شفافيتها ٨٠).
        private val WALLPAPER = Color.rgb(46, 58, 72)
    }

    @Test
    fun screens() {
        val instr = InstrumentationRegistry.getInstrumentation()
        val target = instr.targetContext
        val ctx = arabicRtl(target)
        val outDir = target.getExternalFilesDir("screens")!!
        outDir.mkdirs()
        val failures = ArrayList<String>()

        for (theme in THEMES) {
            val base = instr.context.assets.open("schedule_$theme.json").bufferedReader().use { it.readText() }
            for ((sizeName, wDp, hDp) in SIZES) {
                for (scale in FONT_SCALES) {
                    val name = "lamha_${sizeName}_${theme}_$scale"
                    val schedule = JSONObject(base).put("fontScale", scale).toString()
                    instr.runOnMainSync {
                        failures += render(ctx, schedule, wDp, hDp, File(outDir, "$name.png")).map { "$name: $it" }
                    }
                }
            }
        }
        File(outDir, "failures.txt").writeText(failures.joinToString("\n"))
        assertTrue(failures.joinToString("\n"), failures.isEmpty())
    }

    private fun arabicRtl(context: Context): Context {
        val config = Configuration(context.resources.configuration)
        val ar = Locale.forLanguageTag("ar")
        config.setLocale(ar)
        config.setLayoutDirection(ar)
        return context.createConfigurationContext(config)
    }

    /// يرسم الودجت إلى [file] ويعيد مخالفات التخطيط.
    private fun render(ctx: Context, schedule: String, wDp: Int, hDp: Int, file: File): List<String> {
        val views = LamhaWidgetReceiver.buildViews(ctx, schedule, wDp, hDp, NOW_MILLIS)
        val density = ctx.resources.displayMetrics.density
        val wPx = (wDp * density).toInt()
        val hPx = (hDp * density).toInt()
        val parent = FrameLayout(ctx)
        parent.layoutDirection = View.LAYOUT_DIRECTION_RTL
        parent.addView(views.apply(ctx, parent))
        parent.measure(
            View.MeasureSpec.makeMeasureSpec(wPx, View.MeasureSpec.EXACTLY),
            View.MeasureSpec.makeMeasureSpec(hPx, View.MeasureSpec.EXACTLY),
        )
        parent.layout(0, 0, wPx, hPx)

        val bitmap = Bitmap.createBitmap(wPx, hPx, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bitmap)
        canvas.drawColor(WALLPAPER)
        parent.draw(canvas)
        file.outputStream().use { bitmap.compress(Bitmap.CompressFormat.PNG, 100, it) }
        return check(ctx, parent)
    }

    private fun check(ctx: Context, root: ViewGroup): List<String> {
        val out = ArrayList<String>()
        val texts = ArrayList<TextView>()
        collect(root, texts)
        for (t in texts) {
            if (!shown(t, root)) continue
            val label = "${idName(t)} «${t.text}»"
            if (t.width <= 0) out += "$label: العرض ${t.width}"
            val max = t.maxLines
            if (max > 0 && t.lineCount > max) out += "$label: ${t.lineCount} أسطر والحد $max"
        }

        // عناوين المربعات الخمسة ظاهرة، وكل مربع عمود رأسي: العنوان ثم القيمة (سطر واحد) ثم الثانويات.
        val expected = mapOf(
            ctx.getString(R.string.tile_prayer) to null,
            ctx.getString(R.string.tile_qibla) to null,
            ctx.getString(R.string.tile_deposit) to ctx.getString(R.string.tile_deposit_short),
            ctx.getString(R.string.tile_season) to null,
            ctx.getString(R.string.tile_trad_season) to null,
        )
        val titles = texts.filter { it.id == R.id.tile_title && shown(it, root) && it.text.isNotEmpty() }
        val titleTexts = titles.map { it.text.toString() }
        for ((full, short) in expected) {
            if (full !in titleTexts && (short == null || short !in titleTexts)) out += "عنوان «$full» غير ظاهر"
        }
        for (title in titles) {
            val box = title.parent as ViewGroup
            val column = (0 until box.childCount).map { box.getChildAt(it) }
                .filter { it.visibility == View.VISIBLE }
            val value = box.findViewById<TextView>(R.id.tile_value)
            if (value.lineCount != 1) out += "قيمة «${value.text}» في ${value.lineCount} أسطر"
            for (i in 1 until column.size) {
                val a = rect(column[i - 1], root)
                val b = rect(column[i], root)
                if (b.top < a.bottom) out += "«${title.text}»: ${idName(column[i])} ليس تحت ${idName(column[i - 1])}"
                if (b.right != a.right) out += "«${title.text}»: ${idName(column[i])} غير محاذٍ يميناً"
            }
        }

        // الصف العلوي: اليوم تحت الساعة يميناً، والتواريخ وسطر المدينة والطقس يساراً.
        val clock = rect(root.findViewById(R.id.clock), root)
        val weekday = root.findViewById<TextView>(R.id.weekday)
        val day = rect(weekday, root)
        if (day.top < clock.top + clock.height() / 2) out += "اليوم ليس تحت الساعة"
        if (day.right < clock.left) out += "اليوم ليس في عمود الساعة"
        for (id in intArrayOf(R.id.hijri, R.id.gregorian, R.id.weather)) {
            val v = root.findViewById<TextView>(id)
            if (!shown(v, root)) out += "${idName(v)} مخفي"
            else if (rect(v, root).right > clock.left) out += "${idName(v)} ليس يسار الساعة"
        }
        val weather = root.findViewById<TextView>(R.id.weather).text.toString()
        if (!weather.startsWith("📍")) out += "سطر المدينة والطقس «$weather»"
        return out
    }

    private fun collect(v: View, out: MutableList<TextView>) {
        if (v is TextView) out += v
        if (v is ViewGroup) for (i in 0 until v.childCount) collect(v.getChildAt(i), out)
    }

    /// ظاهر حتى [root] (isShown يحتاج نافذة).
    private fun shown(v: View, root: View): Boolean {
        var c: View = v
        while (true) {
            if (c.visibility != View.VISIBLE) return false
            if (c === root) return true
            c = c.parent as? View ?: return false
        }
    }

    private fun rect(v: View, root: View): Rect {
        var x = 0
        var y = 0
        var c: View = v
        while (c !== root) {
            x += c.left
            y += c.top
            c = c.parent as View
        }
        return Rect(x, y, x + v.width, y + v.height)
    }

    private fun idName(v: View): String =
        if (v.id == View.NO_ID) v.javaClass.simpleName else v.resources.getResourceEntryName(v.id)
}
