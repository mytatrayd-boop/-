package sa.asraty.asraty

import android.annotation.SuppressLint
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    // Stable per-app device id for activation codes (lib/backend/access.dart).
    @SuppressLint("HardwareIds")
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "asraty/device").setMethodCallHandler { call, result ->
            if (call.method == "androidId") {
                result.success(Settings.Secure.getString(contentResolver, Settings.Secure.ANDROID_ID))
            } else {
                result.notImplemented()
            }
        }
    }
}
