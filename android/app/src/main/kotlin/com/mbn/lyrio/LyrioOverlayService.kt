package com.mbn.lyrio

import android.app.Dialog
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Intent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.IntentFilter
import android.content.pm.ServiceInfo
import android.content.res.Configuration
import android.graphics.Color
import android.graphics.PixelFormat
import android.graphics.drawable.GradientDrawable
import android.os.Build
import android.os.IBinder
import android.provider.Settings
import android.util.Log
import android.view.Gravity
import android.view.Choreographer
import android.view.Window
import android.view.WindowManager
import io.flutter.FlutterInjector
import io.flutter.embedding.android.FlutterTextureView
import io.flutter.embedding.android.FlutterView
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.dart.DartExecutor

/** Owns a separate Flutter engine and surface, independent of MainActivity. */
class LyrioOverlayService : Service() {
    companion object { var instance: LyrioOverlayService? = null; private const val CHANNEL = "floating_lyrics" }
    private var engine: FlutterEngine? = null
    private var view: FlutterView? = null
    private var dialog: Dialog? = null
    private lateinit var params: WindowManager.LayoutParams
    private var isCompact = false
    private val screenReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            if (intent?.action == Intent.ACTION_SCREEN_OFF) engine?.lifecycleChannel?.appIsPaused()
            else if (intent?.action == Intent.ACTION_SCREEN_ON) engine?.lifecycleChannel?.appIsResumed()
        }
    }
    private val density get() = resources.displayMetrics.density

    override fun onCreate() {
        super.onCreate()
        LyrioCore.init(this)
        instance = this
        val filter = IntentFilter(Intent.ACTION_SCREEN_OFF).apply { addAction(Intent.ACTION_SCREEN_ON) }
        if (Build.VERSION.SDK_INT >= 33) registerReceiver(screenReceiver, filter, Context.RECEIVER_NOT_EXPORTED)
        else registerReceiver(screenReceiver, filter)
    }
    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == "stop") {
            LyrioCore.preferences().edit().putBoolean("overlayEnabled", false).apply()
            stopSelf(); return START_NOT_STICKY
        }
        if (!Settings.canDrawOverlays(this) || (intent == null && !LyrioCore.preferences().getBoolean("overlayEnabled", false))) {
            stopSelf(); return START_NOT_STICKY
        }
        try {
            val notifications = getSystemService(NotificationManager::class.java)
            notifications.createNotificationChannel(NotificationChannel(CHANNEL, "Floating lyrics", NotificationManager.IMPORTANCE_LOW))
            val open = PendingIntent.getActivity(this, 0, Intent(this, MainActivity::class.java), PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT)
            val stop = PendingIntent.getService(this, 1, Intent(this, LyrioOverlayService::class.java).setAction("stop"), PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT)
            val notification = Notification.Builder(this, CHANNEL).setSmallIcon(R.drawable.ic_lyrio_notification)
                .setContentTitle("Lyrio floating lyrics").setContentText("Following your music • tap to open")
                .setContentIntent(open).setOngoing(true).setOnlyAlertOnce(true)
                .addAction(Notification.Action.Builder(null, "Stop", stop).build()).build()
            if (Build.VERSION.SDK_INT >= 34) startForeground(42, notification, ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE)
            else startForeground(42, notification)
            if (view == null) createWindow()
            LyrioCore.overlayRunning = true
            if (LyrioCore.lyrics.optString("status") == "idle") LyrioCore.fetch()
            LyrioCore.preferences().edit().putBoolean("overlayEnabled", true).apply()
        } catch (_: Exception) {
            LyrioCore.serviceError = "Android could not open the floating window. Check overlay and notification permissions."
            stopSelf()
            return START_NOT_STICKY
        }
        return START_STICKY
    }
    private fun createWindow() {
        val loader = FlutterInjector.instance().flutterLoader()
        loader.startInitialization(applicationContext)
        loader.ensureInitializationComplete(applicationContext, null)
        engine = FlutterEngine(this).also {
            NativeBridge.attach(it, this)
            it.dartExecutor.executeDartEntrypoint(DartExecutor.DartEntrypoint(loader.findAppBundlePath(), "overlayMain"))
            it.lifecycleChannel.appIsResumed()
        }
        view = FlutterView(this, FlutterTextureView(this).apply { isOpaque = false }).apply {
            attachToFlutterEngine(engine!!)
            setBackgroundColor(Color.TRANSPARENT)
        }
        // Hosted in a Dialog (not a raw WindowManager view) so the public
        // Window.setBackgroundBlurRadius API can blur only the area behind
        // this window. FLAG_BLUR_BEHIND would blur the whole screen instead.
        val dlg = Dialog(this, R.style.LyrioOverlay).apply {
            setCancelable(false)
            setCanceledOnTouchOutside(false)
        }
        val w = dlg.window ?: run { stopSelf(); return }
        params = WindowManager.LayoutParams(1, 1, WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL or WindowManager.LayoutParams.FLAG_HARDWARE_ACCELERATED,
            PixelFormat.TRANSLUCENT).apply {
            gravity = Gravity.TOP or Gravity.LEFT
            x = LyrioCore.preferences().getInt("windowX", (16 * density).toInt())
            y = LyrioCore.preferences().getInt("windowY", (100 * density).toInt())
        }
        // Type must be set before show() when using a non-Activity context.
        w.attributes = params
        w.setDimAmount(0f)
        w.setWindowAnimations(0)
        dlg.setContentView(view!!)
        dialog = dlg
        sizeAndClamp()
        applyBlur(w)
        w.attributes = params
        dlg.show()
    }
    /** Window-bounded frosted glass (Android 12+). No-op when disabled. */
    private fun applyBlur(w: Window) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S) return
        val settings = LyrioCore.settings()
        // Rounded drawable defines the blur outline; transparent fill keeps
        // Flutter's own background (opacity/gradient/preset) in charge.
        w.setBackgroundDrawable(GradientDrawable().apply {
            shape = GradientDrawable.RECTANGLE
            cornerRadius = (settings.optDouble("radius", 28.0) * density).toFloat()
            setColor(Color.TRANSPARENT)
        })
        val radius = settings.optDouble("blurRadius", 40.0).toInt().coerceIn(0, 100)
        val enabled = settings.optBoolean("blurBehind") && radius > 0
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            val wm = getSystemService(WindowManager::class.java)
            Log.d("LyrioOverlay", "applyBlur enabled=$enabled radius=$radius crossWindowBlur=${wm.isCrossWindowBlurEnabled} sdk=${Build.VERSION.SDK_INT}")
            w.setBackgroundBlurRadius(if (enabled) radius else 0)
        }
    }
    private var movePending = false
    // Absolute drag state: grab offset between finger and window origin.
    private var grabDX = 0f
    private var grabDY = 0f
    private var dragEvents = 0
    // Hot-path cache: move() runs on every touch event, so it must not
    // parse settings JSON or touch disk. Refreshed in sizeAndClamp().
    private var lockedCached = false
    private var densityPx = 0f
    private var maxX = 0
    private var maxY = 0
    private var dragging = false
    private var appliedFrames = 0
    /** Touch events arrive faster than the display refresh. Applying the
     * window layout on every event relayouts the Flutter view dozens of
     * times per second (log: "Sending viewport metrics") and shakes.
     * Coalesce to one apply per frame instead. */
    private fun scheduleMoveApply() {
        if (movePending) return
        movePending = true
        Choreographer.getInstance().postFrameCallback {
            movePending = false
            appliedFrames++
            val w = dialog?.window ?: return@postFrameCallback
            runCatching { w.attributes = params }.onFailure { stopSelf() }
        }
    }
    private fun clampPosition() {
        params.x = params.x.coerceIn(0, maxX)
        params.y = params.y.coerceIn(0, maxY)
    }
    private fun sizeAndClamp() {
        val settings = LyrioCore.settings()
        val metrics = resources.displayMetrics
        densityPx = metrics.density
        params.width = (settings.optDouble("width", 340.0) * density).toInt().coerceIn((160 * density).toInt().coerceAtMost(metrics.widthPixels), metrics.widthPixels)
        params.height = ((if (isCompact) 76.0 else settings.optDouble("height", 310.0)) * density).toInt().coerceIn((64 * density).toInt(), metrics.heightPixels - (40 * density).toInt())
        maxX = (metrics.widthPixels - params.width).coerceAtLeast(0)
        maxY = (metrics.heightPixels - params.height - (32 * density).toInt()).coerceAtLeast(0)
        lockedCached = settings.optBoolean("locked")
        clampPosition()
        params.flags = params.flags and WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON.inv()
        if (settings.optBoolean("keepScreenOn")) params.flags = params.flags or WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON
    }
    fun applySettings() {
        val w = dialog?.window ?: return
        if (view == null) return
        sizeAndClamp()
        applyBlur(w)
        runCatching { w.attributes = params }.onFailure { stopSelf() }
    }
    fun dragStart(x: Float, y: Float) {
        if (view == null || dialog?.window == null || lockedCached) return
        grabDX = x * densityPx - params.x
        grabDY = y * densityPx - params.y
        if (!dragging) {
            dragging = true
            appliedFrames = 0
            dragEvents = 0
            Log.d("LyrioOverlay", "drag start at ${params.x},${params.y}")
        }
    }
    fun dragTo(x: Float, y: Float) {
        if (view == null || dialog?.window == null || lockedCached) return
        if (!dragging) {
            // Start missed (e.g. service restarted mid-gesture): anchor here
            // so the window never jumps.
            dragStart(x, y)
            return
        }
        dragEvents++
        params.x = (x * densityPx - grabDX).toInt()
        params.y = (y * densityPx - grabDY).toInt()
        clampPosition()
        scheduleMoveApply()
    }
    fun endMove() {
        if (view == null) return
        if (movePending) {
            movePending = false
            appliedFrames++
            dialog?.window?.let { w -> runCatching { w.attributes = params } }
        }
        if (dragging) {
            dragging = false
            Log.d("LyrioOverlay", "drag end at ${params.x},${params.y} events=$dragEvents appliedFrames=$appliedFrames")
        }
        LyrioCore.preferences().edit().putInt("windowX", params.x).putInt("windowY", params.y).apply()
    }
    fun compact(value: Boolean) { isCompact = value; applySettings() }
    override fun onConfigurationChanged(newConfig: Configuration) { super.onConfigurationChanged(newConfig); applySettings() }
    override fun onTaskRemoved(rootIntent: Intent?) { /* Service and its engine intentionally outlive the task. */ }
    override fun onDestroy() {
        unregisterReceiver(screenReceiver)
        runCatching { if (dialog?.isShowing == true) dialog?.dismiss() }
        dialog = null
        view?.let { it.detachFromFlutterEngine() }
        view = null
        engine?.lifecycleChannel?.appIsDetached()
        engine?.destroy()
        engine = null
        instance = null
        LyrioCore.overlayRunning = false
        stopForeground(STOP_FOREGROUND_REMOVE)
        super.onDestroy()
    }
    override fun onBind(intent: Intent?): IBinder? = null
}
