package sa.lamha.lamha

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class CompassMathTest {
    @Test
    fun azimuthIsZeroToThreeSixty() {
        assertEquals(0.0, CompassMath.azimuthDegrees(0f), 1e-9)
        assertEquals(90.0, CompassMath.azimuthDegrees((Math.PI / 2).toFloat()), 1e-4)
        assertEquals(180.0, CompassMath.azimuthDegrees(Math.PI.toFloat()), 1e-4)
        // الغرب سالب في getOrientation: -π/2 → ٢٧٠.
        assertEquals(270.0, CompassMath.azimuthDegrees((-Math.PI / 2).toFloat()), 1e-4)
        assertEquals(315.0, CompassMath.azimuthDegrees((-Math.PI / 4).toFloat()), 1e-4)
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
