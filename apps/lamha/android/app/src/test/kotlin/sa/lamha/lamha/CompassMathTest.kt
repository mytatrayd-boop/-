package sa.lamha.lamha

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class CompassMathTest {
    // مصفوفات دوران (جهاز ← عالم: شرق، شمال، أعلى) بترتيب صفوف، كما يعيدها SensorManager.

    /// الجهاز مسطح على الطاولة وأعلاه إلى الشمال: Y=شمال، X=شرق، Z=أعلى.
    private val flatNorth = floatArrayOf(1f, 0f, 0f, 0f, 1f, 0f, 0f, 0f, 1f)

    /// مسطح وأعلاه إلى الشرق: Y=شرق، X=جنوب، Z=أعلى.
    private val flatEast = floatArrayOf(0f, 1f, 0f, -1f, 0f, 0f, 0f, 0f, 1f)

    /// قائم (الشاشة تواجه المستخدم) وظهره إلى الشمال: Y=أعلى، Z=جنوب (نحو المستخدم)، X=شرق.
    private val uprightFacingNorth = floatArrayOf(1f, 0f, 0f, 0f, 0f, -1f, 0f, 1f, 0f)

    /// قائم وظهره إلى الشرق: Y=أعلى، Z=غرب (نحو المستخدم)، X=جنوب.
    private val uprightFacingEast = floatArrayOf(0f, 0f, -1f, -1f, 0f, 0f, 0f, 1f, 0f)

    @Test
    fun flatDeviceHeadingIsWhereTheTopPoints() {
        assertEquals(0.0, CompassMath.heading(flatNorth, true).degrees, 1e-6)
        assertEquals(90.0, CompassMath.heading(flatEast, true).degrees, 1e-6)
    }

    @Test
    fun uprightDeviceHeadingIsWhereTheBackFaces() {
        val n = CompassMath.heading(uprightFacingNorth, false)
        assertEquals(0.0, n.degrees, 1e-6)
        assertFalse(n.flat)
        assertEquals(90.0, CompassMath.heading(uprightFacingEast, false).degrees, 1e-6)
    }

    @Test
    fun headingStaysInZeroTo360() {
        // أعلاه إلى الغرب: Y=غرب، X=شمال → ٢٧٠.
        val flatWest = floatArrayOf(0f, -1f, 0f, 1f, 0f, 0f, 0f, 0f, 1f)
        assertEquals(270.0, CompassMath.heading(flatWest, true).degrees, 1e-6)
        // مسطح والشاشة لأسفل وأعلاه إلى الشمال: X=غرب، Y=شمال، Z=أسفل؛ يبقى مسطحاً ويقرأ اتجاه أعلاه.
        val faceDown = floatArrayOf(-1f, 0f, 0f, 0f, 1f, 0f, 0f, 0f, -1f)
        val h = CompassMath.heading(faceDown, true)
        assertTrue(h.flat)
        assertEquals(0.0, h.degrees, 1e-6)
    }

    @Test
    fun hysteresisPreventsFlappingNearTheThreshold() {
        // |R[8]| = ٠٫٦ بين الحدّين (٠٫٥ و٠٫٧): الحالة السابقة هي التي تبقى.
        val mid = floatArrayOf(1f, 0f, 0f, 0f, 0.8f, -0.6f, 0f, 0.6f, 0.6f)
        assertTrue(CompassMath.heading(mid, true).flat)
        assertFalse(CompassMath.heading(mid, false).flat)
        // تحت ٠٫٥ يصير قائماً، وفوق ٠٫٧ يصير مسطحاً مهما كانت السابقة.
        val steep = floatArrayOf(1f, 0f, 0f, 0f, 0.9f, -0.4f, 0f, 0.4f, 0.4f)
        assertFalse(CompassMath.heading(steep, true).flat)
        val shallow = floatArrayOf(1f, 0f, 0f, 0f, 0.7f, -0.8f, 0f, 0.8f, 0.8f)
        assertTrue(CompassMath.heading(shallow, false).flat)
    }

    @Test
    fun accuracyMapsAndroidStatusToDegrees() {
        assertEquals(15.0, CompassMath.accuracyDegrees(3)!!, 0.0)
        assertEquals(30.0, CompassMath.accuracyDegrees(2)!!, 0.0)
        assertEquals(45.0, CompassMath.accuracyDegrees(1)!!, 0.0)
        assertNull(CompassMath.accuracyDegrees(0))
        assertNull(CompassMath.accuracyDegrees(-1))
    }
}
