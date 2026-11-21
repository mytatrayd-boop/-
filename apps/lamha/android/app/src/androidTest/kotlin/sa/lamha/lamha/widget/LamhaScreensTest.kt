package sa.lamha.lamha.widget

import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import java.io.File
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith

/// لقطات الودجت الحقيقية على المحاكي (job «screens» في lamha-android.yml): PNG في
/// getExternalFilesDir("screens")، والتحقق من التخطيط في LamhaScreens (sharedTest).
@RunWith(AndroidJUnit4::class)
class LamhaScreensTest {

    @Test
    fun screens() {
        val instr = InstrumentationRegistry.getInstrumentation()
        val target = instr.targetContext
        val ctx = LamhaScreens.arabicRtl(target)
        val outDir = target.getExternalFilesDir("screens")!!
        outDir.mkdirs()
        val failures = ArrayList<String>()

        val cases = LamhaScreens.cases { theme ->
            instr.context.assets.open("schedule_$theme.json").bufferedReader().use { it.readText() }
        }
        for ((name, schedule, size) in cases) {
            instr.runOnMainSync {
                failures += LamhaScreens.render(ctx, schedule, size.first, size.second, File(outDir, name)).map { "$name: $it" }
            }
        }
        File(outDir, "failures.txt").writeText(failures.joinToString("\n"))
        assertTrue(failures.joinToString("\n"), failures.isEmpty())
    }
}
