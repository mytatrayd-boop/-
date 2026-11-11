package sa.lamha.lamha.widget

import android.os.Parcel
import android.widget.RemoteViews
import androidx.test.core.app.ApplicationProvider
import java.io.File
import org.json.JSONObject
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config
import org.robolectric.annotation.GraphicsMode

/// الودجت تُرسَل إلى النظام مغلّفة (Parcel)، والنظام يرفض عند فكّها أكثر من ١٠ مستويات addView متداخلة
/// («Too many nested views»)، فيرمي updateAppWidget خطأً يُسقط التطبيق. هنا نغلّف ونفك كما يفعل النظام،
/// للجداول التجريبية ولأشجار تخطيط حر حتى ١٠ مستويات (الأعمق من FREE_MAX_DEPTH تُرسم بالصفوف القديمة)، ونقيس الحجم (حد Binder ١ ميغابايت).
@RunWith(RobolectricTestRunner::class)
@GraphicsMode(GraphicsMode.Mode.NATIVE)
@Config(sdk = [34], qualifiers = "ar-xhdpi")
class LamhaParcelTest {

    private fun roundTrip(rv: RemoteViews): Int {
        val p = Parcel.obtain()
        try {
            rv.writeToParcel(p, 0)
            val size = p.dataSize()
            p.setDataPosition(0)
            RemoteViews.CREATOR.createFromParcel(p)
            return size
        } finally {
            p.recycle()
        }
    }

    /// شجرة متعرجة: كل مستوى يقسم آخر جزء مرة أفقياً ومرة رأسياً حتى [depth] مستويات.
    private fun zigzag(depth: Int): JSONObject {
        val tiles = listOf("clock", "dayWeather", "qibla", "prayerTimes", "deposit", "season", "tradSeason", "hijri", "gregorian")
        fun node(level: Int): JSONObject {
            val t = tiles[level % tiles.size]
            if (level == depth - 1) return JSONObject().put("tile", t)
            return JSONObject()
                .put("dir", if (level % 2 == 0) "v" else "h")
                .put("children", org.json.JSONArray()
                    .put(JSONObject().put("w", 1).put("tile", t))
                    .put(node(level + 1).put("w", 1)))
        }
        return node(0)
    }

    @Test
    fun parcels() {
        val ctx = LamhaScreens.arabicRtl(ApplicationProvider.getApplicationContext())
        val failures = ArrayList<String>()
        val base = File("src/androidTest/assets/schedule_gold.json").readText()
        val cases = LamhaScreens.cases { File("src/androidTest/assets/schedule_$it.json").readText() }
            .map { it.first to it.second } +
            (2..10).map { d -> "zigzag$d" to JSONObject(base).put("tree", zigzag(d)).toString() }
        for ((name, schedule) in cases) {
            try {
                val size = roundTrip(LamhaWidgetReceiver.buildViews(ctx, schedule, 338, 354, LamhaScreens.NOW_MILLIS))
                if (size > 500_000) failures += "$name: $size bytes"
            } catch (e: Throwable) {
                failures += "$name: ${e.javaClass.simpleName} ${e.message}"
            }
        }
        assertTrue(failures.joinToString("\n"), failures.isEmpty())
    }
}
