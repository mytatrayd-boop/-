package sa.lamha.lamha

/// حسابات البوصلة النقية (بلا Android فتُختبر بـ JUnit).
object CompassMath {
    /// اتجاه الجهاز (azimuth) بالدرجات في [0، 360) من [radians] = orientation[0] من SensorManager.getOrientation
    /// (يعيد مدى (‑π، π]: الشرق موجب والغرب سالب).
    fun azimuthDegrees(radians: Float): Double {
        var deg = Math.toDegrees(radians.toDouble())
        if (deg < 0) deg += 360.0
        if (deg >= 360.0) deg -= 360.0
        return deg
    }

    /// خطأ الحساس بالدرجات من حالة دقة أندرويد (كما كانت flutter_compass تعطي):
    /// عالية ١٥، ومتوسطة ٣٠، ومنخفضة ٤٥، وغير ذلك (غير موثوقة) null.
    fun accuracyDegrees(status: Int): Double? = when (status) {
        3 -> 15.0 // SENSOR_STATUS_ACCURACY_HIGH
        2 -> 30.0 // SENSOR_STATUS_ACCURACY_MEDIUM
        1 -> 45.0 // SENSOR_STATUS_ACCURACY_LOW
        else -> null
    }
}
