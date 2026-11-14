package sa.lamha.lamha

import kotlin.math.abs
import kotlin.math.atan2

/// حساب اتجاه البوصلة من مصفوفة الدوران (نقي، بلا Android فيُختبر بـ JUnit).
///
/// المصفوفة R (٩ عناصر بترتيب صفوف، كما يعيدها SensorManager.getRotationMatrixFromVector) تحوّل من
/// إحداثيات الجهاز إلى العالم (شرق، شمال، أعلى). فمحور الجهاز Y (أعلى الشاشة) في العالم:
/// شرق = R[1] وشمال = R[4]، ومحور Z (خارج الشاشة): شرق = R[2] وشمال = R[5] وأعلى = R[8].
///
/// الجهاز مسطّح (الشاشة لأعلى): الاتجاه هو إلى أين يشير أعلى الجهاز (Y). الجهاز قائماً (الشاشة تواجه
/// المستخدم): أعلى الجهاز يشير إلى السماء فلا اتجاه له، فالاتجاه هو إلى أين يواجه ظهر الجهاز (‑Z).
/// getOrientation القديم يقفز ويرتجف عند الميل لأنه يعتمد Y دائماً، وهذا يبدّل المحور بحدّين مختلفين
/// (تخلّف) فلا يتذبذب قرب الحد، وعند الميل ٥٠–٦٠° يتفق الاتجاهان لدوران حول المحور الأفقي.
object CompassMath {
    /// أقل |R[8]| (جيب تمام ميل الجهاز عن الأفق) ليُعدّ الجهاز مسطحاً بعد أن كان قائماً.
    const val ENTER_FLAT = 0.7f

    /// أقل منه يُعدّ الجهاز قائماً بعد أن كان مسطحاً.
    const val ENTER_UPRIGHT = 0.5f

    /// الاتجاه بالدرجات في [0، 360) من الشمال المغناطيسي، وهل الجهاز مسطح الآن.
    data class Heading(val degrees: Double, val flat: Boolean)

    /// [wasFlat] الحالة السابقة (للتخلّف). يرمي إن كانت [r] أقصر من ٩.
    fun heading(r: FloatArray, wasFlat: Boolean): Heading {
        require(r.size >= 9) { "rotation matrix needs 9 elements" }
        val tilt = abs(r[8])
        val flat = if (wasFlat) tilt >= ENTER_UPRIGHT else tilt > ENTER_FLAT
        val east = if (flat) r[1] else -r[2]
        val north = if (flat) r[4] else -r[5]
        var deg = Math.toDegrees(atan2(east.toDouble(), north.toDouble()))
        if (deg < 0) deg += 360.0
        if (deg >= 360.0) deg -= 360.0
        return Heading(deg, flat)
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
