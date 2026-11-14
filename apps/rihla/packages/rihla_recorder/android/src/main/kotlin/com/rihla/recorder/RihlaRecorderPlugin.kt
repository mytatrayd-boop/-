package com.rihla.recorder

import android.Manifest
import android.app.Activity
import android.content.Context
import android.content.pm.PackageManager
import android.hardware.display.DisplayManager
import android.os.Handler
import android.os.Looper
import android.os.StatFs
import android.util.Log
import android.util.Size
import android.view.Surface
import androidx.camera.core.CameraSelector
import androidx.camera.core.Preview
import androidx.camera.core.SurfaceRequest
import androidx.camera.core.resolutionselector.AspectRatioStrategy
import androidx.camera.core.resolutionselector.ResolutionSelector
import androidx.camera.core.resolutionselector.ResolutionStrategy
import androidx.camera.lifecycle.ProcessCameraProvider
import androidx.core.content.ContextCompat
import androidx.lifecycle.DefaultLifecycleObserver
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleOwner
import androidx.lifecycle.LifecycleRegistry
import androidx.lifecycle.Observer
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.embedding.engine.plugins.lifecycle.HiddenLifecycleReference
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.view.TextureRegistry
import java.io.File
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import java.util.concurrent.CompletableFuture
import java.util.concurrent.Executors
import java.util.concurrent.TimeUnit

/**
 * إضافة rihla_recorder لأندرويد: CameraX (معاينة إلى GlRenderer) + ترميز MediaCodec + ميكروفون.
 * القنوات: MethodChannel "rihla_recorder" وEventChannel "rihla_recorder/events".
 * الانقطاع (ON_PAUSE للنشاط، خطأ كاميرا، فشل كتابة، مساحة) يوقف التسجيل ويحفظ ما صُوِّر ويبلّغ Dart.
 * لم تُجرَّب على جهاز أو محاكي.
 */
class RihlaRecorderPlugin : FlutterPlugin, ActivityAware, MethodChannel.MethodCallHandler, EventChannel.StreamHandler {
    private val main = Handler(Looper.getMainLooper())
    private val worker = Executors.newSingleThreadExecutor { Thread(it, "rihla-ctl") }

    private var appContext: Context? = null
    private var textures: TextureRegistry? = null
    private var methods: MethodChannel? = null
    private var events: EventChannel? = null
    private var sink: EventChannel.EventSink? = null

    private var activity: Activity? = null
    private var activityLifecycle: Lifecycle? = null

    private val camLifecycle = object : LifecycleOwner {
        val registry = LifecycleRegistry(this)
        override val lifecycle: Lifecycle get() = registry
    }
    private var renderer: GlRenderer? = null
    private var producer: TextureRegistry.SurfaceProducer? = null
    private var cameraProvider: ProcessCameraProvider? = null
    private var preview: Preview? = null
    private var boundCamera: androidx.camera.core.Camera? = null
    private var cameraWanted = false
    private var quality = QualityProfile.P720
    private var camSize = Size(1280, 720)

    @Volatile private var session: RecordingSession? = null
    private var warnBytes = 1L shl 30
    private var stopBytes = 300L shl 20
    private var warned = false

    private val displayListener = object : DisplayManager.DisplayListener {
        override fun onDisplayChanged(displayId: Int) { applyRotation() }
        override fun onDisplayAdded(displayId: Int) {}
        override fun onDisplayRemoved(displayId: Int) {}
    }

    private val lifecycleObserver = object : DefaultLifecycleObserver {
        override fun onPause(owner: LifecycleOwner) {
            // SPEC F4: خروج للخلفية/قفل/مكالمة يوقف ويحفظ ما صُوِّر.
            if (session != null) finishRecording("background")
        }

        override fun onStop(owner: LifecycleOwner) {
            if (cameraWanted) unbindCamera()
        }

        override fun onStart(owner: LifecycleOwner) {
            if (cameraWanted && producer != null) bindCamera(null)
        }
    }

    // ---- FlutterPlugin ----

    override fun onAttachedToEngine(b: FlutterPlugin.FlutterPluginBinding) {
        appContext = b.applicationContext
        textures = b.textureRegistry
        methods = MethodChannel(b.binaryMessenger, "rihla_recorder").also { it.setMethodCallHandler(this) }
        events = EventChannel(b.binaryMessenger, "rihla_recorder/events").also { it.setStreamHandler(this) }
    }

    override fun onDetachedFromEngine(b: FlutterPlugin.FlutterPluginBinding) {
        methods?.setMethodCallHandler(null)
        events?.setStreamHandler(null)
        worker.execute {
            runCatching { session?.let { stopSession(it) } }
            main.post { releaseCamera() }
        }
        appContext = null
    }

    override fun onListen(args: Any?, s: EventChannel.EventSink?) { sink = s }
    override fun onCancel(args: Any?) { sink = null }

    // ---- ActivityAware ----

    override fun onAttachedToActivity(b: ActivityPluginBinding) {
        activity = b.activity
        activityLifecycle = (b.lifecycle as HiddenLifecycleReference).lifecycle.also { it.addObserver(lifecycleObserver) }
        (b.activity.getSystemService(Context.DISPLAY_SERVICE) as DisplayManager).registerDisplayListener(displayListener, main)
    }

    override fun onDetachedFromActivityForConfigChanges() = onDetachedFromActivity()
    override fun onReattachedToActivityForConfigChanges(b: ActivityPluginBinding) = onAttachedToActivity(b)

    override fun onDetachedFromActivity() {
        activityLifecycle?.removeObserver(lifecycleObserver)
        activityLifecycle = null
        activity?.let { (it.getSystemService(Context.DISPLAY_SERVICE) as DisplayManager).unregisterDisplayListener(displayListener) }
        activity = null
    }

    // ---- MethodChannel ----

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "openCamera" -> openCamera(QualityProfile.fromKey(call.argument("quality")), result)
            "closeCamera" -> { cameraWanted = false; unbindCamera(); result.success(null) }
            "start" -> startRecording(call, result)
            "stop" -> stopRequested(result)
            "setMuted" -> { session?.muted = call.argument<Boolean>("muted") == true; result.success(null) }
            "pushMapFrame" -> {
                val w = call.argument<Int>("width") ?: 0
                val h = call.argument<Int>("height") ?: 0
                val bytes = call.argument<ByteArray>("bytes")
                if (bytes == null || bytes.size != w * h * 4) result.error("bad_frame", "RGBA size mismatch", null)
                else { renderer?.setMapFrame(w, h, bytes); result.success(null) }
            }
            "storageInfo" -> {
                val q = QualityProfile.fromKey(call.argument("quality"))
                result.success(
                    mapOf(
                        "freeBytes" to freeBytes(),
                        "bytesPerSecond" to q.bytesPerSecond,
                        "bytesPer10Min" to q.bytesFor(600),
                    ),
                )
            }
            "recoverPending" -> worker.execute { reply(result) { recoverPending() } }
            else -> result.notImplemented()
        }
    }

    // ---- الكاميرا ----

    private fun openCamera(q: QualityProfile, result: MethodChannel.Result) {
        val ctx = appContext ?: return result.error("no_context", null, null)
        if (ContextCompat.checkSelfPermission(ctx, Manifest.permission.CAMERA) != PackageManager.PERMISSION_GRANTED) {
            return result.error("permission_denied", "camera", null)
        }
        quality = q
        cameraWanted = true
        worker.execute {
            try {
                ensureRenderer()
                val size = bindAndAwait()
                main.post {
                    result.success(mapOf("textureId" to producer!!.id(), "width" to size.width, "height" to size.height))
                }
            } catch (t: Throwable) {
                Log.e(TAG, "openCamera failed", t)
                cameraWanted = false
                main.post { unbindCamera(); result.error("camera_unavailable", t.message, null) }
            }
        }
    }

    private fun ensureRenderer() {
        if (renderer != null) return
        val r = GlRenderer()
        renderer = r
        val surfaceFuture = r.start()
        val latch = CompletableFuture<Unit>()
        main.post {
            try {
                val p = textures!!.createSurfaceProducer()
                p.setSize(1280, 720)
                producer = p
                r.setPreviewSurface(p.surface)
                latch.complete(Unit)
            } catch (t: Throwable) { latch.completeExceptionally(t) }
        }
        surfaceFuture.get(5, TimeUnit.SECONDS)
        latch.get(5, TimeUnit.SECONDS)
    }

    private fun bindAndAwait(): Size {
        val done = CompletableFuture<Size>()
        main.post { bindCamera(done) }
        return done.get(8, TimeUnit.SECONDS)
    }

    /** على الخيط الرئيسي. [done] يكتمل بحجم الإطار عند وصول SurfaceRequest. */
    private fun bindCamera(done: CompletableFuture<Size>?) {
        val ctx = appContext ?: return
        val r = renderer ?: return
        val future = ProcessCameraProvider.getInstance(ctx)
        future.addListener({
            try {
                val provider = future.get()
                cameraProvider = provider
                val rs = ResolutionSelector.Builder()
                    .setAspectRatioStrategy(AspectRatioStrategy.RATIO_16_9_FALLBACK_AUTO_STRATEGY)
                    .setResolutionStrategy(
                        ResolutionStrategy(Size(quality.width, quality.height), ResolutionStrategy.FALLBACK_RULE_CLOSEST_HIGHER_THEN_LOWER),
                    ).build()
                val p = Preview.Builder().setResolutionSelector(rs).build()
                p.targetRotation = displayRotation()
                p.setSurfaceProvider(ContextCompat.getMainExecutor(ctx)) { req: SurfaceRequest ->
                    val size = req.resolution
                    camSize = size
                    r.setCameraBufferSize(size.width, size.height)
                    producer?.setSize(size.width, size.height)
                    req.setTransformationInfoListener(ContextCompat.getMainExecutor(ctx)) { info ->
                        r.setRotation(info.rotationDegrees)
                    }
                    val surface: Surface = r.cameraSurface()!!
                    req.provideSurface(surface, ContextCompat.getMainExecutor(ctx)) { }
                    done?.complete(size)
                }
                preview = p
                provider.unbindAll()
                val cam = provider.bindToLifecycle(camLifecycle, CameraSelector.DEFAULT_BACK_CAMERA, p)
                camLifecycle.registry.currentState = Lifecycle.State.STARTED
                boundCamera?.cameraInfo?.cameraState?.removeObserver(cameraStateObserver)
                boundCamera = cam
                cam.cameraInfo.cameraState.observeForever(cameraStateObserver)
            } catch (t: Throwable) {
                done?.completeExceptionally(t) ?: onCameraFailure(t.message)
            }
        }, ContextCompat.getMainExecutor(ctx))
    }

    private val cameraStateObserver = Observer<androidx.camera.core.CameraState> { st ->
        val err = st.error
        if (err != null) {
            Log.w(TAG, "camera error code=${err.code}")
            onCameraFailure("camera_error_${err.code}")
        }
    }

    private fun onCameraFailure(reason: String?) {
        if (session != null) finishRecording("cameraError")
        emit(mapOf("type" to "cameraError", "reason" to reason))
    }

    private fun unbindCamera() {
        boundCamera?.cameraInfo?.cameraState?.removeObserver(cameraStateObserver)
        boundCamera = null
        runCatching { cameraProvider?.unbindAll() }
        camLifecycle.registry.currentState = Lifecycle.State.CREATED
    }

    private fun releaseCamera() {
        cameraWanted = false
        unbindCamera()
        renderer?.release()
        renderer = null
        producer?.release()
        producer = null
    }

    @Suppress("DEPRECATION")
    private fun displayRotation(): Int {
        val a = activity ?: return Surface.ROTATION_90
        return if (android.os.Build.VERSION.SDK_INT >= 30) a.display?.rotation ?: Surface.ROTATION_90
        else a.windowManager.defaultDisplay.rotation
    }
    private fun applyRotation() { preview?.targetRotation = displayRotation() }

    // ---- التسجيل ----

    private fun startRecording(call: MethodCall, result: MethodChannel.Result) {
        val ctx = appContext ?: return result.error("no_context", null, null)
        val r = renderer
        if (r == null || !cameraWanted) return result.error("camera_not_open", null, null)
        if (session != null) return result.error("already_recording", null, null)
        val q = QualityProfile.fromKey(call.argument("quality"))
        val muted = call.argument<Boolean>("muted") == true
        val segSec = (call.argument<Int>("segmentSeconds") ?: 60).coerceIn(5, 600)
        warnBytes = call.argument<Number>("warnFreeBytes")?.toLong() ?: warnBytes
        stopBytes = call.argument<Number>("stopFreeBytes")?.toLong() ?: stopBytes
        worker.execute {
            try {
                if (q != quality) {
                    // دقة مختلفة عمّا فُتحت به المعاينة: نعيد الربط (ثوانٍ قليلة).
                    quality = q
                    bindAndAwait()
                }
                if (freeBytes() < stopBytes) throw IllegalStateException("low_storage")
                val root = rootDir()
                val stamp = SimpleDateFormat("yyyyMMdd_HHmmss", Locale.US).format(Date())
                val mic = ContextCompat.checkSelfPermission(ctx, Manifest.permission.RECORD_AUDIO) == PackageManager.PERMISSION_GRANTED
                val s = RecordingSession(
                    r, q, File(root, "rec_$stamp"), File(root, "rihla_$stamp.mp4"), segSec, mic, muted,
                ) { t -> Log.e(TAG, "fatal", t); finishRecording("writeError") }
                s.start()
                session = s
                warned = false
                main.post { scheduleStorageCheck() }
                main.post { result.success(mapOf("micAvailable" to mic)) }
            } catch (t: Throwable) {
                Log.e(TAG, "start failed", t)
                main.post { result.error("start_failed", t.message, null) }
            }
        }
    }

    private fun stopRequested(result: MethodChannel.Result) {
        val s = session ?: return result.error("not_recording", null, null)
        worker.execute { reply(result) { stopSession(s).toMap() } }
    }

    /** يوقف الجلسة ويُبلّغ Dart بحدث interrupted مع النتيجة (لا يضيع ما صُوِّر). */
    private fun finishRecording(reason: String) {
        val s = session ?: return
        worker.execute {
            if (session !== s) return@execute
            try {
                val res = stopSession(s)
                emit(mapOf("type" to "interrupted", "reason" to reason, "result" to res.toMap()))
            } catch (t: Throwable) {
                Log.e(TAG, "finish after $reason failed", t)
                emit(mapOf("type" to "error", "reason" to reason, "message" to t.message))
            }
        }
    }

    @Synchronized
    private fun stopSession(s: RecordingSession): RecordingResult {
        if (session !== s) throw IllegalStateException("session already stopped")
        try {
            return s.stop()
        } finally {
            session = null
        }
    }

    private fun scheduleStorageCheck() {
        main.postDelayed({
            if (session == null) return@postDelayed
            val free = freeBytes()
            emit(mapOf("type" to "storage", "freeBytes" to free))
            if (StorageMath.isBelow(free, stopBytes)) {
                finishRecording("lowStorage")
                return@postDelayed
            }
            if (!warned && StorageMath.isBelow(free, warnBytes)) {
                warned = true
                emit(mapOf("type" to "lowStorageWarning", "freeBytes" to free))
            }
            scheduleStorageCheck()
        }, 5000)
    }

    private fun recoverPending(): List<Map<String, Any?>> {
        val root = rootDir()
        val out = ArrayList<Map<String, Any?>>()
        if (session != null) return out // لا نلمس مجلد جلسة حيّة.
        root.listFiles { f -> f.isDirectory && f.name.startsWith("rec_") }?.forEach { dir ->
            val final = File(root, "rihla_${dir.name.removePrefix("rec_")}.mp4")
            runCatching { RecordingSession.recover(dir, final) }.onFailure { Log.w(TAG, "recover ${dir.name} failed", it) }
                .getOrNull()?.let { out.add(it.toMap()) }
        }
        return out
    }

    // ---- أدوات ----

    private fun rootDir(): File {
        val ctx = appContext!!
        val base = ctx.getExternalFilesDir(null) ?: ctx.filesDir
        return File(base, "rihla").also { it.mkdirs() }
    }

    private fun freeBytes(): Long = runCatching { StatFs(rootDir().path).availableBytes }.getOrDefault(Long.MAX_VALUE)

    private fun emit(m: Map<String, Any?>) { main.post { sink?.success(m) } }

    private fun <T> reply(result: MethodChannel.Result, block: () -> T) {
        try {
            val v = block()
            main.post { result.success(v) }
        } catch (t: Throwable) {
            Log.e(TAG, "call failed", t)
            main.post { result.error("native_error", t.message, null) }
        }
    }

    private fun RecordingResult.toMap(): Map<String, Any?> = mapOf(
        "path" to path, "durationMs" to durationMs, "sizeBytes" to sizeBytes,
        "segments" to segments, "skippedSegments" to skippedSegments, "hasMic" to hasMic,
    )

    companion object {
        private const val TAG = "RihlaRecorder"
    }
}
