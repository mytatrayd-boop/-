package com.adeebai.adeeb

import android.content.ActivityNotFoundException
import android.content.Intent
import android.provider.Settings
import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/// AudioServiceActivity تربط محرك Flutter بخدمة audio_service (التشغيل بالخلفية).
class MainActivity : AudioServiceActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // «افتح إعدادات الصوت» حين لا يوجد صوت عربي (DESIGN §10.4).
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.adeebai.adeeb/tts_settings")
            .setMethodCallHandler { call, result ->
                if (call.method == "open") {
                    result.success(openTtsSettings())
                } else {
                    result.notImplemented()
                }
            }
    }

    private fun openTtsSettings(): Boolean {
        for (action in listOf("com.android.settings.TTS_SETTINGS", Settings.ACTION_SETTINGS)) {
            try {
                startActivity(Intent(action).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
                return true
            } catch (e: ActivityNotFoundException) {
                // جرّب التالي.
            }
        }
        return false
    }
}
