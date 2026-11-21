package sa.lamha.lamha.widget

import androidx.test.core.app.ApplicationProvider
import java.io.File
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config
import org.robolectric.annotation.GraphicsMode

/// لقطات الودجت محلياً بلا محاكي (Robolectric برسم أصلي): PNG في apps/lamha/mockups/widget_screens/
/// بالأحجام والسمات وأحجام الخط وحالات التخطيط (الميزة ٥) في LamhaScreens، مع التحقق نفسه الذي يجريه اختبار المحاكي.
/// الخط هنا خط Robolectric لا خط الجهاز، فاللقطة النهائية من المحاكي (job screens).
@RunWith(RobolectricTestRunner::class)
@GraphicsMode(GraphicsMode.Mode.NATIVE)
@Config(sdk = [34], qualifiers = "ar-xhdpi")
class LamhaScreensRobolectricTest {

    @Test
    fun screens() {
        val ctx = LamhaScreens.arabicRtl(ApplicationProvider.getApplicationContext())
        // مجلد العمل لاختبارات Gradle هو android/app.
        val outDir = File("../../mockups/widget_screens")
        outDir.mkdirs()
        val failures = ArrayList<String>()
        val cases = LamhaScreens.cases { File("src/androidTest/assets/schedule_$it.json").readText() }
        for ((name, schedule, size) in cases) {
            failures += LamhaScreens.render(ctx, schedule, size.first, size.second, File(outDir, name)).map { "$name: $it" }
        }
        assertTrue(failures.joinToString("\n"), failures.isEmpty())
    }
}
