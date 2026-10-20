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
import java.io.File
import java.util.Locale
import org.json.JSONArray
import org.json.JSONObject
import sa.lamha.lamha.R

/// لقطات الودجت والتحقق من تخطيطها، مشتركة بين اختبار المحاكي (androidTest/LamhaScreensTest)
/// واختبار Robolectric المحلي (test/LamhaScreensRobolectricTest). يبني RemoteViews بالدالة نفسها
/// التي يستخدمها المستقبل (LamhaWidgetReceiver.buildViews)، ويطبقها داخل FrameLayout بمقاس الودجت
/// بالعربية ومن اليمين لليسار، ويرسمها PNG، ثم يتحقق: لا سطر فوق حده، ولا نص بعرض صفر ولا مقصوص
/// خارج خانته، وكل عنوان مربع في التخطيط ظاهر، والمربع عمود رأسي محاذى يميناً، واليوم تحت الساعة،
/// والتاريخان والمدينة ظاهرة إن كانت في التخطيط ومخفية إن لم تكن.
object LamhaScreens {
    /// ٣:٠٠ ص بتوقيت أبها في ١٩ أكتوبر ٢٠٢٦، قبل الفجر (fixtureNow في test/app/android_fixture_test.dart).
    const val NOW_MILLIS = 1792368000000L

    /// الجدولان مولّدان من المحرك (android_fixture_test.dart) في src/androidTest/assets.
    val THEMES = listOf("gold", "blue")
    val SIZES = listOf(Triple("wide", 338, 354), Triple("narrow", 290, 320))
    val FONT_SCALES = listOf(0.9, 1.0, 1.3)

    /// خلفية «الشاشة الرئيسية» خلف الودجت (شفافيتها ٨٠).
    private val WALLPAPER = Color.rgb(46, 58, 72)

    fun fileName(size: String, theme: String, scale: Double) = "lamha_${size}_${theme}_$scale.png"

    /// كل اللقطات: (اسم الملف، الجدول، العرض، الارتفاع). [base] جدول السمة من الأصول.
    /// الترتيب الافتراضي بكل الأحجام والسمات وأحجام الخط، ثم حالات الميزة ٥ (بالذهبي) بالمقاسين.
    fun cases(base: (String) -> String): List<Triple<String, String, Pair<Int, Int>>> {
        val out = ArrayList<Triple<String, String, Pair<Int, Int>>>()
        for (theme in THEMES) {
            for ((size, w, h) in SIZES) {
                for (scale in FONT_SCALES) {
                    val schedule = JSONObject(base(theme)).put("fontScale", scale).toString()
                    out += Triple(fileName(size, theme, scale), schedule, w to h)
                }
            }
        }
        for ((name, edit) in LAYOUT_CASES) {
            val root = JSONObject(base("gold"))
            root.put("layout", edit(root.getJSONArray("layout")))
            for ((size, w, h) in SIZES) out += Triple("lamha_${name}_$size.png", root.toString(), w to h)
        }
        return out
    }

    private fun tile(id: String, span: Int, visible: Boolean = true, font: Double = 1.0, primary: Long? = null, secondary: Long? = null) =
        JSONObject().put("id", id).put("visible", visible).put("span", span).put("fontScale", font)
            .put("primaryColor", primary ?: JSONObject.NULL).put("secondaryColor", secondary ?: JSONObject.NULL)

    private fun JSONArray.objects() = (0 until length()).map { getJSONObject(it) }

    /// حالات الميزة ٥: ترتيب مخصص (الصلاة بعرض ٣ في الأعلى، والساعة بعرض ١، وألوان مختلفة)،
    /// وإخفاء ٤ عناصر، وخط «كبير جداً» لمربع واحد (الإيداع).
    private val LAYOUT_CASES: List<Pair<String, (JSONArray) -> JSONArray>> = listOf(
        "custom" to { _ ->
            JSONArray(listOf(
                tile("prayer", 3, primary = 0xFFEE9AB8, secondary = 0xFF7FB2E5),
                tile("clock", 1, primary = 0xFFD6AA5C, secondary = 0xFF78BE96),
                tile("dates", 2, secondary = 0xFFCFCFCF),
                tile("qibla", 1, primary = 0xFF78BE96),
                tile("deposit", 1, primary = 0xFFB39DDB, secondary = 0xFFFFFFFF),
                tile("weather", 1, primary = 0xFFFFFFFF),
                tile("season", 1),
                tile("tradSeason", 2, secondary = 0xFFD6AA5C),
            ))
        },
        "hidden4" to { l ->
            val hide = setOf("dates", "weather", "qibla", "season")
            JSONArray(l.objects().map { it.put("visible", it.getString("id") !in hide) })
        },
        "tilexl" to { l ->
            JSONArray(l.objects().map { if (it.getString("id") == "deposit") it.put("fontScale", 1.3) else it })
        },
    )

    fun arabicRtl(context: Context): Context {
        val config = Configuration(context.resources.configuration)
        val ar = Locale.forLanguageTag("ar")
        config.setLocale(ar)
        config.setLayoutDirection(ar)
        return context.createConfigurationContext(config)
    }

    /// يرسم الودجت إلى [file] ويعيد مخالفات التخطيط.
    fun render(ctx: Context, schedule: String, wDp: Int, hDp: Int, file: File): List<String> {
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
        // ما يفعله المشغّل قبل الرسم في نافذته (ViewTreeObserver.onPreDraw): نص singleLine يُمرَّر
        // إلى موضعه (bringTextIntoView). بلا نافذة هنا يُستدعى يدوياً.
        val texts = ArrayList<TextView>()
        collect(parent, texts)
        for (t in texts) t.onPreDraw()

        val bitmap = Bitmap.createBitmap(wPx, hPx, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bitmap)
        canvas.drawColor(WALLPAPER)
        parent.draw(canvas)
        file.outputStream().use { bitmap.compress(Bitmap.CompressFormat.PNG, 100, it) }
        val layout = LamhaSchedule.layoutOf(JSONObject(schedule)) ?: emptyList()
        val placed = LamhaLogic.packRows(
            LamhaLogic.stackCells(layout.filter { it.visible }.map { LamhaLogic.Cell(it.id, it.span) }),
        ).flatten().flatMap { LamhaLogic.cellElements(it.id) }.toSet()
        return check(ctx, parent, placed)
    }

    private fun check(ctx: Context, root: ViewGroup, placed: Set<String>): List<String> {
        val out = ArrayList<String>()
        val texts = ArrayList<TextView>()
        collect(root, texts)
        for (t in texts) {
            if (!shown(t, root)) continue
            val label = "${idName(t)} «${t.text}»"
            // النص المرسوم داخل حدود العنصر فعلاً (سطر singleLine عرض تخطيطه ضخم ويُمرَّر إليه).
            val layout = t.layout
            if (layout != null && t.text.isNotEmpty()) {
                val inner = t.width - t.totalPaddingLeft - t.totalPaddingRight
                // السطر المختصر بـ«…» يبلغ عرضه قبل الاختصار، فلا يُفحص.
                for (i in 0 until t.lineCount) {
                    if (layout.getEllipsisCount(i) > 0) continue
                    val l = layout.getLineLeft(i) - t.scrollX
                    val r = layout.getLineRight(i) - t.scrollX
                    if (l < -1f || r > inner + 1f) out += "$label: السطر ${i + 1} خارج العنصر ($l..$r من $inner)"
                }
            }
            if (t.width <= 0) out += "$label: العرض ${t.width}"
            // لا قص رأسي: ارتفاع العنصر يسع أسطره، والعنصر داخل حدود كل أب له (بعد حشوته) حتى خانته.
            if (layout != null && t.text.isNotEmpty()) {
                val lines = if (t.maxLines > 0) minOf(t.lineCount, t.maxLines) else t.lineCount
                val need = layout.getLineBottom(lines - 1)
                val has = t.height - t.totalPaddingTop - t.totalPaddingBottom
                if (need > has + 1) out += "$label: مقصوص رأسياً (يحتاج $need وله $has)"
            }
            val r = rect(t, root)
            var p = t.parent as? ViewGroup
            while (p != null && p !== root) {
                val b = rect(p, root)
                val top = b.top + p.paddingTop
                val bottom = b.bottom - p.paddingBottom
                if (r.top < top - 1 || r.bottom > bottom + 1) {
                    out += "$label: مقصوص رأسياً (${r.top}..${r.bottom} في ${idName(p)} $top..$bottom)"
                    break
                }
                if (p.id == R.id.slot) break
                p = p.parent as? ViewGroup
            }
            val max = t.maxLines
            if (max > 0 && t.lineCount > max) out += "$label: ${t.lineCount} أسطر والحد $max"
        }

        // عناوين مربعات المعلومات الظاهرة في التخطيط، وكل مربع عمود رأسي: العنوان ثم القيمة (سطر
        // واحد) ثم الثانويات.
        val expected = listOf(
            Triple("prayer", ctx.getString(R.string.tile_prayer), null),
            Triple("qibla", ctx.getString(R.string.tile_qibla), null),
            Triple("deposit", ctx.getString(R.string.tile_deposit), ctx.getString(R.string.tile_deposit_short)),
            Triple("season", ctx.getString(R.string.tile_season), null),
            Triple("tradSeason", ctx.getString(R.string.tile_trad_season), null),
        ).filter { it.first in placed }
        val titles = texts.filter { it.id == R.id.tile_title && shown(it, root) && it.text.isNotEmpty() }
        val titleTexts = titles.map { it.text.toString() }
        if (titles.size != expected.size) out += "${titles.size} عناوين والمتوقع ${expected.size}"
        for ((_, full, short) in expected) {
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

        // الساعة: اليوم تحتها في عمودها. التاريخان والمدينة والطقس ظاهرة إن كانت في التخطيط.
        val clockView = root.findViewById<View>(R.id.clock)
        if (("clock" in placed) != (clockView != null)) out += "الساعة: في التخطيط ${"clock" in placed}"
        if (clockView != null) {
            val clock = rect(clockView, root)
            val day = rect(root.findViewById<TextView>(R.id.weekday), root)
            if (day.top < clock.top + clock.height() / 2) out += "اليوم ليس تحت الساعة"
            if (day.right < clock.left || day.left > clock.right) out += "اليوم ليس في عمود الساعة"
        }
        for ((id, view) in listOf("dates" to R.id.hijri, "dates" to R.id.gregorian, "weather" to R.id.weather)) {
            val v = root.findViewById<TextView>(view)
            if (id in placed && (v == null || !shown(v, root))) out += "$id غير ظاهر"
            if (id !in placed && v != null) out += "$id ظاهر وهو مخفي"
        }
        root.findViewById<TextView>(R.id.weather)?.let {
            if (!it.text.toString().startsWith("📍")) out += "سطر المدينة والطقس «${it.text}»"
        }
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
