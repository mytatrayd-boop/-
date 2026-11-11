package sa.lamha.lamha

import android.app.ActivityManager
import android.app.ApplicationExitInfo
import android.content.Context
import android.os.Build
import android.util.Log
import java.io.File
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

/// سجل أعطال لمحة (تشخيص، ١١/١١/٢٠٢٦، بلاغ المالك: التطبيق ينهار عند الفتح على جواله ولا جهاز هنا).
/// يحفظ كل خطأ Java غير ملتقَط في ملف داخل التطبيق، وتجمع [report] معه أسباب إنهاء العملية من النظام
/// (ApplicationExitInfo، أندرويد ١١+: انهيار أصلي، قلة ذاكرة، ANR...) ومعلومات الجهاز، لتعرضها DiagActivity
/// بأيقونة منفصلة لا تشغّل Flutter فتعمل حتى لو انهار التطبيق عند فتحه.
object LamhaCrashLog {
    private const val FILE = "last_crash.txt"
    private const val MAX_CHARS = 12_000

    fun install(context: Context) {
        val file = File(context.filesDir, FILE)
        val previous = Thread.getDefaultUncaughtExceptionHandler()
        Thread.setDefaultUncaughtExceptionHandler { thread, error ->
            try {
                val entry = "${stamp(System.currentTimeMillis())}  thread=${thread.name}\n${Log.getStackTraceString(error)}\n"
                val old = if (file.exists()) file.readText() else ""
                file.writeText((entry + "\n" + old).take(MAX_CHARS))
            } catch (_: Throwable) {
                // الكتابة فشلت (ذاكرة أو مساحة): لا نحجب الانهيار الأصلي.
            }
            previous?.uncaughtException(thread, error)
        }
    }

    fun clear(context: Context) {
        File(context.filesDir, FILE).delete()
    }

    private fun stamp(ms: Long) = SimpleDateFormat("yyyy-MM-dd HH:mm:ss", Locale.US).format(Date(ms))

    fun report(context: Context): String {
        val sb = StringBuilder()
        val info = try {
            context.packageManager.getPackageInfo(context.packageName, 0)
        } catch (_: Throwable) {
            null
        }
        val mem = ActivityManager.MemoryInfo()
        (context.getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager).getMemoryInfo(mem)
        sb.appendLine("لمحة ${info?.versionName} (${if (Build.VERSION.SDK_INT >= 28) info?.longVersionCode else "?"})")
        sb.appendLine("${Build.MANUFACTURER} ${Build.MODEL} — Android ${Build.VERSION.RELEASE} (API ${Build.VERSION.SDK_INT}) ${Build.SUPPORTED_ABIS.firstOrNull()}")
        sb.appendLine("ذاكرة الجهاز: ${mem.availMem / 1_000_000} / ${mem.totalMem / 1_000_000} MB متاحة، قلة الذاكرة=${mem.lowMemory}")
        sb.appendLine()
        sb.appendLine("== آخر أخطاء Java في التطبيق ==")
        val file = File(context.filesDir, FILE)
        sb.appendLine(if (file.exists()) file.readText() else "(لا شيء مسجّل)")
        sb.appendLine()
        sb.appendLine("== أسباب إنهاء العملية من النظام (الأحدث أولاً) ==")
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            try {
                val am = context.getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
                val exits = am.getHistoricalProcessExitReasons(context.packageName, 0, 8)
                if (exits.isEmpty()) sb.appendLine("(لا شيء)")
                for (e in exits) {
                    sb.appendLine("${stamp(e.timestamp)}  ${reasonName(e.reason)}  process=${e.processName}  status=${e.status}")
                    sb.appendLine("  importance=${e.importance} pss=${e.pss / 1000}MB rss=${e.rss / 1000}MB")
                    if (!e.description.isNullOrEmpty()) sb.appendLine("  ${e.description}")
                    if (e.reason == ApplicationExitInfo.REASON_ANR) {
                        val trace = try {
                            e.traceInputStream?.bufferedReader()?.use { it.readText().take(2500) }
                        } catch (_: Throwable) {
                            null
                        }
                        if (trace != null) sb.appendLine(trace)
                    }
                }
            } catch (t: Throwable) {
                sb.appendLine("تعذّرت القراءة: $t")
            }
        } else {
            sb.appendLine("(يلزم أندرويد ١١ أو أحدث)")
        }
        return sb.toString()
    }

    private fun reasonName(r: Int) = when (r) {
        ApplicationExitInfo.REASON_CRASH -> "CRASH (خطأ Java)"
        ApplicationExitInfo.REASON_CRASH_NATIVE -> "CRASH_NATIVE (انهيار أصلي)"
        ApplicationExitInfo.REASON_ANR -> "ANR (تعليق)"
        ApplicationExitInfo.REASON_LOW_MEMORY -> "LOW_MEMORY (قلة ذاكرة)"
        ApplicationExitInfo.REASON_SIGNALED -> "SIGNALED"
        ApplicationExitInfo.REASON_EXIT_SELF -> "EXIT_SELF"
        ApplicationExitInfo.REASON_USER_REQUESTED -> "USER_REQUESTED"
        ApplicationExitInfo.REASON_USER_STOPPED -> "USER_STOPPED"
        ApplicationExitInfo.REASON_DEPENDENCY_DIED -> "DEPENDENCY_DIED"
        ApplicationExitInfo.REASON_EXCESSIVE_RESOURCE_USAGE -> "EXCESSIVE_RESOURCE_USAGE"
        ApplicationExitInfo.REASON_INITIALIZATION_FAILURE -> "INITIALIZATION_FAILURE"
        ApplicationExitInfo.REASON_PERMISSION_CHANGE -> "PERMISSION_CHANGE"
        ApplicationExitInfo.REASON_OTHER -> "OTHER"
        else -> "reason=$r"
    }
}
