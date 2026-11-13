package sa.lamha.lamha.widget

import android.view.ViewGroup
import android.widget.FrameLayout
import androidx.test.core.app.ApplicationProvider
import sa.lamha.lamha.R
import java.io.File
import org.junit.Assert.assertEquals
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config
import org.robolectric.annotation.GraphicsMode

/// المربعات العائمة تُضاف إلى `float_layer`، والنظام يطبّق التحديث التالي على الودجت القائمة (reapply) لا على
/// نسخة جديدة؛ فلو لم تُمسح الإضافات السابقة تراكمت نسخ مكررة فوق بعضها (لقطة المالك ١٣ نوفمبر). هنا نطبّق
/// تحديثين متتاليين كما يفعل النظام ونعدّ ما في الطبقة.
@RunWith(RobolectricTestRunner::class)
@GraphicsMode(GraphicsMode.Mode.NATIVE)
@Config(sdk = [34], qualifiers = "ar-xhdpi")
class LamhaFloatTest {

    @Test
    fun repeatedUpdatesDoNotStackFloatingTiles() {
        val ctx = LamhaScreens.arabicRtl(ApplicationProvider.getApplicationContext())
        val schedule = File("src/androidTest/assets/schedule_float.json").readText()
        val build = { LamhaWidgetReceiver.buildViews(ctx, schedule, 338, 440, LamhaScreens.NOW_MILLIS) }
        val view = build().apply(ctx, FrameLayout(ctx))
        val layer = view.findViewById<ViewGroup>(R.id.float_layer)
        // البوصلة والتاريخ الهجري عائمان في الجدول.
        assertEquals(2, layer.childCount)
        repeat(3) { build().reapply(ctx, view) }
        assertEquals("تراكمت المربعات العائمة بعد التحديث", 2, layer.childCount)
    }

    @Test
    fun frameOnlyMovesTheBackgroundPanel() {
        val ctx = LamhaScreens.arabicRtl(ApplicationProvider.getApplicationContext())
        val plain = File("src/androidTest/assets/schedule_black.json").readText()
        val framed = File("src/androidTest/assets/schedule_frame.json").readText()
        val a = LamhaWidgetReceiver.buildViews(ctx, plain, 338, 440, LamhaScreens.NOW_MILLIS).apply(ctx, FrameLayout(ctx))
        val b = LamhaWidgetReceiver.buildViews(ctx, framed, 338, 440, LamhaScreens.NOW_MILLIS).apply(ctx, FrameLayout(ctx))
        // الإطار يظهر حشوةً في غلاف الخلفية فقط.
        val boxA = a.findViewById<ViewGroup>(R.id.bg_box)
        val boxB = b.findViewById<ViewGroup>(R.id.bg_box)
        assertEquals(0, boxA.paddingTop)
        assertEquals(true, boxB.paddingTop > 0)
        assertEquals(true, boxB.paddingLeft > 0)
        // والشبكة (العناصر) بلا أي تغيير في حشوتها أو عدد أجزائها.
        val gridA = a.findViewById<ViewGroup>(R.id.grid)
        val gridB = b.findViewById<ViewGroup>(R.id.grid)
        assertEquals(gridA.paddingTop, gridB.paddingTop)
        assertEquals(gridA.childCount, gridB.childCount)
    }
}
