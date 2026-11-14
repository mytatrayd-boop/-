package com.rihla.recorder

import java.util.PriorityQueue
import kotlin.math.abs
import kotlin.math.cos
import kotlin.math.max
import kotlin.math.min
import kotlin.math.sin

/** جودة التسجيل. المعدلات من ARCHITECTURE 9 (720p ~4Mbps، 1080p ~8Mbps). */
enum class QualityProfile(val key: String, val width: Int, val height: Int, val videoBitrate: Int) {
    P720("p720", 1280, 720, 4_000_000),
    P1080("p1080", 1920, 1080, 8_000_000);

    val mapWidth: Int get() = width / 2
    val bytesPerSecond: Long get() = (videoBitrate + AUDIO_BITRATE) / 8L
    fun bytesFor(seconds: Long): Long = bytesPerSecond * seconds

    companion object {
        const val AUDIO_BITRATE = 96_000
        const val AUDIO_SAMPLE_RATE = 44_100
        const val FPS = 30
        fun fromKey(key: String?): QualityProfile = entries.firstOrNull { it.key == key } ?: P720
    }
}

object StorageMath {
    fun isBelow(freeBytes: Long, thresholdBytes: Long) = freeBytes < thresholdBytes

    /** الدمج يحتاج مساحة بحجم الناتج؛ إن لم تتسع تُحذف المقاطع تدريجياً أثناء الدمج. */
    fun deleteSegmentsProgressively(freeBytes: Long, totalSegmentBytes: Long): Boolean =
        freeBytes < totalSegmentBytes + totalSegmentBytes / 10 + 32L * 1024 * 1024

    /** الدمج لا يحذف المصادر قبل نجاحه: إن لم تتسع المساحة يُرفض الدمج وتبقى المقاطع للاسترداد لاحقاً. */
    fun canMerge(freeBytes: Long, totalSegmentBytes: Long): Boolean = !deleteSegmentsProgressively(freeBytes, totalSegmentBytes)
}

data class RectI(val x: Int, val y: Int, val w: Int, val h: Int)
data class CropUv(val u0: Float, val v0: Float, val u1: Float, val v1: Float)

object LayoutMath {
    /** مستطيل "احتواء" بلا قص داخل المنطقة، مركزياً. */
    fun containRect(srcW: Int, srcH: Int, dstX: Int, dstY: Int, dstW: Int, dstH: Int): RectI {
        if (srcW <= 0 || srcH <= 0) return RectI(dstX, dstY, dstW, dstH)
        val scale = min(dstW.toDouble() / srcW, dstH.toDouble() / srcH)
        val w = (srcW * scale).toInt().coerceIn(1, dstW)
        val h = (srcH * scale).toInt().coerceIn(1, dstH)
        return RectI(dstX + (dstW - w) / 2, dstY + (dstH - h) / 2, w, h)
    }

    /** قص مركزي ("تغطية") في فضاء uv [0,1] لمصدر على منطقة بنسبة مختلفة. */
    fun coverCrop(srcW: Int, srcH: Int, dstW: Int, dstH: Int): CropUv {
        if (srcW <= 0 || srcH <= 0 || dstW <= 0 || dstH <= 0) return CropUv(0f, 0f, 1f, 1f)
        val srcA = srcW.toDouble() / srcH
        val dstA = dstW.toDouble() / dstH
        return if (srcA > dstA) {
            val f = (dstA / srcA).toFloat()
            CropUv((1 - f) / 2, 0f, (1 + f) / 2, 1f)
        } else {
            val f = (srcA / dstA).toFloat()
            CropUv(0f, (1 - f) / 2, 1f, (1 + f) / 2)
        }
    }

    /** y بأصل أعلى-يسار إلى أصل أسفل-يسار (GL). */
    fun glY(topY: Int, h: Int, totalH: Int) = totalH - topY - h

    /** ضرب مصفوفتين 4x4 بترتيب أعمدة (كـandroid.opengl.Matrix.multiplyMM): r = a * b. */
    fun mul(a: FloatArray, b: FloatArray): FloatArray {
        val r = FloatArray(16)
        for (c in 0 until 4) for (row in 0 until 4) {
            var s = 0f
            for (k in 0 until 4) s += a[k * 4 + row] * b[c * 4 + k]
            r[c * 4 + row] = s
        }
        return r
    }

    /** دوران حول مركز uv (0.5,0.5) بالدرجات حول المحور z، ترتيب أعمدة. */
    fun rotateAboutCenter(degrees: Int): FloatArray {
        val rad = Math.toRadians(degrees.toDouble())
        val c = cos(rad).toFloat()
        val s = sin(rad).toFloat()
        // T(0.5) * R * T(-0.5)
        val tx = 0.5f - 0.5f * c + 0.5f * s
        val ty = 0.5f - 0.5f * s - 0.5f * c
        return floatArrayOf(
            c, s, 0f, 0f,
            -s, c, 0f, 0f,
            0f, 0f, 1f, 0f,
            tx, ty, 0f, 1f,
        )
    }

    fun transform(m: FloatArray, x: Float, y: Float): Pair<Float, Float> =
        Pair(m[0] * x + m[4] * y + m[12], m[1] * x + m[5] * y + m[13])
}

/**
 * اختيار دوران صورة الكاميرا (دالة نقية). المحتوى في المخزن باتجاه الحساس؛ الدوران = درجات
 * مع عقارب الساعة لازمة كي تظهر الصورة معتدلة على الشاشة بالاتجاه الحالي (نفس معادلة CameraX).
 * [surfaceRotation] قيم Surface.ROTATION_0..3 (0..3). لم يُتحقق منها على جهاز.
 */
object CameraOrientation {
    fun displayDegrees(surfaceRotation: Int): Int = ((surfaceRotation % 4) + 4) % 4 * 90

    /** خلفية: sensor - display. أمامية (معكوسة): sensor + display. */
    fun relativeRotation(sensorDegrees: Int, surfaceRotation: Int, backFacing: Boolean = true): Int {
        val d = displayDegrees(surfaceRotation)
        val r = if (backFacing) sensorDegrees - d else sensorDegrees + d
        return ((r % 360) + 360) % 360
    }

    /**
     * المصدر الأول: الحساس + اتجاه الشاشة الفعلي (يتبع landscape المعكوس فوراً). عند غيابهما
     * نرجع إلى rotationDegrees من CameraX، وإلا 0. القيمة تُقرَّب لمضاعف 90.
     */
    fun resolve(sensorDegrees: Int?, surfaceRotation: Int?, cameraXDegrees: Int?, backFacing: Boolean = true): Int {
        val raw = if (sensorDegrees != null && surfaceRotation != null) {
            relativeRotation(sensorDegrees, surfaceRotation, backFacing)
        } else cameraXDegrees ?: 0
        return ((Math.round(raw / 90.0).toInt() * 90) % 360 + 360) % 360
    }

    /** قيمة CameraSelector.LENS_FACING_FRONT (0)؛ غير المعروف يُعامل خلفياً (الافتراضي في التطبيق). */
    const val LENS_FACING_FRONT = 0
    fun isBackFacing(lensFacing: Int?): Boolean = lensFacing != LENS_FACING_FRONT

    fun isQuarterTurn(rotation: Int) = rotation == 90 || rotation == 270

    /** أبعاد الصورة بعد الدوران. */
    fun displayedSize(w: Int, h: Int, rotation: Int): Pair<Int, Int> = if (isQuarterTurn(rotation)) Pair(h, w) else Pair(w, h)

    /** مصفوفة العينة النهائية: مصفوفة SurfaceTexture ثم الدوران (تُطبَّق الدوران أولاً على إحداثيات العرض). */
    fun textureMatrix(stMatrix: FloatArray, rotation: Int): FloatArray = LayoutMath.mul(stMatrix, LayoutMath.rotateAboutCenter(rotation))
}

/**
 * محاكاة نقية للمظلل: نقطة خرج مطبّعة (nx,ny) في [0,1] داخل منطقة الرسم -> إحداثيات uv في مخزن الكاميرا.
 * مطابقة لـVERTEX في GlRenderer: p = mix(crop, nx/ny) ثم uv = (stMatrix * R(rotation)) * p.
 */
object SamplePath {
    fun uv(stMatrix: FloatArray, rotation: Int, crop: CropUv, nx: Float, ny: Float): Pair<Float, Float> {
        val px = crop.u0 + (crop.u1 - crop.u0) * nx
        val py = crop.v0 + (crop.v1 - crop.v0) * ny
        return LayoutMath.transform(CameraOrientation.textureMatrix(stMatrix, rotation), px, py)
    }
}

/** سطر تشخيص (logcat، TAG rihla) لقيم الدوران والأبعاد. */
object OrientationLog {
    const val TAG = "rihla"
    fun line(
        event: String, sensor: Int?, displayRot: Int?, cameraX: Int?, computed: Int?,
        srcW: Int, srcH: Int, dstW: Int, dstH: Int,
    ): String {
        val (dw, dh) = CameraOrientation.displayedSize(srcW, srcH, computed ?: 0)
        return "orientation[$event] sensorRotation=$sensor displayRotation=$displayRot " +
            "cameraXRotationDegrees=$cameraX computedRotation=$computed src=${srcW}x$srcH " +
            "displayed=${dw}x$dh target=${dstW}x$dstH"
    }
}

object ClockMath {
    /**
     * طابع إطار الكاميرا بالميكروثانية بساعة التسجيل. إن كان طابع SurfaceTexture بمقياس
     * الوقت الحقيقي (قريباً من الآن بثانية) نستعمله، وإلا (ساعة مستشعر) نستعمل لحظة الرسم.
     */
    fun cameraPtsUs(surfaceTsNs: Long, nowBoottimeNs: Long, startNs: Long): Long {
        val chosen = if (surfaceTsNs > 0 && abs(surfaceTsNs - nowBoottimeNs) < 1_000_000_000L) surfaceTsNs else nowBoottimeNs
        return (chosen - startNs) / 1000
    }

    /** مرساة الصوت: وقت أول قطعة منقوصاً منه مدتها، لا أقل من صفر. */
    fun audioAnchorUs(nowUs: Long, firstChunkFrames: Int, sampleRate: Int): Long =
        max(0L, nowUs - framesToUs(firstChunkFrames.toLong(), sampleRate))

    /**
     * زمن بداية القطعة الحالية بساعة التسجيل من AudioRecord.getTimestamp (BOOTTIME):
     * اللقطة (framePosition عند nanoTime) + فرق الإطارات حتى بداية القطعة.
     */
    fun chunkStartUs(tsNanoTime: Long, tsFramePos: Long, startNs: Long, framesBefore: Long, sampleRate: Int): Long =
        (tsNanoTime - startNs) / 1000 + framesToUs(framesBefore - tsFramePos, sampleRate)

    fun framesToUs(frames: Long, sampleRate: Int): Long = frames * 1_000_000L / sampleRate
    fun audioPtsUs(anchorUs: Long, framesBefore: Long, sampleRate: Int) = anchorUs + framesToUs(framesBefore, sampleRate)
}

object PcmUtil {
    /** كتم: يصفّر البايتات (صمت، فتبقى المدة نفسها). */
    fun silence(buf: ByteArray, len: Int = buf.size) {
        java.util.Arrays.fill(buf, 0, len, 0.toByte())
    }
}

class EncodedSample(val isVideo: Boolean, val ptsUs: Long, val flags: Int, val data: ByteArray) {
    val isKeyFrame: Boolean get() = (flags and KEY_FRAME_FLAG) != 0

    companion object {
        const val KEY_FRAME_FLAG = 1 // MediaCodec.BUFFER_FLAG_KEY_FRAME
    }
}

/**
 * يرتّب عينات الفيديو والصوت بالزمن. لا تُفرَج عينة قبل أن يتجاوز المساران زمنها
 * (العلامة المائية = أصغر آخر زمن للمسارين) كي لا يسبق الصوتُ الفيديو في الملف.
 */
class SampleInterleaver(private val maxQueued: Int = 600) {
    private val queue = PriorityQueue<EncodedSample>(
        compareBy<EncodedSample>({ it.ptsUs }, { if (it.isVideo) 0 else 1 }),
    )
    private var lastVideo = Long.MIN_VALUE
    private var lastAudio = Long.MIN_VALUE
    private var videoDone = false
    private var audioDone = false

    val queued: Int get() = queue.size

    fun add(s: EncodedSample): List<EncodedSample> {
        if (s.isVideo) lastVideo = max(lastVideo, s.ptsUs) else lastAudio = max(lastAudio, s.ptsUs)
        queue.add(s)
        return release()
    }

    fun finishVideo(): List<EncodedSample> { videoDone = true; return release() }
    fun finishAudio(): List<EncodedSample> { audioDone = true; return release() }

    fun flushAll(): List<EncodedSample> {
        val out = ArrayList<EncodedSample>(queue.size)
        while (queue.isNotEmpty()) out.add(queue.poll()!!)
        return out
    }

    private fun release(): List<EncodedSample> {
        val wm = min(if (videoDone) Long.MAX_VALUE else lastVideo, if (audioDone) Long.MAX_VALUE else lastAudio)
        val out = ArrayList<EncodedSample>()
        while (queue.isNotEmpty() && (queue.peek()!!.ptsUs <= wm || queue.size > maxQueued)) out.add(queue.poll()!!)
        return out
    }
}

/** متى يبدأ مقطع جديد: عند أول إطار مفتاحي، ثم عند أول مفتاحي بعد مرور المدة. */
class SegmentPolicy(private val segmentUs: Long) {
    enum class Decision { DROP, WRITE, START_SEGMENT, ROTATE_SEGMENT }

    var segStartUs: Long = -1
        private set
    val started: Boolean get() = segStartUs >= 0

    fun decide(isVideo: Boolean, isKeyFrame: Boolean, ptsUs: Long): Decision {
        if (!started) {
            if (isVideo && isKeyFrame) {
                segStartUs = ptsUs
                return Decision.START_SEGMENT
            }
            return Decision.DROP
        }
        if (isVideo && isKeyFrame && ptsUs - segStartUs >= segmentUs) {
            segStartUs = ptsUs
            return Decision.ROTATE_SEGMENT
        }
        return Decision.WRITE
    }
}

/** يحفظ بداية المقطع المفتوح حالياً (لا تتغير عند قرار ROTATE حتى يُستدعى [markOpened]) فتكون إزاحة المقطع المغلق صحيحة. */
class SegmentTimeline(segmentUs: Long) {
    private val policy = SegmentPolicy(segmentUs)
    private var firstBaseUs = -1L
    var curStartUs = -1L
        private set

    fun decide(isVideo: Boolean, isKeyFrame: Boolean, ptsUs: Long) = policy.decide(isVideo, isKeyFrame, ptsUs)

    /** بعد إغلاق المقطع السابق: المقطع الجديد بدأ عند بداية السياسة. */
    fun markOpened() {
        curStartUs = policy.segStartUs
        if (firstBaseUs < 0) firstBaseUs = curStartUs
    }

    /** إزاحة المقطع المفتوح حالياً عن أول مقطع. */
    fun currentOffsetUs(): Long = curStartUs - firstBaseUs

    fun relativePts(ptsUs: Long): Long = maxOf(0L, ptsUs - curStartUs)
}

data class SegmentEntry(val name: String, val offsetUs: Long)

/** سجل المقاطع المغلقة (سطر لكل مقطع) لاسترداد رحلة انقطعت بقتل العملية. */
object SegmentManifest {
    fun line(e: SegmentEntry) = "${e.name}\t${e.offsetUs}"

    fun parse(text: String): List<SegmentEntry> = text.lineSequence().mapNotNull { l ->
        val p = l.split('\t')
        val off = p.getOrNull(1)?.toLongOrNull()
        if (p.size == 2 && p[0].isNotBlank() && off != null) SegmentEntry(p[0], off) else null
    }.toList()
}

/**
 * أزمنة قطع الصوت مع إعادة مزامنة دورية بدل مرساة وحيدة: إن انحرف الزمن المتوقع (من عدد الإطارات)
 * عن الزمن المرجعي (من AudioRecord.getTimestamp) أكثر من [thresholdUs] تُزاح المرساة. الناتج تزايدي دائماً.
 */
class AudioPtsTracker(private val sampleRate: Int, private val thresholdUs: Long = 40_000) {
    private var anchorUs = -1L
    private var lastPts = -1L
    var resyncs = 0
        private set

    /** [referenceUs] زمن بداية القطعة الحقيقي إن عُرف، وإلا null (لا مزامنة بعد المرساة الأولى). */
    fun next(framesBefore: Long, referenceUs: Long?): Long {
        if (anchorUs < 0) {
            anchorUs = max(0L, (referenceUs ?: 0L) - ClockMath.framesToUs(framesBefore, sampleRate))
        } else if (referenceUs != null) {
            val drift = referenceUs - (anchorUs + ClockMath.framesToUs(framesBefore, sampleRate))
            if (abs(drift) > thresholdUs) { anchorUs += drift; resyncs++ }
        }
        var pts = anchorUs + ClockMath.framesToUs(framesBefore, sampleRate)
        if (pts <= lastPts) pts = lastPts + 1
        lastPts = pts
        return pts
    }

    val anchor: Long get() = max(anchorUs, 0L)
}

/** نقص مساحة (لا يُحتسب محاولة استرداد فاشلة). */
class LowStorageException(message: String) : IllegalStateException(message)

/**
 * سياسة استرداد مجلدات الجلسات المنقطعة. قاعدة ثابتة: لا يُحذف أي مجلد فيه ملفات وسائط أبداً؛
 * يُحذف المجلد الفارغ من الوسائط فقط، وما عداه يُدمج أو يُنقل إلى recovery_failed.
 */
object RecoverPolicy {
    const val MAX_ATTEMPTS = 3
    const val FAILED_DIR = "recovery_failed"

    enum class Action { DELETE_EMPTY, QUARANTINE, RECOVER }

    /** [validSegments] مقاطع السجل الموجودة وغير الفارغة؛ [hasAnyMedia] أي ملف mp4 غير فارغ في المجلد. */
    fun plan(validSegments: Int, hasAnyMedia: Boolean, attempts: Int): Action = when {
        validSegments <= 0 -> if (hasAnyMedia) Action.QUARANTINE else Action.DELETE_EMPTY
        attempts >= MAX_ATTEMPTS -> Action.QUARANTINE
        else -> Action.RECOVER
    }

    fun isStorageFailure(t: Throwable?): Boolean {
        var c = t
        var depth = 0
        while (c != null && depth++ < 8) {
            if (c is LowStorageException) return true
            val m = c.message?.lowercase()
            if (m != null && (m.contains("low_storage") || m.contains("no space left") || m.contains("enospc"))) return true
            c = c.cause
        }
        return false
    }

    /** عدد المحاولات بعد فشل: أخطاء المساحة لا تُحتسب. */
    fun attemptsAfterFailure(previous: Int, t: Throwable?): Int = if (isStorageFailure(t)) previous else previous + 1

    /** اسم وجهة فريد داخل recovery_failed. */
    fun uniqueName(base: String, existing: Set<String>): String {
        if (base !in existing) return base
        var i = 1
        while ("${base}_$i" in existing) i++
        return "${base}_$i"
    }
}
