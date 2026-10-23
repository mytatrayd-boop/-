package sa.lamha.lamha

import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import sa.lamha.lamha.widget.LamhaWeatherWorker

/// قناة sa.lamha/android (services.dart): ألوان النظام (Material You) وإذن الإشعارات والاهتزاز.
class MainActivity : FlutterActivity() {
    private var pendingPermission: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // جلب الطقس الدوري يعمل حتى بلا ودجت على الشاشة (لإشعار شاشة القفل).
        LamhaWeatherWorker.ensureScheduled(this)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "systemColors" -> result.success(systemColors())
                "requestNotificationPermission" -> requestNotificationPermission(result)
                "vibrate" -> result.success(vibrate())
                else -> result.notImplemented()
            }
        }
    }

    /// ألوان النظام في أندرويد ١٢+ (كـ LamhaWidgetReceiver.colors)، وإلا null.
    private fun systemColors(): Map<String, Int>? {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S) return null
        return mapOf(
            "accent" to getColor(android.R.color.system_accent1_200),
            "background" to getColor(android.R.color.system_neutral1_900),
        )
    }

    /// نبضتان بمحرك الاهتزاز نفسه (لا يتبع إعداد «اهتزاز اللمس» كـ HapticFeedback). false بلا محرك.
    private fun vibrate(): Boolean {
        val vibrator = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            (getSystemService(Context.VIBRATOR_MANAGER_SERVICE) as VibratorManager).defaultVibrator
        } else {
            @Suppress("DEPRECATION")
            getSystemService(Context.VIBRATOR_SERVICE) as Vibrator
        }
        if (!vibrator.hasVibrator()) return false
        val pattern = longArrayOf(0, 120, 100, 120)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            vibrator.vibrate(VibrationEffect.createWaveform(pattern, -1))
        } else {
            @Suppress("DEPRECATION")
            vibrator.vibrate(pattern, -1)
        }
        return true
    }

    /// POST_NOTIFICATIONS في أندرويد ١٣+؛ الأقدم لا يحتاج إذناً.
    private fun requestNotificationPermission(result: MethodChannel.Result) {
        if (Build.VERSION.SDK_INT < 33 ||
            checkSelfPermission(POST_NOTIFICATIONS) == PackageManager.PERMISSION_GRANTED
        ) {
            result.success(true)
            return
        }
        pendingPermission?.success(false)
        pendingPermission = result
        requestPermissions(arrayOf(POST_NOTIFICATIONS), REQUEST_NOTIFICATIONS)
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode != REQUEST_NOTIFICATIONS) return
        val granted = grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED
        pendingPermission?.success(granted)
        pendingPermission = null
    }

    companion object {
        private const val CHANNEL = "sa.lamha/android"
        private const val REQUEST_NOTIFICATIONS = 4127

        /// Manifest.permission.POST_NOTIFICATIONS (API 33) نصاً، ليعمل مع أي compileSdk.
        private const val POST_NOTIFICATIONS = "android.permission.POST_NOTIFICATIONS"
    }
}
