package com.rihla.recorder

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class PureTest {
    private fun v(pts: Long, key: Boolean = false) = EncodedSample(true, pts, if (key) 1 else 0, ByteArray(1))
    private fun a(pts: Long) = EncodedSample(false, pts, 0, ByteArray(1))

    @Test fun qualityEstimates() {
        assertEquals(1280, QualityProfile.P720.width)
        assertEquals(640, QualityProfile.P720.mapWidth)
        assertEquals(960, QualityProfile.P1080.mapWidth)
        assertEquals((4_000_000 + 96_000) / 8L, QualityProfile.P720.bytesPerSecond)
        assertEquals(QualityProfile.P1080, QualityProfile.fromKey("p1080"))
        assertEquals(QualityProfile.P720, QualityProfile.fromKey("zzz"))
        // 720p لـ10 دقائق ~ 307MB (يطابق تقدير ARCHITECTURE ~300MB).
        assertEquals(307_200_000L, QualityProfile.P720.bytesFor(600))
    }

    @Test fun storage() {
        assertTrue(StorageMath.isBelow(100, 300))
        assertFalse(StorageMath.isBelow(300, 300))
        assertTrue(StorageMath.deleteSegmentsProgressively(100L shl 20, 500L shl 20))
        assertFalse(StorageMath.deleteSegmentsProgressively(5000L shl 20, 500L shl 20))
    }

    @Test fun containAndCover() {
        val r = LayoutMath.containRect(640, 720, 0, 0, 640, 720)
        assertEquals(RectI(0, 0, 640, 720), r)
        val wide = LayoutMath.containRect(1000, 500, 0, 0, 640, 720) // أعرض: شريطان علوي/سفلي
        assertEquals(640, wide.w); assertEquals(320, wide.h); assertEquals(200, wide.y)
        val c = LayoutMath.coverCrop(1280, 720, 640, 720) // 16:9 إلى 8:9: نصف العرض
        assertEquals(0.25f, c.u0, 1e-5f); assertEquals(0.75f, c.u1, 1e-5f)
        assertEquals(0f, c.v0, 0f); assertEquals(1f, c.v1, 0f)
        val tall = LayoutMath.coverCrop(720, 1280, 1280, 720)
        assertEquals(0f, tall.u0, 0f)
        assertTrue(tall.v0 > 0.3f)
        assertEquals(0, LayoutMath.glY(0, 720, 720))
    }

    @Test fun rotationMatrices() {
        val id = LayoutMath.rotateAboutCenter(0)
        val (x0, y0) = LayoutMath.transform(id, 0.2f, 0.9f)
        assertEquals(0.2f, x0, 1e-5f); assertEquals(0.9f, y0, 1e-5f)
        val (x, y) = LayoutMath.transform(LayoutMath.rotateAboutCenter(180), 0.2f, 0.9f)
        assertEquals(0.8f, x, 1e-5f); assertEquals(0.1f, y, 1e-5f)
        val (cx, cy) = LayoutMath.transform(LayoutMath.rotateAboutCenter(90), 0.5f, 0.5f)
        assertEquals(0.5f, cx, 1e-5f); assertEquals(0.5f, cy, 1e-5f)
        val m = LayoutMath.mul(LayoutMath.rotateAboutCenter(180), LayoutMath.rotateAboutCenter(180))
        val (rx, ry) = LayoutMath.transform(m, 0.3f, 0.6f)
        assertEquals(0.3f, rx, 1e-5f); assertEquals(0.6f, ry, 1e-5f)
    }

    @Test fun clock() {
        val start = 10_000_000_000L
        // طابع بساعة حقيقية: يُستعمل.
        assertEquals(500_000L, ClockMath.cameraPtsUs(start + 500_000_000L, start + 520_000_000L, start))
        // ساعة مستشعر بعيدة: نرجع للحظة الرسم.
        assertEquals(520_000L, ClockMath.cameraPtsUs(1_000L, start + 520_000_000L, start))
        assertEquals(0L, ClockMath.audioAnchorUs(10_000, 4410, 44100)) // لا سالب
        assertEquals(190_000L, ClockMath.audioAnchorUs(200_000, 441, 44100))
        // لا انجراف: 10 دقائق من القطع بلا تراكم أخطاء.
        val frames = 44100L * 600
        assertEquals(600_000_000L, ClockMath.audioPtsUs(0, frames, 44100))
    }

    @Test fun muteKeepsLength() {
        val b = ByteArray(8) { 7 }
        PcmUtil.silence(b, 6)
        assertEquals(listOf<Byte>(0, 0, 0, 0, 0, 0, 7, 7), b.toList())
    }

    @Test fun interleaverOrdersAndHoldsBack() {
        val i = SampleInterleaver()
        assertTrue(i.add(v(0, true)).isEmpty()) // لا صوت بعد
        assertTrue(i.add(v(33_000)).isEmpty())
        val r = i.add(a(20_000)) // العلامة = min(33000, 20000)
        assertEquals(listOf(0L, 20_000L), r.map { it.ptsUs })
        val r2 = i.add(a(40_000))
        assertEquals(listOf(33_000L), r2.map { it.ptsUs })
        val rest = (i.add(v(66_000)) + i.finishAudio() + i.finishVideo()).map { it.ptsUs }
        assertEquals(listOf(40_000L, 66_000L), rest)
        assertEquals(0, i.queued)
    }

    @Test fun interleaverTieVideoFirstAndBounded() {
        val i = SampleInterleaver()
        i.add(a(100)); val r = i.add(v(100))
        assertEquals(listOf(true, false), r.map { it.isVideo })
        val b = SampleInterleaver(maxQueued = 3)
        var out = 0
        for (k in 0 until 10) out += b.add(v(k.toLong())).size // لا صوت أبداً: الذاكرة محدودة
        assertTrue(out >= 6)
        assertTrue(b.queued <= 3)
    }

    @Test fun segmentPolicy() {
        val p = SegmentPolicy(1_000_000)
        assertEquals(SegmentPolicy.Decision.DROP, p.decide(false, false, 0)) // صوت قبل أول مفتاحي
        assertEquals(SegmentPolicy.Decision.DROP, p.decide(true, false, 10))
        assertEquals(SegmentPolicy.Decision.START_SEGMENT, p.decide(true, true, 100))
        assertEquals(SegmentPolicy.Decision.WRITE, p.decide(false, false, 200))
        assertEquals(SegmentPolicy.Decision.WRITE, p.decide(true, true, 900_000)) // مفتاحي مبكر
        assertEquals(SegmentPolicy.Decision.WRITE, p.decide(true, false, 1_200_000))
        assertEquals(SegmentPolicy.Decision.ROTATE_SEGMENT, p.decide(true, true, 1_000_100))
        assertEquals(1_000_100L, p.segStartUs)
    }

    @Test fun manifestRoundtripIgnoresTornLine() {
        val e = listOf(SegmentEntry("seg_0000.mp4", 0), SegmentEntry("seg_0001.mp4", 60_000_033))
        val text = e.joinToString("\n") { SegmentManifest.line(it) } + "\nseg_0002.mp"
        assertEquals(e, SegmentManifest.parse(text))
    }

    @Test fun audioTrackerNoDriftWhenClockAgrees() {
        val t = AudioPtsTracker(44100)
        val first = t.next(0, 100_000)
        assertEquals(100_000L, first)
        // مرجع يطابق العدّ: لا مزامنة.
        val p = t.next(44100, 100_000 + 1_000_000)
        assertEquals(1_100_000L, p)
        assertEquals(0, t.resyncs)
    }

    @Test fun audioTrackerResyncsOnDriftAndStaysMonotonic() {
        val t = AudioPtsTracker(44100, thresholdUs = 40_000)
        t.next(0, 0)
        // انحراف 20ms تحت العتبة: يُتجاهل.
        assertEquals(1_000_000L, t.next(44100, 1_020_000))
        assertEquals(0, t.resyncs)
        // انحراف 200ms (الساعة الحقيقية أبطأ من عدّ الإطارات): تُزاح المرساة.
        val p = t.next(88200, 1_800_000)
        assertEquals(1_800_000L, p)
        assertEquals(1, t.resyncs)
        // انحراف سالب كبير يعيد الزمن للخلف: نضمن تزايداً صارماً.
        val q = t.next(88200 + 1024, 1_000_000)
        assertTrue(q > p)
    }

    @Test fun audioTrackerWithoutReferenceKeepsAnchor() {
        val t = AudioPtsTracker(44100)
        t.next(0, 500_000)
        assertEquals(500_000L + 23_219L, t.next(1024, null))
        assertEquals(500_000L, t.anchor)
    }

    @Test fun chunkStartFromHardwareTimestamp() {
        val start = 5_000_000_000L
        // الإطار 44100 التُقط عند start+2s؛ قطعة تبدأ عند الإطار 45124 => +1024 إطاراً.
        val us = ClockMath.chunkStartUs(start + 2_000_000_000L, 44100, start, 45124, 44100)
        assertEquals(2_000_000L + 23_219L, us)
        // طابع لاحق من القطعة (الإطارات قبله): فرق سالب.
        assertEquals(1_976_781L, ClockMath.chunkStartUs(start + 2_000_000_000L, 45124, start, 44100, 44100))
    }

    @Test fun mergeNeverNeedsDeletingSources() {
        assertTrue(StorageMath.canMerge(5000L shl 20, 500L shl 20))
        assertFalse(StorageMath.canMerge(100L shl 20, 500L shl 20))
    }
}
