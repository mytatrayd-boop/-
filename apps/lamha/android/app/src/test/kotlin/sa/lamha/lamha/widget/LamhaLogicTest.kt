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

    @Test
    fun splitQiblaIntoAngleAndDirection() {
        assertEquals("٣٢٤°" to "شمال غرب", LamhaLogic.splitQibla("٣٢٤° شمال غرب"))
        assertEquals("٩٠°" to "شرق", LamhaLogic.splitQibla("٩٠° شرق"))
        assertEquals("٢٤٣" to "", LamhaLogic.splitQibla("٢٤٣"))
    }

    @Test
    fun prayerTextDefaultsToEmpty() {
        assertEquals("", LamhaLogic.Prayer("fajr", "الفجر", 0L).text)
        assertEquals("٤:٣٥ ص", LamhaLogic.Prayer("fajr", "الفجر", 0L, "٤:٣٥ ص").text)
    }

    @Test
    fun clockShrinksOnlyOnNarrowWidgets() {
        assertEquals(52f, LamhaLogic.clockSizeSp(0), 0.001f)
        assertEquals(52f, LamhaLogic.clockSizeSp(250), 0.001f)
        assertEquals(42f, LamhaLogic.clockSizeSp(180), 0.001f)
    }

    @Test
    fun themeUsesSystemColorsOnlyOnAndroid12WithColors() {
        val gold = 0xFFD6AA5C.toInt() to 0xFF2A241D.toInt()
        val sys = 0xFF112233.toInt() to 0xFF000011.toInt()
        assertEquals(sys, LamhaLogic.themeColors("system", gold.first, gold.second, 31, sys.first, sys.second))
        // أقدم من ١٢، أو بلا ألوان: الذهبي من الجدول.
        assertEquals(gold, LamhaLogic.themeColors("system", gold.first, gold.second, 30, sys.first, sys.second))
        assertEquals(gold, LamhaLogic.themeColors("system", gold.first, gold.second, 33, null, null))
        // سمة عادية: ألوان الجدول ولو توفرت ألوان النظام.
        val blue = 0xFF7FB2E5.toInt() to 0xFF1C2430.toInt()
        assertEquals(blue, LamhaLogic.themeColors("blue", blue.first, blue.second, 34, sys.first, sys.second))
        assertEquals(0, LamhaLogic.backgroundAlpha255(0))
        assertEquals(204, LamhaLogic.backgroundAlpha255(80))
        assertEquals(255, LamhaLogic.backgroundAlpha255(140))
    }

    @Test
    fun weatherAgeAndNewestForSamePlace() {
        val now = t("2026-10-19T12:00:00.000Z")
        val icons = mapOf(0 to "☀️", 3 to "☁️")
        val fresh = LamhaLogic.Weather(31.4, 0, now - 20 * 60_000L, 24.69, 46.72)
        assertEquals("☀️ ٣١°", LamhaLogic.weatherText(fresh, now, 180, icons))
        // ٣ ساعات بالضبط مقبولة، وبعدها «--°».
        assertEquals("☀️ ٣١°", LamhaLogic.weatherText(fresh.copy(fetchedAtMillis = now - 180 * 60_000L), now, 180, icons))
        assertNull(LamhaLogic.weatherText(fresh.copy(fetchedAtMillis = now - 181 * 60_000L), now, 180, icons))
        assertNull(LamhaLogic.weatherText(null, now, 180, icons))
        assertEquals("🌡️ -٣°", LamhaLogic.weatherText(fresh.copy(temp = -2.5, code = 99), now, 180, icons))
        assertEquals("٠°", LamhaLogic.temperatureText(-0.4))

        val older = fresh.copy(temp = 20.0, fetchedAtMillis = now - 60 * 60_000L)
        val otherCity = fresh.copy(temp = 10.0, fetchedAtMillis = now, latitude = 18.2)
        assertEquals(fresh, LamhaLogic.newestWeather(older, fresh, 24.69, 46.72))
        assertEquals(fresh, LamhaLogic.newestWeather(fresh, otherCity, 24.69, 46.72))
        assertNull(LamhaLogic.newestWeather(otherCity, null, 24.69, 46.72))
    }

    @Test
    fun notificationLines() {
        val fajr = LamhaLogic.Prayer("fajr", "الفجر", 0L, "٤:٣٥ ص")
        val (title, text) = LamhaLogic.notificationLines(
            fajr, "٣٢٤°", "راتب أكتوبر", "بعد ٨ أيام",
            "%1\$s · %2\$s", "القبلة %1\$s", "%1\$s %2\$s", "%1\$s · %2\$s",
        )
        assertEquals("الفجر · ٤:٣٥ ص", title)
        assertEquals("القبلة ٣٢٤° · راتب أكتوبر بعد ٨ أيام", text)
        val (t2, x2) = LamhaLogic.notificationLines(
            LamhaLogic.Prayer("fajr", "الفجر", 0L), "٣٢٤°", null, null,
            "%1\$s · %2\$s", "القبلة %1\$s", "%1\$s %2\$s", "%1\$s · %2\$s",
        )
        assertEquals("الفجر", t2)
        assertEquals("القبلة ٣٢٤°", x2)
    }

    @Test
    fun arabicDigits() {
        assertEquals("٢٠٢٦-١٠", LamhaLogic.arabicDigits("2026-10"))
    }

    @Test
    fun shouldFetchWeatherOnlyWhenShownSomewhere() {
        assertTrue(LamhaLogic.shouldFetchWeather(true, 1, false))
        assertTrue(LamhaLogic.shouldFetchWeather(true, 0, true))
        assertTrue(LamhaLogic.shouldFetchWeather(true, 2, true))
        // الطقس مخفي: لا جلب حتى مع ودجت وإشعار.
        assertEquals(false, LamhaLogic.shouldFetchWeather(false, 1, true))
        // لا ودجت ولا إشعار.
        assertEquals(false, LamhaLogic.shouldFetchWeather(true, 0, false))
    }

    @Test
    fun fittingTitleFallsBackToShort() {
        assertEquals("الإيداع القادم", LamhaLogic.fittingTitle("الإيداع القادم", "الإيداع", 70f, 80f))
        assertEquals("الإيداع", LamhaLogic.fittingTitle("الإيداع القادم", "الإيداع", 90f, 80f))
        assertEquals("الإيداع", LamhaLogic.fittingTitle("الإيداع القادم", "الإيداع", 10f, 0f))
        // ٣٢٠dp بثلاثة مربعات بلا رموز: (٣٠٠ ÷ ٣) - ٢٦ = ٧٤.
        assertEquals(74f, LamhaLogic.tileTextWidthDp(320, 1, 3), 0.01f)
        assertEquals(0f, LamhaLogic.tileTextWidthDp(0, 1, 3), 0.01f)
    }

    // الميزة ٣د: الأرقام نفسها في test/app/feature_3d_test.dart (دوال Dart المطابقة).
    @Test
    fun fitTextSizeShrinksOnlyWhenTooWide() {
        assertEquals(44f, LamhaLogic.fitTextSize(44f, 120f, 150f, 28f), 0.001f)
        assertEquals(33f, LamhaLogic.fitTextSize(44f, 200f, 150f, 28f), 0.001f)
        assertEquals(28f, LamhaLogic.fitTextSize(44f, 400f, 150f, 28f), 0.001f)
        assertEquals(44f, LamhaLogic.fitTextSize(44f, 0f, 150f, 28f), 0.001f)
    }

    @Test
    fun headWidths() {
        assertEquals(310f, LamhaLogic.headContentDp(338), 0.001f)
        assertEquals(310f - 8f - 150f - 20f - 4f, LamhaLogic.clockAvailableDp(310f, 150f, 20f), 0.001f)
        assertEquals(310f * 0.4f - 20f - 4f, LamhaLogic.clockAvailableDp(310f, 280f, 20f), 0.001f)
        assertEquals(310f - 8f - 120f, LamhaLogic.leftColumnDp(310f, 120f, 80f), 0.001f)
        assertEquals(310f - 8f - 80f, LamhaLogic.leftColumnDp(310f, 60f, 80f), 0.001f)
    }

    @Test
    fun tileFitScaleShrinksTallestTileToFit() {
        val lines = listOf(13f, 20f, 14f, 14f)
        assertEquals(1.0f, LamhaLogic.tileFitScale(1.0f, 97.5f, lines, 1.25f, 3f), 0.0001f)
        assertEquals((90.5f - 9f) / 76.25f, LamhaLogic.tileFitScale(1.3f, 90.5f, lines, 1.25f, 3f), 0.0001f)
        assertEquals(0.6f, LamhaLogic.tileFitScale(1.3f, 10f, lines, 1.25f, 3f), 0.0001f)
        assertEquals(1.3f, LamhaLogic.tileFitScale(1.3f, 0f, lines, 1.25f, 3f), 0.0001f)
    }

    @Test
    fun tileInnerHeightAndFittingLines() {
        // ٤٠٠dp، صف علوي ٨٠، صفان: (٤٠٠ - ٢٨ - ٨٠ - ١٧ - ٨) ÷ ٢ - ١٦ = ١١٧٫٥.
        assertEquals(117.5f, LamhaLogic.tileInnerHeightDp(400, 80f, 2), 0.001f)
        assertEquals(0f, LamhaLogic.tileInnerHeightDp(0, 80f, 2), 0.001f)
        assertEquals(1, LamhaLogic.fittingLines(0f, 17.5f, 2))
        assertEquals(2, LamhaLogic.fittingLines(17.5f, 17.5f, 2))
        assertEquals(2, LamhaLogic.fittingLines(100f, 17.5f, 2))
        assertEquals(1, LamhaLogic.fittingLines(-5f, 17.5f, 2))
    }
}
