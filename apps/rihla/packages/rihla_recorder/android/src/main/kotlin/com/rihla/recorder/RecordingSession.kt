package com.rihla.recorder

import android.media.AudioFormat
import android.media.AudioRecord
import android.media.MediaCodec
import android.media.MediaCodecInfo
import android.media.MediaFormat
import android.media.MediaRecorder
import android.os.SystemClock
import android.util.Log
import java.io.File
import java.nio.ByteBuffer

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
    private val onFatal: (Throwable) -> Unit,
) {
    private val startNs = SystemClock.elapsedRealtimeNanos()
    private val writer = SegmentWriter(workDir, segmentSeconds, onFatal)
    private var video: MediaCodec? = null
    private var audio: MediaCodec? = null
    private var videoThread: Thread? = null
    private var audioFeedThread: Thread? = null
    private var audioDrainThread: Thread? = null
    @Volatile private var stopRequested = false
    @Volatile var micActive = false
        private set

    fun start() {
        workDir.mkdirs()
        val vf = MediaFormat.createVideoFormat(MediaFormat.MIMETYPE_VIDEO_AVC, profile.width, profile.height).apply {
            setInteger(MediaFormat.KEY_COLOR_FORMAT, MediaCodecInfo.CodecCapabilities.COLOR_FormatSurface)
            setInteger(MediaFormat.KEY_BIT_RATE, profile.videoBitrate)
            setInteger(MediaFormat.KEY_FRAME_RATE, QualityProfile.FPS)
            setInteger(MediaFormat.KEY_I_FRAME_INTERVAL, 1)
            setInteger(MediaFormat.KEY_BITRATE_MODE, MediaCodecInfo.EncoderCapabilities.BITRATE_MODE_VBR)
        }
        val v = MediaCodec.createEncoderByType(MediaFormat.MIMETYPE_VIDEO_AVC)
        v.configure(vf, null, null, MediaCodec.CONFIGURE_FLAG_ENCODE)
        val inputSurface = v.createInputSurface()
        v.start()
        video = v

        val af = MediaFormat.createAudioFormat(MediaFormat.MIMETYPE_AUDIO_AAC, QualityProfile.AUDIO_SAMPLE_RATE, 1).apply {
            setInteger(MediaFormat.KEY_AAC_PROFILE, MediaCodecInfo.CodecProfileLevel.AACObjectLC)
            setInteger(MediaFormat.KEY_BIT_RATE, QualityProfile.AUDIO_BITRATE)
            setInteger(MediaFormat.KEY_MAX_INPUT_SIZE, 16 * 1024)
        }
        val a = MediaCodec.createEncoderByType(MediaFormat.MIMETYPE_AUDIO_AAC)
        a.configure(af, null, null, MediaCodec.CONFIGURE_FLAG_ENCODE)
        a.start()
        audio = a

        videoThread = Thread({ drain(v, true) }, "rihla-vdrain").also { it.start() }
        audioDrainThread = Thread({ drain(a, false) }, "rihla-adrain").also { it.start() }
        audioFeedThread = Thread({ feedAudio(a) }, "rihla-afeed").also { it.start() }
        // آخر خطوة: بعدها يبدأ وصول الإطارات للمرمِّز.
        renderer.setEncoderSurface(inputSurface, profile.width, profile.height, startNs).get()
    }

    private fun drain(codec: MediaCodec, isVideo: Boolean) {
        val info = MediaCodec.BufferInfo()
        var lastPts = -1L
        try {
            while (true) {
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
        var anchorUs = -1L
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
                if (anchorUs < 0) anchorUs = ClockMath.audioAnchorUs(nowUs, frames, rate)
                val pts = ClockMath.audioPtsUs(anchorUs, framesDone, rate)
                if (record == null) {
                    // لا ميكروفون: صمت مُسيَّر بالساعة كي تبقى المدة مطابقة للفيديو.
                    val dueUs = ClockMath.audioPtsUs(anchorUs, framesDone + frames, rate)
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
                val pts = ClockMath.audioPtsUs(maxOf(anchorUs, 0), framesDone, rate)
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
            if (++tries > 300) throw IllegalStateException("audio encoder input stalled")
        }
    }

    /** يوقف ويدمج المقاطع في [finalFile]. آمن للاستدعاء مرة واحدة. */
    fun stop(): RecordingResult {
        stopRequested = true
        runCatching { renderer.setEncoderSurface(null, 0, 0, 0).get() }
        runCatching { video?.signalEndOfInputStream() }
        audioFeedThread?.join(3000)
        videoThread?.join(5000)
        audioDrainThread?.join(5000)
        val entries = writer.close()
        runCatching { video?.stop() }
        runCatching { video?.release() }
        runCatching { audio?.stop() }
        runCatching { audio?.release() }
        return finalize(entries)
    }

    private fun finalize(entries: List<SegmentEntry>): RecordingResult {
        val r = SegmentConcat.concat(workDir, entries, finalFile)
        workDir.deleteRecursively()
        return RecordingResult(
            finalFile.path, r.durationUs / 1000, finalFile.length(), r.usedSegments, r.skippedSegments, micActive,
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
