package com.rihla.recorder

import android.graphics.SurfaceTexture
import android.opengl.EGL14
import android.opengl.EGLConfig
import android.opengl.EGLContext
import android.opengl.EGLDisplay
import android.opengl.EGLExt
import android.opengl.EGLSurface
import android.opengl.GLES11Ext
import android.opengl.GLES20
import android.os.Handler
import android.os.HandlerThread
import android.os.SystemClock
import android.util.Log
import android.view.Surface
import java.nio.ByteBuffer
import java.nio.ByteOrder
import java.util.concurrent.CompletableFuture
import java.util.concurrent.atomic.AtomicInteger

/**
 * خيط GL واحد يملك: نسيج الكاميرا (OES)، نسيج الخريطة (RGBA)، سطح معاينة Flutter، وسطح المرمِّز.
 * كل إطار كاميرا يُرسم مرة للمعاينة (كامل الإطار) ومرة للمرمِّز (لوحة 16:9: خريطة يسار، كاميرا يمين).
 * كل الدوال العامة آمنة من أي خيط. لم تُجرَّب على جهاز.
 */
class GlRenderer {
    private val thread = HandlerThread("rihla-gl").also { it.start() }
    private val handler = Handler(thread.looper)

    private var display: EGLDisplay = EGL14.EGL_NO_DISPLAY
    private var context: EGLContext = EGL14.EGL_NO_CONTEXT
    private var config: EGLConfig? = null
    private var pbuffer: EGLSurface = EGL14.EGL_NO_SURFACE

    private var camTex = 0
    private var mapTex = 0
    private var oesProgram = Program()
    private var tex2dProgram = Program()
    private var cameraSt: SurfaceTexture? = null
    private var cameraSurface: Surface? = null

    private var previewSurface: EGLSurface = EGL14.EGL_NO_SURFACE
    private var encSurface: EGLSurface = EGL14.EGL_NO_SURFACE
    private var encW = 0
    private var encH = 0
    private var startNs = 0L

    @Volatile private var rotationDeg = 0
    @Volatile private var camW = 1280
    @Volatile private var camH = 720

    private val pendingMap = java.util.concurrent.atomic.AtomicReference<MapFrame?>(null)
    private var mapW = 0
    private var mapH = 0
    private var mapUploaded = false

    private val stMatrix = FloatArray(16)
    private val quad = ByteBuffer.allocateDirect(8 * 4).order(ByteOrder.nativeOrder()).asFloatBuffer().apply {
        put(floatArrayOf(-1f, -1f, 1f, -1f, -1f, 1f, 1f, 1f)); position(0)
    }

    val framesRendered = AtomicInteger(0)
    val framesEncoded = AtomicInteger(0)
    @Volatile var released = false
        private set

    class MapFrame(val w: Int, val h: Int, val rgba: ByteBuffer)
    private class Program { var id = 0; var pos = 0; var tex = -1; var crop = -1; var sampler = -1 }

    /** ينشئ سياق EGL ونسيج الكاميرا ويعيد Surface تُمرَّر لـCameraX. */
    fun start(): CompletableFuture<Surface> {
        val f = CompletableFuture<Surface>()
        handler.post {
            try {
                initEgl()
                initGl()
                val st = SurfaceTexture(camTex)
                st.setDefaultBufferSize(camW, camH)
                st.setOnFrameAvailableListener({ onFrame() }, handler)
                cameraSt = st
                cameraSurface = Surface(st)
                f.complete(cameraSurface)
            } catch (e: Throwable) {
                f.completeExceptionally(e)
            }
        }
        return f
    }

    fun cameraSurface(): Surface? = cameraSurface

    fun setCameraBufferSize(w: Int, h: Int) {
        camW = w; camH = h
        handler.post { cameraSt?.setDefaultBufferSize(w, h) }
    }

    fun setRotation(deg: Int) { rotationDeg = ((deg % 360) + 360) % 360 }

    fun setMapFrame(w: Int, h: Int, rgba: ByteArray) {
        if (w <= 0 || h <= 0 || rgba.size != w * h * 4) return
        pendingMap.set(MapFrame(w, h, ByteBuffer.wrap(rgba)))
    }

    fun setPreviewSurface(s: Surface?): CompletableFuture<Unit> = post {
        if (previewSurface != EGL14.EGL_NO_SURFACE) {
            EGL14.eglMakeCurrent(display, pbuffer, pbuffer, context)
            EGL14.eglDestroySurface(display, previewSurface)
            previewSurface = EGL14.EGL_NO_SURFACE
        }
        if (s != null) previewSurface = EGL14.eglCreateWindowSurface(display, config, s, intArrayOf(EGL14.EGL_NONE), 0)
    }

    fun setEncoderSurface(s: Surface?, w: Int, h: Int, startBoottimeNs: Long): CompletableFuture<Unit> = post {
        if (encSurface != EGL14.EGL_NO_SURFACE) {
            EGL14.eglMakeCurrent(display, pbuffer, pbuffer, context)
            EGL14.eglDestroySurface(display, encSurface)
            encSurface = EGL14.EGL_NO_SURFACE
        }
        if (s != null) {
            encW = w; encH = h; startNs = startBoottimeNs
            encSurface = EGL14.eglCreateWindowSurface(display, config, s, intArrayOf(EGL14.EGL_NONE), 0)
        }
    }

    fun release() {
        released = true
        post {
            EGL14.eglMakeCurrent(display, EGL14.EGL_NO_SURFACE, EGL14.EGL_NO_SURFACE, EGL14.EGL_NO_CONTEXT)
            if (previewSurface != EGL14.EGL_NO_SURFACE) EGL14.eglDestroySurface(display, previewSurface)
            if (encSurface != EGL14.EGL_NO_SURFACE) EGL14.eglDestroySurface(display, encSurface)
            if (pbuffer != EGL14.EGL_NO_SURFACE) EGL14.eglDestroySurface(display, pbuffer)
            cameraSurface?.release()
            cameraSt?.release()
            if (context != EGL14.EGL_NO_CONTEXT) EGL14.eglDestroyContext(display, context)
            if (display != EGL14.EGL_NO_DISPLAY) EGL14.eglTerminate(display)
            display = EGL14.EGL_NO_DISPLAY
        }.whenComplete { _, _ -> thread.quitSafely() }
    }

    private fun post(block: () -> Unit): CompletableFuture<Unit> {
        val f = CompletableFuture<Unit>()
        if (!thread.isAlive) { f.complete(Unit); return f }
        handler.post {
            try { block(); f.complete(Unit) } catch (e: Throwable) { f.completeExceptionally(e) }
        }
        return f
    }

    // ---- EGL / GL ----

    private fun initEgl() {
        display = EGL14.eglGetDisplay(EGL14.EGL_DEFAULT_DISPLAY)
        check(display != EGL14.EGL_NO_DISPLAY) { "no EGL display" }
        val v = IntArray(2)
        check(EGL14.eglInitialize(display, v, 0, v, 1)) { "eglInitialize failed" }
        val attribs = intArrayOf(
            EGL14.EGL_RED_SIZE, 8, EGL14.EGL_GREEN_SIZE, 8, EGL14.EGL_BLUE_SIZE, 8, EGL14.EGL_ALPHA_SIZE, 8,
            EGL14.EGL_RENDERABLE_TYPE, EGL14.EGL_OPENGL_ES2_BIT,
            EGL_RECORDABLE_ANDROID, 1,
            EGL14.EGL_NONE,
        )
        val configs = arrayOfNulls<EGLConfig>(1)
        val n = IntArray(1)
        check(EGL14.eglChooseConfig(display, attribs, 0, configs, 0, 1, n, 0) && n[0] > 0) { "no EGL config" }
        config = configs[0]
        context = EGL14.eglCreateContext(
            display, config, EGL14.EGL_NO_CONTEXT, intArrayOf(EGL14.EGL_CONTEXT_CLIENT_VERSION, 2, EGL14.EGL_NONE), 0,
        )
        check(context != EGL14.EGL_NO_CONTEXT) { "no EGL context" }
        pbuffer = EGL14.eglCreatePbufferSurface(
            display, config, intArrayOf(EGL14.EGL_WIDTH, 1, EGL14.EGL_HEIGHT, 1, EGL14.EGL_NONE), 0,
        )
        check(EGL14.eglMakeCurrent(display, pbuffer, pbuffer, context)) { "eglMakeCurrent failed" }
    }

    private fun initGl() {
        val t = IntArray(2)
        GLES20.glGenTextures(2, t, 0)
        camTex = t[0]; mapTex = t[1]
        GLES20.glBindTexture(GLES11Ext.GL_TEXTURE_EXTERNAL_OES, camTex)
        setTexParams(GLES11Ext.GL_TEXTURE_EXTERNAL_OES)
        GLES20.glBindTexture(GLES20.GL_TEXTURE_2D, mapTex)
        setTexParams(GLES20.GL_TEXTURE_2D)
        oesProgram = build(
            VERTEX, "#extension GL_OES_EGL_image_external : require\nprecision mediump float;" +
                "varying vec2 vUv; uniform samplerExternalOES uTexture;" +
                "void main(){ gl_FragColor = texture2D(uTexture, vUv); }",
        )
        tex2dProgram = build(
            VERTEX_2D, "precision mediump float; varying vec2 vUv; uniform sampler2D uTexture;" +
                "void main(){ gl_FragColor = texture2D(uTexture, vUv); }",
        )
    }

    private fun setTexParams(target: Int) {
        GLES20.glTexParameteri(target, GLES20.GL_TEXTURE_MIN_FILTER, GLES20.GL_LINEAR)
        GLES20.glTexParameteri(target, GLES20.GL_TEXTURE_MAG_FILTER, GLES20.GL_LINEAR)
        GLES20.glTexParameteri(target, GLES20.GL_TEXTURE_WRAP_S, GLES20.GL_CLAMP_TO_EDGE)
        GLES20.glTexParameteri(target, GLES20.GL_TEXTURE_WRAP_T, GLES20.GL_CLAMP_TO_EDGE)
    }

    private fun build(vs: String, fs: String): Program {
        fun compile(type: Int, src: String): Int {
            val s = GLES20.glCreateShader(type)
            GLES20.glShaderSource(s, src)
            GLES20.glCompileShader(s)
            val ok = IntArray(1)
            GLES20.glGetShaderiv(s, GLES20.GL_COMPILE_STATUS, ok, 0)
            check(ok[0] != 0) { "shader: " + GLES20.glGetShaderInfoLog(s) }
            return s
        }
        val p = Program()
        p.id = GLES20.glCreateProgram()
        GLES20.glAttachShader(p.id, compile(GLES20.GL_VERTEX_SHADER, vs))
        GLES20.glAttachShader(p.id, compile(GLES20.GL_FRAGMENT_SHADER, fs))
        GLES20.glLinkProgram(p.id)
        val ok = IntArray(1)
        GLES20.glGetProgramiv(p.id, GLES20.GL_LINK_STATUS, ok, 0)
        check(ok[0] != 0) { "link: " + GLES20.glGetProgramInfoLog(p.id) }
        p.pos = GLES20.glGetAttribLocation(p.id, "aPos")
        p.tex = GLES20.glGetUniformLocation(p.id, "uTex")
        p.crop = GLES20.glGetUniformLocation(p.id, "uCrop")
        p.sampler = GLES20.glGetUniformLocation(p.id, "uTexture")
        return p
    }

    // ---- الرسم ----

    private fun onFrame() {
        if (released || display == EGL14.EGL_NO_DISPLAY) return
        val st = cameraSt ?: return
        try {
            EGL14.eglMakeCurrent(display, pbuffer, pbuffer, context)
            st.updateTexImage()
        } catch (e: RuntimeException) {
            Log.w(TAG, "updateTexImage failed", e)
            return
        }
        st.getTransformMatrix(stMatrix)
        val tsNs = st.timestamp
        val now = SystemClock.elapsedRealtimeNanos()
        uploadMap()
        val texMat = LayoutMath.mul(stMatrix, LayoutMath.rotateAboutCenter(rotationDeg))
        val quarterTurn = rotationDeg == 90 || rotationDeg == 270
        val dispW = if (quarterTurn) camH else camW
        val dispH = if (quarterTurn) camW else camH
        try {
            if (previewSurface != EGL14.EGL_NO_SURFACE) drawPreview(texMat)
            if (encSurface != EGL14.EGL_NO_SURFACE) drawEncoder(texMat, dispW, dispH, ClockMath.cameraPtsUs(tsNs, now, startNs))
        } catch (e: Throwable) {
            Log.w(TAG, "draw failed", e)
        }
        framesRendered.incrementAndGet()
    }

    private fun uploadMap() {
        val f = pendingMap.getAndSet(null) ?: return
        GLES20.glBindTexture(GLES20.GL_TEXTURE_2D, mapTex)
        GLES20.glPixelStorei(GLES20.GL_UNPACK_ALIGNMENT, 1)
        GLES20.glTexImage2D(GLES20.GL_TEXTURE_2D, 0, GLES20.GL_RGBA, f.w, f.h, 0, GLES20.GL_RGBA, GLES20.GL_UNSIGNED_BYTE, f.rgba)
        mapW = f.w; mapH = f.h; mapUploaded = true
    }

    private fun drawPreview(texMat: FloatArray) {
        if (!EGL14.eglMakeCurrent(display, previewSurface, previewSurface, context)) return
        val size = IntArray(1)
        EGL14.eglQuerySurface(display, previewSurface, EGL14.EGL_WIDTH, size, 0)
        val w = size[0]
        EGL14.eglQuerySurface(display, previewSurface, EGL14.EGL_HEIGHT, size, 0)
        val h = size[0]
        GLES20.glViewport(0, 0, w, h)
        drawCamera(texMat, CropUv(0f, 0f, 1f, 1f))
        EGL14.eglSwapBuffers(display, previewSurface)
    }

    private fun drawEncoder(texMat: FloatArray, dispW: Int, dispH: Int, ptsUs: Long) {
        if (ptsUs < 0) return
        if (!EGL14.eglMakeCurrent(display, encSurface, encSurface, context)) return
        GLES20.glViewport(0, 0, encW, encH)
        GLES20.glClearColor(14 / 255f, 19 / 255f, 22 / 255f, 1f)
        GLES20.glClear(GLES20.GL_COLOR_BUFFER_BIT)
        val half = encW / 2
        // D16: الخريطة يسار (احتواء بلا قص كي يبقى الإسناد)، الكاميرا يمين (قص مركزي).
        if (mapUploaded) {
            val r = LayoutMath.containRect(mapW, mapH, 0, 0, half, encH)
            GLES20.glViewport(r.x, r.y, r.w, r.h)
            drawMap()
        }
        GLES20.glViewport(half, 0, encW - half, encH)
        drawCamera(texMat, LayoutMath.coverCrop(dispW, dispH, encW - half, encH))
        EGLExt.eglPresentationTimeANDROID(display, encSurface, ptsUs * 1000)
        if (EGL14.eglSwapBuffers(display, encSurface)) framesEncoded.incrementAndGet()
    }

    private fun drawCamera(texMat: FloatArray, crop: CropUv) {
        val p = oesProgram
        GLES20.glUseProgram(p.id)
        GLES20.glActiveTexture(GLES20.GL_TEXTURE0)
        GLES20.glBindTexture(GLES11Ext.GL_TEXTURE_EXTERNAL_OES, camTex)
        GLES20.glUniform1i(p.sampler, 0)
        GLES20.glUniformMatrix4fv(p.tex, 1, false, texMat, 0)
        GLES20.glUniform4f(p.crop, crop.u0, crop.v0, crop.u1, crop.v1)
        drawQuad(p)
    }

    private fun drawMap() {
        val p = tex2dProgram
        GLES20.glUseProgram(p.id)
        GLES20.glActiveTexture(GLES20.GL_TEXTURE0)
        GLES20.glBindTexture(GLES20.GL_TEXTURE_2D, mapTex)
        GLES20.glUniform1i(p.sampler, 0)
        drawQuad(p)
    }

    private fun drawQuad(p: Program) {
        GLES20.glEnableVertexAttribArray(p.pos)
        GLES20.glVertexAttribPointer(p.pos, 2, GLES20.GL_FLOAT, false, 8, quad)
        GLES20.glDrawArrays(GLES20.GL_TRIANGLE_STRIP, 0, 4)
        GLES20.glDisableVertexAttribArray(p.pos)
    }

    companion object {
        private const val TAG = "RihlaGl"
        private const val EGL_RECORDABLE_ANDROID = 0x3142
        private const val VERTEX = "attribute vec4 aPos; uniform mat4 uTex; uniform vec4 uCrop; varying vec2 vUv;" +
            "void main(){ gl_Position = aPos; vec2 p = mix(uCrop.xy, uCrop.zw, aPos.xy * 0.5 + 0.5);" +
            "vUv = (uTex * vec4(p, 0.0, 1.0)).xy; }"

        // الخريطة: صفوف RGBA من الأعلى للأسفل، فنقلب v.
        private const val VERTEX_2D = "attribute vec4 aPos; varying vec2 vUv;" +
            "void main(){ gl_Position = aPos; vec2 p = aPos.xy * 0.5 + 0.5; vUv = vec2(p.x, 1.0 - p.y); }"
    }
}
