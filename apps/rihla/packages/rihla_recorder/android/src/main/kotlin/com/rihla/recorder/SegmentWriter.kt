package com.rihla.recorder

import android.media.MediaCodec
import android.media.MediaFormat
import android.media.MediaMuxer
import android.util.Log
import java.io.File
import java.nio.ByteBuffer

/**
 * يكتب العينات المرتّبة في مقاطع mp4 قصيرة (كل مقطع يبدأ بإطار مفتاحي). يُغلَق كل مقطع بسليم
 * (moov مكتوب) فلا يضيع ما سبقه إن قُتلت العملية؛ ويُسجَّل في segments.txt. الدمج في SegmentConcat.
 * الكتابة تتم تحت قفل من خيطي السحب (فيديو/صوت).
 */
class SegmentWriter(
    private val dir: File,
    segmentSeconds: Int,
    private val onFatal: (Throwable) -> Unit,
) {
    private val policy = SegmentPolicy(segmentSeconds * 1_000_000L)
    private val interleaver = SampleInterleaver()
    private val lock = Any()
    private var videoFormat: MediaFormat? = null
    private var audioFormat: MediaFormat? = null
    private var muxer: MediaMuxer? = null
    private var vTrack = -1
    private var aTrack = -1
    private var index = 0
    private var currentName = ""
    private var firstBaseUs = -1L
    private var lastPtsUs = 0L
    private var failed = false
    val entries = ArrayList<SegmentEntry>()
    private val manifest = File(dir, MANIFEST)

    val durationUs: Long get() = synchronized(lock) { if (firstBaseUs < 0) 0 else lastPtsUs - firstBaseUs }

    fun setVideoFormat(f: MediaFormat) = synchronized(lock) { videoFormat = f; drainLocked(emptyList()) }
    fun setAudioFormat(f: MediaFormat) = synchronized(lock) { audioFormat = f; drainLocked(emptyList()) }

    fun submit(s: EncodedSample) = synchronized(lock) { drainLocked(interleaver.add(s)) }
    fun finishVideo() = synchronized(lock) { drainLocked(interleaver.finishVideo()) }
    fun finishAudio() = synchronized(lock) { drainLocked(interleaver.finishAudio()) }

    /** يفرغ الباقي ويغلق المقطع الأخير. */
    fun close(): List<SegmentEntry> = synchronized(lock) {
        drainLocked(interleaver.flushAll())
        closeSegmentLocked()
        entries.toList()
    }

    private val pending = ArrayDeque<EncodedSample>()

    private fun drainLocked(ready: List<EncodedSample>) {
        pending.addAll(ready)
        // لا كتابة قبل معرفة صيغتي المسارين (تأتيان قبل أول عينة عادة).
        if (failed || videoFormat == null || audioFormat == null) return
        while (pending.isNotEmpty()) {
            val s = pending.removeFirst()
            try {
                write(s)
            } catch (e: Throwable) {
                Log.e(TAG, "mux write failed", e)
                failed = true
                pending.clear()
                onFatal(e)
                return
            }
        }
    }

    private fun write(s: EncodedSample) {
        when (policy.decide(s.isVideo, s.isKeyFrame, s.ptsUs)) {
            SegmentPolicy.Decision.DROP -> return
            SegmentPolicy.Decision.START_SEGMENT -> {
                if (firstBaseUs < 0) firstBaseUs = s.ptsUs
                openSegment()
            }
            SegmentPolicy.Decision.ROTATE_SEGMENT -> {
                closeSegmentLocked()
                openSegment()
            }
            SegmentPolicy.Decision.WRITE -> {}
        }
        val m = muxer ?: return
        val info = MediaCodec.BufferInfo()
        info.set(0, s.data.size, maxOf(0L, s.ptsUs - policy.segStartUs), s.flags)
        m.writeSampleData(if (s.isVideo) vTrack else aTrack, ByteBuffer.wrap(s.data), info)
        lastPtsUs = maxOf(lastPtsUs, s.ptsUs)
    }

    private fun openSegment() {
        currentName = "seg_%04d.mp4".format(index++)
        val m = MediaMuxer(File(dir, currentName).path, MediaMuxer.OutputFormat.MUXER_OUTPUT_MPEG_4)
        vTrack = m.addTrack(videoFormat!!)
        aTrack = m.addTrack(audioFormat!!)
        m.start()
        muxer = m
    }

    private fun closeSegmentLocked() {
        val m = muxer ?: return
        muxer = null
        try {
            m.stop()
        } catch (e: Throwable) {
            Log.w(TAG, "muxer.stop failed for $currentName", e)
            m.runCatching { release() }
            return
        }
        m.release()
        val e = SegmentEntry(currentName, policy.segStartUs - firstBaseUs)
        entries.add(e)
        manifest.appendText(SegmentManifest.line(e) + "\n")
    }

    companion object {
        private const val TAG = "RihlaSegWriter"
        const val MANIFEST = "segments.txt"
    }
}
