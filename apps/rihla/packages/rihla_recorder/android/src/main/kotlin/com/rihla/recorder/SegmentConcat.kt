package com.rihla.recorder

import android.media.MediaCodec
import android.media.MediaExtractor
import android.media.MediaFormat
import android.media.MediaMuxer
import android.util.Log
import java.io.File
import java.nio.ByteBuffer

/** يدمج مقاطع mp4 بلا إعادة ترميز (remux) مع إزاحة الزمن لكل مقطع. */
object SegmentConcat {
    private const val TAG = "RihlaConcat"

    class Result(val durationUs: Long, val usedSegments: Int, val skippedSegments: Int)

    fun concat(dir: File, entries: List<SegmentEntry>, out: File): Result {
        val total = entries.sumOf { File(dir, it.name).length() }
        val progressive = StorageMath.deleteSegmentsProgressively(dir.usableSpace, total)
        var muxer: MediaMuxer? = null
        var vOut = -1
        var aOut = -1
        var lastPts = 0L
        var used = 0
        var skipped = 0
        val buf = ByteBuffer.allocate(4 * 1024 * 1024)
        val info = MediaCodec.BufferInfo()
        try {
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
                    if (muxer == null) {
                        muxer = MediaMuxer(out.path, MediaMuxer.OutputFormat.MUXER_OUTPUT_MPEG_4)
                        vOut = muxer.addTrack(ev.getTrackFormat(vi))
                        if (ai >= 0) aOut = muxer.addTrack(ea.getTrackFormat(ai))
                        muxer.start()
                    }
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
                        muxer.writeSampleData(if (useVideo) vOut else aOut, buf, info)
                        lastPts = maxOf(lastPts, pts)
                        ex.advance()
                    }
                    used++
                } catch (t: Throwable) {
                    Log.w(TAG, "segment ${e.name} skipped", t)
                    skipped++
                } finally {
                    ev.release(); ea.release()
                }
                if (progressive) f.delete()
            }
            check(muxer != null) { "no usable segments" }
            muxer.stop()
        } finally {
            muxer?.runCatching { release() }
        }
        return Result(lastPts, used, skipped)
    }

    private fun trackOf(ex: MediaExtractor, prefix: String): Int {
        for (i in 0 until ex.trackCount) {
            if (ex.getTrackFormat(i).getString(MediaFormat.KEY_MIME)?.startsWith(prefix) == true) return i
        }
        return -1
    }
}
