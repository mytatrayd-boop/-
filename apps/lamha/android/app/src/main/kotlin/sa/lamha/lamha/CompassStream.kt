package sa.lamha.lamha

import android.content.Context
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import android.os.SystemClock
import io.flutter.plugin.common.EventChannel

/// قناة sa.lamha/compass (services.dart AndroidCompassSource): اتجاه الجهاز (azimuth) من حساس «متجه الدوران»
/// كما في المواصفات المعتمدة: getRotationMatrixFromVector ثم getOrientation، والاتجاه = orientation[0] بالدرجات.
/// كل حدث {heading: درجات من الشمال المغناطيسي، accuracy: خطأ الدرجات أو null}.
/// بلا الحساس: خطأ بالرمز unavailable فيعود التطبيق لمكتبة flutter_compass.
class CompassStream(context: Context) : EventChannel.StreamHandler, SensorEventListener {
    private val manager = context.getSystemService(Context.SENSOR_SERVICE) as SensorManager
    private val sensor: Sensor? = manager.getDefaultSensor(Sensor.TYPE_ROTATION_VECTOR)
    private val rotation = FloatArray(9)
    private val orientation = FloatArray(3)
    private var sink: EventChannel.EventSink? = null
    private var status = SensorManager.SENSOR_STATUS_ACCURACY_MEDIUM
    private var lastSent = 0L

    override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
        val s = sensor
        if (s == null) {
            events.error("unavailable", "no rotation vector sensor", null)
            return
        }
        sink = events
        lastSent = 0L
        manager.registerListener(this, s, SensorManager.SENSOR_DELAY_GAME)
    }

    override fun onCancel(arguments: Any?) {
        manager.unregisterListener(this)
        sink = null
    }

    override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) {
        status = accuracy
    }

    override fun onSensorChanged(event: SensorEvent) {
        val out = sink ?: return
        // GAME ≈ ٥٠ قراءة/ثانية؛ ٣٠ كافية لحركة سلسة دون إغراق القناة.
        val now = SystemClock.elapsedRealtime()
        if (now - lastSent < MIN_INTERVAL_MS) return
        lastSent = now
        SensorManager.getRotationMatrixFromVector(rotation, event.values)
        SensorManager.getOrientation(rotation, orientation)
        val azimuth = CompassMath.azimuthDegrees(orientation[0])
        out.success(mapOf("heading" to azimuth, "accuracy" to CompassMath.accuracyDegrees(status)))
    }

    private companion object {
        const val MIN_INTERVAL_MS = 33L
    }
}
