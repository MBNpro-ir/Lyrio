package com.mbn.lyrio

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
import android.graphics.PixelFormat
import android.os.Build
import android.os.IBinder
import android.provider.Settings
import android.view.Gravity
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
    private lateinit var manager: WindowManager
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
        manager = getSystemService(WindowManager::class.java)
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
            setBackgroundColor(android.graphics.Color.TRANSPARENT)
        }
        params = WindowManager.LayoutParams(1, 1, WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL or WindowManager.LayoutParams.FLAG_HARDWARE_ACCELERATED,
            PixelFormat.TRANSLUCENT).apply {
            gravity = Gravity.TOP or Gravity.LEFT
            x = LyrioCore.preferences().getInt("windowX", (16 * density).toInt())
            y = LyrioCore.preferences().getInt("windowY", (100 * density).toInt())
        }
        sizeAndClamp()
        manager.addView(view, params)
    }
    private fun sizeAndClamp() {
        val settings = LyrioCore.settings()
        val metrics = resources.displayMetrics
        params.width = (settings.optDouble("width", 340.0) * density).toInt().coerceIn((160 * density).toInt().coerceAtMost(metrics.widthPixels), metrics.widthPixels)
        params.height = ((if (isCompact) 76.0 else settings.optDouble("height", 310.0)) * density).toInt().coerceIn((64 * density).toInt(), metrics.heightPixels - (40 * density).toInt())
        params.x = params.x.coerceIn(0, (metrics.widthPixels - params.width).coerceAtLeast(0))
        params.y = params.y.coerceIn(0, (metrics.heightPixels - params.height - (32 * density).toInt()).coerceAtLeast(0))
        params.flags = params.flags and WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON.inv()
        if (settings.optBoolean("keepScreenOn")) params.flags = params.flags or WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON
    }
    fun applySettings() {
        if (view == null) return
        sizeAndClamp()
        runCatching { manager.updateViewLayout(view, params) }.onFailure { stopSelf() }
    }
    fun move(dx: Float, dy: Float) {
        if (view == null) return
        if (LyrioCore.settings().optBoolean("locked")) return
        params.x += (dx * density).toInt()
        params.y += (dy * density).toInt()
        applySettings()
        LyrioCore.preferences().edit().putInt("windowX", params.x).putInt("windowY", params.y).apply()
    }
    fun compact(value: Boolean) { isCompact = value; applySettings() }
    override fun onConfigurationChanged(newConfig: Configuration) { super.onConfigurationChanged(newConfig); applySettings() }
    override fun onTaskRemoved(rootIntent: Intent?) { /* Service and its engine intentionally outlive the task. */ }
    override fun onDestroy() {
        unregisterReceiver(screenReceiver)
        view?.let { runCatching { manager.removeView(it) }; it.detachFromFlutterEngine() }
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
