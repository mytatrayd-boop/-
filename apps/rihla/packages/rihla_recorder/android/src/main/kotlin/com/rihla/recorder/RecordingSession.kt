package com.rihla.recorder

import android.media.AudioFormat
import android.media.AudioTimestamp
import android.media.AudioRecord
import android.media.MediaCodec
import android.media.MediaCodecInfo
import android.media.MediaFormat
import android.media.MediaRecorder
import android.os.Build
import android.os.SystemClock
import android.util.Log
import java.io.File
import java.nio.ByteBuffer
import java.util.concurrent.TimeUnit

class RecordingResult(
    val path: String,
    val durationMs: Long,
    val sizeBytes: Long,
    val segments: Int,
    val skippedSegments: Int,
    val hasMic: Boolean,
)

/**
 * جلسة تسجيل واحدة: مرمِّز فيديو (سطح إدخال من GlRenderer) + مرمِّز AAC + SegmentWriter.
 * كل الأزمنة بساعة واحدة (elapsedRealtimeNanos منسوباً إلى startNs). لم تُجرَّب على جهاز.
 */
class RecordingSession(
    private val renderer: GlRenderer,
    private val profile: QualityProfile,
    private val workDir: File,
    private val finalFile: File,
    segmentSeconds: Int,
    private val micAllowed: Boolean,
    @Volatile var muted: Boolean,
    onFatalCb: (Throwable) -> Unit,
    onSegmentLost: () -> Unit = {},
) {
    private val startNs = SystemClock.elapsedRealtimeNanos()

    /** أثناء التنظيف/الإيقاف لا نبلّغ أخطاء الخيوط التي نغلقها بأنفسنا. */
    @Volatile private var closing = false
    @Volatile private var aborted = false
    private val onFatal: (Throwable) -> Unit = { t -> if (!closing) onFatalCb(t) }
    private val writer = SegmentWriter(workDir, segmentSeconds, onFatal, onSegmentLost)
    private var inputSurface: android.view.Surface? = null
    private var video: MediaCodec? = null
    private var audio: MediaCodec? = null
    private var videoThread: Thread? = null
    private var audioFeedThread: Thread? = null
    private var audioDrainThread: Thread? = null
    @Volatile private var stopRequested = false
    @Volatile var micActive = false
        private set

    /** عند أي فشل: تنظيف كامل (مرمِّزات، خيوط، سطح، مجلد العمل) ثم إعادة رمي الخطأ. */
    fun start() {
        try {
            startInternal()
        } catch (t: Throwable) {
            Log.e(TAG, "start failed; cleaning up", t)
            teardown()
            throw t
        }
    }

    private fun startInternal() {
        workDir.mkdirs()
        val vf = MediaFormat.createVideoFormat(MediaFormat.MIMETYPE_VIDEO_AVC, profile.width, profile.height).apply {
            setInteger(MediaFormat.KEY_COLOR_FORMAT, MediaCodecInfo.CodecCapabilities.COLOR_FormatSurface)
            setInteger(MediaFormat.KEY_BIT_RATE, profile.videoBitrate)
            setInteger(MediaFormat.KEY_FRAME_RATE, QualityProfile.FPS)
            setInteger(MediaFormat.KEY_I_FRAME_INTERVAL, 1)
            setInteger(MediaFormat.KEY_BITRATE_MODE, MediaCodecInfo.EncoderCapabilities.BITRATE_MODE_VBR)
        }
        val v = MediaCodec.createEncoderByType(MediaFormat.MIMETYPE_VIDEO_AVC)
        video = v
        v.configure(vf, null, null, MediaCodec.CONFIGURE_FLAG_ENCODE)
        val surface = v.createInputSurface()
        inputSurface = surface
        v.start()

        val af = MediaFormat.createAudioFormat(MediaFormat.MIMETYPE_AUDIO_AAC, QualityProfile.AUDIO_SAMPLE_RATE, 1).apply {
            setInteger(MediaFormat.KEY_AAC_PROFILE, MediaCodecInfo.CodecProfileLevel.AACObjectLC)
            setInteger(MediaFormat.KEY_BIT_RATE, QualityProfile.AUDIO_BITRATE)
            setInteger(MediaFormat.KEY_MAX_INPUT_SIZE, 16 * 1024)
        }
        val a = MediaCodec.createEncoderByType(MediaFormat.MIMETYPE_AUDIO_AAC)
        audio = a
        a.configure(af, null, null, MediaCodec.CONFIGURE_FLAG_ENCODE)
        a.start()

        videoThread = Thread({ drain(v, true) }, "rihla-vdrain").also { it.start() }
        audioDrainThread = Thread({ drain(a, false) }, "rihla-adrain").also { it.start() }
        audioFeedThread = Thread({ feedAudio(a) }, "rihla-afeed").also { it.start() }
        // آخر خطوة: بعدها يبدأ وصول الإطارات للمرمِّز.
        renderer.setEncoderSurface(surface, profile.width, profile.height, startNs).get(5, TimeUnit.SECONDS)
    }

    /** يوقف الخيوط ويحرر المرمِّزات والسطح. آمن للاستدعاء أكثر من مرة. يعيد true إن ماتت كل الخيوط. */
    private fun teardown(): Boolean {
        closing = true
        stopRequested = true
        runCatching { renderer.setEncoderSurface(null, 0, 0, 0).get(3, TimeUnit.SECONDS) }
        runCatching { video?.signalEndOfInputStream() }
        val threads = listOfNotNull(audioFeedThread, videoThread, audioDrainThread)
        threads.forEach { it.join(2000) }
        if (threads.any { it.isAlive }) {
            aborted = true
            threads.forEach { if (it.isAlive) it.interrupt() }
            threads.forEach { it.join(2000) }
        }
        val allDead = threads.none { it.isAlive }
        if (allDead) {
            runCatching { writer.close() }
            releaseCodecs()
            runCatching { workDir.deleteRecursively() }
        } else {
            // لا نغلق المرمِّزات والخيوط ما زالت تستعملها (انهيار native)؛ نسجّل ونترك.
            Log.e(TAG, "threads still alive after abort; codecs left for process cleanup")
        }
        return allDead
    }

    private fun releaseCodecs() {
        runCatching { video?.stop() }
        runCatching { video?.release() }
        runCatching { audio?.stop() }
        runCatching { audio?.release() }
        runCatching { inputSurface?.release() }
        video = null; audio = null; inputSurface = null
    }

    private fun drain(codec: MediaCodec, isVideo: Boolean) {
        val info = MediaCodec.BufferInfo()
        var lastPts = -1L
        try {
            while (true) {
                if (aborted) break
                val i = codec.dequeueOutputBuffer(info, 10_000)
                when {
                    i == MediaCodec.INFO_OUTPUT_FORMAT_CHANGED ->
                        if (isVideo) writer.setVideoFormat(codec.outputFormat) else writer.setAudioFormat(codec.outputFormat)
                    i >= 0 -> {
                        val out = codec.getOutputBuffer(i)
                        val isConfig = (info.flags and MediaCodec.BUFFER_FLAG_CODEC_CONFIG) != 0
                        if (out != null && info.size > 0 && !isConfig) {
                            out.position(info.offset)
                            out.limit(info.offset + info.size)
                            val bytes = ByteArray(info.size)
                            out.get(bytes)
                            var pts = info.presentationTimeUs
                            if (pts <= lastPts) pts = lastPts + 1 // MediaMuxer يشترط تزايداً صارماً
                            lastPts = pts
                            writer.submit(EncodedSample(isVideo, pts, info.flags, bytes))
                        }
                        codec.releaseOutputBuffer(i, false)
                        if ((info.flags and MediaCodec.BUFFER_FLAG_END_OF_STREAM) != 0) break
                    }
                }
            }
        } catch (t: Throwable) {
            Log.e(TAG, "drain failed (video=$isVideo)", t)
            onFatal(t)
        } finally {
            if (isVideo) writer.finishVideo() else writer.finishAudio()
        }
    }

    private fun feedAudio(codec: MediaCodec) {
        val rate = QualityProfile.AUDIO_SAMPLE_RATE
        val chunkFrames = 1024
        val chunk = ByteArray(chunkFrames * 2)
        var record: AudioRecord? = null
        if (micAllowed) {
            try {
                val min = AudioRecord.getMinBufferSize(rate, AudioFormat.CHANNEL_IN_MONO, AudioFormat.ENCODING_PCM_16BIT)
                val r = AudioRecord(
                    MediaRecorder.AudioSource.MIC, rate, AudioFormat.CHANNEL_IN_MONO,
                    AudioFormat.ENCODING_PCM_16BIT, maxOf(min * 2, 8192),
                )
                if (r.state == AudioRecord.STATE_INITIALIZED) {
                    r.startRecording()
                    if (r.recordingState == AudioRecord.RECORDSTATE_RECORDING) record = r else r.release()
                } else r.release()
            } catch (t: Throwable) {
                Log.w(TAG, "mic init failed", t)
            }
        }
        micActive = record != null
        var framesDone = 0L
        val tracker = AudioPtsTracker(rate)
        val ts = AudioTimestamp()
        try {
            while (!stopRequested) {
                var bytes = chunk.size
                if (record != null) {
                    bytes = record.read(chunk, 0, chunk.size)
                    if (bytes < 0) { // خطأ قراءة: نكمل بصمت بدل أن نفقد الفيديو.
                        Log.w(TAG, "AudioRecord.read=$bytes; continuing silent")
                        record.runCatching { stop(); release() }
                        record = null
                        micActive = false
                        continue
                    }
                    if (bytes == 0) continue
                }
                val nowUs = (SystemClock.elapsedRealtimeNanos() - startNs) / 1000
                val frames = bytes / 2
                // مرجع الزمن: طابع العتاد (يُعاد قياسه دورياً فلا انجراف)؛ بدونه المرساة الأولى فقط.
                val hwRef = if (record != null && Build.VERSION.SDK_INT >= 24 &&
                    record.getTimestamp(ts, AudioTimestamp.TIMEBASE_BOOTTIME) == AudioRecord.SUCCESS
                ) ClockMath.chunkStartUs(ts.nanoTime, ts.framePosition, startNs, framesDone, rate) else null
                val ref = hwRef ?: if (framesDone == 0L) ClockMath.audioAnchorUs(nowUs, frames, rate) else null
                val pts = tracker.next(framesDone, ref)
                if (record == null) {
                    // لا ميكروفون: صمت مُسيَّر بالساعة كي تبقى المدة مطابقة للفيديو.
                    val dueUs = pts + ClockMath.framesToUs(frames.toLong(), rate)
                    val waitMs = (dueUs - nowUs) / 1000
                    if (waitMs > 0) Thread.sleep(waitMs)
                    PcmUtil.silence(chunk, bytes)
                } else if (muted) {
                    PcmUtil.silence(chunk, bytes)
                }
                queueInput(codec, chunk, bytes, pts, 0)
                framesDone += frames
            }
        } catch (t: Throwable) {
            Log.e(TAG, "audio feed failed", t)
            onFatal(t)
        } finally {
            record?.runCatching { stop(); release() }
            runCatching {
                val pts = tracker.anchor + ClockMath.framesToUs(framesDone, rate)
                queueInput(codec, chunk, 0, pts, MediaCodec.BUFFER_FLAG_END_OF_STREAM)
            }
        }
    }

    private fun queueInput(codec: MediaCodec, data: ByteArray, len: Int, ptsUs: Long, flags: Int) {
        var tries = 0
        while (true) {
            val i = codec.dequeueInputBuffer(10_000)
            if (i >= 0) {
                val b: ByteBuffer = codec.getInputBuffer(i)!!
                b.clear()
                b.put(data, 0, len)
                codec.queueInputBuffer(i, 0, len, ptsUs, flags)
                return
            }
            if (aborted || ++tries > 300) throw IllegalStateException("audio encoder input stalled")
        }
    }

    /**
     * يوقف ويدمج المقاطع في [finalFile]. آمن للاستدعاء مرة واحدة. إن لم تنتهِ الخيوط في المهلة
     * نقطعها (aborted) وننتظر؛ ولا نغلق المرمِّزات والخيوط حيّة.
     */
    fun stop(): RecordingResult {
        closing = true
        stopRequested = true
        runCatching { renderer.setEncoderSurface(null, 0, 0, 0).get(3, TimeUnit.SECONDS) }
        runCatching { video?.signalEndOfInputStream() }
        audioFeedThread?.join(3000)
        videoThread?.join(5000)
        audioDrainThread?.join(5000)
        val threads = listOfNotNull(audioFeedThread, videoThread, audioDrainThread)
        if (threads.any { it.isAlive }) {
            Log.w(TAG, "threads did not finish in time; aborting")
            aborted = true
            threads.forEach { if (it.isAlive) it.interrupt() }
            threads.forEach { it.join(3000) }
        }
        val entries = writer.close()
        if (threads.none { it.isAlive }) releaseCodecs()
        else Log.e(TAG, "threads still alive; codecs not released to avoid native crash")
        return finalize(entries)
    }

    private fun finalize(entries: List<SegmentEntry>): RecordingResult {
        val r = SegmentConcat.concat(workDir, entries, finalFile)
        workDir.deleteRecursively()
        return RecordingResult(
            finalFile.path, r.durationUs / 1000, finalFile.length(), r.usedSegments, r.skippedSegments + writer.lostSegments, micActive,
        )
    }

    companion object {
        private const val TAG = "RihlaSession"

        /** يسترد مجلد جلسة انقطعت (قتل العملية): يدمج المقاطع المسجَّلة في segments.txt. */
        fun recover(workDir: File, finalFile: File): RecordingResult? {
            val m = File(workDir, SegmentWriter.MANIFEST)
            val entries = if (m.exists()) SegmentManifest.parse(m.readText()).filter { File(workDir, it.name).exists() } else emptyList()
            if (entries.isEmpty()) { workDir.deleteRecursively(); return null }
            val r = SegmentConcat.concat(workDir, entries, finalFile)
            workDir.deleteRecursively()
            return RecordingResult(finalFile.path, r.durationUs / 1000, finalFile.length(), r.usedSegments, r.skippedSegments, false)
        }
    }
}
