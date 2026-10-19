package sa.lamha.lamha.widget

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class LamhaLogicTest {

    private val riyadh = "Asia/Riyadh"
    private fun t(s: String) = LamhaLogic.parseIsoMillis(s)

    @Test
    fun parsesDartIsoWithOffsetAndUtc() {
        // 2026-10-19T04:35:00+03:00 = 01:35Z
        assertEquals(t("2026-10-19T01:35:00.000Z"), t("2026-10-19T04:35:00.000+0300"))
        assertEquals(1_792_373_700_000L, t("2026-10-19T01:35:00.000Z"))
        assertEquals(t("2026-10-19T01:35:00.000Z"), t("2026-10-19T04:35:00.000123+03:00"))
        assertEquals(0L, t("1970-01-01T00:00:00Z"))
    }

    @Test
    fun localDateUsesCityZoneNotDevice() {
        // 22:30Z يوم 18 = 01:30 يوم 19 في الرياض.
        assertEquals("2026-10-19", LamhaLogic.localDate(t("2026-10-18T22:30:00.000Z"), riyadh))
        assertEquals("2026-10-18", LamhaLogic.localDate(t("2026-10-18T20:59:00.000Z"), riyadh))
    }

    @Test
    fun dayIndexFallsBackToFirst() {
        val dates = listOf("2026-10-18", "2026-10-19", "2026-10-20")
        assertEquals(1, LamhaLogic.dayIndex(dates, "2026-10-19"))
        assertEquals(0, LamhaLogic.dayIndex(dates, "2026-12-01"))
    }

    private fun day(date: String) = listOf(
        LamhaLogic.Prayer("isha", "العشاء", t("${date}T19:00:00.000+0300")),
        LamhaLogic.Prayer("fajr", "الفجر", t("${date}T04:30:00.000+0300")),
        LamhaLogic.Prayer("sunrise", "الشروق", t("${date}T05:50:00.000+0300")),
        LamhaLogic.Prayer("dhuhr", "الظهر", t("${date}T11:40:00.000+0300")),
        LamhaLogic.Prayer("asr", "العصر", t("${date}T15:05:00.000+0300")),
        LamhaLogic.Prayer("maghrib", "المغرب", t("${date}T17:30:00.000+0300")),
    )

    @Test
    fun nextPrayerIsFirstAfterNowSkippingSunrise() {
        val today = day("2026-10-19")
        val tomorrow = day("2026-10-20")
        assertEquals("fajr", LamhaLogic.nextPrayer(today, tomorrow, t("2026-10-19T03:00:00.000+0300"))?.key)
        // بعد الفجر وقبل الشروق: الظهر لا الشروق.
        assertEquals("dhuhr", LamhaLogic.nextPrayer(today, tomorrow, t("2026-10-19T05:00:00.000+0300"))?.key)
        assertEquals("maghrib", LamhaLogic.nextPrayer(today, tomorrow, t("2026-10-19T15:05:00.000+0300"))?.key)
    }

    @Test
    fun afterIshaIsTomorrowFajr() {
        val tomorrow = day("2026-10-20")
        val next = LamhaLogic.nextPrayer(day("2026-10-19"), tomorrow, t("2026-10-19T21:00:00.000+0300"))
        assertEquals("fajr", next?.key)
        assertEquals(t("2026-10-20T04:30:00.000+0300"), next?.atMillis)
        assertNull(LamhaLogic.nextPrayer(day("2026-10-19"), null, t("2026-10-19T21:00:00.000+0300")))
    }

    @Test
    fun gridRowsMatchesPreview() {
        val all = LamhaLogic.gridElements
        fun shape(n: Int) = LamhaLogic.gridRows(all.take(n)).map { r -> r.map { it.flex } }
        assertEquals(emptyList<List<Int>>(), shape(0))
        assertEquals(listOf(listOf(1)), shape(1))
        assertEquals(listOf(listOf(1, 1)), shape(2))
        assertEquals(listOf(listOf(1, 1), listOf(1)), shape(3))
        assertEquals(listOf(listOf(1, 1), listOf(1, 1)), shape(4))
        assertEquals(listOf(listOf(1, 1, 1), listOf(1, 2)), shape(5))
        // الترتيب يُحفظ بعد الإخفاء: بلا قبلة.
        val rows = LamhaLogic.gridRows(listOf("prayer", "deposit", "season"))
        assertEquals(listOf("prayer", "deposit"), rows[0].map { it.element })
        assertEquals(listOf("season"), rows[1].map { it.element })
        assertEquals("tradSeason", LamhaLogic.gridRows(all)[1][1].element)
    }

    @Test
    fun withLamMatchesDart() {
        assertEquals("للشتاء", LamhaLogic.withLam("الشتاء"))
        assertEquals("لسهيل", LamhaLogic.withLam("سهيل"))
    }

    @Test
    fun updateTimesIncludePrayersMidnightsAndNoonsInOrder() {
        val now = t("2026-10-19T12:30:00.000+0300")
        val prayers = day("2026-10-19").map { it.atMillis }
        val times = LamhaLogic.updateTimes(listOf("2026-10-19"), prayers, riyadh, now)
        assertEquals(
            listOf(
                t("2026-10-19T15:05:00.000+0300"),
                t("2026-10-19T17:30:00.000+0300"),
                t("2026-10-19T19:00:00.000+0300"),
                t("2026-10-20T00:00:00.000+0300"),
                t("2026-10-20T12:00:00.000+0300"),
            ),
            times,
        )
        assertTrue(times.all { it > now })
    }

    @Test
    fun amPmInCityZone() {
        assertTrue(LamhaLogic.isAm(t("2026-10-19T11:59:00.000+0300"), riyadh))
        assertTrue(!LamhaLogic.isAm(t("2026-10-19T12:00:00.000+0300"), riyadh))
    }
}
