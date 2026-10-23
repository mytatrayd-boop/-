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

    // الميزة ٥: الحالات نفسها في test/engine/widget_layout_test.dart.
    private fun cells(spec: String) = spec.split(" ").map {
        LamhaLogic.Cell(it.dropLast(1), it.takeLast(1).toInt())
    }

    private fun shape(cells: List<LamhaLogic.Cell>) =
        LamhaLogic.packRows(cells).map { r -> r.map { "${it.id}${it.span}" } }

    @Test
    fun packRowsDefaultMatchesOwnerDesign() {
        // الميزة ٦: تصميم المالك ٣ (defaultLayout في Dart).
        val all = LamhaLogic.defaultLayout(setOf("hijri", "gregorian", "weather", "prayer", "qibla", "deposit", "season", "tradSeason"))
        assertEquals(listOf("dates", "weather", "prayer"), all.filter { !it.visible }.map { it.id })
        assertEquals(
            listOf(
                listOf("clock2", "dayWeather1"), listOf("hijri+gregorian2", "qibla1"),
                listOf("prayerTimes3"), listOf("deposit3"), listOf("season1", "tradSeason1", "tradPoints1"),
            ),
            shape(LamhaLogic.stackCells(all.filter { it.visible }.map { LamhaLogic.Cell(it.id, it.span) })),
        )
        val clock = all.first()
        assertEquals(LamhaLogic.Tile("clock", span = 2, fontScale = 2f, showSub = false), clock)
        assertEquals(listOf(false, false), all.filter { it.id == "season" || it.id == "tradSeason" }.map { it.showTitle })
        assertEquals(listOf("dates", "weather"), LamhaLogic.cellElements("dates+weather"))
    }

    @Test
    fun legacyDefaultStillStacksDatesAndWeather() {
        val legacy = cells("clock1 dates2 weather2 prayer1 qibla1 deposit1 season1 tradSeason2")
        assertEquals(
            listOf(listOf("clock1", "dates+weather2"), listOf("prayer1", "qibla1", "deposit1"), listOf("season1", "tradSeason2")),
            shape(LamhaLogic.stackCells(legacy)),
        )
    }

    @Test
    fun stackCellsOnlyWeatherRightAfterDatesWithSameSpan() {
        assertEquals(listOf(listOf("dates2", "weather1"), listOf("qibla3")), shape(LamhaLogic.stackCells(cells("dates2 weather1 qibla1"))))
        assertEquals(listOf(listOf("weather3"), listOf("dates3")), shape(LamhaLogic.stackCells(cells("weather2 dates2"))))
        assertEquals(listOf(listOf("dates+weather3"), listOf("prayer3")), shape(LamhaLogic.stackCells(cells("dates3 weather3 prayer1"))))
        // الميزة ٦: الميلادي تحت الهجري بالشرط نفسه.
        assertEquals(listOf(listOf("hijri+gregorian2", "qibla1")), shape(LamhaLogic.stackCells(cells("hijri2 gregorian2 qibla1"))))
        assertEquals(listOf(listOf("gregorian3"), listOf("hijri3")), shape(LamhaLogic.stackCells(cells("gregorian2 hijri2"))))
        assertEquals(listOf(listOf("hijri2", "gregorian1")), shape(LamhaLogic.stackCells(cells("hijri2 gregorian1"))))
    }

    @Test
    fun packRowsStretchWrapAndLimit() {
        assertEquals(listOf(listOf("a1", "b1", "c1"), listOf("d3")), shape(cells("a1 b1 c1 d1")))
        assertEquals(listOf(listOf("a1", "b2")), shape(cells("a1 b1")))
        assertEquals(listOf(listOf("a3"), listOf("b2", "c1")), shape(cells("a2 b2 c1")))
        assertEquals(
            listOf(listOf("a3"), listOf("b3"), listOf("c3"), listOf("d3"), listOf("e3")),
            shape(cells("a3 b3 c3 d3 e3 f1")),
        )
        assertEquals(
            listOf(listOf("a3"), listOf("b3"), listOf("c3"), listOf("d3"), listOf("e2", "f1")),
            shape(cells("a3 b3 c3 d3 e2 f1 g1")),
        )
        assertEquals(emptyList<List<String>>(), shape(emptyList()))
        assertEquals(listOf(listOf("a3")), shape(cells("a5")))
        assertEquals(listOf(listOf("a1", "b2")), shape(cells("a0 b1")))
        assertEquals(
            listOf(listOf("prayer3"), listOf("clock1", "dates2"), listOf("weather1", "qibla1", "deposit1")),
            shape(cells("prayer3 clock1 dates2 weather1 qibla1 deposit1")),
        )
    }

    @Test
    fun rowHeightsByContent() {
        val (s1, h1) = LamhaLogic.rowHeights(listOf(80f, 20f, 100f), listOf(0f, 0f, 20f), 300f, 8f)
        assertEquals(1f, s1, 1e-5f)
        val k = 284f / 220f
        assertEquals(80f * k, h1[0], 1e-3f)
        assertEquals(20f * k, h1[1], 1e-3f)
        assertEquals(120f * k, h1[2], 1e-3f)

        val (s2, h2) = LamhaLogic.rowHeights(listOf(80f, 20f, 100f), listOf(0f, 0f, 20f), 200f, 8f)
        assertEquals(0.82f, s2, 1e-5f)
        assertEquals(65.6f, h2[0], 1e-3f)
        assertEquals(102f, h2[2], 1e-3f)
        assertEquals(184f, h2.sum(), 1e-3f)

        assertEquals(0.6f, LamhaLogic.rowHeights(listOf(80f, 20f, 100f), listOf(0f, 0f, 20f), 50f, 8f).first, 1e-5f)
        val (s3, h3) = LamhaLogic.rowHeights(listOf(80f, 20f), listOf(4f, 4f), 0f, 8f)
        assertEquals(1f, s3, 1e-5f)
        assertEquals(listOf(84f, 24f), h3)
        assertEquals(emptyList<Float>(), LamhaLogic.rowHeights(emptyList(), emptyList(), 300f, 8f).second)

        // صفوف السطور بقدر محتواها، وصفوف المربعات تقتسم الباقي بالتساوي، وإن نقص فبنسبتها.
        val fa = LamhaLogic.rowHeights(listOf(80f, 20f, 100f), listOf(0f, 0f, 20f), 300f, 0f, flexible = listOf(false, false, true))
        assertEquals(1f, fa.first, 1e-5f)
        assertEquals(listOf(80f, 20f, 200f), fa.second)
        val fb = LamhaLogic.rowHeights(listOf(50f, 60f, 70f), listOf(0f, 20f, 20f), 300f, 0f, flexible = listOf(false, true, true))
        assertEquals(listOf(50f, 125f, 125f), fb.second)
        val (s5, h5) = LamhaLogic.rowHeights(
            listOf(80f, 20f, 100f), listOf(0f, 0f, 20f), 120f, 0f, flexible = listOf(false, false, true),
        )
        assertEquals(0.6f, s5, 1e-5f)
        assertEquals(48f, h5[0], 1e-3f)
        assertEquals(12f, h5[1], 1e-3f)
        assertEquals(60f, h5[2], 1e-3f)

        val (s4, h4) = LamhaLogic.rowHeights(listOf(80f, 20f, 100f), listOf(0f, 0f, 20f), 300f, 0f, equal = true)
        assertEquals(listOf(100f, 100f, 100f), h4)
        assertEquals(0.8f, s4, 1e-5f)
    }

    @Test
    fun defaultLayoutFromOldVisible() {
        val l = LamhaLogic.defaultLayout(setOf("gregorian", "prayer", "tradSeason"))
        assertEquals(
            mapOf(
                "clock" to true, "dayWeather" to false, "hijri" to false, "gregorian" to true, "qibla" to false,
                "prayerTimes" to true, "deposit" to false, "season" to false, "tradSeason" to true, "tradPoints" to true,
                "dates" to false, "weather" to false, "prayer" to false,
            ),
            l.associate { it.id to it.visible },
        )
        assertEquals(listOf(2, 1, 2, 2, 1, 3, 3, 1, 1, 1, 2, 2, 1), l.map { it.span })
        assertEquals(listOf("clock"), LamhaLogic.defaultLayout(emptySet()).filter { it.visible }.map { it.id })
    }

    @Test
    fun slotInnerWidth() {
        // ٣٣٨dp: (٣١٨ × ١ ÷ ٣) - ٨ = ٩٨، وبعرض ٣ = ٣١٠.
        assertEquals(98f, LamhaLogic.slotInnerDp(338, 1), 0.01f)
        assertEquals(310f, LamhaLogic.slotInnerDp(338, 3), 0.01f)
        assertEquals(0f, LamhaLogic.slotInnerDp(0, 1), 0.01f)
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
        assertEquals("☀️ \u2066٣١°\u2069", LamhaLogic.weatherText(fresh, now, 180, icons))
        // ٣ ساعات بالضبط مقبولة، وبعدها «--°».
        assertEquals("☀️ \u2066٣١°\u2069", LamhaLogic.weatherText(fresh.copy(fetchedAtMillis = now - 180 * 60_000L), now, 180, icons))
        assertNull(LamhaLogic.weatherText(fresh.copy(fetchedAtMillis = now - 181 * 60_000L), now, 180, icons))
        assertNull(LamhaLogic.weatherText(null, now, 180, icons))
        assertEquals("🌡️ \u2066-٣°\u2069", LamhaLogic.weatherText(fresh.copy(temp = -2.5, code = 99), now, 180, icons))
        assertEquals("\u2066٠°\u2069", LamhaLogic.temperatureText(-0.4))

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
    fun formatDigitsBothWays() {
        // الحالات نفسها في test/engine/arabic_test.dart.
        assertEquals("٢٠٢٦-١٠", LamhaLogic.formatDigits("2026-10"))
        assertEquals("2026-10 4:56 ص", LamhaLogic.formatDigits("٢٠٢٦-10 ٤:٥٦ ص", latin = true))
        assertEquals("\u206631°\u2069", LamhaLogic.temperatureText(31.4, latin = true))
        assertEquals("\u2066٣١°\u2069", LamhaLogic.temperatureText(31.4))
        val now = t("2026-10-19T12:00:00.000Z")
        val w = LamhaLogic.Weather(31.4, 0, now, 24.69, 46.72)
        assertEquals("☀️ \u206631°\u2069", LamhaLogic.weatherText(w, now, 180, mapOf(0 to "☀️"), latin = true))
    }

    // الميزة ٦: الحالات نفسها في test/engine/widget_layout_test.dart (rotatePrayers).
    @Test
    fun rotatePrayersNextFirst() {
        fun keys(now: String, tomorrow: Boolean = true) =
            LamhaLogic.rotatePrayers(day("2026-10-19"), if (tomorrow) day("2026-10-20") else null, t(now))
        val tomorrowStart = t("2026-10-20T00:00:00.000+0300")
        // قبل الفجر: بالترتيب، كلها اليوم.
        val beforeFajr = keys("2026-10-19T03:00:00.000+0300")
        assertEquals(listOf("fajr", "dhuhr", "asr", "maghrib", "isha"), beforeFajr.map { it.key })
        assertTrue(beforeFajr.all { it.atMillis < tomorrowStart })
        // بعد الظهر: العصر أولاً، والفجر والظهر من الغد.
        val afterDhuhr = keys("2026-10-19T12:00:00.000+0300")
        assertEquals(listOf("asr", "maghrib", "isha", "fajr", "dhuhr"), afterDhuhr.map { it.key })
        assertEquals(listOf(false, false, false, true, true), afterDhuhr.map { it.atMillis >= tomorrowStart })
        // بعد العشاء: فجر الغد أولاً، وكلها من الغد.
        val afterIsha = keys("2026-10-19T21:00:00.000+0300")
        assertEquals(listOf("fajr", "dhuhr", "asr", "maghrib", "isha"), afterIsha.map { it.key })
        assertTrue(afterIsha.all { it.atMillis >= tomorrowStart })
        // بلا يوم تالٍ: أوقات اليوم.
        assertTrue(keys("2026-10-19T21:00:00.000+0300", tomorrow = false).all { it.atMillis < tomorrowStart })
    }

    @Test
    fun fitColumnsCases() {
        // يتسع كله.
        assertEquals(LamhaLogic.ColumnsFit(true, 1f, true, 1f), LamhaLogic.fitColumns(80f, 60f, 16f, 25f, 50f, 20f, 40f, 2f))
        // أعرض اسم ٧٥ في ٦٠: الأعمدة كلها ٠٫٨، والسطر الفرعي ٦٠/١٢٠ = ٠٫٥ < ٠٫٦ فيُخفى.
        val narrow = LamhaLogic.fitColumns(80f, 60f, 0f, 25f, 75f, 20f, 120f, 2f)
        assertEquals(0.8f, narrow.nameScale, 1e-6f)
        assertEquals(false, narrow.sub)
        // ضيق الارتفاع: العنوان أولاً (٢٥+٢+٢٠ = ٤٧ ≤ ٥٠).
        assertEquals(LamhaLogic.ColumnsFit(false, 1f, true, 1f), LamhaLogic.fitColumns(50f, 60f, 16f, 25f, 50f, 20f, 40f, 2f))
        // ثم يصغر السطران معاً حتى ٨٠٪: (٤٢−٢)/٤٥ ≈ ٠٫٨٨٩.
        val shrunk = LamhaLogic.fitColumns(42f, 60f, 16f, 25f, 50f, 20f, 40f, 2f)
        assertEquals(false, shrunk.title)
        assertEquals(true, shrunk.sub)
        assertEquals(40f / 45f, shrunk.nameScale, 1e-5f)
        assertEquals(40f / 45f, shrunk.subScale, 1e-5f)
        // وإلا يُخفى السطر الفرعي، ثم يصغر الاسم.
        assertEquals(LamhaLogic.ColumnsFit(false, 1f, false, 1f), LamhaLogic.fitColumns(30f, 60f, 16f, 25f, 50f, 20f, 40f, 2f))
        assertEquals(0.8f, LamhaLogic.fitColumns(20f, 60f, 16f, 25f, 50f, 20f, 40f, 2f).nameScale, 1e-6f)
    }

    @Test
    fun qiblaIconBackgroundDarkensRing() {
        // الحالات نفسها في test/engine/widget_theme_test.dart.
        assertEquals(0xFF3C301A.toInt(), LamhaLogic.qiblaIconBackground(0xFFD6AA5C.toInt()))
        assertEquals(0xFF243240.toInt(), LamhaLogic.qiblaIconBackground(0xFF7FB2E5.toInt()))
        assertEquals(0xFF474747.toInt(), LamhaLogic.qiblaIconBackground(0xFFFFFFFF.toInt()))
    }

    @Test
    fun qiblaIconTargetFillsSlot() {
        assertEquals(85f, LamhaLogic.qiblaIconTarget(100f), 1e-4f)
        assertEquals(110f, LamhaLogic.qiblaIconTarget(200f), 1e-6f)
        assertEquals(36f, LamhaLogic.qiblaIconTarget(0f), 1e-6f)
    }

    @Test
    fun depositsGrid() {
        // الحالات نفسها في test/engine/widget_layout_test.dart.
        assertEquals(listOf(1, 2, 6, 6), listOf(1, 2, 3, 4).map { LamhaLogic.maxDeposits(it) })
        assertEquals(listOf(1, 1, 2, 2), listOf(1, 3, 4, 6).map { LamhaLogic.depositColumns(it) })
        assertEquals(listOf(1, 3, 2, 3, 3), listOf(1, 3, 4, 5, 6).map { LamhaLogic.gridRows(it) })
        assertEquals(LamhaLogic.GridFit(true, 1f), LamhaLogic.fitGrid(100f, 60f, 16f, 20f, 50f, 3, 2f))
        val narrow = LamhaLogic.fitGrid(100f, 60f, 16f, 20f, 75f, 3, 2f)
        assertEquals(true, narrow.title)
        assertEquals(0.8f, narrow.scale, 1e-6f)
        assertEquals(LamhaLogic.GridFit(false, 1f), LamhaLogic.fitGrid(70f, 60f, 16f, 20f, 50f, 3, 2f))
        val short = LamhaLogic.fitGrid(49f, 60f, 16f, 20f, 50f, 3, 2f)
        assertEquals(false, short.title)
        assertEquals(0.75f, short.scale, 1e-6f)
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
    fun fittingLines() {
        assertEquals(1, LamhaLogic.fittingLines(0f, 17.5f, 2))
        assertEquals(2, LamhaLogic.fittingLines(17.5f, 17.5f, 2))
        assertEquals(2, LamhaLogic.fittingLines(100f, 17.5f, 2))
        assertEquals(1, LamhaLogic.fittingLines(-5f, 17.5f, 2))
    }

    // الميزة ٥ب: الحالات نفسها في widget_layout_test.dart.
    @Test
    fun wrapLinesAtSpacesOnly() {
        assertEquals(1, LamhaLogic.wrapLines(listOf(30f, 20f), 5f, 80f))
        assertEquals(2, LamhaLogic.wrapLines(listOf(30f, 20f), 5f, 54f))
        assertEquals(2, LamhaLogic.wrapLines(listOf(10f, 10f, 10f), 0f, 20f))
        assertEquals(1, LamhaLogic.wrapLines(emptyList(), 0f, 10f))
    }

    private val twoSubs = listOf(LamhaLogic.SubLine(17.5f, 1), LamhaLogic.SubLine(17.5f, 2))

    private fun fit(height: Float, width: Float, fromStart: Boolean = false, subs: List<LamhaLogic.SubLine> = twoSubs) =
        LamhaLogic.fitTile(height, width, 16f, 25f, listOf(30f, 20f), 5f, subs, fromStart, 3f)

    @Test
    fun fitTileCases() {
        val a = fit(100f, 80f)
        assertEquals(LamhaLogic.TileFit(true, 1f, 1, listOf(0, 1), listOf(1f, 1f), 1), a)
        assertEquals(2, fit(120f, 80f).lastSubLines)
        val u = fit(0f, 0f)
        assertEquals(listOf(0, 1), u.subs)
        assertEquals(2, u.lastSubLines)
        // ضيق الارتفاع: الثانويات بأولويتها، ثم العنوان، ثم أدنى تصغير للقيمة.
        assertEquals(emptyList<Int>(), fit(60f, 80f).subs)
        assertTrue(fit(60f, 80f).title)
        assertEquals(listOf(1), fit(70f, 80f, fromStart = true).subs)
        val c = fit(30f, 80f)
        assertEquals(false, c.title)
        assertEquals(emptyList<Int>(), c.subs)
        assertEquals(1f, c.valueScale, 1e-6f)
        val d = fit(100f, 40f)
        assertEquals(2, d.valueLines)
        assertEquals(listOf(0), d.subs)
        assertTrue(d.title)
        assertEquals(false, fit(60f, 40f).title)
        assertEquals(2, fit(60f, 40f).valueLines)
        assertEquals(2, fit(40f, 40f).valueLines)
        assertEquals(0.8f, fit(40f, 40f).valueScale, 1e-5f)
        assertEquals(0.8f, LamhaLogic.fitTile(20f, 80f, 0f, 25f, listOf(30f)).valueScale, 1e-6f)
        // القيمة تصغر عرضياً فقط إن لم تتسع أعرض كلمة، وبأدنى تصغير.
        val e = fit(200f, 24f)
        assertEquals(0.8f, e.valueScale, 1e-6f)
        assertEquals(2, e.valueLines)
        assertEquals(1f, fit(200f, 30f).valueScale, 1e-6f)
        // سطر لا يُختصر (العدّاد): يصغر حتى ٧٠٪ وإلا يُخفى.
        val g = fit(200f, 80f, subs = listOf(LamhaLogic.SubLine(17.5f, 1, 100f), LamhaLogic.SubLine(17.5f, 1, 200f)))
        assertEquals(listOf(0), g.subs)
        assertEquals(0.8f, g.subScales.single(), 1e-6f)
    }

    @Test
    fun fitPointsCases() {
        // الحالات نفسها في test/engine/widget_layout_test.dart.
        assertEquals(true to listOf(2, 2), LamhaLogic.fitPoints(60f, 12f, 10f, listOf(2, 2), 2f))
        assertEquals(false to listOf(2, 2), LamhaLogic.fitPoints(45f, 12f, 10f, listOf(2, 2), 2f))
        assertEquals(listOf(3, 1), LamhaLogic.fitPoints(100f, 0f, 10f, listOf(4, 1)).second)
        assertEquals(listOf(2), LamhaLogic.fitPoints(25f, 0f, 10f, listOf(2, 2), 2f).second)
    }
}
