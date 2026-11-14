package com.rihla.recorder

import android.media.MediaCodec
import android.media.MediaExtractor
import android.media.MediaFormat
import android.media.MediaMuxer
import android.util.Log
import java.io.File
import java.nio.ByteBuffer
import java.nio.file.Files
import java.nio.file.StandardCopyOption

/**
 * يدمج مقاطع mp4 بلا إعادة ترميز (remux) مع إزاحة الزمن لكل مقطع.
 * يكتب إلى ملف مؤقت ".part" ثم يعيد تسميته عند النجاح؛ عند الفشل يُحذف الجزئي. لا يحذف المصادر أبداً
 * (يحذفها المستدعي بعد النجاح). إن لم تتسع المساحة يرفض الدمج وتبقى المقاطع للاسترداد لاحقاً.
 */
object SegmentConcat {
    private const val TAG = "RihlaConcat"

    class Result(val durationUs: Long, val usedSegments: Int, val skippedSegments: Int)

    /** فشل في الكتابة إلى الـmuxer (غير قابل للتجاوز بتخطي مقطع). */
    private class MuxFailure(cause: Throwable) : RuntimeException(cause)

    fun concat(dir: File, entries: List<SegmentEntry>, out: File): Result {
        val total = entries.sumOf { File(dir, it.name).length() }
        if (!StorageMath.canMerge(dir.usableSpace, total)) {
            throw IllegalStateException("low_storage_for_merge: segments kept in ${dir.path}")
        }
        val part = File(out.path + ".part")
        part.delete()
        var muxer: MediaMuxer? = null
        var ok = false
        try {
            // فحص مسبق: صيغة الفيديو من أول مقطع صالح، وصيغة الصوت من أول مقطع فيه صوت (قد لا يكون الأول).
            var vFmt: MediaFormat? = null
            var aFmt: MediaFormat? = null
            for (e in entries) {
                if (vFmt != null && aFmt != null) break
                val ex = MediaExtractor()
                try {
                    ex.setDataSource(File(dir, e.name).path)
                    val vi = trackOf(ex, "video/")
                    val ai = trackOf(ex, "audio/")
                    if (vi >= 0 && vFmt == null) vFmt = ex.getTrackFormat(vi)
                    if (ai >= 0 && aFmt == null) aFmt = ex.getTrackFormat(ai)
                } catch (t: Throwable) {
                    Log.w(TAG, "probe ${e.name} failed", t)
                } finally {
                    ex.release()
                }
            }
            check(vFmt != null) { "no usable segments" }
            val m = MediaMuxer(part.path, MediaMuxer.OutputFormat.MUXER_OUTPUT_MPEG_4)
            muxer = m
            val vOut = m.addTrack(vFmt)
            val aOut = if (aFmt != null) m.addTrack(aFmt) else -1
            m.start()

            var lastPts = 0L
            var used = 0
            var skipped = 0
            val buf = ByteBuffer.allocate(4 * 1024 * 1024)
            val info = MediaCodec.BufferInfo()
            for (e in entries) {
                val f = File(dir, e.name)
                val ev = MediaExtractor()
                val ea = MediaExtractor()
                try {
                    ev.setDataSource(f.path)
                    ea.setDataSource(f.path)
                    val vi = trackOf(ev, "video/")
                    val ai = trackOf(ea, "audio/")
                    if (vi < 0) { skipped++; continue }
                    ev.selectTrack(vi)
                    if (ai >= 0) ea.selectTrack(ai)
                    var vAlive = true
                    var aAlive = ai >= 0 && aOut >= 0
                    while (vAlive || aAlive) {
                        val vt = if (vAlive) ev.sampleTime else Long.MAX_VALUE
                        val at = if (aAlive) ea.sampleTime else Long.MAX_VALUE
                        if (vAlive && vt < 0) { vAlive = false; continue }
                        if (aAlive && at < 0) { aAlive = false; continue }
                        val useVideo = vAlive && (!aAlive || vt <= at)
                        val ex = if (useVideo) ev else ea
                        buf.clear()
                        val size = ex.readSampleData(buf, 0)
                        if (size < 0) { if (useVideo) vAlive = false else aAlive = false; continue }
                        val pts = ex.sampleTime + e.offsetUs
                        info.set(0, size, maxOf(0L, pts), if ((ex.sampleFlags and MediaExtractor.SAMPLE_FLAG_SYNC) != 0) MediaCodec.BUFFER_FLAG_KEY_FRAME else 0)
                        try {
                            m.writeSampleData(if (useVideo) vOut else aOut, buf, info)
                        } catch (t: Throwable) {
                            throw MuxFailure(t)
                        }
                        lastPts = maxOf(lastPts, pts)
                        ex.advance()
                    }
                    used++
                } catch (t: MuxFailure) {
                    throw t
                } catch (t: Throwable) {
                    Log.w(TAG, "segment ${e.name} skipped", t)
                    skipped++
                } finally {
                    ev.release(); ea.release()
                }
            }
            check(used > 0) { "no usable segments" }
            m.stop()
            muxer = null
            m.release()
            Files.move(part.toPath(), out.toPath(), StandardCopyOption.REPLACE_EXISTING)
            ok = true
            return Result(lastPts, used, skipped)
        } finally {
            muxer?.runCatching { release() }
            if (!ok) part.delete()
        }
    }

    private fun trackOf(ex: MediaExtractor, prefix: String): Int {
        for (i in 0 until ex.trackCount) {
            if (ex.getTrackFormat(i).getString(MediaFormat.KEY_MIME)?.startsWith(prefix) == true) return i
        }
        return -1
    }
}
